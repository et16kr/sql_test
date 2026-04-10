-- Reproducer: FATAL in sort temp packed-row FIRST_VALUE update on chained rows
--             with split-write update payload (PR05 scenario)
--
-- Root cause:
--   fullscan/16_temp_row_mode2_wide_payload.sql sets __TEMP_SORT_ROW_PACKING = 1
--   at line 14 and never resets it.  Tests that follow in all.ts
--   (hierarchy, hitnohit, packedrow/01-05) all inherit packing = 1.
--   When packedrow/05_hotfirst_chained_split_update.sql runs with packing = 1
--   it crashes the server.
--
--   The crash is in the packed-row chained UPDATE path triggered by FIRST_VALUE.
--   The update column V_UPD is 9100 bytes -- larger than one WA page (~8 KB).
--   The written-back value must be split across multiple chained pages
--   ("split write").  The packed chained-row update code does not handle
--   this split-write case correctly and triggers IDE_ERROR(0) inside
--   checkAndDump, crashing the server process.
--
--   This is distinct from BUG-09 (packed_window_update_chained_fatal.sql)
--   which covered the case where the UPDATE value fit within one page but
--   the source row was chained.  Here both the source row AND the update
--   payload require multi-page storage.
--
-- Chaining is triggered by:
--   COLD1 VARCHAR(7000) + COLD2 VARCHAR(7000) = 14000 bytes cold payload
--   V_UPD VARCHAR(9100) hot payload for the first row of each group
--   Combined packed row >> one WA page => chained layout, split update.
--
-- Expected outcome when run standalone with __TEMP_SORT_ROW_PACKING = 1:
--   FATAL (server crash, ERR-91015)
-- When __TEMP_SORT_ROW_PACKING is 0 (default): runs without error.
--
-- This test explicitly sets the property to 1 so it can be run in isolation
-- without depending on another test leaving dirty state.

ALTER SYSTEM SET __TEMP_SORT_ROW_PACKING = 1;

--+SKIP BEGIN;
DROP TABLE T_PKD_PR05_FATAL;
--+SKIP END;

CREATE TABLE T_PKD_PR05_FATAL
(
    ID      INTEGER,
    GRP_ID  INTEGER,
    V_SORT  VARCHAR(128),
    COLD1   VARCHAR(7000),
    COLD2   VARCHAR(7000),
    V_UPD   VARCHAR(10000)
) TABLESPACE SYS_TBS_DISK_DATA;

-- 5 groups x 4 rows = 20 rows.
-- Row 1 of each group: V_UPD = 9100 bytes (forces split write on FIRST_VALUE update).
-- Other rows: V_UPD = 96 bytes (hot section only, no split).
-- COLD1 + COLD2 = 14000 bytes per row => every row is chained.
INSERT INTO T_PKD_PR05_FATAL
SELECT (G.GRP_ID - 1) * 4 + S.SEQ_NO AS ID,
       G.GRP_ID,
       LPAD(TO_CHAR(100 - S.SEQ_NO), 4, '0'),
       RPAD('C1_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 7000, 'X'),
       RPAD('C2_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 7000, 'Y'),
       CASE
           WHEN S.SEQ_NO = 1
               THEN RPAD('TOP_' || TO_CHAR(G.GRP_ID), 9100, 'T')
           ELSE RPAD('LOW_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 96, 'L')
       END
  FROM (SELECT LEVEL AS GRP_ID FROM DUAL CONNECT BY LEVEL <= 5) G,
       (SELECT LEVEL AS SEQ_NO FROM DUAL CONNECT BY LEVEL <= 4) S;

-- This SELECT triggers the crash:
--   TEMP_TBS_DISK forces a sort temp table.
--   FIRST_VALUE writes back V_UPD (9100 bytes) into every row of the partition.
--   The target rows are chained packed rows; the 9100-byte value must be split
--   across chained pages => split-write code path crashes the server.
SELECT /*+ TEMP_TBS_DISK */
       GRP_ID,
       ID,
       LENGTH(FIRST_VALUE(V_UPD) OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID)) AS FV_LEN,
       (LENGTH(COLD1) + LENGTH(COLD2)) AS COLD_SIG
  FROM T_PKD_PR05_FATAL
 ORDER BY GRP_ID, ID;

-- Lines below are unreachable if the bug is present (server crashes above).
DROP TABLE T_PKD_PR05_FATAL;
ALTER SYSTEM SET __TEMP_SORT_ROW_PACKING = 0;
