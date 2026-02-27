-- Test Purpose: Verify LIMIT with ORDER BY on disk temp sort path.
-- Checks: Top-N ordering is correct and deterministic.
-- Disk sort temp coverage 06: LIMIT-SORT on wide rows
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV06;
--+SKIP_END;

CREATE TABLE DST_COV06
(
    ID       INTEGER,
    SCORE    NUMERIC(12),
    TAG      VARCHAR(64),
    PAD1     VARCHAR(3200),
    PAD2     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV06
SELECT LEVEL,
       MOD(LEVEL * 97, 100000),
       'T' || TO_CHAR(MOD(LEVEL, 40)),
       RPAD('Q' || TO_CHAR(MOD(LEVEL, 300)), 3200, 'Q'),
       RPAD('W' || TO_CHAR(MOD(LEVEL, 500)), 3200, 'W')
  FROM DUAL
CONNECT BY LEVEL <= 2200;

SELECT /*+ TEMP_TBS_DISK */ ID, SCORE, TAG
  FROM DST_COV06
 ORDER BY SCORE DESC, ID
 LIMIT 30;

DROP TABLE DST_COV06;
