#!/bin/sh

tde_create_temp_plain_fixture()
{
    tde_case_guard
    tde_cleanup_temp_plain_objects

    tde_run_isql_checked <<'EOF'
CREATE MEMORY TABLESPACE TDE_TMP_PLAIN_TBS
SIZE 32M
AUTOEXTEND OFF;

CREATE TABLE TDE_TMP_PLAIN_T
(
    I INTEGER PRIMARY KEY,
    V VARCHAR(32)
)
TABLESPACE TDE_TMP_PLAIN_TBS;

INSERT INTO TDE_TMP_PLAIN_T VALUES (1, 'plain-one');
INSERT INTO TDE_TMP_PLAIN_T VALUES (2, 'plain-two');
COMMIT;

ALTER SYSTEM CHECKPOINT;
EOF
}

tde_create_extended_fixture()
{
    tde_case_guard
    tde_run_isql_best_effort "DROP TABLE ${TDE_EXT_PLAIN_TABLE};
DROP TABLE ${TDE_EXT_ENC_TABLE};
DROP TABLESPACE ${TDE_EXT_PLAIN_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE ${TDE_EXT_ENC_TABLESPACE} INCLUDING CONTENTS AND DATAFILES;
ALTER SYSTEM CHECKPOINT;"

    tde_run_isql_checked <<'EOF'
CREATE MEMORY TABLESPACE TDE2_PLAIN_TBS
SIZE 64M
AUTOEXTEND OFF;

CREATE TABLE TDE2_PLAIN_T
(
    I INTEGER PRIMARY KEY,
    V VARCHAR(32)
)
TABLESPACE TDE2_PLAIN_TBS;

INSERT INTO TDE2_PLAIN_T VALUES (1, 'plain-alpha');
INSERT INTO TDE2_PLAIN_T VALUES (2, 'plain-beta');
COMMIT;

CREATE MEMORY TABLESPACE TDE2_ENC_TBS
SIZE 64M
AUTOEXTEND OFF
ENCRYPTION;

CREATE TABLE TDE2_ENC_T
(
    I INTEGER PRIMARY KEY,
    V VARCHAR(32)
)
TABLESPACE TDE2_ENC_TBS;

INSERT INTO TDE2_ENC_T VALUES (1, 'enc-alpha');
INSERT INTO TDE2_ENC_T VALUES (2, 'enc-beta');
COMMIT;

ALTER SYSTEM CHECKPOINT;
EOF
}

tde_create_new_encrypted_fixture()
{
    tde_case_guard
    tde_cleanup_new_encrypted_objects

    tde_run_isql_checked <<'EOF'
CREATE MEMORY TABLESPACE TDE_TMP_NEW_ENC_TBS
SIZE 32M
AUTOEXTEND OFF
ENCRYPTION;

CREATE TABLE TDE_TMP_NEW_ENC_T
(
    I INTEGER PRIMARY KEY,
    V VARCHAR(32)
)
TABLESPACE TDE_TMP_NEW_ENC_TBS;

INSERT INTO TDE_TMP_NEW_ENC_T VALUES (1, 'new-enc-one');
COMMIT;

ALTER SYSTEM CHECKPOINT;
EOF
}

tde_create_empty_plain_fixture()
{
    tde_case_guard
    tde_cleanup_empty_plain_tablespace

    tde_run_isql_checked <<'EOF'
CREATE MEMORY TABLESPACE TDE_TMP_EMPTY_PLAIN_TBS
SIZE 32M
AUTOEXTEND OFF;

ALTER SYSTEM CHECKPOINT;
EOF
}

tde_encrypt_tablespace()
{
    aTablespaceName=$1

    tde_case_guard
    tde_run_isql_checked <<EOF
ALTER TABLESPACE ${aTablespaceName} OFFLINE;
ALTER TABLESPACE ${aTablespaceName} ENCRYPTION OFFLINE ENCRYPT;
ALTER TABLESPACE ${aTablespaceName} ONLINE;
ALTER SYSTEM CHECKPOINT;
EOF
}

tde_rekey_tablespace()
{
    aTablespaceName=$1

    tde_case_guard
    tde_run_isql_checked <<EOF
ALTER TABLESPACE ${aTablespaceName} OFFLINE;
ALTER TABLESPACE ${aTablespaceName} ENCRYPTION REKEY;
ALTER TABLESPACE ${aTablespaceName} ONLINE;
ALTER SYSTEM CHECKPOINT;
EOF
}

tde_decrypt_tablespace()
{
    aTablespaceName=$1

    tde_case_guard
    tde_run_isql_checked <<EOF
ALTER TABLESPACE ${aTablespaceName} OFFLINE;
ALTER TABLESPACE ${aTablespaceName} ENCRYPTION OFFLINE DECRYPT;
ALTER TABLESPACE ${aTablespaceName} ONLINE;
ALTER SYSTEM CHECKPOINT;
EOF
}

tde_prepare_temp_plain_fixture()
{
    tde_prepare_base_fixture
    tde_create_temp_plain_fixture
}

tde_prepare_extended_fixture()
{
    tde_prepare_base_fixture
    tde_create_extended_fixture
}

tde_prepare_new_encrypted_fixture()
{
    tde_create_new_encrypted_fixture
}

tde_prepare_empty_plain_fixture()
{
    tde_create_empty_plain_fixture
}

tde_prepare_empty_encrypted_fixture()
{
    tde_create_empty_plain_fixture
    tde_encrypt_tablespace "${TDE_TMP_EMPTY_PLAIN_TABLESPACE}"
}

tde_prepare_all_plain_fixture()
{
    tde_prepare_base_fixture
    tde_create_temp_plain_fixture
    tde_create_extended_fixture
    tde_rotate_master_key_once
    tde_rotate_master_key_once
    tde_create_new_encrypted_fixture
    tde_encrypt_tablespace "${TDE_EXT_PLAIN_TABLESPACE}"
    tde_create_empty_plain_fixture
    tde_encrypt_tablespace "${TDE_TMP_EMPTY_PLAIN_TABLESPACE}"
    tde_decrypt_all_and_restart
}
