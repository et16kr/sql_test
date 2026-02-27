-- Test Purpose: Verify hierarchical ORDER SIBLINGS BY ascending behavior.
-- Checks: Sibling ordering and hierarchy traversal order are correct.
-- Disk sort temp coverage 18: CONNECT BY + ORDER SIBLINGS BY with wide rows
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV18_TREE;
--+SKIP_END;

CREATE TABLE DST_COV18_TREE
(
    ID         INTEGER,
    PARENT_ID  INTEGER,
    NAME_KEY   VARCHAR(128),
    PAD1       VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV18_TREE
SELECT LEVEL,
       CASE WHEN LEVEL = 1 THEN NULL ELSE TRUNC((LEVEL - 2) / 3) + 1 END,
       RPAD('NODE' || TO_CHAR(MOD(LEVEL, 200)), 128, 'X'),
       RPAD('TREE' || TO_CHAR(LEVEL), 3200, 'T')
  FROM DUAL
CONNECT BY LEVEL <= 800;

SELECT /*+ TEMP_TBS_DISK */ ID, PARENT_ID, LEVEL
  FROM DST_COV18_TREE
 START WITH PARENT_ID IS NULL
CONNECT BY PRIOR ID = PARENT_ID
 ORDER SIBLINGS BY NAME_KEY;

DROP TABLE DST_COV18_TREE;
