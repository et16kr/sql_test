--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh encrypted_file_no_plaintext;
-- Test Purpose: Verify encrypted checkpoint-image files do not expose inserted row plaintext.
-- Checks: The deterministic marker remains readable through SQL while absent from encrypted files.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_MARKER_ROW
  FROM TDE_SQLT_T
 WHERE I = 901
   AND V = 'TDE9_SECRET_ALPHA';
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENCRYPTED_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE_SQLT_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
