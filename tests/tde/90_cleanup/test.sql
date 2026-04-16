-- Test Purpose: Remove TDE suite objects and leave the dedicated test path clean.
-- Checks: The encrypted MRDB tablespace is gone after suite cleanup runs.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS PASS_COUNT FROM V$TABLESPACES WHERE NAME = 'TDE_SQLT_TBS';
