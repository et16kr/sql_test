-- Test Purpose: Validate disk sort/group on all SQL-usable variable column types.
-- Coverage Types:
--   VARCHAR, NVARCHAR, CHAR, NCHAR, NUMERIC, NUMBER, FLOAT,
--   VARBYTE, VARBIT, BYTE, NIBBLE, BIT, BLOB, CLOB
-- Checks:
--   1) __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2 is applied
--   2) ORDER BY over mixed payload returns full row count
--   3) GROUP BY count is stable
--   4) variable-length span and null payload checks are correct
--   5) property reset to default (0)

--+SKIP_BEGIN;
DROP TABLE DST_COV_FS19_ALLTYPE;
--+SKIP_END;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2;

SELECT CASE
           WHEN MEMORY_VALUE1 = '2' THEN 1 ELSE 0
       END AS PASS_PROP_SET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

CREATE TABLE DST_COV_FS19_ALLTYPE
(
    ID         INTEGER,
    C_VARCHAR  VARCHAR(1024),
    C_NVARCHAR NVARCHAR(512),
    C_CHAR     CHAR(32),
    C_NCHAR    NCHAR(32),
    C_NUMERIC  NUMERIC(20,6),
    C_NUMBER   NUMBER,
    C_FLOAT    FLOAT,
    C_VARBYTE  VARBYTE(64),
    C_VARBIT   VARBIT(64),
    C_BYTE     BYTE(64),
    C_NIBBLE   NIBBLE(64),
    C_BIT      BIT(64),
    C_BLOB     BLOB,
    C_CLOB     CLOB
);

INSERT INTO DST_COV_FS19_ALLTYPE
SELECT LEVEL,
       CASE MOD(LEVEL, 4)
            WHEN 0 THEN RPAD('V' || TO_CHAR(LEVEL), 33, 'V')
            WHEN 1 THEN RPAD('W' || TO_CHAR(LEVEL), 256, 'W')
            WHEN 2 THEN RPAD('X' || TO_CHAR(LEVEL), 700, 'X')
            ELSE RPAD('Y' || TO_CHAR(LEVEL), 1000, 'Y')
       END,
       RPAD('N' || TO_CHAR(MOD(LEVEL, 300)), 120, 'N'),
       RPAD(CHR(65 + MOD(LEVEL, 26)), 32, CHR(65 + MOD(LEVEL, 26))),
       RPAD(CHR(97 + MOD(LEVEL, 26)), 32, CHR(97 + MOD(LEVEL, 26))),
       TO_NUMBER(MOD(LEVEL, 257)) / 13,
       TO_NUMBER(MOD(LEVEL, 257)) / 17,
       TO_NUMBER(MOD(LEVEL, 257)) / 19,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL
  FROM DUAL
CONNECT BY LEVEL <= 7000;

SELECT COUNT(*) AS SORT_ROW_CNT
  FROM (
        SELECT C_VARCHAR,
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
               C_BIT,
               C_BLOB,
               C_CLOB
          FROM DST_COV_FS19_ALLTYPE
         ORDER BY C_CHAR, C_NUMERIC DESC, ID
       ) S;

SELECT COUNT(*) AS GROUP_CHAR_CNT
  FROM (
        SELECT C_CHAR,
               COUNT(*) AS CNT
          FROM DST_COV_FS19_ALLTYPE
         GROUP BY C_CHAR
       ) G;

SELECT CASE
           WHEN (
                SELECT MIN(LENGTH(C_VARCHAR))
                  FROM DST_COV_FS19_ALLTYPE
                ) = 33
            AND (
                SELECT MAX(LENGTH(C_VARCHAR))
                  FROM DST_COV_FS19_ALLTYPE
                ) = 1000
           THEN 1 ELSE 0
       END AS PASS_VARCHAR_SPAN
  FROM DUAL;

SELECT CASE
           WHEN (
                SELECT COUNT(*)
                  FROM DST_COV_FS19_ALLTYPE
                 WHERE C_BLOB IS NULL
                   AND C_CLOB IS NULL
                   AND C_VARBYTE IS NULL
                   AND C_VARBIT IS NULL
                   AND C_BYTE IS NULL
                   AND C_NIBBLE IS NULL
                   AND C_BIT IS NULL
                ) = 7000
           THEN 1 ELSE 0
       END AS PASS_NULL_VARBIN_LOB
  FROM DUAL;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 0;

SELECT CASE
           WHEN MEMORY_VALUE1 = '0' THEN 1 ELSE 0
       END AS PASS_PROP_RESET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

DROP TABLE DST_COV_FS19_ALLTYPE;
