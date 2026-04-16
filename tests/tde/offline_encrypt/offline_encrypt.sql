--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_extended_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh encrypt_tablespace TDE2_PLAIN_TBS;
-- Test Purpose: Encrypt an existing plain MRDB tablespace while offline.
-- Checks: The plain tablespace becomes encrypted and the operation view reports success.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_PLAIN_COUNT FROM TDE2_PLAIN_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_PLAIN_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE2_PLAIN_TBS'
   AND IS_ENCRYPTED = 1
   AND ENCRYPT_ALGORITHM = 'AES-256-CTR'
   AND MASTER_KEY_ID = (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_OPERATION
  FROM V$TDE_OPERATION
 WHERE OPERATION = 'OFFLINE_ENCRYPT'
   AND STATE = 'SUCCESS';