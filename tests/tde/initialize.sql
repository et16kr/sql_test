-- Test Purpose: Reset the dedicated TDE test environment and rebuild the base fixture.
-- Checks: Common keystore, master-key, and base encrypted tablespace setup completes and leaves visible base fixture metadata.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_COUNT FROM TDE_SQLT_T;
SELECT CASE WHEN SUM(CASE WHEN (I = 1 AND V = 'alpha') OR (I = 2 AND V = 'beta') THEN 1 ELSE 0 END) = 2 THEN 1 ELSE 0 END AS PASS_DISTINCT FROM TDE_SQLT_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_HASH_RESTORE FROM V$TABLESPACES WHERE NAME = 'TDE_SQLT_TBS' AND IS_ENCRYPTED = 1 AND ENCRYPT_ALGORITHM = 'AES-256-CTR' AND MASTER_KEY_ID > 0;
