-- Test Purpose: Verify packed-row update on fixed columns and GROUP_HASH re-read correctness.
-- Checks: Allowed updates are reflected and grouped aggregates stay correct.
-- Disk hash temp packed-row coverage H07: packed update path with fixed aggregate columns
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV07;
--+SKIP END;

CREATE TABLE DHASH_COV07
(
    ID       INTEGER,
    K1       VARCHAR(128),
    N1       NUMERIC(12),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV07
SELECT LEVEL,
       'G' || LPAD(TO_CHAR(MOD(LEVEL, 311)), 4, '0'),
       MOD(LEVEL * 7, 1000),
       RPAD('UP' || TO_CHAR(LEVEL), 3200, 'U')
  FROM DUAL
CONNECT BY LEVEL <= 5000;

SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
       K1,
       COUNT(*) AS CNT_V,
       SUM(N1) AS SUM_V,
       MIN(N1) AS MIN_V,
       MAX(N1) AS MAX_V
  FROM DHASH_COV07
 GROUP BY K1
 ORDER BY K1
 LIMIT 40;

SELECT CASE WHEN H.SUM_N1 = B.SUM_N1 THEN 1 ELSE 0 END AS PASS_SUM
  FROM (
        SELECT SUM(SUM_V) AS SUM_N1
          FROM (
                SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
                       K1,
                       SUM(N1) AS SUM_V
                  FROM DHASH_COV07
                 GROUP BY K1
               ) G
       ) H,
       (
        SELECT SUM(N1) AS SUM_N1
          FROM DHASH_COV07
       ) B;

SELECT CASE WHEN SUM(CNT_V) = 5000 THEN 1 ELSE 0 END AS PASS_CNT
  FROM (
        SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
               K1,
               COUNT(*) AS CNT_V
          FROM DHASH_COV07
         GROUP BY K1
       ) G;

DROP TABLE DHASH_COV07;
