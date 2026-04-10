-- Reproducer: FATAL in sort temp packed-row window-update on chained rows
--
-- Root cause:
--   fullscan/14_groupby_repro_mode_compare.sql sets __TEMP_SORT_ROW_PACKING = 1
--   at its last statement and never resets it.  Every test that runs after it
--   in all.ts inherits that property value.  When packedrow/02_window_multi_update.sql
--   runs with packing = 1 it crashes the server.
--
--   The crash itself is in the Phase-4/5 packed-row UPDATE path of the sort
--   temp table.  Window functions (ROW_NUMBER, DENSE_RANK, LAG, …) write back
--   their results via smiSortTempTable::update.  When the source row is a
--   *chained* packed row (packed value length exceeds one WA page so the row
--   spans multiple pages), the update logic enters a code path that is not
--   implemented correctly, triggering IDE_ERROR(0) inside checkAndDump which
--   crashes the server process.
--
--   Chained rows are triggered when a table has two or more large VARCHAR
--   columns whose combined packed size exceeds a WA page (~8 KB).
--   Two VARCHAR(3000) columns filled to capacity produce a packed row of
--   roughly 6000+ bytes: this exceeds the internal threshold and forces the
--   chained-row layout, which is the code path that crashes.
--
-- Expected outcome when run standalone: FATAL (server crash, ERR-91015)
-- When __TEMP_SORT_ROW_PACKING is 0 (default): runs without error.
--
-- This test explicitly sets the property to 1 so it can be run in isolation
-- without depending on another test leaving dirty state.

ALTER SYSTEM SET __TEMP_SORT_ROW_PACKING = 1;

--+SKIP BEGIN;
DROP TABLE T_PKD_FATAL;
--+SKIP END;

CREATE TABLE T_PKD_FATAL
(
    ID   INTEGER,
    GRP  INTEGER,
    V1   VARCHAR(3000),
    V2   VARCHAR(3000)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO T_PKD_FATAL
SELECT LEVEL,
       MOD(LEVEL, 5),
       RPAD('A' || TO_CHAR(LEVEL), 3000, 'A'),
       RPAD('B' || TO_CHAR(MOD(LEVEL, 10)), 3000, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 50;

-- This SELECT triggers the crash:
--   TEMP_TBS_DISK forces a sort temp table.
--   ROW_NUMBER writes back into the sort temp table (packed-row update path).
--   With a chained packed row the update crashes the server.
SELECT /*+ TEMP_TBS_DISK */
       GRP,
       ID,
       ROW_NUMBER() OVER (PARTITION BY GRP ORDER BY V1, ID) AS RN
  FROM T_PKD_FATAL
 WHERE ROWNUM <= 5
 ORDER BY GRP, RN;

-- Lines below are unreachable if the bug is present (server crashes above).
DROP TABLE T_PKD_FATAL;
ALTER SYSTEM SET __TEMP_SORT_ROW_PACKING = 0;
