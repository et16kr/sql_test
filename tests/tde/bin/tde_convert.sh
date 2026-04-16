#!/bin/sh

tde_decrypt_all_and_restart()
{
    tde_case_guard

    for sTablespaceName in \
        "${TDE_SQLT_TABLESPACE}" \
        "${TDE_EXT_PLAIN_TABLESPACE}" \
        "${TDE_EXT_ENC_TABLESPACE}" \
        "${TDE_TMP_NEW_ENC_TABLESPACE}" \
        "${TDE_TMP_EMPTY_PLAIN_TABLESPACE}"
    do
        tde_decrypt_tablespace_if_needed "${sTablespaceName}"
    done

    tde_checkpoint
    tde_server_restart_expect_success
}

tde_prepare_offline_decrypt_fixture()
{
    tde_prepare_extended_fixture
    tde_encrypt_tablespace "${TDE_EXT_PLAIN_TABLESPACE}"
}

tde_negative_online_operation()
{
    tde_case_guard

    tde_run_isql_expect_error \
        "The tablespace must already be offline for this TDE operation." <<EOF
ALTER TABLESPACE ${TDE_EXT_ENC_TABLESPACE} ENCRYPTION REKEY;
EOF
}

tde_negative_invalid_state()
{
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_run_isql_checked <<EOF
ALTER TABLESPACE ${TDE_EXT_ENC_TABLESPACE} ONLINE;
EOF
        fi
    }

    tde_case_guard
    trap cleanup EXIT HUP INT TERM

    tde_run_isql_checked <<EOF
ALTER TABLESPACE ${TDE_EXT_ENC_TABLESPACE} OFFLINE;
EOF

    tde_run_isql_expect_error \
        "The requested MRDB TDE operation does not match the current tablespace encryption state." <<EOF
ALTER TABLESPACE ${TDE_EXT_ENC_TABLESPACE} ENCRYPTION OFFLINE ENCRYPT;
EOF

    tde_run_isql_checked <<EOF
ALTER TABLESPACE ${TDE_EXT_ENC_TABLESPACE} ONLINE;
EOF

    RESTORED=1
    trap - EXIT HUP INT TERM
}
