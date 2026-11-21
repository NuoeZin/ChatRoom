"""聊天室服务器核心实现。"""

from __future__ import annotations

import secrets
import socket
import threading

from .protocol import (
    BROADCAST_ADDR,
    ENCODING,
    FRAME_SIZE,
    MAX_NAME_CHARS,
    MessageBuffer,
    encode_frame,
)

_ID_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


class Client:
    """一个已连接的客户端。"""

    __slots__ = ("sock", "addr", "name", "buf", "send_lock")

    def __init__(self, sock, addr):
        self.sock = sock
        self.addr = addr
        self.name = None
        self.buf = MessageBuffer()
        self.send_lock = threading.Lock()


class ChatRoomServer:
    """局域网聊天室服务器。"""

    def __init__(self, room_name, port=6510, broadcast_port=6511,
                 interval=1.0, max_users=0):
        self.room_name = room_name
        self.port = port
        self.broadcast_port = broadcast_port
        self.interval = max(0.2, float(interval))
        self.max_users = max(0, int(max_users))
        self.room_id = "".join(secrets.choice(_ID_CHARS) for _ in range(20))

        self.clients = []                 # list[Client]，按加入顺序
        self.lock = threading.RLock()
        self.running = True
        self._stopped = False

        self.tcp_socket = None
        self.udp_socket = None
        self._discovery_event = threading.Event()
        self._print_lock = threading.Lock()

    # ==================== 启动 / 停止 ====================

    def start(self):
        """启动服务器并阻塞在连接循环中（Ctrl+C 退出）。"""
        self._start_tcp()
        self._start_udp()

        threading.Thread(
            target=self._broadcast_loop, daemon=True, name="discovery"
        ).start()

        self._print_banner()

        try:
            self._accept_loop()
        except KeyboardInterrupt:
            self._log("\n正在关闭服务器...")
        finally:
            self.stop()

    def stop(self):
        """关闭所有套接字并结束线程。"""
        if self._stopped:
            return
        self._stopped = True
        self.running = False
        self._discovery_event.set()

        with self.lock:
            clients = list(self.clients)
            self.clients.clear()

        for client in clients:
            try:
                client.sock.close()
            except OSError:
                pass

        for sock in (self.tcp_socket, self.udp_socket):
            if sock is not None:
                try:
                    sock.close()
                except OSError:
                    pass

        self._log("服务器已关闭。")

    def _start_tcp(self):
        self.tcp_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.tcp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            self.tcp_socket.bind(("0.0.0.0", self.port))
        except OSError as exc:
            print("[错误] 无法绑定 TCP 端口 {}：{}".format(self.port, exc))
            print("提示：可能已有服务器（GameMaker 或另一个 server.py）占用该端口。")
            raise SystemExit(1)
        self.tcp_socket.listen(20)

    def _start_udp(self):
        self.udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.udp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    def _print_banner(self):
        limit = "不限" if self.max_users <= 0 else str(self.max_users)
        print()
        print("=" * 58)
        print("            ChatRoom 聊天室服务器")
        print("  房间名称 : {}".format(self.room_name))
        print("  TCP 端口 : {}   (客户端连接)".format(self.port))
        print("  UDP 端口 : {}   (局域网广播)".format(self.broadcast_port))
        print("  人数上限 : {}".format(limit))
        for ip in _local_ipv4_addresses():
            print("  本机地址 : {}".format(ip))
        print("=" * 58)
        print("等待客户端连接... (Ctrl+C 退出)")
        print()

    # ==================== 连接处理 ====================

    def _accept_loop(self):
        while self.running:
            try:
                conn, addr = self.tcp_socket.accept()
            except OSError:
                break

            client = Client(conn, addr)
            with self.lock:
                full = self.max_users > 0 and len(self.clients) >= self.max_users
                if not full:
                    self.clients.append(client)

            if full:
                self._log("[拒绝] {}:{}  人数已达上限 {}".format(
                    addr[0], addr[1], self.max_users))
                try:
                    conn.close()
                except OSError:
                    pass
                continue

            conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            self._log("[连接] {}:{}".format(addr[0], addr[1]))
            threading.Thread(
                target=self._client_loop, args=(client,), daemon=True,
                name="client-{}".format(addr[1])
            ).start()

            # 人数变化：立即补发一次发现广播
            self._discovery_event.set()

    def _client_loop(self, client):
        try:
            while self.running:
                try:
                    data = client.sock.recv(65536)
                except OSError:
                    break
                if not data:
                    break

                client.buf.feed(data)
                for text in client.buf.pop_messages():
                    self._handle_message(client, text)
        finally:
            self._drop_client(client, "连接结束")

    def _handle_message(self, client, text):
        if text.startswith("&ping="):
            # 心跳应答长度可变，避免在弱网下反复发送 10 KB 填充帧
            self._send_to_client(client, "&pong=" + text[6:])
            return

        if text.startswith("&name="):
            if client.name is not None:
                return  # 已注册过昵称，忽略重复注册

            name = text[6:].strip()
            if not name:
                return
            if len(name) > MAX_NAME_CHARS:
                name = name[:12] + "..."

            with self.lock:
                client.name = name
                online = len(self.clients)

            self._log("[加入] {} ({})  在线 {} 人".format(name, client.addr[0], online))
            self._print_members()
            self._broadcast("&coly={}已加入".format(name))
            # 让后加入者立即获得准确人数，而不是从自己的加入通知开始估算
            self._send_to_client(client, "&count={}".format(online))
            self._discovery_event.set()
            return

        self._log("[消息] {}".format(text))
        self._broadcast(text)

    def _send_to_client(self, client, text):
        """向单个客户端发送一条 NUL 结尾的消息。"""
        payload = text.encode(ENCODING, errors="replace")[:FRAME_SIZE - 1]
        frame = payload + b"\x00"

        try:
            with client.send_lock:
                client.sock.sendall(frame)
        except OSError:
            self._drop_client(client, "发送失败")

    def _broadcast(self, text):
        """向所有客户端发送一条 10000 字节定长帧。"""
        frame = encode_frame(text)

        with self.lock:
            clients = list(self.clients)

        dead = []
        for client in clients:
            try:
                with client.send_lock:
                    client.sock.sendall(frame)
            except OSError:
                dead.append(client)

        for client in dead:
            self._drop_client(client, "发送失败")

    def _drop_client(self, client, reason):
        with self.lock:
            if client not in self.clients:
                return
            self.clients.remove(client)
            name = client.name
            addr = client.addr
            online = len(self.clients)

        try:
            client.sock.close()
        except OSError:
            pass

        if name:
            self._log("[离开] {} ({}) - {}  在线 {} 人".format(
                name, addr[0], reason, online))
            self._print_members()
            self._broadcast("&coly={}已离开".format(name))
        else:
            self._log("[断开] {}:{} - {}".format(addr[0], addr[1], reason))

        self._discovery_event.set()

    # ==================== 发现广播 ====================

    def _broadcast_loop(self):
        self._send_discovery()  # 启动后立即广播一次
        while self.running:
            # 到达间隔或被成员变化唤醒
            self._discovery_event.wait(self.interval)
            self._discovery_event.clear()
            if not self.running:
                break
            self._send_discovery()

    def _send_discovery(self):
        with self.lock:
            online = len(self.clients)

        data = "&sern={}|{}|{}|{}".format(
            self.room_name, online, self.port, self.room_id
        ).encode(ENCODING) + b"\x00"
        try:
            self.udp_socket.sendto(data, (BROADCAST_ADDR, self.broadcast_port))
        except OSError as exc:
            self._log("[广播] 发送失败：{}".format(exc))

    # ==================== 控制台输出 ====================

    def _print_members(self):
        with self.lock:
            members = [(c.name, c.addr[0]) for c in self.clients if c.name]

        with self._print_lock:
            print("--- 在线成员 ({}) ---".format(len(members)))
            for index, (name, ip) in enumerate(members, 1):
                print("  {:2d}. {}  ({})".format(index, name, ip))
            print("-" * 30, flush=True)

    def _log(self, message):
        with self._print_lock:
            print(message, flush=True)


def _local_ipv4_addresses():
    """获取本机局域网 IPv4 地址，便于用户告知其他机器。"""
    addresses = set()
    try:
        host = socket.gethostname()
        for info in socket.getaddrinfo(host, None, socket.AF_INET):
            addresses.add(info[4][0])
    except OSError:
        pass
    addresses.discard("127.0.0.1")
    return sorted(addresses)
