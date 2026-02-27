-- Test Purpose: Verify ORDER BY on mixed expressions is evaluated and sorted correctly.
-- Checks: Expression-based ordering result is deterministic and valid.
-- Disk sort temp coverage FS08: mixed expression sort on packed-row candidate
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_FS08;
--+SKIP_END;

CREATE TABLE DST_COV_FS08
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    K1       VARCHAR(64),
    PAD1     VARCHAR(3200),
    PAD2     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_FS08
SELECT LEVEL,
       MOD(LEVEL, 53),
       'K' || LPAD(TO_CHAR(MOD(LEVEL, 900)), 4, '0'),
       RPAD('A' || TO_CHAR(MOD(LEVEL, 301)), 3200, 'A'),
       RPAD('B' || TO_CHAR(MOD(LEVEL, 211)), 3200, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 2300;

SELECT /*+ TEMP_TBS_DISK */ ID, GRP_ID
  FROM DST_COV_FS08
 ORDER BY MOD(GRP_ID, 7), LENGTH(PAD1) DESC, K1, ID DESC
 LIMIT 70;

DROP TABLE DST_COV_FS08;
