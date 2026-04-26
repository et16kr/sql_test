--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh v2_compat_or_reject;
-- Test Purpose: Lock the line-based v2 keystore policy as either accepted-and-migrated or explicitly rejected.
-- Checks: The original v3/base encrypted fixture is restored after the policy probe.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_BASE_ROWS FROM TDE_SQLT_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_BASE_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE_SQLT_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
