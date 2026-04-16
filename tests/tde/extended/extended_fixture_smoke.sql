--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_extended_fixture;
-- Test Purpose: Prepare additional MRDB TDE objects for rotate and offline convert coverage.
-- Checks: Plain and encrypted MRDB tablespaces are created and visible.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_PLAIN_COUNT FROM TDE2_PLAIN_T;
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ENC_COUNT FROM TDE2_ENC_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_PLAIN_TBS FROM V$TABLESPACES WHERE NAME = 'TDE2_PLAIN_TBS' AND IS_ENCRYPTED = 0;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENC_TBS FROM V$TABLESPACES WHERE NAME = 'TDE2_ENC_TBS' AND IS_ENCRYPTED = 1 AND ENCRYPT_ALGORITHM = 'AES-256-CTR' AND MASTER_KEY_ID > 0;