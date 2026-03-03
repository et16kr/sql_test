-- Test Purpose: Verify packed-row hash subquery/grid fetch path correctness.
-- Checks: HASH_SJ subquery membership and output cardinality are correct.
-- Disk hash temp packed-row coverage H10: hash subquery path (temp RID/grid fetch pattern)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV10_A;
DROP TABLE DHASH_COV10_B;
--+SKIP END;

CREATE TABLE DHASH_COV10_A
(
    ID       INTEGER,
    K1       VARCHAR(64),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DHASH_COV10_B
(
    ID       INTEGER,
    K1       VARCHAR(64),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV10_A
SELECT LEVEL,
       'K' || LPAD(TO_CHAR(LEVEL), 4, '0'),
       RPAD('A' || TO_CHAR(LEVEL), 3200, 'A')
  FROM DUAL
CONNECT BY LEVEL <= 1000;

INSERT INTO DHASH_COV10_B
SELECT LEVEL,
       'K' || LPAD(TO_CHAR(LEVEL + 300), 4, '0'),
       RPAD('B' || TO_CHAR(LEVEL), 3200, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 600;

ALTER SESSION SET EXPLAIN PLAN = ONLY;
SELECT /*+ TEMP_TBS_DISK HASH_SJ */
       A.ID,
       A.K1
  FROM DHASH_COV10_A A
 WHERE A.K1 IN (
       SELECT /*+ HASH_SJ */ B.K1
         FROM DHASH_COV10_B B
       )
 ORDER BY A.K1, A.ID
 LIMIT 20;
ALTER SESSION SET EXPLAIN PLAN = OFF;

SELECT /*+ TEMP_TBS_DISK HASH_SJ */
       COUNT(*) AS MATCH_CNT
  FROM DHASH_COV10_A A
 WHERE A.K1 IN (
       SELECT /*+ HASH_SJ */ B.K1
         FROM DHASH_COV10_B B
       );

SELECT CASE WHEN COUNT(*) = 600 THEN 1 ELSE 0 END AS PASS_HASH_SJ
  FROM (
        SELECT /*+ TEMP_TBS_DISK HASH_SJ */
               A.ID
          FROM DHASH_COV10_A A
         WHERE A.K1 IN (
               SELECT /*+ HASH_SJ */ B.K1
                 FROM DHASH_COV10_B B
               )
       ) X;

DROP TABLE DHASH_COV10_A;
DROP TABLE DHASH_COV10_B;
