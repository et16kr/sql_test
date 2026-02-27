-- Test Purpose: Validate window sort on memory table with disk-temp default property.
-- Checks:
--   1) table is created without TABLESPACE clause (memory table path)
--   2) __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2 is applied
--   3) window row_number result is correct
--   4) property is reset to default (0) at end
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DWIN_COV06_MEM;
--+SKIP_END;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2;

SELECT CASE
           WHEN MEMORY_VALUE1 = '2' THEN 1 ELSE 0
       END AS PASS_PROP_SET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

CREATE TABLE DWIN_COV06_MEM
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    V1       VARCHAR(512),
    V2       VARCHAR(512)
);

INSERT INTO DWIN_COV06_MEM
SELECT LEVEL,
       MOD(LEVEL, 37),
       RPAD('A' || TO_CHAR(LEVEL), 300, 'A'),
       RPAD('B' || TO_CHAR(MOD(LEVEL, 100)), 300, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 2400;

SELECT ID, GRP_ID, RN
  FROM (
        SELECT ID,
               GRP_ID,
               ROW_NUMBER() OVER (PARTITION BY GRP_ID ORDER BY V2 DESC, ID) AS RN
          FROM DWIN_COV06_MEM
       ) W
 WHERE RN <= 2
 ORDER BY GRP_ID, RN, ID
 LIMIT 60;

SELECT CASE
           WHEN (
                SELECT COUNT(*)
                  FROM (
                        SELECT ID,
                               GRP_ID,
                               ROW_NUMBER() OVER (
                                   PARTITION BY GRP_ID
                                   ORDER BY V2 DESC, ID
                               ) AS RN
                          FROM DWIN_COV06_MEM
                       ) W
                 WHERE RN = 1
                ) = 37
           THEN 1 ELSE 0
       END AS PASS_WINDOW_TOP1
  FROM DUAL;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 0;

SELECT CASE
           WHEN MEMORY_VALUE1 = '0' THEN 1 ELSE 0
       END AS PASS_PROP_RESET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

DROP TABLE DWIN_COV06_MEM;
