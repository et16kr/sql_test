-- Test Purpose: Verify RIGHT OUTER sort-join hit/no-hit semantics.
-- Checks: Matched rows and right-side unmatched rows are correct.
-- Disk sort temp coverage HN04: RIGHT OUTER sort join hit/non-hit path
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_HN04_A;
DROP TABLE DST_COV_HN04_B;
--+SKIP END;

CREATE TABLE DST_COV_HN04_A
(
    ID      INTEGER,
    K1      INTEGER,
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV_HN04_B
(
    ID      INTEGER,
    K1      INTEGER,
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_HN04_A
SELECT LEVEL,
       LEVEL,
       RPAD('RA' || TO_CHAR(LEVEL), 3200, 'R')
  FROM DUAL
CONNECT BY LEVEL <= 800;

INSERT INTO DST_COV_HN04_B
SELECT LEVEL,
       LEVEL + 200,
       RPAD('RB' || TO_CHAR(LEVEL), 3200, 'T')
  FROM DUAL
CONNECT BY LEVEL <= 1000;

SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */
       SUM(CASE WHEN A.K1 IS NULL THEN 1 ELSE 0 END) AS RIGHT_ONLY_CNT,
       COUNT(*) AS TOTAL_CNT
  FROM DST_COV_HN04_A A RIGHT OUTER JOIN DST_COV_HN04_B B
    ON A.K1 = B.K1;

DROP TABLE DST_COV_HN04_A;
DROP TABLE DST_COV_HN04_B;
