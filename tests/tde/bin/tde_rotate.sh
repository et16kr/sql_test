#!/bin/sh

tde_rotate_master_key_once()
{
    tde_case_guard
    tde_run_isql_checked <<'EOF'
ALTER SYSTEM TDE ROTATE MASTER KEY;
ALTER SYSTEM CHECKPOINT;
EOF
}

tde_prepare_rotate_once_fixture()
{
    tde_prepare_extended_fixture
    tde_rotate_master_key_once
}

tde_prepare_rotate_twice_fixture()
{
    tde_prepare_extended_fixture
    tde_rotate_master_key_once
    tde_rotate_master_key_once
}

tde_prepare_rekey_fixture()
{
    tde_prepare_rotate_once_fixture
}

tde_prepare_rekey_reference_fixture()
{
    tde_prepare_rotate_twice_fixture
    tde_create_new_encrypted_fixture
    tde_encrypt_tablespace "${TDE_EXT_PLAIN_TABLESPACE}"
    tde_create_empty_plain_fixture
    tde_encrypt_tablespace "${TDE_TMP_EMPTY_PLAIN_TABLESPACE}"
    tde_rotate_master_key_once
    tde_rekey_tablespace "${TDE_TMP_EMPTY_PLAIN_TABLESPACE}"
}

tde_negative_rotated_key_history()
{
    BACKUP_PATH=$(mktemp)
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_restore_file "${BACKUP_PATH}" "${TDE_KEYSTORE_PATH}"
            if ! tde_probe_server
            then
                tde_server_start_expect_success >/dev/null 2>&1 || true
            fi
        fi

        rm -f "${BACKUP_PATH}"
    }

    tde_case_guard

    [ -f "${TDE_KEYSTORE_PATH}" ] ||
        tde_fail "keystore file not found: ${TDE_KEYSTORE_PATH}"

    cp "${TDE_KEYSTORE_PATH}" "${BACKUP_PATH}" ||
        tde_fail "failed to backup keystore file."

    ACTIVE_KEY_ID=$(awk -F= '/^ACTIVE_MASTER_KEY_ID=/{print $2; exit}' "${BACKUP_PATH}")

    [ -n "${ACTIVE_KEY_ID}" ] ||
        tde_fail "failed to read active master key id."

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success

    awk -F= -v aKey="${ACTIVE_KEY_ID}" '
        /^VERSION=/ { print; next; }
        /^ACTIVE_MASTER_KEY_ID=/ { print; next; }
        /^WRAP_KEY_CHECK=/ { print; next; }
        $0 ~ ("^MASTER_KEY=" aKey ":") { print; next; }
    ' "${BACKUP_PATH}" > "${TDE_KEYSTORE_PATH}" ||
        tde_fail "failed to rewrite rotated keystore history."

    tde_server_start_expect_failure "smERR_ABORT_TDEMasterKeyHistoryMissing"
    tde_restore_file "${BACKUP_PATH}" "${TDE_KEYSTORE_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PATH}"
}
