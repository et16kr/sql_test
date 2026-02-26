-- Test Purpose: Verify full outer join result combined with window processing remains correct.
-- Checks: Join cardinality and downstream window values are valid.
-- Disk sort temp coverage 20: full outer sort join + window update mixed scenario
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV20_A;
DROP TABLE DST_COV20_B;
--+SKIP END;

CREATE TABLE DST_COV20_A
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    KEY1     INTEGER,
    PAD1     VARCHAR(3200),
    PAD2     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV20_B
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    KEY1     INTEGER,
    PAD1     VARCHAR(3200),
    PAD2     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV20_A
SELECT LEVEL,
       MOD(LEVEL, 33),
       LEVEL,
       RPAD('XA' || TO_CHAR(LEVEL), 3200, 'X'),
       RPAD('YA' || TO_CHAR(MOD(LEVEL, 80)), 3200, 'Y')
  FROM DUAL
CONNECT BY LEVEL <= 900;

INSERT INTO DST_COV20_B
SELECT LEVEL,
       MOD(LEVEL, 33),
       LEVEL + 300,
       RPAD('XB' || TO_CHAR(LEVEL), 3200, 'Z'),
       RPAD('YB' || TO_CHAR(MOD(LEVEL, 80)), 3200, 'W')
  FROM DUAL
CONNECT BY LEVEL <= 900;

SELECT GID, RN
  FROM (
        SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */
               CASE WHEN A.GRP_ID IS NULL THEN B.GRP_ID ELSE A.GRP_ID END AS GID,
               ROW_NUMBER() OVER (
                   PARTITION BY CASE WHEN A.GRP_ID IS NULL THEN B.GRP_ID ELSE A.GRP_ID END
                   ORDER BY CASE WHEN A.ID IS NULL THEN B.ID ELSE A.ID END
               ) AS RN
          FROM DST_COV20_A A FULL OUTER JOIN DST_COV20_B B
            ON A.KEY1 = B.KEY1
       ) X
 WHERE RN <= 2
 ORDER BY GID, RN;

DROP TABLE DST_COV20_A;
DROP TABLE DST_COV20_B;
