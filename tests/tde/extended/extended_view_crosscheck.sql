--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_extended_fixture;
-- Test Purpose: Cross-check general and dedicated views for the extended MRDB fixtures.
-- Checks: Plain and encrypted extended tablespaces are visible with the expected state.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_EXT_PLAIN FROM V$TABLESPACES WHERE NAME = 'TDE2_PLAIN_TBS' AND IS_ENCRYPTED = 0;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_EXT_ENC FROM V$TDE_TABLESPACES WHERE NAME = 'TDE2_ENC_TBS' AND IS_ENCRYPTED = 1 AND ENCRYPT_ALGORITHM = 'AES-256-CTR';
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_REFCOUNT FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1 AND REFERENCED_TABLESPACE_COUNT = 2;