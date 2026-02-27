-- Test Purpose: Validate FIRST_VALUE update-column path on memory table with disk-temp default property.
-- Checks:
--   1) table is created without TABLESPACE clause (memory table path)
--   2) __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2 is applied
--   3) FIRST_VALUE + DENSE_RANK works with 14/15/3200 payload boundaries
--   4) property is reset to default (0) at end
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DWIN_COV07_MEM_UPD;
--+SKIP_END;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2;

SELECT CASE
           WHEN MEMORY_VALUE1 = '2' THEN 1 ELSE 0
       END AS PASS_PROP_SET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

CREATE TABLE DWIN_COV07_MEM_UPD
(
    ID         INTEGER,
    GRP_ID     INTEGER,
    V_PAYLOAD  VARCHAR(3200),
    V_SORT     VARCHAR(3200)
);

INSERT INTO DWIN_COV07_MEM_UPD
SELECT LEVEL,
       MOD(LEVEL, 31),
       CASE MOD(LEVEL, 3)
            WHEN 0 THEN RPAD('A' || TO_CHAR(LEVEL), 14, 'A')
            WHEN 1 THEN RPAD('B' || TO_CHAR(LEVEL), 15, 'B')
            ELSE RPAD('C' || TO_CHAR(LEVEL), 3200, 'C')
       END,
       CASE
            WHEN MOD(LEVEL, 3) = MOD(MOD(LEVEL, 31), 3)
            THEN RPAD('Z' || TO_CHAR(LEVEL), 3200, 'Z')
            ELSE RPAD('Q' || TO_CHAR(LEVEL), 3200, 'Q')
       END
  FROM DUAL
CONNECT BY LEVEL <= 2600;

SELECT GRP_ID,
       MIN(FV_LEN) AS MIN_FV_LEN,
       MAX(FV_LEN) AS MAX_FV_LEN,
       COUNT(*) AS CNT
  FROM (
        SELECT GRP_ID,
               DENSE_RANK() OVER (
                   PARTITION BY GRP_ID
                   ORDER BY V_SORT DESC, ID
               ) AS DRANK,
               LENGTH(
                   FIRST_VALUE(V_PAYLOAD) OVER (
                       PARTITION BY GRP_ID
                       ORDER BY V_SORT DESC, ID
                   )
               ) AS FV_LEN
          FROM DWIN_COV07_MEM_UPD
       ) W
 WHERE DRANK <= 2
 GROUP BY GRP_ID
 ORDER BY GRP_ID
 LIMIT 31;

SELECT CASE
           WHEN (
                SELECT COUNT(*)
                  FROM (
                        SELECT GRP_ID,
                               DENSE_RANK() OVER (
                                   PARTITION BY GRP_ID
                                   ORDER BY V_SORT DESC, ID
                               ) AS DRANK
                          FROM DWIN_COV07_MEM_UPD
                       ) W
                 WHERE DRANK = 1
                ) = 31
           THEN 1 ELSE 0
       END AS PASS_TOP1_CNT
  FROM DUAL;

SELECT CASE
           WHEN (
                SELECT COUNT(*)
                  FROM (
                        SELECT DISTINCT
                               LENGTH(
                                   FIRST_VALUE(V_PAYLOAD) OVER (
                                       PARTITION BY GRP_ID
                                       ORDER BY V_SORT DESC, ID
                                   )
                               ) AS FV_LEN
                          FROM DWIN_COV07_MEM_UPD
                       ) X
                 WHERE FV_LEN IN (14, 15, 3200)
                ) = 3
           THEN 1 ELSE 0
       END AS PASS_FV_LEN_CLASSES
  FROM DUAL;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 0;

SELECT CASE
           WHEN MEMORY_VALUE1 = '0' THEN 1 ELSE 0
       END AS PASS_PROP_RESET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

DROP TABLE DWIN_COV07_MEM_UPD;
