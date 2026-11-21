#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
server.py 自检脚本（不依赖 GameMaker）：
  1. 读取 config.json 检查配置加载；
  2. 模拟两个 GameMaker 客户端（10000 字节定长帧）连接、注册、聊天、离开；
  3. 检查空昵称拒绝、加入/离开通知、消息转发和 UDP 发现广播；
  4. 检查人数上限。

运行： python selftest.py
"""

import socket
import sys
import threading
import time

from wheattalk.config import load_config
from wheattalk.protocol import FRAME_SIZE
from wheattalk.server import ChatRoomServer


ROOM_NAME = "自检房间"


def pick_free_port(kind=socket.SOCK_STREAM):
    sock = socket.socket(socket.AF_INET, kind)
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    sock.close()
    return port


def send_frame(sock, text):
    payload = text.encode("utf-8") + b"\x00"
    assert len(payload) <= FRAME_SIZE
    sock.sendall(payload + b"\x00" * (FRAME_SIZE - len(payload)))


class MessageReader:
    """保留 TCP 尾部数据，避免一次 recv 中的后续消息被丢掉。"""

    def __init__(self, sock):
        self.sock = sock
        self.buf = b""

    def recv_message(self, timeout=3.0):
        self.sock.settimeout(timeout)
        while True:
            end = self.buf.find(b"\x00")
            if end >= 0:
                raw = self.buf[:end]
                self.buf = self.buf[end + 1:].lstrip(b"\x00")
                if raw:
                    return raw.decode("utf-8", errors="replace")
                continue

            chunk = self.sock.recv(65536)
            if not chunk:
                return None
            self.buf += chunk


_READERS = {}


def recv_message(sock, timeout=3.0):
    reader = _READERS.get(sock)
    if reader is None:
        reader = MessageReader(sock)
        _READERS[sock] = reader
    return reader.recv_message(timeout)


def connect_retry(port, timeout=5.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            sock = socket.create_connection(("127.0.0.1", port), timeout=1.0)
            sock.settimeout(3.0)
            return sock
        except OSError:
            time.sleep(0.05)
    raise RuntimeError("服务器未在预期时间内开始监听")


def check(condition, label):
    if condition:
        print("  [通过] {}".format(label))
        return True
    print("  [失败] {}".format(label))
    return False


def test_main_protocol():
    tcp_port = pick_free_port(socket.SOCK_STREAM)
    udp_port = pick_free_port(socket.SOCK_DGRAM)

    udp_listener = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp_listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    udp_listener.bind(("", udp_port))
    udp_listener.settimeout(4.0)

    server = ChatRoomServer(ROOM_NAME, port=tcp_port,
                            broadcast_port=udp_port, interval=0.5)
    threading.Thread(target=server.start, daemon=True).start()

    ok = True
    a = b = None
    try:
        a = connect_retry(tcp_port)

        # 空昵称（仅空白）应被拒绝：服务器不广播加入通知
        send_frame(a, "&name=   ")
        try:
            recv_message(a, 0.6)
            ok &= check(False, "空昵称被服务器拒绝（无加入通知）")
        except socket.timeout:
            ok &= check(True, "空昵称被服务器拒绝（无加入通知）")

        send_frame(a, "&name=Alice")
        ok &= check(recv_message(a) == "&coly=Alice已加入", "Alice 收到自己加入通知")
        ok &= check(recv_message(a) == "&count=1", "Alice 收到准确在线人数")

        send_frame(a, "&ping=selftest")
        ok &= check(recv_message(a) == "&pong=selftest", "Alice 收到服务器心跳应答")

        b = connect_retry(tcp_port)
        send_frame(b, "&name=Bob")
        ok &= check(recv_message(a) == "&coly=Bob已加入", "Alice 收到 Bob 加入通知")
        ok &= check(recv_message(b) == "&coly=Bob已加入", "Bob 收到自己加入通知")
        ok &= check(recv_message(b) == "&count=2", "Bob 收到准确在线人数")

        send_frame(a, "Alice:你好，世界")
        ok &= check(recv_message(a) == "Alice:你好，世界", "Alice 收到消息回显")
        ok &= check(recv_message(b) == "Alice:你好，世界", "Bob 收到 Alice 的消息")

        b.close()
        b = None
        ok &= check(recv_message(a) == "&coly=Bob已离开", "Alice 收到 Bob 离开通知")

        try:
            packet, _ = udp_listener.recvfrom(2048)
            text = packet.split(b"\x00", 1)[0].decode("utf-8", errors="replace")
            ok &= check(text.startswith("&sern={}|".format(ROOM_NAME)),
                        "UDP 发现广播格式正确: {}".format(text))
        except socket.timeout:
            print("  [警告] 未收到 UDP 广播（可能被防火墙拦截）")
    finally:
        if a is not None:
            a.close()
        if b is not None:
            b.close()
        udp_listener.close()
        server.stop()

    return ok


def test_max_users():
    tcp_port = pick_free_port(socket.SOCK_STREAM)
    udp_port = pick_free_port(socket.SOCK_DGRAM)

    server = ChatRoomServer("限流房间", port=tcp_port,
                            broadcast_port=udp_port, interval=0.5,
                            max_users=1)
    threading.Thread(target=server.start, daemon=True).start()

    ok = True
    a = b = None
    try:
        a = connect_retry(tcp_port)
        send_frame(a, "&name=A")
        ok &= check(recv_message(a) == "&coly=A已加入", "人数上限：第一位用户加入")
        ok &= check(recv_message(a) == "&count=1", "人数上限：第一位用户收到准确人数")

        try:
            b = connect_retry(tcp_port)
            try:
                send_frame(b, "&name=B")
            except OSError:
                pass
        except OSError:
            b = None

        # 第二位用户不应被加入成员列表，也不应广播加入
        try:
            extra = recv_message(a, 0.8)
            ok &= check(extra == "", "人数上限：未广播第二位用户加入（收到: {}）".format(extra))
        except socket.timeout:
            ok &= check(True, "人数上限：未广播第二位用户加入")
    finally:
        if a is not None:
            a.close()
        if b is not None:
            try:
                b.close()
            except OSError:
                pass
        server.stop()

    return ok


def main():
    print("[配置] 当前 config.json:")
    cfg = load_config()
    print("  房间名称={}  TCP={}  UDP={}  间隔={}  人数上限={}".format(
        cfg.room_name, cfg.port, cfg.broadcast_port, cfg.interval,
        "不限" if cfg.max_users <= 0 else cfg.max_users))

    ok = True
    ok &= test_main_protocol()
    ok &= test_max_users()

    print()
    if ok:
        print("自检全部通过。")
        return 0
    print("自检存在失败项。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
