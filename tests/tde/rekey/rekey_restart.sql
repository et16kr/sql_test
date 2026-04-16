--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rekey_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh rekey_tablespace TDE2_ENC_TBS;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh restart_smoke;
-- Test Purpose: Restart after REKEY on the extended encrypted tablespace.
-- Checks: The rekeyed tablespace remains readable after restart.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ROWS FROM TDE2_ENC_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_REKEYED FROM V$TDE_TABLESPACES WHERE NAME = 'TDE2_ENC_TBS' AND MASTER_KEY_ID = (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);