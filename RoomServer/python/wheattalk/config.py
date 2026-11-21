"""配置文件加载与校验。"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

DEFAULT_ROOM_NAME = "ChatRoom 聊天室"
DEFAULT_PORT = 6510
DEFAULT_BROADCAST_PORT = 6511
DEFAULT_INTERVAL = 1.0
DEFAULT_MAX_USERS = 0


@dataclass
class ServerConfig:
    room_name: str = DEFAULT_ROOM_NAME
    port: int = DEFAULT_PORT
    broadcast_port: int = DEFAULT_BROADCAST_PORT
    interval: float = DEFAULT_INTERVAL
    max_users: int = DEFAULT_MAX_USERS


def default_config_path() -> Path:
    # wheattalk/config.py -> ChatRoomServer/config.json
    return Path(__file__).resolve().parent.parent / "config.json"


def _as_int(value, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _as_float(value, default: float) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def load_config(path: Optional[str] = None) -> ServerConfig:
    """读取 config.json；字段缺失或非法时回退到默认值。"""
    cfg_path = Path(path) if path else default_config_path()

    if not cfg_path.exists():
        if path:
            print("[配置] 找不到 {}，使用默认配置".format(cfg_path))
        return ServerConfig()

    try:
        data = json.loads(cfg_path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("配置根节点必须是 JSON 对象")
    except (OSError, ValueError) as exc:
        print("[配置] 读取 {} 失败：{}；使用默认配置".format(cfg_path, exc))
        return ServerConfig()

    room_name = str(data.get("room_name", DEFAULT_ROOM_NAME)).strip()
    if not room_name:
        room_name = DEFAULT_ROOM_NAME

    port = _as_int(data.get("port", DEFAULT_PORT), DEFAULT_PORT)
    broadcast_port = _as_int(
        data.get("broadcast_port", DEFAULT_BROADCAST_PORT), DEFAULT_BROADCAST_PORT
    )
    interval = _as_float(data.get("interval", DEFAULT_INTERVAL), DEFAULT_INTERVAL)
    max_users = _as_int(data.get("max_users", DEFAULT_MAX_USERS), DEFAULT_MAX_USERS)

    if not (1 <= port <= 65535):
        port = DEFAULT_PORT
    if not (1 <= broadcast_port <= 65535):
        broadcast_port = DEFAULT_BROADCAST_PORT
    if interval < 0.2:
        interval = 0.2
    if max_users < 0:
        max_users = 0

    return ServerConfig(room_name, port, broadcast_port, interval, max_users)
