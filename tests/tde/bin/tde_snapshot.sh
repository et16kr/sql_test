#!/bin/sh

tde_snapshot_backup_pre_post_rotate()
{
    tde_case_guard

    tde_checkpoint
    tde_snapshot_state "${TDE_SNAPSHOT_PRE_ROTATE}" 0 0

    tde_run_isql_checked <<'EOF'
ALTER SYSTEM TDE ROTATE MASTER KEY;
ALTER SYSTEM CHECKPOINT;
EOF

    tde_snapshot_state "${TDE_SNAPSHOT_POST_ROTATE}" 0 0
}

tde_prepare_snapshot_fixture()
{
    tde_prepare_rotate_twice_fixture
    tde_create_new_encrypted_fixture
    tde_snapshot_backup_pre_post_rotate
}

tde_snapshot_restore_old_history_ok()
{
    BACKUP_DIR=$(tde_snapshot_dir "${TDE_SNAPSHOT_ROLLBACK}")
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_server_stop_expect_success >/dev/null 2>&1 || true
            tde_restore_snapshot_state "${TDE_SNAPSHOT_ROLLBACK}" 0 0
            tde_server_start_expect_success >/dev/null 2>&1 || true
        fi
    }

    tde_case_guard
    trap cleanup EXIT HUP INT TERM

    tde_checkpoint
    tde_snapshot_state "${TDE_SNAPSHOT_ROLLBACK}" 0 0

    tde_server_stop_expect_success
    tde_restore_snapshot_state "${TDE_SNAPSHOT_PRE_ROTATE}" 0 0
    tde_server_start_expect_success

    RESTORED=1
    trap - EXIT HUP INT TERM
}

tde_snapshot_restore_old_history_missing_key_fail()
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

    cp "${TDE_KEYSTORE_PATH}" "${BACKUP_PATH}" ||
        tde_fail "failed to backup keystore file."

    ACTIVE_KEY_ID=$(awk -F= '/^ACTIVE_MASTER_KEY_ID=/{print $2; exit}' "${BACKUP_PATH}")

    [ -n "${ACTIVE_KEY_ID}" ] || tde_fail "failed to read active master key id."

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success

    awk -F= -v aKey="${ACTIVE_KEY_ID}" '
        /^VERSION=/ { print; next; }
        /^ACTIVE_MASTER_KEY_ID=/ { print; next; }
        /^WRAP_KEY_CHECK=/ { print; next; }
        $0 ~ ("^MASTER_KEY=" aKey ":") { print; next; }
    ' "${BACKUP_PATH}" > "${TDE_KEYSTORE_PATH}" ||
        tde_fail "failed to prune keystore history."

    tde_server_start_expect_failure "smERR_ABORT_TDEMasterKeyHistoryMissing"
    tde_restore_file "${BACKUP_PATH}" "${TDE_KEYSTORE_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PATH}"
}
