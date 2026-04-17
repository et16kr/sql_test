#!/bin/sh

tde_case_guard()
{
    tde_require_env
    tde_require_safe_paths
    tde_require_server_up
}

tde_reset_environment()
{
    sStartLogPath=

    tde_require_env
    tde_require_safe_paths
    tde_replace_property TDE_AUTO_LOAD 1

    if ! tde_probe_server
    then
        sStartLogPath=$(mktemp)

        if ! tde_try_server_start "${sStartLogPath}"
        then
            rm -f "${sStartLogPath}"
            tde_force_rebuild_database
            tde_server_start_expect_success
        else
            rm -f "${sStartLogPath}"
        fi
    fi

    tde_run_best_effort_cleanup
    tde_server_stop_expect_success
    tde_remove_tde_artifacts
    tde_reset_snapshots

    sStartLogPath=$(mktemp)

    if ! tde_try_server_start "${sStartLogPath}"
    then
        rm -f "${sStartLogPath}"
        tde_force_rebuild_database
        tde_server_start_expect_success
    else
        rm -f "${sStartLogPath}"
    fi
}

tde_prepare_base_fixture()
{
    tde_reset_environment

    tde_run_isql_checked <<'EOF'
ALTER SYSTEM TDE CREATE KEYSTORE;
ALTER SYSTEM TDE CREATE MASTER KEY;

CREATE MEMORY TABLESPACE TDE_SQLT_TBS
SIZE 64M
AUTOEXTEND OFF
ENCRYPTION;

CREATE TABLE TDE_SQLT_T
(
    I INTEGER PRIMARY KEY,
    V VARCHAR(32)
)
TABLESPACE TDE_SQLT_TBS;

INSERT INTO TDE_SQLT_T VALUES (1, 'alpha');
INSERT INTO TDE_SQLT_T VALUES (2, 'beta');
COMMIT;

ALTER SYSTEM CHECKPOINT;
EOF
}

tde_restart_smoke()
{
    tde_case_guard
    tde_server_restart_expect_success
}

tde_restart_repeat_smoke()
{
    tde_case_guard
    tde_server_restart_expect_success
    tde_server_restart_expect_success
}

tde_restart_after_checkpoint()
{
    tde_case_guard
    tde_checkpoint
    tde_server_restart_expect_success
}

tde_finalize_environment()
{
    tde_require_env
    tde_require_safe_paths

    if ! tde_probe_server
    then
        tde_server_start_expect_success
    fi

    tde_run_best_effort_cleanup
    tde_replace_property TDE_AUTO_LOAD 1
    tde_reset_snapshots
    tde_remove_tde_artifacts
}
