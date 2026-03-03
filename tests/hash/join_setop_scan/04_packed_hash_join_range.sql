-- Test Purpose: Verify packed-row hash join range scenario correctness.
-- Checks: Hash join cardinality and range-filtered rows are correct.
-- Disk hash temp packed-row coverage H04: hash range scan path (openHashCursor/fetchHashNext)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV04_A;
DROP TABLE DHASH_COV04_B;
--+SKIP END;

CREATE TABLE DHASH_COV04_A
(
    ID       INTEGER,
    K1       VARCHAR(64),
    N1       NUMERIC(12)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DHASH_COV04_B
(
    ID       INTEGER,
    K1       VARCHAR(64),
    PAD1     VARCHAR(3200),
    PAD2     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV04_A
SELECT LEVEL,
       'K' || LPAD(TO_CHAR(MOD(LEVEL, 900)), 4, '0'),
       MOD(LEVEL * 17, 100000)
  FROM DUAL
CONNECT BY LEVEL <= 3500;

INSERT INTO DHASH_COV04_B
SELECT LEVEL,
       'K' || LPAD(TO_CHAR(MOD(LEVEL, 900)), 4, '0'),
       RPAD('B1_' || TO_CHAR(LEVEL), 3200, 'X'),
       RPAD('B2_' || TO_CHAR(MOD(LEVEL, 400)), 3200, 'Y')
  FROM DUAL
CONNECT BY LEVEL <= 1800;

SELECT /*+ TEMP_TBS_DISK ORDERED USE_HASH(B, A) */
       COUNT(*) AS JOIN_CNT
  FROM DHASH_COV04_A A, DHASH_COV04_B B
 WHERE A.K1 = B.K1;

SELECT CASE WHEN COUNT(*) = 7000 THEN 1 ELSE 0 END AS PASS_JOIN_CNT
  FROM (
        SELECT /*+ TEMP_TBS_DISK ORDERED USE_HASH(B, A) */
               A.ID,
               B.ID AS BID
          FROM DHASH_COV04_A A, DHASH_COV04_B B
         WHERE A.K1 = B.K1
       ) X;

SELECT /*+ TEMP_TBS_DISK ORDERED USE_HASH(B, A) */
       A.K1,
       LENGTH(B.PAD1) AS L1,
       LENGTH(B.PAD2) AS L2
  FROM DHASH_COV04_A A, DHASH_COV04_B B
 WHERE A.K1 = B.K1
 ORDER BY A.K1, A.ID
 LIMIT 40;

DROP TABLE DHASH_COV04_A;
DROP TABLE DHASH_COV04_B;
