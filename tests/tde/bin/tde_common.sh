#!/bin/sh

# Shared helper functions for sql_test MRDB TDE cases.

TDE_SQLT_TABLESPACE=TDE_SQLT_TBS
TDE_SQLT_TABLE=TDE_SQLT_T
TDE_EXT_PLAIN_TABLESPACE=TDE2_PLAIN_TBS
TDE_EXT_ENC_TABLESPACE=TDE2_ENC_TBS
TDE_EXT_PLAIN_TABLE=TDE2_PLAIN_T
TDE_EXT_ENC_TABLE=TDE2_ENC_T
TDE_TMP_PLAIN_TABLESPACE=TDE_TMP_PLAIN_TBS
TDE_TMP_PLAIN_TABLE=TDE_TMP_PLAIN_T
TDE_TMP_EMPTY_PLAIN_TABLESPACE=TDE_TMP_EMPTY_PLAIN_TBS
TDE_TMP_NEW_ENC_TABLESPACE=TDE_TMP_NEW_ENC_TBS
TDE_TMP_NEW_ENC_TABLE=TDE_TMP_NEW_ENC_T
TDE_REPRO_TABLESPACE=TDE_REPRO_TBS
TDE_REPRO_TABLE=TDE_REPRO_T

TDE_SNAPSHOT_PRE_ROTATE=pre_rotate_history
TDE_SNAPSHOT_POST_ROTATE=post_rotate_history
TDE_SNAPSHOT_ROLLBACK=rollback_current

TDE_HDR_OFFSET_VERSION=728
TDE_HDR_OFFSET_ALGORITHM=732
TDE_HDR_OFFSET_MASTER_KEY_ID=736
TDE_HDR_OFFSET_WRAPPED_TBS_KEY=740

tde_fail()
{
    echo "[tests/tde] $*" >&2
    exit 1
}

tde_require_env()
{
    [ -n "${ALTIBASE_HOME:-}" ] || tde_fail "ALTIBASE_HOME is not set."
    command -v is >/dev/null 2>&1 || tde_fail "'is' command not found in PATH."
    command -v server >/dev/null 2>&1 || tde_fail "'server' command not found in PATH."
    command -v perl >/dev/null 2>&1 || tde_fail "'perl' command not found in PATH."

    ALTIBASE_PROPERTIES_PATH="${ALTIBASE_PROPERTIES_PATH:-${ALTIBASE_HOME}/conf/altibase.properties}"
    export ALTIBASE_PROPERTIES_PATH

    [ -f "${ALTIBASE_PROPERTIES_PATH}" ] ||
        tde_fail "properties file not found: ${ALTIBASE_PROPERTIES_PATH}"

    TDE_SERVER_HOST="${ALTIBASE_SERVER_NAME:-localhost}"
    TDE_SERVER_PORT="${ALTIBASE_PORT_NO:-$(tde_get_property PORT_NO)}"

    [ -n "${TDE_SERVER_PORT}" ] ||
        tde_fail "ALTIBASE_PORT_NO and PORT_NO are not set."
}

tde_get_property()
{
    awk -F= -v aKey="$1" '
        function trim(aValue) {
            sub(/^[[:space:]]+/, "", aValue);
            sub(/[[:space:]]+$/, "", aValue);
            return aValue;
        }

        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next; }

        trim($1) == aKey {
            print trim(substr($0, index($0, "=") + 1));
            exit;
        }
    ' "${ALTIBASE_PROPERTIES_PATH}"
}

tde_is_safe_path()
{
    aPath=$1

    if [ "${SQL_TEST_TDE_ALLOW_UNSAFE_PATH:-0}" = "1" ]
    then
        return 0
    fi

    case "${aPath}" in
        /tmp/*|*sql_test*|*tde_test*|*tde-test*)
            return 0
            ;;
    esac

    return 1
}

tde_require_safe_paths()
{
    TDE_KEYSTORE_PATH=$(tde_get_property TDE_KEYSTORE_PATH)
    TDE_WRAP_KEY_PATH=$(tde_get_property TDE_WRAP_KEY_PATH)

    [ -n "${TDE_KEYSTORE_PATH}" ] || tde_fail "TDE_KEYSTORE_PATH is not set."
    [ -n "${TDE_WRAP_KEY_PATH}" ] || tde_fail "TDE_WRAP_KEY_PATH is not set."

    tde_is_safe_path "${TDE_KEYSTORE_PATH}" ||
        tde_fail "unsafe keystore path: ${TDE_KEYSTORE_PATH}"
    tde_is_safe_path "${TDE_WRAP_KEY_PATH}" ||
        tde_fail "unsafe wrap key path: ${TDE_WRAP_KEY_PATH}"

    TDE_KEYSTORE_DIR=$(dirname "${TDE_KEYSTORE_PATH}")
    TDE_WRAP_KEY_DIR=$(dirname "${TDE_WRAP_KEY_PATH}")
    TDE_DB_DIR="${ALTIBASE_HOME}/dbs"
    TDE_LOG_DIR="${ALTIBASE_HOME}/logs"
    TDE_SNAPSHOT_ROOT="${TDE_KEYSTORE_DIR}/snapshots"

    [ -d "${TDE_KEYSTORE_DIR}" ] ||
        tde_fail "keystore parent directory not found: ${TDE_KEYSTORE_DIR}"
    [ -d "${TDE_WRAP_KEY_DIR}" ] ||
        tde_fail "wrap key parent directory not found: ${TDE_WRAP_KEY_DIR}"
    [ -d "${TDE_DB_DIR}" ] ||
        tde_fail "DB directory not found: ${TDE_DB_DIR}"
    [ -d "${TDE_LOG_DIR}" ] ||
        tde_fail "log directory not found: ${TDE_LOG_DIR}"
    [ -w "${TDE_KEYSTORE_DIR}" ] ||
        tde_fail "keystore parent directory is not writable: ${TDE_KEYSTORE_DIR}"
    [ -w "${TDE_WRAP_KEY_DIR}" ] ||
        tde_fail "wrap key parent directory is not writable: ${TDE_WRAP_KEY_DIR}"

    mkdir -p "${TDE_SNAPSHOT_ROOT}" ||
        tde_fail "failed to create snapshot root: ${TDE_SNAPSHOT_ROOT}"
}

tde_probe_server()
{
    sOutPath=$(mktemp)

    printf 'SELECT 1 FROM DUAL;\nquit\n' |
        is -s "${TDE_SERVER_HOST}" -port "${TDE_SERVER_PORT}" -silent >"${sOutPath}" 2>&1

    if [ "$?" -ne 0 ] || grep -q "\\[ERR-" "${sOutPath}"
    then
        rm -f "${sOutPath}"
        return 1
    fi

    if awk '
        /^[[:space:]]*1[[:space:]]*$/ {
            sFound = 1;
        }

        END {
            exit !sFound;
        }
    ' "${sOutPath}"
    then
        rm -f "${sOutPath}"
        return 0
    fi

    rm -f "${sOutPath}"
    return 1
}

tde_wait_for_server_up()
{
    sTry=0
    sStableCount=0

    while [ "${sTry}" -lt 30 ]
    do
        if tde_probe_server
        then
            sStableCount=$((sStableCount + 1))

            if [ "${sStableCount}" -ge 2 ]
            then
                return 0
            fi
        else
            sStableCount=0
        fi

        sleep 1
        sTry=$((sTry + 1))
    done

    return 1
}

tde_wait_for_server_down()
{
    sTry=0

    while [ "${sTry}" -lt 30 ]
    do
        if ! tde_probe_server
        then
            return 0
        fi

        sleep 1
        sTry=$((sTry + 1))
    done

    return 1
}

tde_require_server_up()
{
    tde_probe_server || tde_fail "server is not running."
}

tde_run_server()
{
    aMode=$1
    aLogPath=$2

    server "${aMode}" >"${aLogPath}" 2>&1 || true
}

tde_try_server_start()
{
    aLogPath=$1

    tde_run_server start "${aLogPath}"
    tde_wait_for_server_up
}

tde_dump_log()
{
    aLogPath=$1

    if [ -f "${aLogPath}" ]
    then
        sed -n '1,200p' "${aLogPath}" >&2
    fi
}

tde_get_file_size()
{
    aPath=$1

    if [ -f "${aPath}" ]
    then
        wc -c < "${aPath}" | tr -d ' '
    else
        echo 0
    fi
}

tde_dump_log_from_offset()
{
    aLogPath=$1
    aOffset=$2

    if [ ! -f "${aLogPath}" ]
    then
        return 0
    fi

    tail -c "+$((aOffset + 1))" "${aLogPath}" 2>/dev/null
}

tde_trace_contains_start_failure()
{
    aPattern=$1
    aSmLogPath=$2
    aSmOffset=$3
    aBootLogPath=$4
    aBootOffset=$5
    aErrorLogPath=$6
    aErrorOffset=$7
    sTracePattern=

    case "${aPattern}" in
        smERR_ABORT_TDEUnwrapFailure)
            sTracePattern='\[TDE\] startup failed\. \(Stage:unwrap, .*Result:11\)'
            ;;
        smERR_ABORT_TDEInvalidKeyStore)
            sTracePattern='\[TDE\] startup failed\. \(Stage:unwrap, .*Result:8\)'
            ;;
        smERR_ABORT_TDEMasterKeyHistoryMissing)
            sTracePattern='\[TDE\] startup failed\. \(Stage:unwrap, .*Result:10\)'
            ;;
        smERR_ABORT_TDEAutoLoadDisabled)
            sTracePattern='\[TDE\] startup failed\. \(Stage:auto-load, .*Result:-1\)'
            ;;
        *)
            sTracePattern="${aPattern}"
            ;;
    esac

    if tde_dump_log_from_offset "${aSmLogPath}" "${aSmOffset}" |
         grep -E -q "${sTracePattern}"
    then
        return 0
    fi

    if tde_dump_log_from_offset "${aBootLogPath}" "${aBootOffset}" |
         grep -E -q "${sTracePattern}"
    then
        return 0
    fi

    if tde_dump_log_from_offset "${aErrorLogPath}" "${aErrorOffset}" |
         grep -E -q "${sTracePattern}"
    then
        return 0
    fi

    return 1
}

tde_dump_failure_traces()
{
    aBootLogPath=$1
    aBootOffset=$2
    aSmLogPath=$3
    aSmOffset=$4
    aErrorLogPath=$5
    aErrorOffset=$6

    echo "[tests/tde] appended boot log:" >&2
    tde_dump_log_from_offset "${aBootLogPath}" "${aBootOffset}" | sed -n '1,200p' >&2
    echo "[tests/tde] appended sm log:" >&2
    tde_dump_log_from_offset "${aSmLogPath}" "${aSmOffset}" | sed -n '1,200p' >&2
    echo "[tests/tde] appended error log:" >&2
    tde_dump_log_from_offset "${aErrorLogPath}" "${aErrorOffset}" | sed -n '1,200p' >&2
}

tde_server_stop_expect_success()
{
    sLogPath=$(mktemp)

    tde_run_server stop "${sLogPath}"

    if ! tde_wait_for_server_down
    then
        tde_dump_log "${sLogPath}"
        rm -f "${sLogPath}"
        tde_fail "server did not stop."
    fi

    rm -f "${sLogPath}"
}

tde_server_start_expect_success()
{
    sLogPath=$(mktemp)

    tde_run_server start "${sLogPath}"

    if ! tde_wait_for_server_up
    then
        tde_dump_log "${sLogPath}"
        rm -f "${sLogPath}"
        tde_fail "server did not start."
    fi

    rm -f "${sLogPath}"
}

tde_server_restart_expect_success()
{
    tde_server_stop_expect_success
    tde_server_start_expect_success
}

tde_server_start_expect_failure()
{
    aPattern=$1
    sLogPath=$(mktemp)
    sBootLogPath="${ALTIBASE_HOME}/trc/altibase_boot.log"
    sSmLogPath="${ALTIBASE_HOME}/trc/altibase_sm.log"
    sErrorLogPath="${ALTIBASE_HOME}/trc/altibase_error.log"
    sBootOffset=$(tde_get_file_size "${sBootLogPath}")
    sSmOffset=$(tde_get_file_size "${sSmLogPath}")
    sErrorOffset=$(tde_get_file_size "${sErrorLogPath}")

    tde_run_server start "${sLogPath}"

    if tde_wait_for_server_up
    then
        tde_dump_log "${sLogPath}"
        rm -f "${sLogPath}"
        tde_fail "server unexpectedly started."
    fi

    if [ -n "${aPattern}" ]
    then
        if ! grep -q "${aPattern}" "${sLogPath}"
        then
            if ! tde_trace_contains_start_failure "${aPattern}" \
                    "${sSmLogPath}" "${sSmOffset}" \
                    "${sBootLogPath}" "${sBootOffset}" \
                    "${sErrorLogPath}" "${sErrorOffset}"
            then
                tde_dump_log "${sLogPath}"
                tde_dump_failure_traces "${sBootLogPath}" "${sBootOffset}" \
                    "${sSmLogPath}" "${sSmOffset}" \
                    "${sErrorLogPath}" "${sErrorOffset}"
                rm -f "${sLogPath}"
                tde_fail "expected pattern not found: ${aPattern}"
            fi
        fi
    fi

    rm -f "${sLogPath}"
}

tde_server_start_expect_failure_any()
{
    sLogPath=$(mktemp)
    sBootLogPath="${ALTIBASE_HOME}/trc/altibase_boot.log"
    sSmLogPath="${ALTIBASE_HOME}/trc/altibase_sm.log"
    sErrorLogPath="${ALTIBASE_HOME}/trc/altibase_error.log"
    sBootOffset=$(tde_get_file_size "${sBootLogPath}")
    sSmOffset=$(tde_get_file_size "${sSmLogPath}")
    sErrorOffset=$(tde_get_file_size "${sErrorLogPath}")
    sMatched=0

    tde_run_server start "${sLogPath}"

    if tde_wait_for_server_up
    then
        tde_dump_log "${sLogPath}"
        rm -f "${sLogPath}"
        tde_fail "server unexpectedly started."
    fi

    for sPattern in "$@"
    do
        if grep -q "${sPattern}" "${sLogPath}"
        then
            sMatched=1
            break
        fi

        if tde_trace_contains_start_failure "${sPattern}" \
                "${sSmLogPath}" "${sSmOffset}" \
                "${sBootLogPath}" "${sBootOffset}" \
                "${sErrorLogPath}" "${sErrorOffset}"
        then
            sMatched=1
            break
        fi
    done

    if [ "${sMatched}" -ne 1 ]
    then
        tde_dump_log "${sLogPath}"
        tde_dump_failure_traces "${sBootLogPath}" "${sBootOffset}" \
            "${sSmLogPath}" "${sSmOffset}" \
            "${sErrorLogPath}" "${sErrorOffset}"
        rm -f "${sLogPath}"
        tde_fail "expected startup failure pattern not found."
    fi

    rm -f "${sLogPath}"
}

tde_run_isql_raw()
{
    aOutPath=$1
    sSqlPath=$(mktemp)

    cat > "${sSqlPath}"
    printf '\nquit\n' >> "${sSqlPath}"

    is -s "${TDE_SERVER_HOST}" -port "${TDE_SERVER_PORT}" -f "${sSqlPath}" > "${aOutPath}" 2>&1 || true

    rm -f "${sSqlPath}"
}

tde_run_sysdba_raw()
{
    aOutPath=$1
    sSqlPath=$(mktemp)

    cat > "${sSqlPath}"
    printf '\nquit\n' >> "${sSqlPath}"

    "${ALTIBASE_HOME}/bin/isql" -u sys -p MANAGER -sysdba -noprompt \
        < "${sSqlPath}" > "${aOutPath}" 2>&1 || true

    rm -f "${sSqlPath}"
}

tde_run_isql_best_effort()
{
    sOutPath=$(mktemp)

    tde_run_isql_raw "${sOutPath}" <<EOF
$1
EOF

    rm -f "${sOutPath}"
}

tde_run_isql_checked()
{
    sOutPath=$(mktemp)

    tde_run_isql_raw "${sOutPath}"

    if grep -q "\\[ERR-" "${sOutPath}"
    then
        sed -n '1,200p' "${sOutPath}" >&2
        rm -f "${sOutPath}"
        tde_fail "unexpected SQL error."
    fi

    rm -f "${sOutPath}"
}

tde_run_isql_expect_error()
{
    aPattern=$1
    sOutPath=$(mktemp)

    tde_run_isql_raw "${sOutPath}"

    if ! grep -q "\\[ERR-" "${sOutPath}"
    then
        sed -n '1,200p' "${sOutPath}" >&2
        rm -f "${sOutPath}"
        tde_fail "expected SQL error was not raised."
    fi

    if ! grep -F -q "${aPattern}" "${sOutPath}"
    then
        sed -n '1,200p' "${sOutPath}" >&2
        rm -f "${sOutPath}"
        tde_fail "expected SQL error text not found: ${aPattern}"
    fi

    rm -f "${sOutPath}"
}

tde_query_int()
{
    sOutPath=$(mktemp)
    sValue=

    tde_run_isql_raw "${sOutPath}"

    if grep -q "\\[ERR-" "${sOutPath}"
    then
        sed -n '1,200p' "${sOutPath}" >&2
        rm -f "${sOutPath}"
        tde_fail "unexpected SQL error while querying integer value."
    fi

    sValue=$(awk '
        /^[[:space:]]*[0-9]+[[:space:]]*$/ {
            gsub(/[[:space:]]/, "", $0);
            sValue = $0;
        }
        END {
            if ( sValue == "" ) {
                exit 1;
            }

            print sValue;
        }
    ' "${sOutPath}") || {
        sed -n '1,200p' "${sOutPath}" >&2
        rm -f "${sOutPath}"
        tde_fail "failed to parse integer query result."
    }

    rm -f "${sOutPath}"
    printf '%s\n' "${sValue}"
}

tde_get_active_master_key_id()
{
    tde_query_int <<'EOF'
SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1;
EOF
}

tde_tablespace_exists()
{
    aTablespaceName=$1
    sValue=$(tde_query_int <<EOF
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END FROM V\$TABLESPACES WHERE NAME = '${aTablespaceName}';
EOF
)

    [ "${sValue}" = "1" ]
}

tde_tablespace_is_encrypted()
{
    aTablespaceName=$1
    sValue=$(tde_query_int <<EOF
SELECT CASE WHEN COUNT(*) = 1 AND MAX(IS_ENCRYPTED) = 1 THEN 1 ELSE 0 END
  FROM V\$TABLESPACES
 WHERE NAME = '${aTablespaceName}';
EOF
)

    [ "${sValue}" = "1" ]
}

tde_get_tbs_files()
{
    aTablespaceName=$1

    for sFilePath in "${TDE_DB_DIR}/${aTablespaceName}"-*
    do
        if [ -f "${sFilePath}" ]
        then
            printf '%s\n' "${sFilePath}"
        fi
    done
}

tde_patch_file_hex()
{
    aFilePath=$1
    aOffset=$2
    aHex=$3

    perl -e '
        my ($sPath, $sOffset, $sHex) = @ARGV;
        open(my $sFile, "+<", $sPath) or die "open failed";
        binmode($sFile);
        seek($sFile, $sOffset, 0) or die "seek failed";
        print {$sFile} pack("H*", $sHex) or die "write failed";
        close($sFile) or die "close failed";
    ' "${aFilePath}" "${aOffset}" "${aHex}" ||
        tde_fail "failed to patch file: ${aFilePath}"
}

tde_patch_tbs_files_hex()
{
    aTablespaceName=$1
    aOffset=$2
    aHex=$3
    sFound=0

    for sFilePath in $(tde_get_tbs_files "${aTablespaceName}")
    do
        sFound=1
        tde_patch_file_hex "${sFilePath}" "${aOffset}" "${aHex}"
    done

    [ "${sFound}" -eq 1 ] || tde_fail "tablespace files not found: ${aTablespaceName}"
}

tde_uint32_to_le_hex()
{
    aValue=$1

    perl -e 'printf "%s\n", unpack("H*", pack("V", shift));' "${aValue}"
}

tde_keystore_is_v3()
{
    [ -f "${TDE_KEYSTORE_PATH}" ] || return 1

    [ "$(od -An -tx1 -N4 "${TDE_KEYSTORE_PATH}" | tr -d ' \n')" = "41544b53" ]
}

tde_expect_missing_history_by_header()
{
    aTablespaceName=$1
    aSnapshotName=$2
    RESTORED=0

    cleanup()
    {
        if [ "${RESTORED}" -eq 0 ]
        then
            tde_server_stop_expect_success >/dev/null 2>&1 || true
            tde_restore_snapshot_state "${aSnapshotName}" 1 0
            tde_server_start_expect_success >/dev/null 2>&1 || true
        fi
    }

    tde_case_guard

    tde_checkpoint
    tde_snapshot_state "${aSnapshotName}" 1 0

    ACTIVE_KEY_ID=$(tde_get_active_master_key_id)
    CORRUPTED_KEY_ID=$((ACTIVE_KEY_ID + 1000))
    CORRUPTED_HEX=$(tde_uint32_to_le_hex "${CORRUPTED_KEY_ID}")

    trap cleanup EXIT HUP INT TERM

    tde_server_stop_expect_success
    tde_patch_tbs_files_hex "${aTablespaceName}" \
        "${TDE_HDR_OFFSET_MASTER_KEY_ID}" \
        "${CORRUPTED_HEX}"
    tde_server_start_expect_failure "smERR_ABORT_TDEMasterKeyHistoryMissing"
    tde_restore_snapshot_state "${aSnapshotName}" 1 0
    RESTORED=1
    tde_server_start_expect_success

    trap - EXIT HUP INT TERM
}

tde_snapshot_dir()
{
    printf '%s/%s\n' "${TDE_SNAPSHOT_ROOT}" "$1"
}

tde_snapshot_state()
{
    aSnapshotName=$1
    aWithKeys=${2:-1}
    aWithProperty=${3:-0}
    sSnapshotDir=$(tde_snapshot_dir "${aSnapshotName}")
    sDbDir="${sSnapshotDir}/dbs"
    sLogDir="${sSnapshotDir}/logs"

    rm -rf "${sSnapshotDir}"
    mkdir -p "${sDbDir}" "${sLogDir}" ||
        tde_fail "failed to create snapshot directory: ${sSnapshotDir}"

    : > "${sSnapshotDir}/manifest.txt"

    for sFilePath in "${TDE_DB_DIR}"/*
    do
        if [ -f "${sFilePath}" ]
        then
            cp "${sFilePath}" "${sDbDir}/" ||
                tde_fail "failed to snapshot file: ${sFilePath}"
            basename "${sFilePath}" >> "${sSnapshotDir}/manifest.txt"
        fi
    done

    for sFilePath in "${TDE_LOG_DIR}"/loganchor* "${TDE_LOG_DIR}"/logfile*
    do
        if [ -f "${sFilePath}" ]
        then
            cp "${sFilePath}" "${sLogDir}/" ||
                tde_fail "failed to snapshot log file: ${sFilePath}"
            basename "${sFilePath}" >> "${sSnapshotDir}/manifest.txt"
        fi
    done

    if [ "${aWithKeys}" = "1" ]
    then
        if [ -f "${TDE_KEYSTORE_PATH}" ]
        then
            cp "${TDE_KEYSTORE_PATH}" "${sSnapshotDir}/keystore" ||
                tde_fail "failed to snapshot keystore."
        fi

        if [ -f "${TDE_WRAP_KEY_PATH}" ]
        then
            cp "${TDE_WRAP_KEY_PATH}" "${sSnapshotDir}/wrap.key" ||
                tde_fail "failed to snapshot wrap key."
        fi
    fi

    if [ "${aWithProperty}" = "1" ]
    then
        cp "${ALTIBASE_PROPERTIES_PATH}" "${sSnapshotDir}/altibase.properties" ||
            tde_fail "failed to snapshot property file."
    fi
}

tde_restore_snapshot_state()
{
    aSnapshotName=$1
    aWithKeys=${2:-0}
    aWithProperty=${3:-0}
    sSnapshotDir=$(tde_snapshot_dir "${aSnapshotName}")
    sDbDir="${sSnapshotDir}/dbs"
    sLogDir="${sSnapshotDir}/logs"

    [ -d "${sDbDir}" ] ||
        tde_fail "snapshot DB directory not found: ${sDbDir}"
    [ -d "${sLogDir}" ] ||
        tde_fail "snapshot log directory not found: ${sLogDir}"

    rm -f "${TDE_DB_DIR}"/*
    rm -f "${TDE_LOG_DIR}"/loganchor* "${TDE_LOG_DIR}"/logfile*

    for sFilePath in "${sDbDir}"/*
    do
        if [ -f "${sFilePath}" ]
        then
            cp "${sFilePath}" "${TDE_DB_DIR}/" ||
                tde_fail "failed to restore snapshot file: ${sFilePath}"
        fi
    done

    for sFilePath in "${sLogDir}"/*
    do
        if [ -f "${sFilePath}" ]
        then
            cp "${sFilePath}" "${TDE_LOG_DIR}/" ||
                tde_fail "failed to restore snapshot log: ${sFilePath}"
        fi
    done

    if [ "${aWithKeys}" = "1" ]
    then
        tde_restore_file "${sSnapshotDir}/keystore" "${TDE_KEYSTORE_PATH}"
        tde_restore_file "${sSnapshotDir}/wrap.key" "${TDE_WRAP_KEY_PATH}"
    fi

    if [ "${aWithProperty}" = "1" ]
    then
        tde_restore_file "${sSnapshotDir}/altibase.properties" "${ALTIBASE_PROPERTIES_PATH}"
    fi
}

tde_restore_file()
{
    aBackupPath=$1
    aTargetPath=$2

    if [ -f "${aBackupPath}" ]
    then
        cp "${aBackupPath}" "${aTargetPath}" ||
            tde_fail "failed to restore ${aTargetPath}"
    fi
}

tde_checkpoint()
{
    tde_run_isql_checked <<'EOF'
ALTER SYSTEM CHECKPOINT;
EOF
}

tde_cleanup_temp_plain_objects()
{
    tde_run_isql_best_effort "DROP TABLE ${TDE_TMP_PLAIN_TABLE};
DROP TABLESPACE ${TDE_TMP_PLAIN_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
ALTER SYSTEM CHECKPOINT;"
}

tde_cleanup_new_encrypted_objects()
{
    tde_run_isql_best_effort "DROP TABLE ${TDE_TMP_NEW_ENC_TABLE};
DROP TABLESPACE ${TDE_TMP_NEW_ENC_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
ALTER SYSTEM CHECKPOINT;"
}

tde_cleanup_empty_plain_tablespace()
{
    tde_run_isql_best_effort "DROP TABLESPACE ${TDE_TMP_EMPTY_PLAIN_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
ALTER SYSTEM CHECKPOINT;"
}

tde_decrypt_tablespace_if_needed()
{
    aTablespaceName=$1

    if tde_tablespace_exists "${aTablespaceName}" && tde_tablespace_is_encrypted "${aTablespaceName}"
    then
        tde_run_isql_checked <<EOF
ALTER TABLESPACE ${aTablespaceName} OFFLINE;
ALTER TABLESPACE ${aTablespaceName} ENCRYPTION OFFLINE DECRYPT;
ALTER TABLESPACE ${aTablespaceName} ONLINE;
EOF
    fi
}

tde_run_best_effort_cleanup()
{
    tde_run_isql_best_effort "DROP TABLE ${TDE_TMP_PLAIN_TABLE};
DROP TABLE ${TDE_TMP_NEW_ENC_TABLE};
DROP TABLE ${TDE_REPRO_TABLE};
DROP TABLE ${TDE_EXT_PLAIN_TABLE};
DROP TABLE ${TDE_EXT_ENC_TABLE};
DROP TABLE ${TDE_SQLT_TABLE};
DROP TABLESPACE ${TDE_TMP_PLAIN_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE ${TDE_TMP_EMPTY_PLAIN_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE ${TDE_TMP_NEW_ENC_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE ${TDE_REPRO_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE ${TDE_EXT_ENC_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE ${TDE_SQLT_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
ALTER SYSTEM CHECKPOINT;"
}

tde_force_rebuild_database()
{
    sDbName=$(tde_get_property DB_NAME)
    sOutPath=$(mktemp)

    [ -n "${sDbName}" ] || tde_fail "DB_NAME is not set."

    tde_run_sysdba_raw "${sOutPath}" <<EOF
startup process;
drop database ${sDbName};
create database ${sDbName} INITSIZE=10M noarchivelog character set UTF8 national character set UTF8;
EOF

    if ! grep -q "Create success." "${sOutPath}"
    then
        sed -n '1,200p' "${sOutPath}" >&2
        rm -f "${sOutPath}"
        tde_fail "failed to rebuild the database baseline."
    fi

    rm -f "${sOutPath}"

    sOutPath=$(mktemp)
    tde_run_sysdba_raw "${sOutPath}" <<'EOF'
ALTER SYSTEM SET CHECKPOINT_BULK_WRITE_PAGE_COUNT = 0;
ALTER SYSTEM SET CHECKPOINT_BULK_WRITE_SLEEP_SEC  = 0;
ALTER SYSTEM SET CHECKPOINT_BULK_WRITE_SLEEP_USEC = 0;
shutdown abort;
EOF
    rm -f "${sOutPath}"

    tde_wait_for_server_down >/dev/null 2>&1 || true
}

tde_remove_tde_artifacts()
{
    rm -f "${TDE_KEYSTORE_PATH}" "${TDE_WRAP_KEY_PATH}"
    rm -f \
        ${TDE_DB_DIR}/${TDE_SQLT_TABLESPACE}-* \
        ${TDE_DB_DIR}/${TDE_EXT_PLAIN_TABLESPACE}-* \
        ${TDE_DB_DIR}/${TDE_EXT_ENC_TABLESPACE}-* \
        ${TDE_DB_DIR}/${TDE_TMP_PLAIN_TABLESPACE}-* \
        ${TDE_DB_DIR}/${TDE_TMP_EMPTY_PLAIN_TABLESPACE}-* \
        ${TDE_DB_DIR}/${TDE_TMP_NEW_ENC_TABLESPACE}-* \
        ${TDE_DB_DIR}/${TDE_REPRO_TABLESPACE}-*
}

tde_reset_snapshots()
{
    rm -rf "${TDE_SNAPSHOT_ROOT}"
    mkdir -p "${TDE_SNAPSHOT_ROOT}" ||
        tde_fail "failed to recreate snapshot root."
}

tde_replace_property()
{
    aKey=$1
    aValue=$2
    sTempPath=$(mktemp)

    awk -F= -v aKey="${aKey}" -v aValue="${aValue}" '
        function trim(aText) {
            sub(/^[[:space:]]+/, "", aText);
            sub(/[[:space:]]+$/, "", aText);
            return aText;
        }

        BEGIN {
            sFound = 0;
        }

        trim($1) == aKey {
            print aKey "=" aValue;
            sFound = 1;
            next;
        }

        {
            print;
        }

        END {
            if ( sFound == 0 ) {
                print aKey "=" aValue;
            }
        }
    ' "${ALTIBASE_PROPERTIES_PATH}" > "${sTempPath}" ||
        tde_fail "failed to rewrite property file."

    mv "${sTempPath}" "${ALTIBASE_PROPERTIES_PATH}" ||
        tde_fail "failed to replace property file."
}
