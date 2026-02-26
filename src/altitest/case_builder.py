"""Build executable case plans from SQL paths."""

from __future__ import annotations

import os
from pathlib import Path
from typing import List

from .model import CasePlan, PhasePlan
from .utils import repo_relpath


def _to_out_path(sql_path: str, repo_root: str, out_actual_dir: str, ext: str) -> str:
    rel = repo_relpath(sql_path, repo_root)
    rel_no_ext = os.path.splitext(rel)[0]
    return str(Path(out_actual_dir, rel_no_ext + ext))


def build_case_plans(sql_paths: List[str], repo_root: str, out_actual_dir: str) -> List[CasePlan]:
    plans: List[CasePlan] = []
    for idx, sql_path in enumerate(sql_paths, start=1):
        sql_path = str(Path(sql_path).resolve())
        base = os.path.basename(sql_path)
        parent = os.path.dirname(sql_path)
        if base == "test.sql":
            mode = "triple"
            init_sql = str(Path(parent, "init.sql"))
            destroy_sql = str(Path(parent, "destroy.sql"))
            test_sql = sql_path
            phases: List[PhasePlan] = []
            if os.path.exists(init_sql):
                phases.append(PhasePlan(name="init", sql_path=init_sql))
            phases.append(PhasePlan(name="test", sql_path=test_sql))
            if os.path.exists(destroy_sql):
                phases.append(PhasePlan(name="destroy", sql_path=destroy_sql))
            lst_path = str(Path(parent, "test.lst"))
        else:
            mode = "single"
            init_sql = ""
            destroy_sql = ""
            test_sql = sql_path
            phases = [PhasePlan(name="test", sql_path=test_sql)]
            lst_path = os.path.splitext(test_sql)[0] + ".lst"

        out_path = _to_out_path(test_sql, repo_root, out_actual_dir, ".out")
        err_path = _to_out_path(test_sql, repo_root, out_actual_dir, ".err")

        plans.append(
            CasePlan(
                index=idx,
                sql_path=sql_path,
                mode=mode,
                phases=phases,
                init_sql=init_sql,
                test_sql=test_sql,
                destroy_sql=destroy_sql,
                lst_path=lst_path,
                out_path=out_path,
                err_path=err_path,
            )
        )

    return plans

