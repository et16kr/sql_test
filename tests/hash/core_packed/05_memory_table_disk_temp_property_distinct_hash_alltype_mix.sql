-- Test Purpose: Validate DISTINCT_HASH on mixed variable column types.
-- Coverage Types:
--   VARCHAR, NVARCHAR, CHAR, NCHAR, NUMERIC, NUMBER, FLOAT,
--   VARBYTE, VARBIT, BYTE, NIBBLE, BIT
-- Checks:
--   1) __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2 is applied
--   2) DISTINCT_HASH returns expected unique count
--   3) property reset to default (0)

--+SKIP_BEGIN;
DROP TABLE DHASH_COV05_ALLTYPE;
--+SKIP_END;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2;

SELECT CASE
           WHEN MEMORY_VALUE1 = '2' THEN 1 ELSE 0
       END AS PASS_PROP_SET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

CREATE TABLE DHASH_COV05_ALLTYPE
(
    ID         INTEGER,
    C_VARCHAR  VARCHAR(256),
    C_NVARCHAR NVARCHAR(256),
    C_CHAR     CHAR(32),
    C_NCHAR    NCHAR(32),
    C_NUMERIC  NUMERIC(20,6),
    C_NUMBER   NUMBER,
    C_FLOAT    FLOAT,
    C_VARBYTE  VARBYTE(64),
    C_VARBIT   VARBIT(64),
    C_BYTE     BYTE(64),
    C_NIBBLE   NIBBLE(64),
    C_BIT      BIT(64)
);

INSERT INTO DHASH_COV05_ALLTYPE
SELECT LEVEL,
       'K' || LPAD(TO_CHAR(MOD(LEVEL, 257)), 4, '0'),
       'N' || LPAD(TO_CHAR(MOD(LEVEL, 257)), 4, '0'),
       RPAD('C' || TO_CHAR(MOD(LEVEL, 257)), 32, 'C'),
       RPAD('D' || TO_CHAR(MOD(LEVEL, 257)), 32, 'D'),
       TO_NUMBER(MOD(LEVEL, 257)) / 13,
       TO_NUMBER(MOD(LEVEL, 257)) / 17,
       TO_NUMBER(MOD(LEVEL, 257)) / 19,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL
  FROM DUAL
CONNECT BY LEVEL <= 9000;

SELECT /*+ DISTINCT_HASH */
       COUNT(*) AS DISTINCT_CNT
  FROM (
        SELECT DISTINCT C_VARCHAR,
                        C_NVARCHAR,
                        C_CHAR,
                        C_NCHAR,
                        C_NUMERIC,
                        C_NUMBER,
                        C_FLOAT,
                        C_VARBYTE,
                        C_VARBIT,
                        C_BYTE,
                        C_NIBBLE,
                        C_BIT
          FROM DHASH_COV05_ALLTYPE
       ) D;

SELECT /*+ DISTINCT_HASH */
       C_VARCHAR,
       C_NVARCHAR
  FROM (
        SELECT DISTINCT C_VARCHAR,
                        C_NVARCHAR,
                        C_CHAR,
                        C_NCHAR,
                        C_NUMERIC,
                        C_NUMBER,
                        C_FLOAT,
                        C_VARBYTE,
                        C_VARBIT,
                        C_BYTE,
                        C_NIBBLE,
                        C_BIT
          FROM DHASH_COV05_ALLTYPE
       ) D
 ORDER BY C_VARCHAR
 LIMIT 20;

SELECT CASE
           WHEN (
                SELECT /*+ DISTINCT_HASH */ COUNT(*)
                  FROM (
                        SELECT DISTINCT C_VARCHAR,
                                        C_NVARCHAR,
                                        C_CHAR,
                                        C_NCHAR,
                                        C_NUMERIC,
                                        C_NUMBER,
                                        C_FLOAT,
                                        C_VARBYTE,
                                        C_VARBIT,
                                        C_BYTE,
                                        C_NIBBLE,
                                        C_BIT
                          FROM DHASH_COV05_ALLTYPE
                       ) X
                ) = 257
           THEN 1 ELSE 0
       END AS PASS_DISTINCT_CNT
  FROM DUAL;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 0;

SELECT CASE
           WHEN MEMORY_VALUE1 = '0' THEN 1 ELSE 0
       END AS PASS_PROP_RESET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

DROP TABLE DHASH_COV05_ALLTYPE;
