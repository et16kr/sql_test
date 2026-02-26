"""Execution helpers for SYSTEM and is commands."""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Tuple

from .directive_parser import DirectiveAction


@dataclass
class CommandResult:
    returncode: int
    stdout: str
    stderr: str
    timed_out: bool = False
    error: str = ""


def _to_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    if isinstance(value, str):
        return value
    return str(value)



def run_shell_command(command: str, env: Dict[str, str], timeout_sec: int) -> CommandResult:
    try:
        proc = subprocess.run(
            command,
            shell=True,
            executable="/bin/bash",
            capture_output=True,
            text=True,
            env=env,
            timeout=timeout_sec,
        )
        return CommandResult(returncode=proc.returncode, stdout=_to_text(proc.stdout), stderr=_to_text(proc.stderr))
    except subprocess.TimeoutExpired as e:
        return CommandResult(
            returncode=124,
            stdout=_to_text(e.stdout),
            stderr=_to_text(e.stderr),
            timed_out=True,
            error="timeout",
        )
    except Exception as e:  # pragma: no cover - defensive
        return CommandResult(returncode=1, stdout="", stderr="", error=str(e))



def run_system_actions(actions: Iterable[DirectiveAction], base_env: Dict[str, str], timeout_sec: int) -> Tuple[bool, CommandResult]:
    last = CommandResult(returncode=0, stdout="", stderr="")
    for action in actions:
        env = dict(base_env)
        env.update(action.env)
        last = run_shell_command(action.command, env, timeout_sec)
        if last.timed_out or last.error or last.returncode != 0:
            return False, last
    return True, last



def execute_is(sql_file: str, timeout_sec: int, env: Dict[str, str]) -> CommandResult:
    command = ["is", "-f", sql_file]
    try:
        proc = subprocess.run(command, capture_output=True, text=True, env=env, timeout=timeout_sec)
        return CommandResult(returncode=proc.returncode, stdout=_to_text(proc.stdout), stderr=_to_text(proc.stderr))
    except subprocess.TimeoutExpired as e:
        return CommandResult(
            returncode=124,
            stdout=_to_text(e.stdout),
            stderr=_to_text(e.stderr),
            timed_out=True,
            error="timeout",
        )
    except FileNotFoundError as e:
        return CommandResult(returncode=127, stdout="", stderr="", error=str(e))
    except Exception as e:  # pragma: no cover - defensive
        return CommandResult(returncode=1, stdout="", stderr="", error=str(e))



def write_text(path: str, text: object) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", encoding="utf-8") as f:
        f.write(_to_text(text))
