"""Recovery handling for FATAL cases."""

from __future__ import annotations

from typing import Dict, Tuple

from .executor import run_shell_command



def recover_with_clean_and_start(base_env: Dict[str, str], timeout_sec: int) -> Tuple[bool, str]:
    clean_res = run_shell_command("clean", env=base_env, timeout_sec=timeout_sec)
    if clean_res.timed_out or clean_res.error or clean_res.returncode != 0:
        return False, f"clean failed rc={clean_res.returncode} err={clean_res.error}"

    start_res = run_shell_command("server start", env=base_env, timeout_sec=timeout_sec)
    if start_res.timed_out or start_res.error or start_res.returncode != 0:
        return False, f"server start failed rc={start_res.returncode} err={start_res.error}"

    return True, "recovery succeeded"
