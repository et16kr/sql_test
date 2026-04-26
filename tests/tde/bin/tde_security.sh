#!/bin/sh

tde_v2_wrap_key_check_hex()
{
    aWrapKeyHex=$1

    perl -MDigest::SHA=sha256_hex -e '
        my $sHex = shift;
        print sha256_hex("ALTIBASE_TDE_WRAP_KEY_CHECK_V2" . pack("H*", $sHex)), "\n";
    ' "${aWrapKeyHex}" ||
        tde_fail "failed to calculate v2 wrap key check."
}

tde_first_tbs_file()
{
    aTablespaceName=$1

    tde_get_tbs_files "${aTablespaceName}" | sed -n '1p'
}

tde_copy_tbs_files()
{
    aTablespaceName=$1
    aTargetDir=$2
    sFound=0

    rm -rf "${aTargetDir}"
    mkdir -p "${aTargetDir}" ||
        tde_fail "failed to create copy directory: ${aTargetDir}"

    for sFilePath in $(tde_get_tbs_files "${aTablespaceName}")
    do
        sFound=1
        cp "${sFilePath}" "${aTargetDir}/" ||
            tde_fail "failed to copy tablespace file: ${sFilePath}"
    done

    [ "${sFound}" -eq 1 ] || tde_fail "tablespace files not found: ${aTablespaceName}"
}

tde_copied_tbs_files_differ()
{
    aLeftDir=$1
    aRightDir=$2
    sCompared=0

    for sLeftPath in "${aLeftDir}"/*
    do
        [ -f "${sLeftPath}" ] || continue
        sRightPath="${aRightDir}/$(basename "${sLeftPath}")"
        [ -f "${sRightPath}" ] || continue
        sCompared=1

        if ! cmp -s "${sLeftPath}" "${sRightPath}"
        then
            return 0
        fi
    done

    [ "${sCompared}" -eq 1 ] || tde_fail "no copied tablespace files were comparable."
    return 1
}

tde_copied_tbs_file_nonce_differs()
{
    aLeftDir=$1
    aRightDir=$2
    sCompared=0

    for sLeftPath in "${aLeftDir}"/*
    do
        [ -f "${sLeftPath}" ] || continue
        sRightPath="${aRightDir}/$(basename "${sLeftPath}")"
        [ -f "${sRightPath}" ] || continue
        sCompared=1

        sLeftNonce=$(tde_read_file_hex "${sLeftPath}" "${TDE_HDR_OFFSET_FILE_NONCE}" 8)
        sRightNonce=$(tde_read_file_hex "${sRightPath}" "${TDE_HDR_OFFSET_FILE_NONCE}" 8)

        if [ "${sLeftNonce}" != "${sRightNonce}" ]
        then
            return 0
        fi
    done

    [ "${sCompared}" -eq 1 ] || tde_fail "no copied tablespace files were comparable."
    return 1
}

tde_negative_corrupted_keystore_hmac()
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
    tde_keystore_is_v3 ||
        tde_fail "keystore is not v3."

    cp "${TDE_KEYSTORE_PATH}" "${BACKUP_PATH}" ||
        tde_fail "failed to backup keystore file."

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success
    sSize=$(wc -c < "${TDE_KEYSTORE_PATH}" | tr -d ' ')
    [ "${sSize}" -gt 0 ] || tde_fail "keystore is empty."
    tde_xor_file_byte "${TDE_KEYSTORE_PATH}" "$((sSize - 1))" "01"
    tde_server_start_expect_failure_any \
        "smERR_ABORT_TDEUnwrapFailure" \
        "smERR_ABORT_TDEInvalidKeyStore"
    tde_restore_file "${BACKUP_PATH}" "${TDE_KEYSTORE_PATH}"
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
    rm -f "${BACKUP_PATH}"
}

tde_negative_corrupted_checkpoint_header_hmac()
{
    RESTORED=0
    SNAPSHOT_NAME=stage9_header_hmac

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_server_stop_expect_success >/dev/null 2>&1 || true
            tde_restore_snapshot_state "${SNAPSHOT_NAME}" 1 0
            tde_server_start_expect_success >/dev/null 2>&1 || true
        fi
    }

    tde_case_guard
    tde_checkpoint
    tde_snapshot_state "${SNAPSHOT_NAME}" 1 0

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success
    tde_xor_tbs_files_byte "${TDE_SQLT_TABLESPACE}" \
        "${TDE_HDR_OFFSET_HEADER_HMAC}" \
        "01"
    tde_server_start_expect_failure "Stage:header-validate, .*Result:11"
    tde_restore_snapshot_state "${SNAPSHOT_NAME}" 1 0
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
}

tde_v2_compat_or_reject()
{
    WRAP_KEY_HEX=00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff
    WRAP_KEY_CHECK=
    OUT_PATH=
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_prepare_base_fixture >/dev/null 2>&1 || true
        fi

        [ -n "${OUT_PATH}" ] && rm -f "${OUT_PATH}"
    }

    tde_case_guard

    trap cleanup EXIT HUP INT TERM

    tde_reset_environment
    WRAP_KEY_CHECK=$(tde_v2_wrap_key_check_hex "${WRAP_KEY_HEX}")

    printf '%s\n' "${WRAP_KEY_HEX}" > "${TDE_WRAP_KEY_PATH}" ||
        tde_fail "failed to write v2 wrap key."
    {
        printf 'VERSION=2\n'
        printf 'ACTIVE_MASTER_KEY_ID=0\n'
        printf 'WRAP_KEY_CHECK=%s\n' "${WRAP_KEY_CHECK}"
    } > "${TDE_KEYSTORE_PATH}" ||
        tde_fail "failed to write v2 keystore."

    OUT_PATH=$(mktemp)
    tde_run_isql_raw "${OUT_PATH}" <<'EOF'
ALTER SYSTEM TDE CREATE MASTER KEY;
EOF

    if grep -q "\\[ERR-" "${OUT_PATH}"
    then
        if ! grep -E -q "Unsupported|unsupported|not supported|not support" "${OUT_PATH}"
        then
            sed -n '1,200p' "${OUT_PATH}" >&2
            tde_fail "v2 keystore was neither accepted nor explicitly rejected."
        fi
    else
        tde_keystore_is_v3 ||
            tde_fail "accepted v2 keystore was not migrated to v3."
        [ "$(tde_get_active_master_key_id)" -gt 0 ] ||
            tde_fail "accepted v2 keystore did not produce an active master key."
    fi

    rm -f "${OUT_PATH}"
    OUT_PATH=

    tde_prepare_base_fixture
    RESTORED=1

    trap - EXIT HUP INT TERM
}

tde_insert_ciphertext_marker()
{
    aTableName=$1
    aID=$2
    aMarker=$3

    tde_run_isql_checked <<EOF
DELETE FROM ${aTableName} WHERE I = ${aID};
INSERT INTO ${aTableName} VALUES (${aID}, '${aMarker}');
COMMIT;
ALTER SYSTEM CHECKPOINT;
EOF
}

tde_encrypted_file_no_plaintext()
{
    tde_case_guard
    tde_insert_ciphertext_marker "${TDE_SQLT_TABLE}" 901 "TDE9_SECRET_ALPHA"
    tde_assert_tbs_plaintext_absent "${TDE_SQLT_TABLESPACE}" "TDE9_SECRET_ALPHA"
}

tde_plain_header_encrypted_body()
{
    tde_case_guard
    tde_insert_ciphertext_marker "${TDE_SQLT_TABLE}" 902 "TDE9_SECRET_BODY"
    tde_assert_tbs_v3_header_magic "${TDE_SQLT_TABLESPACE}"
    tde_assert_tbs_plaintext_absent "${TDE_SQLT_TABLESPACE}" "TDE9_SECRET_BODY"
}

tde_same_page_ciphertext_changes_after_checkpoint()
{
    LEFT_DIR=$(mktemp -d)
    RIGHT_DIR=$(mktemp -d)

    cleanup()
    {
        rm -rf "${LEFT_DIR}" "${RIGHT_DIR}"
    }

    tde_case_guard
    trap cleanup EXIT HUP INT TERM

    tde_insert_ciphertext_marker "${TDE_SQLT_TABLE}" 903 "TDE9_NONCE_STABLE"
    tde_copy_tbs_files "${TDE_SQLT_TABLESPACE}" "${LEFT_DIR}"

    tde_insert_ciphertext_marker "${TDE_SQLT_TABLE}" 903 "TDE9_NONCE_DIRTY"
    tde_insert_ciphertext_marker "${TDE_SQLT_TABLE}" 903 "TDE9_NONCE_STABLE"
    tde_copy_tbs_files "${TDE_SQLT_TABLESPACE}" "${RIGHT_DIR}"

    tde_copied_tbs_files_differ "${LEFT_DIR}" "${RIGHT_DIR}" ||
        tde_fail "ciphertext did not change across checkpoint generations."
    tde_copied_tbs_file_nonce_differs "${LEFT_DIR}" "${RIGHT_DIR}" ||
        tde_fail "file nonce did not change across checkpoint generations."
    tde_assert_tbs_plaintext_absent "${TDE_SQLT_TABLESPACE}" "TDE9_NONCE_STABLE"

    trap - EXIT HUP INT TERM
    cleanup
}

tde_offline_convert_fresh_nonce()
{
    LEFT_DIR=$(mktemp -d)
    RIGHT_DIR=$(mktemp -d)

    cleanup()
    {
        rm -rf "${LEFT_DIR}" "${RIGHT_DIR}"
    }

    tde_case_guard
    trap cleanup EXIT HUP INT TERM

    tde_run_isql_checked <<'EOF'
DELETE FROM TDE_TMP_PLAIN_T WHERE I = 904;
INSERT INTO TDE_TMP_PLAIN_T VALUES (904, 'TDE9_OFFLINE_NONCE');
COMMIT;
ALTER SYSTEM CHECKPOINT;
EOF

    tde_encrypt_tablespace "${TDE_TMP_PLAIN_TABLESPACE}"
    tde_copy_tbs_files "${TDE_TMP_PLAIN_TABLESPACE}" "${LEFT_DIR}"
    tde_assert_tbs_plaintext_absent "${TDE_TMP_PLAIN_TABLESPACE}" "TDE9_OFFLINE_NONCE"

    tde_decrypt_tablespace "${TDE_TMP_PLAIN_TABLESPACE}"
    tde_encrypt_tablespace "${TDE_TMP_PLAIN_TABLESPACE}"
    tde_copy_tbs_files "${TDE_TMP_PLAIN_TABLESPACE}" "${RIGHT_DIR}"
    tde_assert_tbs_plaintext_absent "${TDE_TMP_PLAIN_TABLESPACE}" "TDE9_OFFLINE_NONCE"

    tde_copied_tbs_files_differ "${LEFT_DIR}" "${RIGHT_DIR}" ||
        tde_fail "offline converted ciphertext did not change after re-encrypt."
    tde_copied_tbs_file_nonce_differs "${LEFT_DIR}" "${RIGHT_DIR}" ||
        tde_fail "offline converted file nonce did not change after re-encrypt."

    trap - EXIT HUP INT TERM
    cleanup
}
