"""命令行入口：从 config.json 读取配置，命令行参数可覆盖。"""

from __future__ import annotations

import argparse

from .config import load_config
from .server import ChatRoomServer


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
    description="ChatRoom 聊天室独立服务器（与 GameMaker 客户端兼容）"
    )
    parser.add_argument("--config", "-c", default=None,
                        help="配置文件路径（默认：ChatRoomServer/config.json）")
    parser.add_argument("--name", "-n", default=None,
                        help="聊天室名称（覆盖配置）")
    parser.add_argument("--port", "-p", type=int, default=None,
                        help="TCP 监听端口（覆盖配置）")
    parser.add_argument("--broadcast-port", "-b", type=int, default=None,
                        help="UDP 广播端口（覆盖配置）")
    parser.add_argument("--interval", "-i", type=float, default=None,
                        help="发现广播间隔秒数（覆盖配置）")
    parser.add_argument("--max-users", "-m", type=int, default=None,
                        help="人数上限，0 表示不限制（覆盖配置）")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    cfg = load_config(args.config)

    if args.name is not None and args.name.strip():
        cfg.room_name = args.name.strip()
    if args.port is not None:
        cfg.port = args.port
    if args.broadcast_port is not None:
        cfg.broadcast_port = args.broadcast_port
    if args.interval is not None:
        cfg.interval = max(0.2, args.interval)
    if args.max_users is not None:
        cfg.max_users = max(0, args.max_users)

    if not (1 <= cfg.port <= 65535):
        cfg.port = 6510
    if not (1 <= cfg.broadcast_port <= 65535):
        cfg.broadcast_port = 6511

    limit = "不限" if cfg.max_users <= 0 else str(cfg.max_users)
    print("[配置] 房间名称={}  TCP={}  UDP={}  人数上限={}".format(
        cfg.room_name, cfg.port, cfg.broadcast_port, limit))

    server = ChatRoomServer(
        cfg.room_name,
        port=cfg.port,
        broadcast_port=cfg.broadcast_port,
        interval=cfg.interval,
        max_users=cfg.max_users,
    )
    server.start()
