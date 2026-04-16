-- Test Purpose: Clean up all known TDE test fixtures and verify no tracked tablespaces remain.
-- Checks: Base, extended, and temporary MRDB tablespaces are removed from both general and dedicated views.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh finalize_environment;
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS PASS_TABLESPACES_GONE
  FROM V$TABLESPACES
 WHERE NAME IN ('TDE_SQLT_TBS',
                'TDE2_PLAIN_TBS',
                'TDE2_ENC_TBS',
                'TDE_TMP_PLAIN_TBS',
                'TDE_TMP_NEW_ENC_TBS',
                'TDE_TMP_EMPTY_PLAIN_TBS',
                'TDE_REPRO_TBS');
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS PASS_TDE_TABLESPACES_GONE
  FROM V$TDE_TABLESPACES
 WHERE NAME IN ('TDE_SQLT_TBS',
                'TDE2_PLAIN_TBS',
                'TDE2_ENC_TBS',
                'TDE_TMP_PLAIN_TBS',
                'TDE_TMP_NEW_ENC_TBS',
                'TDE_TMP_EMPTY_PLAIN_TBS',
                'TDE_REPRO_TBS');
