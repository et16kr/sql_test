--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_extended_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh negative_invalid_state;
-- Test Purpose: Verify invalid offline TDE state transitions are rejected.
-- Checks: The encrypted tablespace remains online and readable after the expected failure.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ENC_COUNT FROM TDE2_ENC_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_REKEYED_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE2_ENC_TBS'
   AND IS_ENCRYPTED = 1;