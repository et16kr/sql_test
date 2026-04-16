--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_empty_encrypted_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh rotate_master_key;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh rekey_tablespace TDE_TMP_EMPTY_PLAIN_TBS;
-- Test Purpose: Rekey an empty encrypted MRDB tablespace.
-- Checks: The empty tablespace moves to the active key.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_EMPTY_REKEYED FROM V$TDE_TABLESPACES WHERE NAME = 'TDE_TMP_EMPTY_PLAIN_TBS' AND IS_ENCRYPTED = 1 AND MASTER_KEY_ID = (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);