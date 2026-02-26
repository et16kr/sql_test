-- Test Purpose: Verify packed-row INTERSECT/non-hit behavior with DISTINCT_HASH path.
-- Checks: Non-overlap and overlap set results are correct.
-- Disk hash temp packed-row coverage H06: INTERSECT path (same-row/non-hit)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV06_A;
DROP TABLE DHASH_COV06_B;
--+SKIP END;

CREATE TABLE DHASH_COV06_A
(
    K1       INTEGER,
    K2       VARCHAR(128),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DHASH_COV06_B
(
    K1       INTEGER,
    K2       VARCHAR(128),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV06_A
SELECT LEVEL,
       CASE MOD(LEVEL, 4)
            WHEN 0 THEN 'PX'
            WHEN 1 THEN 'PXA'
            WHEN 2 THEN 'PXAA'
            ELSE 'PXAAA'
       END,
       RPAD('IA' || TO_CHAR(LEVEL), 3200, 'I')
  FROM DUAL
CONNECT BY LEVEL <= 800;

INSERT INTO DHASH_COV06_B
SELECT LEVEL + 400,
       CASE MOD(LEVEL + 400, 4)
            WHEN 0 THEN 'PX'
            WHEN 1 THEN 'PXA'
            WHEN 2 THEN 'PXAA'
            ELSE 'PXAAA'
       END,
       RPAD('IB' || TO_CHAR(LEVEL), 3200, 'J')
  FROM DUAL
CONNECT BY LEVEL <= 800;

SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */
       COUNT(*) AS INTERSECT_CNT
  FROM (
        SELECT K1, K2 FROM DHASH_COV06_A
        INTERSECT
        SELECT K1, K2 FROM DHASH_COV06_B
       ) X;

SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */
       K1,
       K2,
       LENGTH(K2) AS L2
  FROM (
        SELECT K1, K2 FROM DHASH_COV06_A
        INTERSECT
        SELECT K1, K2 FROM DHASH_COV06_B
       ) X
 ORDER BY K1, K2
 LIMIT 30;

SELECT CASE WHEN COUNT(*) = 400 THEN 1 ELSE 0 END AS PASS_INTERSECT
  FROM (
        SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */
               K1,
               K2
          FROM (
                SELECT K1, K2 FROM DHASH_COV06_A
                INTERSECT
                SELECT K1, K2 FROM DHASH_COV06_B
               ) Y
       ) X;

DROP TABLE DHASH_COV06_A;
DROP TABLE DHASH_COV06_B;
