-- Test Purpose: Verify chained packed rows with many keys in non-key-only fetch path.
-- Checks: Row decode and aggregation remain correct under chained storage.
-- Disk sort temp coverage PR03: packed + chained + many key columns (>8)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_PR03;
--+SKIP_END;

CREATE TABLE DST_COV_PR03
(
    ID       INTEGER,
    K1       VARCHAR(64),
    K2       VARCHAR(64),
    K3       VARCHAR(64),
    K4       VARCHAR(64),
    K5       VARCHAR(64),
    K6       VARCHAR(64),
    K7       VARCHAR(64),
    K8       VARCHAR(64),
    K9       VARCHAR(64),
    V1       VARCHAR(10000),
    V2       VARCHAR(10000),
    V3       VARCHAR(10000)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_PR03
SELECT LEVEL,
       'K1_' || LPAD(TO_CHAR(MOD(LEVEL, 97)), 3, '0'),
       'K2_' || LPAD(TO_CHAR(MOD(LEVEL, 89)), 3, '0'),
       'K3_' || LPAD(TO_CHAR(MOD(LEVEL, 83)), 3, '0'),
       'K4_' || LPAD(TO_CHAR(MOD(LEVEL, 79)), 3, '0'),
       'K5_' || LPAD(TO_CHAR(MOD(LEVEL, 73)), 3, '0'),
       'K6_' || LPAD(TO_CHAR(MOD(LEVEL, 71)), 3, '0'),
       'K7_' || LPAD(TO_CHAR(MOD(LEVEL, 67)), 3, '0'),
       'K8_' || LPAD(TO_CHAR(MOD(LEVEL, 61)), 3, '0'),
       'K9_' || LPAD(TO_CHAR(MOD(LEVEL, 59)), 3, '0'),
       RPAD('V1_' || TO_CHAR(LEVEL), 9000, 'X'),
       RPAD('V2_' || TO_CHAR(MOD(LEVEL, 200)), 9000, 'Y'),
       RPAD('V3_' || TO_CHAR(MOD(LEVEL, 50)), 9000, 'Z')
  FROM DUAL
CONNECT BY LEVEL <= 520;

SELECT /*+ TEMP_TBS_DISK */ ID, LENGTH(V1) AS L1
  FROM DST_COV_PR03
 ORDER BY K1, K2, K3, K4, K5, K6, K7, K8, K9, ID
 LIMIT 40;

SELECT CASE WHEN COUNT(*) = 520 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM DST_COV_PR03;

DROP TABLE DST_COV_PR03;
