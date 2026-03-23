"""Execution helpers for SYSTEM and is commands."""

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Optional, Set, Tuple

from .directive_parser import DirectiveAction


@dataclass
class CommandResult:
    returncode: int
    stdout: str
    stderr: str
    timed_out: bool = False
    error: str = ""


_START_CMD_RE = re.compile(
    r"^(?P<indent>\s*)(?P<cmd>START)(?P<ws>\s+)(?P<target>\"[^\"]+\"|'[^']+'|[^\s;]+)(?P<rest>.*)$",
    re.IGNORECASE,
)
_AT_CMD_RE = re.compile(
    r"^(?P<indent>\s*)(?P<cmd>@@|@)(?P<target>\"[^\"]+\"|'[^']+'|[^\s;]+)(?P<rest>.*)$"
)


def _to_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    if isinstance(value, str):
        return value
    return str(value)


def ensure_script_trailing_newline(text: str) -> str:
    if text and not text.endswith("\n"):
        return f"{text}\n"
    return text


def build_env(base_env: Dict[str, str], overrides: Dict[str, str], unset_env_keys: Optional[Set[str]] = None) -> Dict[str, str]:
    env = dict(base_env)
    for key in unset_env_keys or set():
        env.pop(key, None)
    env.update(overrides)
    return env


def _unquote_target(raw_target: str) -> Tuple[str, str]:
    if len(raw_target) >= 2 and raw_target[0] == raw_target[-1] and raw_target[0] in {"'", '"'}:
        return raw_target[1:-1], raw_target[0]
    return raw_target, ""


def _quote_target(target: str, quote_char: str) -> str:
    if quote_char:
        return f"{quote_char}{target}{quote_char}"
    return target


def _resolve_relative_include(source_dir: Path, target: str) -> Optional[Path]:
    if not target or target.startswith("/") or target.startswith("?"):
        return None
    candidate = (source_dir / target).resolve()
    if candidate.exists():
        return candidate
    if not candidate.suffix:
        candidate_with_sql = candidate.with_suffix(".sql")
        if candidate_with_sql.exists():
            return candidate_with_sql
    return None


def _mirror_path_for_source(source_path: Path, mirror_root: Path) -> Path:
    parts = source_path.resolve().parts
    if source_path.is_absolute() and parts and parts[0] == "/":
        parts = parts[1:]
    return mirror_root.joinpath("_resolved", *parts)


def _match_include_line(line: str) -> Optional[re.Match[str]]:
    stripped = line.lstrip()
    if not stripped or stripped.startswith("--") or stripped.startswith("/*") or stripped.startswith("*"):
        return None

    match = _AT_CMD_RE.match(line)
    if match is not None:
        return match

    match = _START_CMD_RE.match(line)
    if match is None:
        return None

    target, _ = _unquote_target(match.group("target"))
    if target.upper() == "WITH":
        return None
    return match


def _ensure_rewritten_child_script(
    source_path: Path,
    mirror_root: Path,
    cache: Dict[str, str],
    active: Set[str],
    echo_map: Optional[Dict[str, str]] = None,
) -> str:
    source_abs = source_path.resolve()
    key = str(source_abs)
    if key in cache:
        return cache[key]

    mirror_path = _mirror_path_for_source(source_abs, mirror_root)
    cache[key] = str(mirror_path)
    if key in active:
        return str(mirror_path)

    active.add(key)
    try:
        text = source_abs.read_text(encoding="utf-8", errors="replace")
        rewritten = rewrite_script_includes(
            text,
            str(source_abs),
            str(mirror_root),
            cache=cache,
            active=active,
            echo_map=echo_map,
        )
        mirror_path.parent.mkdir(parents=True, exist_ok=True)
        mirror_path.write_text(ensure_script_trailing_newline(rewritten), encoding="utf-8")
    finally:
        active.discard(key)
    return str(mirror_path)


def rewrite_script_includes(
    script_text: str,
    source_sql_path: str,
    mirror_root: str,
    cache: Optional[Dict[str, str]] = None,
    active: Optional[Set[str]] = None,
    echo_map: Optional[Dict[str, str]] = None,
) -> str:
    source_dir = Path(source_sql_path).resolve().parent
    mirror_root_path = Path(mirror_root).resolve()
    cache = cache if cache is not None else {}
    active = active if active is not None else set()

    rewritten_lines = []
    for line in script_text.splitlines(keepends=True):
        match = _match_include_line(line)
        if match is None:
            rewritten_lines.append(line)
            continue

        raw_target = match.group("target")
        target, quote_char = _unquote_target(raw_target)
        resolved = _resolve_relative_include(source_dir, target)
        if resolved is None:
            rewritten_lines.append(line)
            continue

        try:
            rewritten_target = _ensure_rewritten_child_script(
                resolved,
                mirror_root_path,
                cache,
                active,
                echo_map=echo_map,
            )
        except OSError:
            rewritten_lines.append(line)
            continue

        indent = match.group("indent")
        command = match.group("cmd")
        separator = match.groupdict().get("ws", "") or ""
        rest = match.group("rest")
        newline = line[len(line.rstrip("\r\n")) :]
        original_command = line[: len(line) - len(newline)]
        rewritten_command_name = "@" if command == "@@" else command
        rewritten_command = f"{indent}{rewritten_command_name}{separator}{_quote_target(rewritten_target, quote_char)}{rest}"
        if echo_map is not None:
            echo_map[rewritten_command] = original_command
        rewritten_lines.append(f"{rewritten_command}{newline}")

    return "".join(rewritten_lines)


def restore_rewritten_include_output(output_text: str, echo_map: Dict[str, str]) -> str:
    if not output_text or not echo_map:
        return output_text

    restored_lines = []
    prefix = "iSQL> "
    for line in output_text.splitlines(keepends=True):
        newline = line[len(line.rstrip("\r\n")) :]
        content = line[: len(line) - len(newline)]
        if content.startswith(prefix):
            command = content[len(prefix) :]
            original_command = echo_map.get(command)
            if original_command is not None:
                restored_lines.append(f"{prefix}{original_command}{newline}")
                continue
        restored_lines.append(line)
    return "".join(restored_lines)



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
        env = build_env(base_env, action.env, action.unset_env_keys)
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
