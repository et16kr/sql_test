--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_offline_decrypt_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh decrypt_tablespace TDE2_PLAIN_TBS;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh restart_smoke;
-- Test Purpose: Restart after OFFLINE DECRYPT on the transformed tablespace.
-- Checks: The decrypted tablespace remains plain and readable after restart.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ROWS FROM TDE2_PLAIN_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_PLAIN_TBS FROM V$TDE_TABLESPACES WHERE NAME = 'TDE2_PLAIN_TBS' AND IS_ENCRYPTED = 0 AND MASTER_KEY_ID = 0;