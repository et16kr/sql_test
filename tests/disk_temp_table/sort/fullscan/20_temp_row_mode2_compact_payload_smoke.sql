-- Test Purpose: Validate small mode2 compact-payload temp-row behavior on ROW_NUMBER insert-select.
-- Checks:
--   1) __TEMP_SORT_ROW_PACKING = 1 is applied explicitly for deterministic mode2 coverage.
--   2) ROW_NUMBER-based insert-select keeps all 100 source rows.
--   3) x$tablespaces id 4/5 page ratio stays within the expected compact-payload bound.
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SET_ENV ALTIBASE_SYS_TEMP_FILE_INIT_SIZE=1048510;
--+SYSTEM clean;
--+SYSTEM server start;
connect SYS/MANAGER;

--+SKIP BEGIN;
DROP TABLE T1;
DROP TABLE T0;
DROP TABLESPACE TBS1 INCLUDING CONTENTS AND DATAFILES;
--+SKIP END;

CREATE TABLESPACE TBS1 DATAFILE 'tbs1.dbf' SIZE 1M AUTOEXTEND ON MAXSIZE 1G;

CREATE TABLE T0
(
    I0  VARCHAR(5),
    I1  VARCHAR(33),
    I3  VARCHAR(6),
    I4  VARCHAR(6),
    D1  VARCHAR(3200),
    D2  VARCHAR(3200),
    D3  VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE T1
(
    I0  VARCHAR(5),
    I1  VARCHAR(33),
    D1  VARCHAR(3200),
    D2  VARCHAR(3200),
    D3  VARCHAR(3200)
) TABLESPACE TBS1;

INSERT INTO T0
SELECT CHR(65 + MOD(LEVEL, 26)),
       TO_CHAR(LEVEL),
       CHR(65 + MOD(LEVEL, 26)),
       CHR(65 + MOD(LEVEL, 26)),
       CHR(65 + MOD(LEVEL, 26)),
       CHR(65 + MOD(LEVEL, 26)),
       CHR(65 + MOD(LEVEL, 26))
  FROM DUAL
CONNECT BY LEVEL <= 100;

ALTER SYSTEM SET __TEMP_SORT_ROW_PACKING = 1;

INSERT INTO T1
SELECT I0,
       I1,
       D1,
       D2,
       D3
  FROM (
        SELECT TB1.*,
               ROW_NUMBER() OVER (
                   PARTITION BY I0, I1
                   ORDER BY ROWNUM, I4 DESC, I3 DESC
               ) AS SEQNO
          FROM T0 TB1
       )
 WHERE SEQNO = 1;

SELECT CASE WHEN COUNT(*) = 100 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM T1;

SELECT CASE WHEN T.P4 < (T.P5 * 2) THEN 1 ELSE 0 END AS IS_GT
  FROM (
        SELECT MAX(CASE WHEN ID = 4 THEN TOTAL_PAGE_COUNT END) AS P4,
               MAX(CASE WHEN ID = 5 THEN TOTAL_PAGE_COUNT END) AS P5
          FROM X$TABLESPACES
         WHERE ID IN (4, 5)
       ) T;

--+SET_ENV ALTIBASE_SYS_TEMP_FILE_INIT_SIZE=104857600;
--+SYSTEM clean;
--+SYSTEM server start;
