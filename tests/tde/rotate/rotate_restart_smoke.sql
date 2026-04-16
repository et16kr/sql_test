--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rotate_once_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh restart_smoke;
-- Test Purpose: Restart after the first master-key rotate.
-- Checks: Key history and the old tablespace binding survive restart.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_KEY_COUNT FROM V$TDE_MASTER_KEYS;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_OLD_KEY FROM V$TABLESPACES WHERE NAME = 'TDE2_ENC_TBS' AND MASTER_KEY_ID <> (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);