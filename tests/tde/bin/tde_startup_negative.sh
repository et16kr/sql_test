#!/bin/sh

tde_duplicate_statement_rejected()
{
    aExpectedPattern=$1
    sOutPath=$(mktemp)

    tde_run_isql_raw "${sOutPath}"

    if grep -q "\\[ERR-" "${sOutPath}" &&
       grep -F -q "${aExpectedPattern}" "${sOutPath}"
    then
        if ! tde_probe_server
        then
            tde_server_start_expect_success
        fi

        rm -f "${sOutPath}"
        return 0
    fi

    if grep -q "ERR-91015" "${sOutPath}" ||
       grep -q "ERR-50032" "${sOutPath}"
    then
        if ! tde_probe_server
        then
            tde_server_start_expect_success
        fi

        rm -f "${sOutPath}"
        return 0
    fi

    sed -n '1,200p' "${sOutPath}" >&2
    rm -f "${sOutPath}"
    tde_fail "duplicate statement was not rejected."
}

tde_duplicate_keystore_rejected()
{
    tde_case_guard

    tde_duplicate_statement_rejected \
        "The data file already exists" <<'EOF'
ALTER SYSTEM TDE CREATE KEYSTORE;
EOF
}

tde_duplicate_master_key_rejected()
{
    tde_case_guard

    tde_duplicate_statement_rejected \
        "An active TDE master key already exists in the keystore." <<'EOF'
ALTER SYSTEM TDE CREATE MASTER KEY;
EOF
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

tde_negative_invalid_keystore_version()
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

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success

    awk '
        /^VERSION=/ {
            print "VERSION=9";
            next;
        }

        {
            print;
        }
    ' "${BACKUP_PATH}" > "${TDE_KEYSTORE_PATH}" ||
        tde_fail "failed to rewrite keystore version."

    tde_server_start_expect_failure "smERR_ABORT_TDEInvalidKeyStore"
    tde_restore_file "${BACKUP_PATH}" "${TDE_KEYSTORE_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PATH}"
}

tde_negative_invalid_keystore_missing_active()
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

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success

    grep -v '^ACTIVE_MASTER_KEY_ID=' "${BACKUP_PATH}" > "${TDE_KEYSTORE_PATH}" ||
        tde_fail "failed to remove ACTIVE_MASTER_KEY_ID."

    tde_server_start_expect_failure_any \
        "smERR_ABORT_TDEInvalidKeyStore" \
        "smERR_ABORT_TDEMasterKeyHistoryMissing"
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

tde_negative_corrupted_wrapped_tbs_key()
{
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_prepare_base_fixture >/dev/null 2>&1 || true
        fi
    }

    tde_case_guard

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success
    tde_patch_tbs_files_hex "${TDE_SQLT_TABLESPACE}" "${TDE_HDR_OFFSET_WRAPPED_TBS_KEY}" "00112233"
    tde_server_start_expect_failure "smERR_ABORT_TDEUnwrapFailure"
    tde_prepare_base_fixture
    RESTORED=1

    trap - EXIT HUP INT TERM
}

tde_negative_corrupted_header_master_key_id()
{
    RESTORED=0
    ACTIVE_KEY_ID=
    CORRUPTED_KEY_ID=
    CORRUPTED_HEX=

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_prepare_base_fixture >/dev/null 2>&1 || true
        fi
    }

    tde_case_guard

    trap cleanup EXIT HUP INT TERM

    ACTIVE_KEY_ID=$(tde_get_active_master_key_id)
    CORRUPTED_KEY_ID=$((ACTIVE_KEY_ID + 1000))
    CORRUPTED_HEX=$(tde_uint32_to_le_hex "${CORRUPTED_KEY_ID}")

    tde_server_stop_expect_success
    tde_patch_tbs_files_hex "${TDE_SQLT_TABLESPACE}" "${TDE_HDR_OFFSET_MASTER_KEY_ID}" "${CORRUPTED_HEX}"
    tde_server_start_expect_failure "smERR_ABORT_TDEMasterKeyHistoryMissing"
    tde_prepare_base_fixture
    RESTORED=1

    trap - EXIT HUP INT TERM
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

tde_plain_only_autoload_off_ok()
{
    BACKUP_PROP=$(mktemp)
    BACKUP_KEYSTORE=$(mktemp)
    BACKUP_WRAP=$(mktemp)
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_restore_file "${BACKUP_PROP}" "${ALTIBASE_PROPERTIES_PATH}"
            tde_restore_file "${BACKUP_KEYSTORE}" "${TDE_KEYSTORE_PATH}"
            tde_restore_file "${BACKUP_WRAP}" "${TDE_WRAP_KEY_PATH}"

            if ! tde_probe_server
            then
                tde_server_start_expect_success >/dev/null 2>&1 || true
            fi
        fi

        rm -f "${BACKUP_PROP}" "${BACKUP_KEYSTORE}" "${BACKUP_WRAP}"
    }

    tde_case_guard

    cp "${ALTIBASE_PROPERTIES_PATH}" "${BACKUP_PROP}" ||
        tde_fail "failed to backup property file."
    cp "${TDE_KEYSTORE_PATH}" "${BACKUP_KEYSTORE}" ||
        tde_fail "failed to backup keystore file."
    cp "${TDE_WRAP_KEY_PATH}" "${BACKUP_WRAP}" ||
        tde_fail "failed to backup wrap key file."

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success
    tde_replace_property TDE_AUTO_LOAD 0
    rm -f "${TDE_KEYSTORE_PATH}" "${TDE_WRAP_KEY_PATH}"
    tde_server_start_expect_success
    tde_server_stop_expect_success
    tde_restore_file "${BACKUP_PROP}" "${ALTIBASE_PROPERTIES_PATH}"
    tde_restore_file "${BACKUP_KEYSTORE}" "${TDE_KEYSTORE_PATH}"
    tde_restore_file "${BACKUP_WRAP}" "${TDE_WRAP_KEY_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PROP}" "${BACKUP_KEYSTORE}" "${BACKUP_WRAP}"
}

tde_all_decrypted_autoload_off_ok()
{
    BACKUP_PROP=$(mktemp)
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_restore_file "${BACKUP_PROP}" "${ALTIBASE_PROPERTIES_PATH}"

            if ! tde_probe_server
            then
                tde_server_start_expect_success >/dev/null 2>&1 || true
            fi
        fi

        rm -f "${BACKUP_PROP}"
    }

    tde_case_guard

    cp "${ALTIBASE_PROPERTIES_PATH}" "${BACKUP_PROP}" ||
        tde_fail "failed to backup property file."

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success
    tde_replace_property TDE_AUTO_LOAD 0
    tde_server_start_expect_success
    tde_server_stop_expect_success
    tde_restore_file "${BACKUP_PROP}" "${ALTIBASE_PROPERTIES_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PROP}"
}
