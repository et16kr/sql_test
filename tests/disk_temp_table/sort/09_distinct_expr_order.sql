-- Test Purpose: Verify DISTINCT on expression output with ORDER BY uses correct dedup/sort behavior.
-- Checks: Expression distinctness and final ordering are both satisfied.
-- Disk sort temp coverage FS09: DISTINCT with expression ORDER BY
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_FS09;
--+SKIP END;

CREATE TABLE DST_COV_FS09
(
    ID       INTEGER,
    K1       VARCHAR(64),
    K2       VARCHAR(64),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_FS09
SELECT LEVEL,
       'K' || TO_CHAR(MOD(LEVEL, 170)),
       'Z' || TO_CHAR(MOD(LEVEL, 90)),
       RPAD('C' || TO_CHAR(MOD(LEVEL, 50)), 3200, 'C')
  FROM DUAL
CONNECT BY LEVEL <= 2600;

SELECT /*+ TEMP_TBS_DISK DISTINCT_SORT */ DISTINCT K1, SUBSTR(K2, 1, 2) AS K2S
  FROM DST_COV_FS09
 ORDER BY K1, K2S
 LIMIT 90;

DROP TABLE DST_COV_FS09;
