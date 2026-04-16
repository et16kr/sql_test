-- Test Purpose: Verify wrong wrap key causes startup failure and clean recovery.
-- Checks: Expected startup failure happens and restored environment reads encrypted data.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_COUNT FROM TDE_SQLT_T;
SELECT CASE WHEN SUM(CASE WHEN (I = 1 AND V = 'alpha') OR (I = 2 AND V = 'beta') THEN 1 ELSE 0 END) = 2 THEN 1 ELSE 0 END AS PASS_DISTINCT FROM TDE_SQLT_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_HASH_RESTORE FROM V$TABLESPACES WHERE NAME = 'TDE_SQLT_TBS' AND IS_ENCRYPTED = 1 AND ENCRYPT_ALGORITHM = 'AES-256-CTR' AND MASTER_KEY_ID > 0;
