"""Utility helpers for altitest."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def make_run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def ensure_dir(path: str) -> None:
    Path(path).mkdir(parents=True, exist_ok=True)


def is_subpath(path: str, root: str) -> bool:
    try:
        Path(path).resolve().relative_to(Path(root).resolve())
        return True
    except ValueError:
        return False


def repo_relpath(path: str, root: str) -> str:
    return os.path.relpath(Path(path).resolve(), Path(root).resolve())

