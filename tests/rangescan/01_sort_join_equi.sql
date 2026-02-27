-- Test Purpose: Verify equi-condition sort join correctness.
-- Checks: Join cardinality and projected results are correct.
-- Disk sort temp coverage 10: equi join forced to sort join (range cursor path)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV10_A;
DROP TABLE DST_COV10_B;
--+SKIP_END;

CREATE TABLE DST_COV10_A
(
    ID     INTEGER,
    K1     INTEGER,
    K2     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV10_B
(
    ID     INTEGER,
    K1     INTEGER,
    K2     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV10_A
SELECT LEVEL,
       MOD(LEVEL, 401),
       MOD(LEVEL, 113),
       RPAD('A' || TO_CHAR(LEVEL), 3200, 'A')
  FROM DUAL
CONNECT BY LEVEL <= 1800;

INSERT INTO DST_COV10_B
SELECT LEVEL,
       MOD(LEVEL, 401),
       MOD(LEVEL, 113),
       RPAD('B' || TO_CHAR(LEVEL), 3200, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 1900;

SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */
       COUNT(*) AS JOIN_CNT
  FROM DST_COV10_A A,
       DST_COV10_B B
 WHERE A.K1 = B.K1
   AND A.K2 = B.K2;

DROP TABLE DST_COV10_A;
DROP TABLE DST_COV10_B;
