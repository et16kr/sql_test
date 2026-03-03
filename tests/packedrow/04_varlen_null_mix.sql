-- Test Purpose: Verify packed row handling for variable-length columns mixed with NULLs.
-- Checks: NULL/value boundaries and length handling are correct.
-- Disk sort temp coverage PR04: packed var-length null/short/long mixed values
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_PR04;
--+SKIP END;

CREATE TABLE DST_COV_PR04
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    K1       VARCHAR(64),
    V1       VARCHAR(3200),
    V2       VARCHAR(3200),
    V3       VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_PR04
SELECT LEVEL,
       MOD(LEVEL, 41),
       'K' || LPAD(TO_CHAR(MOD(LEVEL, 300)), 4, '0'),
       CASE WHEN MOD(LEVEL, 7) = 0 THEN NULL
            WHEN MOD(LEVEL, 7) = 1 THEN 'S'
            ELSE RPAD('V1_' || TO_CHAR(LEVEL), MOD(LEVEL, 3200), 'A') END,
       CASE WHEN MOD(LEVEL, 9) = 0 THEN NULL
            WHEN MOD(LEVEL, 9) = 1 THEN 'T'
            ELSE RPAD('V2_' || TO_CHAR(MOD(LEVEL, 100)), MOD(LEVEL * 3, 3200), 'B') END,
       CASE WHEN MOD(LEVEL, 11) = 0 THEN NULL
            WHEN MOD(LEVEL, 11) = 1 THEN 'U'
            ELSE RPAD('V3_' || TO_CHAR(MOD(LEVEL, 200)), MOD(LEVEL * 5, 3200), 'C') END
  FROM DUAL
CONNECT BY LEVEL <= 2600;

SELECT /*+ TEMP_TBS_DISK */ ID, GRP_ID, LENGTH(V1) AS L1, LENGTH(V2) AS L2
  FROM DST_COV_PR04
 ORDER BY K1, V1, V2, ID
 LIMIT 60;

SELECT SUM(CASE WHEN V1 IS NULL THEN 1 ELSE 0 END) AS V1_NULL_CNT,
       SUM(CASE WHEN V2 IS NULL THEN 1 ELSE 0 END) AS V2_NULL_CNT,
       COUNT(*) AS TOTAL_CNT
  FROM DST_COV_PR04;

DROP TABLE DST_COV_PR04;
