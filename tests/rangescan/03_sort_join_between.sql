-- Test Purpose: Verify BETWEEN-range sort join correctness.
-- Checks: Range inclusion semantics and join counts are correct.
-- Disk sort temp coverage RS03: sort join with BETWEEN-like inequality
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_RS03_A;
DROP TABLE DST_COV_RS03_B;
--+SKIP_END;

CREATE TABLE DST_COV_RS03_A
(
    ID      INTEGER,
    K1      INTEGER,
    K2      INTEGER,
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV_RS03_B
(
    ID      INTEGER,
    K1      INTEGER,
    K2      INTEGER,
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_RS03_A
SELECT LEVEL,
       MOD(LEVEL, 700),
       MOD(LEVEL, 113),
       RPAD('A' || TO_CHAR(LEVEL), 3200, 'A')
  FROM DUAL
CONNECT BY LEVEL <= 1900;

INSERT INTO DST_COV_RS03_B
SELECT LEVEL,
       MOD(LEVEL, 700),
       MOD(LEVEL, 113),
       RPAD('B' || TO_CHAR(LEVEL), 3200, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 1200;

SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */ COUNT(*) AS JOIN_CNT
  FROM DST_COV_RS03_A A,
       DST_COV_RS03_B B
 WHERE A.K1 >= B.K1
   AND A.K1 <= (B.K1 + 5)
   AND A.K2 = B.K2;

DROP TABLE DST_COV_RS03_A;
DROP TABLE DST_COV_RS03_B;
