-- Test Purpose: Validate DISTINCT_HASH on memory table with disk-temp default property.
-- Checks:
--   1) table is created without TABLESPACE clause (memory table path)
--   2) __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2 is applied
--   3) DISTINCT_HASH results are correct
--   4) property is reset to default (0) at end
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV04_MEM;
--+SKIP END;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2;

SELECT CASE
           WHEN MEMORY_VALUE1 = '2' THEN 1 ELSE 0
       END AS PASS_PROP_SET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

CREATE TABLE DHASH_COV04_MEM
(
    ID      INTEGER,
    K1      VARCHAR(256),
    V1      VARCHAR(512)
);

INSERT INTO DHASH_COV04_MEM
SELECT LEVEL,
       'K' || LPAD(TO_CHAR(MOD(LEVEL, 211)), 4, '0'),
       RPAD('V' || TO_CHAR(MOD(LEVEL, 211)), 300, 'V')
  FROM DUAL
CONNECT BY LEVEL <= 5000;

SELECT /*+ DISTINCT_HASH */
       COUNT(*) AS DISTINCT_CNT
  FROM (
        SELECT DISTINCT K1
          FROM DHASH_COV04_MEM
       ) D;

SELECT /*+ DISTINCT_HASH */
       K1
  FROM (
        SELECT DISTINCT K1
          FROM DHASH_COV04_MEM
       ) D
 ORDER BY K1
 LIMIT 30;

SELECT CASE
           WHEN (
                SELECT /*+ DISTINCT_HASH */ COUNT(*)
                  FROM (
                        SELECT DISTINCT K1
                          FROM DHASH_COV04_MEM
                       ) X
                ) = 211
           THEN 1 ELSE 0
       END AS PASS_DISTINCT_CNT
  FROM DUAL;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 0;

SELECT CASE
           WHEN MEMORY_VALUE1 = '0' THEN 1 ELSE 0
       END AS PASS_PROP_RESET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

DROP TABLE DHASH_COV04_MEM;
