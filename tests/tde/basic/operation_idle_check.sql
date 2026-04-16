--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
-- Test Purpose: Check the dedicated operation view while no TDE task is running.
-- Checks: The singleton operation row stays at NONE/IDLE.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_IDLE_ROW FROM V$TDE_OPERATION WHERE OPERATION = 'NONE' AND STATE = 'IDLE' AND TARGET_MASTER_KEY_ID = 0;