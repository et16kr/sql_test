--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_extended_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh encrypt_tablespace TDE2_PLAIN_TBS;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh restart_smoke;
-- Test Purpose: Restart after OFFLINE ENCRYPT on an existing plain tablespace.
-- Checks: The newly encrypted tablespace remains readable after restart.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ROWS FROM TDE2_PLAIN_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENC_TBS FROM V$TDE_TABLESPACES WHERE NAME = 'TDE2_PLAIN_TBS' AND IS_ENCRYPTED = 1;