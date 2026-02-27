"""Utility helpers for altitest."""

from __future__ import annotations

import errno
import fcntl
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import TextIO


class ConcurrentRunError(RuntimeError):
    def __init__(self, lock_path: str, holder: str = "") -> None:
        super().__init__(f"another run is already holding lock: {lock_path}")
        self.lock_path = lock_path
        self.holder = holder


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


def acquire_run_lock(lock_path: str, holder: str) -> TextIO:
    lock_file = Path(lock_path).resolve()
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    fp = lock_file.open("a+", encoding="utf-8")
    try:
        try:
            fcntl.flock(fp.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            if exc.errno in (errno.EACCES, errno.EAGAIN):
                fp.seek(0)
                current_holder = fp.read().strip()
                raise ConcurrentRunError(str(lock_file), current_holder) from exc
            raise

        fp.seek(0)
        fp.truncate()
        fp.write(holder.strip() + "\n")
        fp.flush()
        return fp
    except Exception:
        fp.close()
        raise


def release_run_lock(lock_fp: TextIO) -> None:
    try:
        lock_fp.seek(0)
        lock_fp.truncate()
        lock_fp.flush()
    except Exception:
        pass
    try:
        fcntl.flock(lock_fp.fileno(), fcntl.LOCK_UN)
    finally:
        lock_fp.close()
