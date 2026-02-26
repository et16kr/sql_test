-- Test Purpose: Verify hierarchical ORDER SIBLINGS BY descending behavior.
-- Checks: Descending sibling ordering and hierarchy traversal order are correct.
-- Disk sort temp coverage HI02: CONNECT BY with descending sibling order
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_HI02_TREE;
--+SKIP END;

CREATE TABLE DST_COV_HI02_TREE
(
    ID         INTEGER,
    PARENT_ID  INTEGER,
    SORT_KEY   VARCHAR(128),
    PAD1       VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_HI02_TREE
SELECT LEVEL,
       CASE WHEN LEVEL = 1 THEN NULL ELSE TRUNC((LEVEL - 2) / 4) + 1 END,
       RPAD('NODE' || TO_CHAR(MOD(LEVEL, 300)), 128, 'Z'),
       RPAD('H' || TO_CHAR(LEVEL), 3200, 'H')
  FROM DUAL
CONNECT BY LEVEL <= 900;

SELECT /*+ TEMP_TBS_DISK */ ID, PARENT_ID, LEVEL
  FROM DST_COV_HI02_TREE
 START WITH PARENT_ID IS NULL
CONNECT BY PRIOR ID = PARENT_ID
 ORDER SIBLINGS BY SORT_KEY DESC;

DROP TABLE DST_COV_HI02_TREE;
