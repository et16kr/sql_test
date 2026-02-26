"""Port health checks for Altibase availability."""

from __future__ import annotations

import socket

from .config import DEFAULT_PORT, DEFAULT_PORT_CHECK_TIMEOUT_SEC



def resolve_port(env: dict) -> int:
    raw = env.get("ALTIBASE_PORT_NO", "")
    if not raw:
        return DEFAULT_PORT
    try:
        port = int(raw)
    except ValueError:
        return DEFAULT_PORT
    if not (1 <= port <= 65535):
        return DEFAULT_PORT
    return port



def is_port_open(host: str, port: int, timeout_sec: float = DEFAULT_PORT_CHECK_TIMEOUT_SEC) -> bool:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(timeout_sec)
    try:
        sock.connect((host, port))
        return True
    except OSError:
        return False
    finally:
        sock.close()

