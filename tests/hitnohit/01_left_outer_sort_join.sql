-- Test Purpose: Verify LEFT OUTER sort-join hit/no-hit row preservation.
-- Checks: Matched rows and left-side unmatched rows are both correct.
-- Disk sort temp coverage 12: LEFT OUTER JOIN with sort join (hit/nohit path)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV12_A;
DROP TABLE DST_COV12_B;
--+SKIP_END;

CREATE TABLE DST_COV12_A
(
    ID     INTEGER,
    K1     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV12_B
(
    ID     INTEGER,
    K1     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV12_A
SELECT LEVEL,
       LEVEL,
       RPAD('LA' || TO_CHAR(LEVEL), 3200, 'L')
  FROM DUAL
CONNECT BY LEVEL <= 1200;

INSERT INTO DST_COV12_B
SELECT LEVEL,
       LEVEL * 2,
       RPAD('LB' || TO_CHAR(LEVEL), 3200, 'R')
  FROM DUAL
CONNECT BY LEVEL <= 700;

SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */
       SUM(CASE WHEN B.K1 IS NULL THEN 1 ELSE 0 END) AS LEFT_ONLY_CNT,
       COUNT(*) AS TOTAL_CNT
  FROM DST_COV12_A A LEFT OUTER JOIN DST_COV12_B B
    ON A.K1 = B.K1;

DROP TABLE DST_COV12_A;
DROP TABLE DST_COV12_B;
