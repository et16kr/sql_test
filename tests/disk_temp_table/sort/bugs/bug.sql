create table t1 (a char(1000), b char(1000), c char(10000), d char(10000), e char(10000)) tablespace sys_tbs_disk_data;
create table t2 (a char(1000), b char(1000), c char(10000), d char(10000), e char(10000)) tablespace sys_tbs_disk_data;

insert into t1 values (1, 1, 1, 1, 1);
insert into t1 values (2, 2, 2, 2, 2);
insert into t1 values (3, 3, 3, 3, 3);
insert into t1 values (4, 4, 4, 4, 4);
insert into t1 values (5, 5, 5, 5, 5);
insert into t1 values (6, 6, 6, 6, 6);
insert into t1 values (7, 7, 7, 7, 7);
insert into t1 values (8, 8, 8, 8, 8);
insert into t1 values (9, 9, 9, 9, 9);
insert into t1 values (1, 1, 1, 1, 1);
insert into t1 values (2, 2, 2, 2, 2);
insert into t1 values (3, 3, 3, 3, 3);
insert into t1 values (4, 4, 4, 4, 4);
insert into t1 values (5, 5, 5, 5, 5);
insert into t1 values (6, 6, 6, 6, 6);
insert into t1 values (7, 7, 7, 7, 7);
insert into t1 values (8, 8, 8, 8, 8);
insert into t1 values (9, 9, 9, 9, 9);

insert into t2 values (5, 5, 50, 50, 50);
insert into t2 values (1, 2, 3, 4, 5);
insert into t2 values (0, 0, 0, 0, 0);
insert into t2 values (1, 1, 100, 100, 100);
insert into t2 values (10, 10, 10, 10, 10);
insert into t2 values (7, 4, 3, 3, 3);
insert into t2 values (8, 8, 9, 9, 9);

ALTER SYSTEM SET INIT_TOTAL_WA_SIZE = 0;
alter system set __TEMP_SORT_ROW_PACKING_DISABLE = 1;

select /*+ USE_SORT(t2, t1) */ (t1.a+0), (t1.b+0), (t1.c+0), (t1.d+0), (t1.e+0), (t2.c+0), (t2.d+0), (t2.e+0)
from t1, t2 where t1.a = t2.a and t1.b = t2.b;

alter system set __TEMP_SORT_ROW_PACKING_DISABLE = 0;

select /*+ USE_SORT(t2, t1) */ (t1.a+0), (t1.b+0), (t1.c+0), (t1.d+0), (t1.e+0), (t2.c+0), (t2.d+0), (t2.e+0)
from t1, t2 where t1.a = t2.a and t1.b = t2.b;

drop table t1;
drop table t2;
ALTER SYSTEM SET INIT_TOTAL_WA_SIZE = 134217728;
