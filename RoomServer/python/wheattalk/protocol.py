"""网络协议常量与 10000 字节定长帧编解码。"""

from __future__ import annotations

FRAME_SIZE = 10000
ENCODING = "utf-8"
BROADCAST_ADDR = "255.255.255.255"
MAX_NAME_CHARS = 15


def encode_frame(text: str) -> bytes:
    """把文本编码为 GameMaker 兼容的 10000 字节定长帧。"""
    payload = text.encode(ENCODING, errors="replace")
    if len(payload) > FRAME_SIZE - 1:
        payload = payload[:FRAME_SIZE - 1]

    frame = payload + b"\x00"
    if len(frame) < FRAME_SIZE:
        frame += b"\x00" * (FRAME_SIZE - len(frame))
    return frame


class MessageBuffer:
    """把 TCP 字节流按 \\x00 切分成消息，并忽略定长帧中的零填充。

    GameMaker 客户端每次发送 10000 字节（字符串 + 空终止符 + 零填充），
    TCP 也可能把一次发送拆成多个分片，因此这里做累积与切分。
    """

    __slots__ = ("_buf",)

    def __init__(self) -> None:
        self._buf = bytearray()

    def feed(self, data: bytes) -> None:
        self._buf.extend(data)

    def pop_messages(self):
        """逐个产出已完整到达的 UTF-8 消息。"""
        while True:
            end = self._buf.find(b"\x00")
            if end < 0:
                return

            raw = bytes(self._buf[:end])
            del self._buf[:end + 1]

            # 跳过定长帧里的连续 0 填充
            while self._buf[:1] == b"\x00":
                del self._buf[:1]

            if not raw:
                continue

            text = raw.decode(ENCODING, errors="replace").strip("\r\n")
            if text:
                yield text
