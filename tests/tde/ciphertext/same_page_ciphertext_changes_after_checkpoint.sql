--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh same_page_ciphertext_changes_after_checkpoint;
-- Test Purpose: Verify repeat checkpoints of the same logical encrypted row produce fresh ciphertext.
-- Checks: The helper compares copied checkpoint images and their file nonces across generations.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_MARKER_ROW
  FROM TDE_SQLT_T
 WHERE I = 903
   AND V = 'TDE9_NONCE_STABLE';
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENCRYPTED_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE_SQLT_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
