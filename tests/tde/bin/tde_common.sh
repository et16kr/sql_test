#!/bin/sh

# Shared helper functions for sql_test MRDB TDE phase 1 cases.

TDE_SQLT_TABLESPACE=TDE_SQLT_TBS
TDE_SQLT_TABLE=TDE_SQLT_T

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

    ALTIBASE_PROPERTIES_PATH="${ALTIBASE_PROPERTIES_PATH:-${ALTIBASE_HOME}/conf/altibase.properties}"
    export ALTIBASE_PROPERTIES_PATH

    [ -f "${ALTIBASE_PROPERTIES_PATH}" ] ||
        tde_fail "properties file not found: ${ALTIBASE_PROPERTIES_PATH}"
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

    [ -d "${TDE_KEYSTORE_DIR}" ] ||
        tde_fail "keystore parent directory not found: ${TDE_KEYSTORE_DIR}"
    [ -d "${TDE_WRAP_KEY_DIR}" ] ||
        tde_fail "wrap key parent directory not found: ${TDE_WRAP_KEY_DIR}"
    [ -w "${TDE_KEYSTORE_DIR}" ] ||
        tde_fail "keystore parent directory is not writable: ${TDE_KEYSTORE_DIR}"
    [ -w "${TDE_WRAP_KEY_DIR}" ] ||
        tde_fail "wrap key parent directory is not writable: ${TDE_WRAP_KEY_DIR}"
}

tde_probe_server()
{
    printf 'SELECT 1 FROM DUAL;\nquit\n' | is -silent >/dev/null 2>&1
}

tde_wait_for_server_up()
{
    sTry=0

    while [ "${sTry}" -lt 30 ]
    do
        if tde_probe_server
        then
            return 0
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

tde_dump_log()
{
    aLogPath=$1

    if [ -f "${aLogPath}" ]
    then
        sed -n '1,200p' "${aLogPath}" >&2
    fi
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
            tde_dump_log "${sLogPath}"
            rm -f "${sLogPath}"
            tde_fail "expected pattern not found: ${aPattern}"
        fi
    fi

    rm -f "${sLogPath}"
}

tde_run_isql_best_effort()
{
    aSqlPath=$(mktemp)

    cat > "${aSqlPath}" <<EOF
$1
quit
EOF

    is -f "${aSqlPath}" >/dev/null 2>&1 || true
    rm -f "${aSqlPath}"
}

tde_run_best_effort_cleanup()
{
    tde_run_isql_best_effort "DROP TABLE ${TDE_SQLT_TABLE};
DROP TABLESPACE ${TDE_SQLT_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
ALTER SYSTEM CHECKPOINT;"
}

tde_remove_tde_artifacts()
{
    rm -f "${TDE_KEYSTORE_PATH}" "${TDE_WRAP_KEY_PATH}"
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
