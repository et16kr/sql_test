-- Test Purpose: Verify FULL OUTER join behavior on sparse key overlap.
-- Checks: Sparse-match join output includes all required unmatched rows.
-- Disk sort temp coverage HN06: sparse FULL OUTER sort join
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_HN06_A;
DROP TABLE DST_COV_HN06_B;
--+SKIP_END;

CREATE TABLE DST_COV_HN06_A
(
    ID      INTEGER,
    K1      INTEGER,
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV_HN06_B
(
    ID      INTEGER,
    K1      INTEGER,
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_HN06_A
SELECT LEVEL,
       LEVEL * 3,
       RPAD('FA' || TO_CHAR(LEVEL), 3200, 'F')
  FROM DUAL
CONNECT BY LEVEL <= 700;

INSERT INTO DST_COV_HN06_B
SELECT LEVEL,
       LEVEL * 5,
       RPAD('FB' || TO_CHAR(LEVEL), 3200, 'G')
  FROM DUAL
CONNECT BY LEVEL <= 700;

SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */
       SUM(CASE WHEN A.K1 IS NULL THEN 1 ELSE 0 END) AS RIGHT_ONLY_CNT,
       SUM(CASE WHEN B.K1 IS NULL THEN 1 ELSE 0 END) AS LEFT_ONLY_CNT,
       COUNT(*) AS TOTAL_CNT
  FROM DST_COV_HN06_A A FULL OUTER JOIN DST_COV_HN06_B B
    ON A.K1 = B.K1;

DROP TABLE DST_COV_HN06_A;
DROP TABLE DST_COV_HN06_B;
