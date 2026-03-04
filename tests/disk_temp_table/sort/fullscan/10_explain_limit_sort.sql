-- Test Purpose: Verify EXPLAIN PLAN ONLY flow does not affect subsequent LIMIT sort execution.
-- Checks: Explain-only stage succeeds and real execution still returns correct ordered rows.
-- Disk sort temp coverage FS10: explain-only + runtime limit-sort
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_FS10;
--+SKIP END;

CREATE TABLE DST_COV_FS10
(
    ID       INTEGER,
    SCORE    NUMERIC(12),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_FS10
SELECT LEVEL,
       MOD(LEVEL * 131, 100000),
       RPAD('E' || TO_CHAR(MOD(LEVEL, 500)), 3200, 'E')
  FROM DUAL
CONNECT BY LEVEL <= 2400;

ALTER SESSION SET EXPLAIN PLAN = ONLY;
SELECT /*+ TEMP_TBS_DISK */ ID, SCORE
  FROM DST_COV_FS10
 ORDER BY SCORE DESC, ID
 LIMIT 25;
ALTER SESSION SET EXPLAIN PLAN = OFF;

SELECT /*+ TEMP_TBS_DISK */ ID, SCORE
  FROM DST_COV_FS10
 ORDER BY SCORE DESC, ID
 LIMIT 25;

DROP TABLE DST_COV_FS10;
