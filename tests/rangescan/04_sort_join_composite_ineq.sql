-- Test Purpose: Verify composite inequality sort join correctness.
-- Checks: Composite predicate evaluation and result cardinality are correct.
-- Disk sort temp coverage RS04: composite key sort join with inequality
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_RS04_A;
DROP TABLE DST_COV_RS04_B;
--+SKIP_END;

CREATE TABLE DST_COV_RS04_A
(
    ID      INTEGER,
    K1      INTEGER,
    K2      INTEGER,
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV_RS04_B
(
    ID      INTEGER,
    K1      INTEGER,
    K2      INTEGER,
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_RS04_A
SELECT LEVEL,
       MOD(LEVEL, 500),
       MOD(LEVEL, 61),
       RPAD('RA' || TO_CHAR(LEVEL), 3200, 'R')
  FROM DUAL
CONNECT BY LEVEL <= 1700;

INSERT INTO DST_COV_RS04_B
SELECT LEVEL,
       MOD(LEVEL, 500),
       MOD(LEVEL, 61),
       RPAD('RB' || TO_CHAR(LEVEL), 3200, 'S')
  FROM DUAL
CONNECT BY LEVEL <= 900;

SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */ COUNT(*) AS JOIN_CNT
  FROM DST_COV_RS04_A A,
       DST_COV_RS04_B B
 WHERE A.K1 = B.K1
   AND A.K2 >= B.K2
   AND A.K2 <= (B.K2 + 2);

DROP TABLE DST_COV_RS04_A;
DROP TABLE DST_COV_RS04_B;
