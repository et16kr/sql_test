--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh negative_corrupted_checkpoint_header_hmac;
-- Test Purpose: Corrupt the v3 checkpoint-image header HMAC and verify startup refuses it.
-- Checks: The recovered environment can still read the base encrypted tablespace.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_BASE_ROWS FROM TDE_SQLT_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_BASE_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE_SQLT_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
