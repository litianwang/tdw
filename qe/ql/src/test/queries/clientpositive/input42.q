drop table table1;
create table table1  (col_name1 string, col_name2 string) partition by hashkey(col_name1);
explain
insert overwrite table table1 select * from src;
insert overwrite table table1 select * from src;
select * from table1;
drop table table1;
