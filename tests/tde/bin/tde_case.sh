#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "${SCRIPT_DIR}/tde_common.sh"

tde_case_guard()
{
    tde_require_env
    tde_require_safe_paths
    tde_require_server_up
}

tde_bootstrap_init()
{
    tde_case_guard
    tde_run_best_effort_cleanup
    tde_replace_property TDE_AUTO_LOAD 1
    tde_server_stop_expect_success
    tde_remove_tde_artifacts
    tde_server_start_expect_success
}

tde_restart_smoke()
{
    tde_case_guard
    tde_server_restart_expect_success
}

tde_negative_wrap_key()
{
    BACKUP_PATH=$(mktemp)
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_restore_file "${BACKUP_PATH}" "${TDE_WRAP_KEY_PATH}"
            if ! tde_probe_server
            then
                tde_server_start_expect_success >/dev/null 2>&1 || true
            fi
        fi

        rm -f "${BACKUP_PATH}"
    }

    tde_case_guard

    [ -f "${TDE_WRAP_KEY_PATH}" ] ||
        tde_fail "wrap key file not found: ${TDE_WRAP_KEY_PATH}"

    cp "${TDE_WRAP_KEY_PATH}" "${BACKUP_PATH}" ||
        tde_fail "failed to backup wrap key file."

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success

    cat > "${TDE_WRAP_KEY_PATH}" <<'EOF'
00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff
EOF

    tde_server_start_expect_failure "smERR_ABORT_TDEUnwrapFailure"
    tde_restore_file "${BACKUP_PATH}" "${TDE_WRAP_KEY_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PATH}"
}

tde_negative_invalid_keystore()
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

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success

    grep -v '^WRAP_KEY_CHECK=' "${BACKUP_PATH}" > "${TDE_KEYSTORE_PATH}" ||
        tde_fail "failed to damage keystore file."

    tde_server_start_expect_failure "smERR_ABORT_TDEInvalidKeyStore"
    tde_restore_file "${BACKUP_PATH}" "${TDE_KEYSTORE_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PATH}"
}

tde_negative_missing_master_key()
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
    WRAP_KEY_CHECK=$(awk -F= '/^WRAP_KEY_CHECK=/{print $2; exit}' "${BACKUP_PATH}")
    WRAPPED_MASTER_KEY=$(awk -F'[=:]' '/^MASTER_KEY=/{print $3; exit}' "${BACKUP_PATH}")

    [ -n "${ACTIVE_KEY_ID}" ] || tde_fail "failed to read active master key id."
    [ -n "${WRAP_KEY_CHECK}" ] || tde_fail "failed to read wrap key check."
    [ -n "${WRAPPED_MASTER_KEY}" ] || tde_fail "failed to read wrapped master key."

    NEW_ACTIVE_KEY_ID=$((ACTIVE_KEY_ID + 1000))

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success

    cat > "${TDE_KEYSTORE_PATH}" <<EOF
VERSION=2
ACTIVE_MASTER_KEY_ID=${NEW_ACTIVE_KEY_ID}
WRAP_KEY_CHECK=${WRAP_KEY_CHECK}
MASTER_KEY=${NEW_ACTIVE_KEY_ID}:${WRAPPED_MASTER_KEY}
EOF

    tde_server_start_expect_failure "smERR_ABORT_TDEMasterKeyHistoryMissing"
    tde_restore_file "${BACKUP_PATH}" "${TDE_KEYSTORE_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PATH}"
}

tde_negative_autoload_off()
{
    BACKUP_PATH=$(mktemp)
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_restore_file "${BACKUP_PATH}" "${ALTIBASE_PROPERTIES_PATH}"
            if ! tde_probe_server
            then
                tde_server_start_expect_success >/dev/null 2>&1 || true
            fi
        fi

        rm -f "${BACKUP_PATH}"
    }

    tde_case_guard

    cp "${ALTIBASE_PROPERTIES_PATH}" "${BACKUP_PATH}" ||
        tde_fail "failed to backup property file."

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success
    tde_replace_property TDE_AUTO_LOAD 0
    tde_server_start_expect_failure "smERR_ABORT_TDEAutoLoadDisabled"
    tde_restore_file "${BACKUP_PATH}" "${ALTIBASE_PROPERTIES_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PATH}"
}

tde_cleanup_after_suite()
{
    tde_case_guard
    tde_run_best_effort_cleanup
    tde_replace_property TDE_AUTO_LOAD 1
    tde_remove_tde_artifacts
}

case "${1:-}" in
    case_guard)
        tde_case_guard
        ;;
    bootstrap_init)
        tde_bootstrap_init
        ;;
    restart_smoke)
        tde_restart_smoke
        ;;
    negative_wrap_key)
        tde_negative_wrap_key
        ;;
    negative_invalid_keystore)
        tde_negative_invalid_keystore
        ;;
    negative_missing_master_key)
        tde_negative_missing_master_key
        ;;
    negative_autoload_off)
        tde_negative_autoload_off
        ;;
    cleanup_after_suite)
        tde_cleanup_after_suite
        ;;
    *)
        tde_fail "unknown action: ${1:-<empty>}"
        ;;
esac
