#!/bin/sh

tde_log_files_have_plaintext()
{
    aPlainText=$1
    sFoundLog=0

    for sFilePath in "${TDE_LOG_DIR}"/logfile*
    do
        [ -f "${sFilePath}" ] || continue
        sFoundLog=1
        sScanOffset=0

        if [ -n "${TDE_LOG_SCAN_OFFSETS:-}" ]
        then
            sScanOffset=$(
                awk -v aName="$(basename "${sFilePath}")" '
                    $1 == aName {
                        print $2;
                        sFound = 1;
                        exit;
                    }

                    END {
                        if (sFound != 1) {
                            print 0;
                        }
                    }
                ' "${TDE_LOG_SCAN_OFFSETS}"
            )
        fi

        if tail -c +"$((sScanOffset + 1))" "${sFilePath}" |
             LC_ALL=C grep -a -F -q -- "${aPlainText}"
        then
            return 0
        fi
    done

    [ "${sFoundLog}" -eq 1 ] ||
        tde_fail "log files not found: ${TDE_LOG_DIR}"

    return 1
}

tde_log_record_scan_offsets()
{
    aOffsetPath=$1
    sFoundLog=0

    : > "${aOffsetPath}" ||
        tde_fail "failed to initialize log scan offset file."

    for sFilePath in "${TDE_LOG_DIR}"/logfile*
    do
        [ -f "${sFilePath}" ] || continue
        sFoundLog=1
        printf '%s %s\n' \
            "$(basename "${sFilePath}")" \
            "$(wc -c < "${sFilePath}" | tr -d ' ')" \
            >> "${aOffsetPath}" ||
            tde_fail "failed to record log scan offset."
    done

    [ "${sFoundLog}" -eq 1 ] ||
        tde_fail "log files not found: ${TDE_LOG_DIR}"
}

tde_assert_log_plaintext_absent()
{
    aPlainText=$1

    if tde_log_files_have_plaintext "${aPlainText}"
    then
        tde_fail "plaintext marker was found in recovery logs: ${aPlainText}"
    fi
}

tde_log_assert_markers_absent()
{
    for sMarker in "$@"
    do
        tde_assert_log_plaintext_absent "${sMarker}"
    done
}

tde_log_shutdown_abort()
{
    sOutPath=$(mktemp)

    tde_run_sysdba_raw "${sOutPath}" <<'EOF'
shutdown abort;
EOF

    if ! tde_wait_for_server_down
    then
        sed -n '1,200p' "${sOutPath}" >&2
        rm -f "${sOutPath}"
        tde_fail "server did not stop after shutdown abort."
    fi

    rm -f "${sOutPath}"
}

tde_log_redo_undo_plaintext_absent()
{
    OFFSET_PATH=$(mktemp)

    cleanup()
    {
        TDE_LOG_SCAN_OFFSETS=
        rm -f "${OFFSET_PATH}"
    }

    tde_case_guard
    trap cleanup EXIT HUP INT TERM
    tde_log_record_scan_offsets "${OFFSET_PATH}"

    tde_run_isql_checked <<'EOF'
AUTOCOMMIT OFF;
DELETE FROM TDE_SQLT_T WHERE I IN (1101, 1102);
INSERT INTO TDE_SQLT_T VALUES (1101, 'TDE11_REDO_MARKER');
INSERT INTO TDE_SQLT_T VALUES (1102, 'TDE11_UNDO_BASE');
COMMIT;
UPDATE TDE_SQLT_T SET V = 'TDE11_UNDO_AFTER' WHERE I = 1102;
ROLLBACK;
AUTOCOMMIT ON;
ALTER SYSTEM CHECKPOINT;
EOF

    TDE_LOG_SCAN_OFFSETS=${OFFSET_PATH}
    tde_log_assert_markers_absent \
        "TDE11_REDO_MARKER" \
        "TDE11_UNDO_BASE" \
        "TDE11_UNDO_AFTER"

    trap - EXIT HUP INT TERM
    cleanup
}

tde_log_recovery_after_abort()
{
    OFFSET_PATH=$(mktemp)
    RECOVERED=0

    cleanup()
    {
        TDE_LOG_SCAN_OFFSETS=

        if [ "${RECOVERED}" -eq 0 ] && ! tde_probe_server
        then
            tde_server_start_expect_success >/dev/null 2>&1 || true
        fi

        rm -f "${OFFSET_PATH}"
    }

    tde_case_guard
    trap cleanup EXIT HUP INT TERM
    tde_log_record_scan_offsets "${OFFSET_PATH}"

    tde_run_isql_checked <<'EOF'
DELETE FROM TDE_SQLT_T WHERE I = 1103;
COMMIT;
INSERT INTO TDE_SQLT_T VALUES (1103, 'TDE11_RECOVERY_MARKER');
COMMIT;
EOF

    tde_log_shutdown_abort
    tde_server_start_expect_success

    RECOVERED=1
    trap - EXIT HUP INT TERM

    TDE_LOG_SCAN_OFFSETS=${OFFSET_PATH}
    tde_log_assert_markers_absent "TDE11_RECOVERY_MARKER"

    cleanup
}

tde_log_replication_reader_smoke()
{
    OFFSET_PATH=$(mktemp)

    cleanup()
    {
        TDE_LOG_SCAN_OFFSETS=
        rm -f "${OFFSET_PATH}"
    }

    tde_case_guard
    trap cleanup EXIT HUP INT TERM
    tde_log_record_scan_offsets "${OFFSET_PATH}"

    tde_run_isql_checked <<'EOF'
DELETE FROM TDE_SQLT_T WHERE I IN (1104, 1105);
INSERT INTO TDE_SQLT_T VALUES (1104, 'TDE11_RP_INSERT');
INSERT INTO TDE_SQLT_T VALUES (1105, 'TDE11_RP_UPDATE_A');
COMMIT;
UPDATE TDE_SQLT_T SET V = 'TDE11_RP_UPDATE_B' WHERE I = 1105;
DELETE FROM TDE_SQLT_T WHERE I = 1104;
COMMIT;
ALTER SYSTEM CHECKPOINT;
EOF

    TDE_LOG_SCAN_OFFSETS=${OFFSET_PATH}
    tde_log_assert_markers_absent \
        "TDE11_RP_INSERT" \
        "TDE11_RP_UPDATE_A" \
        "TDE11_RP_UPDATE_B"

    trap - EXIT HUP INT TERM
    cleanup
}
