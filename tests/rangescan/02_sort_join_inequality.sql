-- Test Purpose: Verify inequality-condition sort join correctness.
-- Checks: Range-based join filtering and result cardinality are correct.
-- Disk sort temp coverage 11: range-like sort join predicate
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV11_A;
DROP TABLE DST_COV11_B;
--+SKIP END;

CREATE TABLE DST_COV11_A
(
    ID     INTEGER,
    K1     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV11_B
(
    ID     INTEGER,
    K1     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV11_A
SELECT LEVEL,
       MOD(LEVEL, 500),
       RPAD('A' || TO_CHAR(LEVEL), 3200, 'A')
  FROM DUAL
CONNECT BY LEVEL <= 1400;

INSERT INTO DST_COV11_B
SELECT LEVEL,
       MOD(LEVEL, 500),
       RPAD('B' || TO_CHAR(LEVEL), 3200, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 900;

SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */
       COUNT(*) AS RANGE_JOIN_CNT
  FROM DST_COV11_A A,
       DST_COV11_B B
 WHERE A.K1 >= B.K1
   AND A.K1 <= (B.K1 + 2);

DROP TABLE DST_COV11_A;
DROP TABLE DST_COV11_B;
