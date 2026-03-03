-- Test Purpose: Verify FULL OUTER sort-join hit/no-hit row preservation.
-- Checks: Both-side unmatched rows are preserved with correct join results.
-- Disk sort temp coverage 13: FULL OUTER JOIN with sort join (hit + nonhit scan)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV13_A;
DROP TABLE DST_COV13_B;
--+SKIP END;

CREATE TABLE DST_COV13_A
(
    ID     INTEGER,
    K1     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV13_B
(
    ID     INTEGER,
    K1     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV13_A
SELECT LEVEL,
       LEVEL,
       RPAD('FA' || TO_CHAR(LEVEL), 3200, 'F')
  FROM DUAL
CONNECT BY LEVEL <= 1000;

INSERT INTO DST_COV13_B
SELECT LEVEL,
       LEVEL + 500,
       RPAD('FB' || TO_CHAR(LEVEL), 3200, 'G')
  FROM DUAL
CONNECT BY LEVEL <= 1000;

SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */
       SUM(CASE WHEN A.K1 IS NULL THEN 1 ELSE 0 END) AS RIGHT_ONLY_CNT,
       SUM(CASE WHEN B.K1 IS NULL THEN 1 ELSE 0 END) AS LEFT_ONLY_CNT,
       COUNT(*) AS TOTAL_CNT
  FROM DST_COV13_A A FULL OUTER JOIN DST_COV13_B B
    ON A.K1 = B.K1;

DROP TABLE DST_COV13_A;
DROP TABLE DST_COV13_B;
