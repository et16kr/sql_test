#!/bin/sh

tde_repro_rekey_metadata_mismatch()
{
    REPRO_TABLESPACE=TDE_REPRO_TBS
    REPRO_TABLE=TDE_REPRO_T
    OUT_PATH=$(mktemp)

    cleanup()
    {
        rm -f "${OUT_PATH}"
    }

    trap cleanup EXIT HUP INT TERM

    tde_reset_environment

    tde_run_isql_checked <<EOF
ALTER SYSTEM TDE CREATE KEYSTORE;
ALTER SYSTEM TDE CREATE MASTER KEY;

CREATE MEMORY TABLESPACE ${REPRO_TABLESPACE}
SIZE 64M
AUTOEXTEND OFF
ENCRYPTION;

CREATE TABLE ${REPRO_TABLE}
(
    I INTEGER PRIMARY KEY,
    V VARCHAR(32)
)
TABLESPACE ${REPRO_TABLESPACE};

INSERT INTO ${REPRO_TABLE} VALUES (1, 'repro-alpha');
INSERT INTO ${REPRO_TABLE} VALUES (2, 'repro-beta');
COMMIT;

ALTER SYSTEM CHECKPOINT;
ALTER TABLESPACE ${REPRO_TABLESPACE} OFFLINE;
EOF

    # Reproduce the review finding by corrupting only the on-disk wrapped TBS
    # key after startup has already loaded the runtime TDE key.
    tde_patch_tbs_files_hex "${REPRO_TABLESPACE}" \
                            "${TDE_HDR_OFFSET_WRAPPED_TBS_KEY}" \
                            "00112233"

    tde_run_isql_raw "${OUT_PATH}" <<EOF
ALTER TABLESPACE ${REPRO_TABLESPACE} ENCRYPTION REKEY;
EOF

    tde_run_isql_best_effort <<EOF
ALTER TABLESPACE ${REPRO_TABLESPACE} ONLINE;
EOF

    rm -f "${OUT_PATH}"
    trap - EXIT HUP INT TERM
}
