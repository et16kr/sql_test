-- Test Purpose: Verify DISTINCT_SORT removes duplicates correctly on disk temp path.
-- Checks: Distinct output cardinality and ordered values are as expected.
-- Disk sort temp coverage 04: DISTINCT_SORT with wide variable columns
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV04;
--+SKIP_END;

CREATE TABLE DST_COV04
(
    ID      INTEGER,
    K1      VARCHAR(64),
    K2      VARCHAR(64),
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV04
SELECT LEVEL,
       'K' || TO_CHAR(MOD(LEVEL, 120)),
       'S' || TO_CHAR(MOD(LEVEL, 45)),
       RPAD('P' || TO_CHAR(MOD(LEVEL, 33)), 3200, 'P')
  FROM DUAL
CONNECT BY LEVEL <= 2400;

SELECT /*+ TEMP_TBS_DISK DISTINCT_SORT */ DISTINCT K1, K2
  FROM DST_COV04
 ORDER BY K1, K2
 LIMIT 60;

SELECT CASE WHEN COUNT(*) = 2400 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM DST_COV04;

DROP TABLE DST_COV04;
