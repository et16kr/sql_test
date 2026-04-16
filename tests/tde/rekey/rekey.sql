--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rekey_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh rekey_tablespace TDE2_ENC_TBS;
-- Test Purpose: Rekey an existing encrypted MRDB tablespace to the active master key.
-- Checks: The encrypted tablespace now points to the active key and the operation view reports success.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ENC_COUNT FROM TDE2_ENC_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_REKEYED_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE2_ENC_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID = (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_OPERATION
  FROM V$TDE_OPERATION
 WHERE OPERATION = 'REKEY'
   AND STATE = 'SUCCESS';