DECLARE @DatabaseInfo TABLE
(
Database_name varchar(150),
Database_Size bigint,
Remark varchar(2000)
)

Insert @DatabaseInfo 
exec sp_databases;

with LastUsed AS
(
select d.name 'Database', LastUsed =
(select X1= max(bb.xx) 
from (
    select xx = max(last_user_seek) 
        where max(last_user_seek) is not null 
    union all 
    select xx = max(last_user_scan) 
        where max(last_user_scan) is not null 
    union all 
    select xx = max(last_user_lookup) 
        where max(last_user_lookup) is not null 
    union all 
        select xx = max(last_user_update) 
        where max(last_user_update) is not null) bb) 
FROM master.dbo.sysdatabases d 
left outer join 
sys.dm_db_index_usage_stats s 
on d.dbid= s.database_id 
group by d.name
)

select Database_name, Database_size/1000000 'Size in GB', LastUsed from @DatabaseInfo di
join LastUsed lu on di.Database_name = lu.[Database]
order by LastUsed, Database_Size desc

