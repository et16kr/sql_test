#!/bin/sh

tde_run_isql_expect_server_crash()
{
    sOutPath=$(mktemp)

    tde_run_isql_raw "${sOutPath}"

    if ! tde_wait_for_server_down
    then
        sed -n '1,200p' "${sOutPath}" >&2
        rm -f "${sOutPath}"
        tde_fail "server did not crash during injected TDE operation."
    fi

    rm -f "${sOutPath}"
}

tde_crash_recover_operation()
{
    aCrashPoint=$1
    aTablespaceName=$2
    sSqlPath=$(mktemp)
    sRecovered=0

    cat > "${sSqlPath}"

    cleanup()
    {
        unset ALTIBASE_TDE_CRASH_INJECT

        if [ "${sRecovered}" -eq 0 ]
        then
            if ! tde_probe_server
            then
                tde_server_start_expect_success >/dev/null 2>&1 || true
            fi

            tde_run_isql_best_effort "ALTER TABLESPACE ${aTablespaceName} ONLINE;"
        fi

        rm -f "${sSqlPath}"
    }

    tde_case_guard
    trap cleanup EXIT HUP INT TERM

    ALTIBASE_TDE_CRASH_INJECT="${aCrashPoint}"
    export ALTIBASE_TDE_CRASH_INJECT
    tde_server_restart_expect_success

    tde_run_isql_expect_server_crash < "${sSqlPath}"

    unset ALTIBASE_TDE_CRASH_INJECT
    tde_server_start_expect_success
    tde_run_isql_best_effort "ALTER TABLESPACE ${aTablespaceName} ONLINE;"
    tde_checkpoint

    sRecovered=1
    trap - EXIT HUP INT TERM
    rm -f "${sSqlPath}"
}

tde_crash_offline_encrypt_writing_target()
{
    tde_crash_recover_operation "journal_writing_target" \
        "${TDE_EXT_PLAIN_TABLESPACE}" <<EOF
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} OFFLINE;
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} ENCRYPTION OFFLINE ENCRYPT;
EOF
}

tde_crash_offline_encrypt_target_synced()
{
    tde_crash_recover_operation "journal_target_synced" \
        "${TDE_EXT_PLAIN_TABLESPACE}" <<EOF
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} OFFLINE;
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} ENCRYPTION OFFLINE ENCRYPT;
EOF
}

tde_crash_offline_encrypt_flush_tbs_node()
{
    tde_crash_recover_operation "flush_tbs_node" \
        "${TDE_EXT_PLAIN_TABLESPACE}" <<EOF
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} OFFLINE;
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} ENCRYPTION OFFLINE ENCRYPT;
EOF
}

tde_crash_offline_decrypt_target_synced()
{
    tde_crash_recover_operation "journal_target_synced" \
        "${TDE_EXT_PLAIN_TABLESPACE}" <<EOF
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} OFFLINE;
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} ENCRYPTION OFFLINE DECRYPT;
EOF
}

tde_crash_rekey_committed()
{
    tde_crash_recover_operation "journal_committed" \
        "${TDE_EXT_ENC_TABLESPACE}" <<EOF
ALTER TABLESPACE ${TDE_EXT_ENC_TABLESPACE} OFFLINE;
ALTER TABLESPACE ${TDE_EXT_ENC_TABLESPACE} ENCRYPTION REKEY;
EOF
}

tde_crash_operation_journal_resume()
{
    tde_crash_recover_operation "journal_committed" \
        "${TDE_EXT_PLAIN_TABLESPACE}" <<EOF
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} OFFLINE;
ALTER TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} ENCRYPTION OFFLINE ENCRYPT;
EOF
}
