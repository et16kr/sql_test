--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_temp_plain_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh offline_convert_fresh_nonce;
-- Test Purpose: Verify offline decrypt/re-encrypt of the same logical rows produces fresh ciphertext.
-- Checks: The helper compares copied encrypted files and their nonces across offline conversions.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_MARKER_ROW
  FROM TDE_TMP_PLAIN_T
 WHERE I = 904
   AND V = 'TDE9_OFFLINE_NONCE';
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENCRYPTED_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE_TMP_PLAIN_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
