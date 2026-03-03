-- Test Purpose: Verify packed-row full scan remains correct with many key groups and wide variable payloads.
-- Checks: Ordering and cardinality remain correct under many-key distribution.
-- Disk sort temp coverage 02: packed row + many sort keys (non key-only compare)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV02;
--+SKIP END;

CREATE TABLE DST_COV02
(
    ID    INTEGER,
    K1    VARCHAR(32),
    K2    VARCHAR(32),
    K3    VARCHAR(32),
    K4    VARCHAR(32),
    K5    VARCHAR(32),
    K6    VARCHAR(32),
    K7    VARCHAR(32),
    K8    VARCHAR(32),
    K9    VARCHAR(32),
    K10   VARCHAR(32),
    PAD1  VARCHAR(3200),
    PAD2  VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV02
SELECT LEVEL,
       LPAD(TO_CHAR(MOD(LEVEL, 97)), 4, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 89)), 4, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 83)), 4, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 79)), 4, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 73)), 4, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 71)), 4, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 67)), 4, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 61)), 4, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 59)), 4, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 53)), 4, '0'),
       RPAD('X' || TO_CHAR(LEVEL), 3200, 'X'),
       RPAD('Y' || TO_CHAR(MOD(LEVEL, 111)), 3200, 'Y')
  FROM DUAL
CONNECT BY LEVEL <= 1500;

SELECT /*+ TEMP_TBS_DISK */ ID
  FROM DST_COV02
 ORDER BY K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, ID
 LIMIT 30;

SELECT CASE WHEN COUNT(*) = 1500 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM DST_COV02;

DROP TABLE DST_COV02;
