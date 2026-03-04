-- Repro script for TEMP_SORT_ROW_PACKED_DISABLE group-by mismatch on disk tablespace.
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md
--
-- Expected on affected build:
--   SELECT COUNT(*) FROM gb_repro;                                => 40
--   MODE 1 grouped row count (subquery count)                     => 7
--   MODE 2 grouped row count (subquery count)                     => 20

-- If the table already exists, drop it first.
--+SET_ENV ALTIBASE_SYS_TEMP_FILE_INIT_SIZE=1048576;
--+SYSTEM clean;
--+SYSTEM server start;
--+SKIP BEGIN;
drop table gb_repro;
--+SKIP END;

create table gb_repro
(
    i_manufact_id  integer,
    i_item_id      char(16),
    i_item_desc    varchar(200),
    i_current_price numeric(7,2)
)
tablespace sys_tbs_disk_data;

-- (100, AAAAAAAADNCBAAAA, ..., 55.87) x 6
insert into gb_repro values (100, 'AAAAAAAADNCBAAAA', 'Serious studies reduce inadeq', 55.87);
insert into gb_repro values (100, 'AAAAAAAADNCBAAAA', 'Serious studies reduce inadeq', 55.87);
insert into gb_repro values (100, 'AAAAAAAADNCBAAAA', 'Serious studies reduce inadeq', 55.87);
insert into gb_repro values (100, 'AAAAAAAADNCBAAAA', 'Serious studies reduce inadeq', 55.87);
insert into gb_repro values (100, 'AAAAAAAADNCBAAAA', 'Serious studies reduce inadeq', 55.87);
insert into gb_repro values (100, 'AAAAAAAADNCBAAAA', 'Serious studies reduce inadeq', 55.87);

-- (482, AAAAAAAACOFCAAAA, ..., 44.30) x 3
insert into gb_repro values (482, 'AAAAAAAACOFCAAAA', 'Fresh pp. may undermine glad, old costs. No doubt urban resources could work even clothes. Forces deal as new, secret parents; together definite police shall cov', 44.30);
insert into gb_repro values (482, 'AAAAAAAACOFCAAAA', 'Fresh pp. may undermine glad, old costs. No doubt urban resources could work even clothes. Forces deal as new, secret parents; together definite police shall cov', 44.30);
insert into gb_repro values (482, 'AAAAAAAACOFCAAAA', 'Fresh pp. may undermine glad, old costs. No doubt urban resources could work even clothes. Forces deal as new, secret parents; together definite police shall cov', 44.30);

-- (380, AAAAAAAAHBODAAAA, ..., 53.54) x 8
insert into gb_repro values (380, 'AAAAAAAAHBODAAAA', 'Beautiful bombs save safely by a authorities; even british changes feel pools. Large losses will find efforts; very gross clubs reconcile ce', 53.54);
insert into gb_repro values (380, 'AAAAAAAAHBODAAAA', 'Beautiful bombs save safely by a authorities; even british changes feel pools. Large losses will find efforts; very gross clubs reconcile ce', 53.54);
insert into gb_repro values (380, 'AAAAAAAAHBODAAAA', 'Beautiful bombs save safely by a authorities; even british changes feel pools. Large losses will find efforts; very gross clubs reconcile ce', 53.54);
insert into gb_repro values (380, 'AAAAAAAAHBODAAAA', 'Beautiful bombs save safely by a authorities; even british changes feel pools. Large losses will find efforts; very gross clubs reconcile ce', 53.54);
insert into gb_repro values (380, 'AAAAAAAAHBODAAAA', 'Beautiful bombs save safely by a authorities; even british changes feel pools. Large losses will find efforts; very gross clubs reconcile ce', 53.54);
insert into gb_repro values (380, 'AAAAAAAAHBODAAAA', 'Beautiful bombs save safely by a authorities; even british changes feel pools. Large losses will find efforts; very gross clubs reconcile ce', 53.54);
insert into gb_repro values (380, 'AAAAAAAAHBODAAAA', 'Beautiful bombs save safely by a authorities; even british changes feel pools. Large losses will find efforts; very gross clubs reconcile ce', 53.54);
insert into gb_repro values (380, 'AAAAAAAAHBODAAAA', 'Beautiful bombs save safely by a authorities; even british changes feel pools. Large losses will find efforts; very gross clubs reconcile ce', 53.54);

-- (300, AAAAAAAADLBEAAAA, ..., 54.92) x 18
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);
insert into gb_repro values (300, 'AAAAAAAADLBEAAAA', 'Traditional cars shall not think often states. Necessary issues apply increased contracts. About royal lines cannot take to the papers. Nevertheless crucial', 54.92);

-- (155, AAAAAAAADNDAAAAA, ..., 47.47) x 1
insert into gb_repro values (155, 'AAAAAAAADNDAAAAA', 'Boats return small, right words. Hours say generally hostile, hard firms. Other, bri', 47.47);

-- (380, AAAAAAAAKFEAAAAA, ..., 65.21) x 2
insert into gb_repro values (380, 'AAAAAAAAKFEAAAAA', 'Available classes could draw linguistic politicians; extremely available times withdraw old changes; common systems would not look all particularly poor others. Free, e', 65.21);
insert into gb_repro values (380, 'AAAAAAAAKFEAAAAA', 'Available classes could draw linguistic politicians; extremely available times withdraw old changes; common systems would not look all particularly poor others. Free, e', 65.21);

-- (774, AAAAAAAAEBHCAAAA, ..., 44.21) x 2
insert into gb_repro values (774, 'AAAAAAAAEBHCAAAA', 'Rights glimpse usually to a strategies. Electronic elements take fiercely formal, other clubs. At all gold words sh', 44.21);
insert into gb_repro values (774, 'AAAAAAAAEBHCAAAA', 'Rights glimpse usually to a strategies. Electronic elements take fiercely formal, other clubs. At all gold words sh', 44.21);

commit;

-- Base row count
select count(*) from gb_repro;

-- Mode 1: expected 7
alter system set __TEMP_SORT_ROW_PACKED_DISABLE = 1;
select count(*) from (
    select i_manufact_id, i_item_id, i_item_desc, i_current_price
      from gb_repro
     group by i_item_id, i_item_desc, i_current_price, i_manufact_id
) x;

-- Mode 2: expected 20 on affected build
alter system set __TEMP_SORT_ROW_PACKED_DISABLE = 0;
select count(*) from (
    select i_manufact_id, i_item_id, i_item_desc, i_current_price
      from gb_repro
     group by i_item_id, i_item_desc, i_current_price, i_manufact_id
) x;

-- Optional detail output
alter system set __TEMP_SORT_ROW_PACKED_DISABLE = 1;
select count(*) from
(select i_manufact_id, i_item_id, i_item_desc, i_current_price
  from gb_repro
 group by i_item_id, i_item_desc, i_current_price, i_manufact_id);

alter system set __TEMP_SORT_ROW_PACKED_DISABLE = 0;
select count(*) from
(select i_manufact_id, i_item_id, i_item_desc, i_current_price
  from gb_repro
 group by i_item_id, i_item_desc, i_current_price, i_manufact_id);
