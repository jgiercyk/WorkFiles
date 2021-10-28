/****** Script for SelectTopNRows command from SSMS  ******/
Declare 
      @sdate Date
    , @edate date
    , @ddate date
    , @lastcheckdt date
    , @offsetdays int
    , @offsetdt date

IF @edate is null
SELECT @edate = max(inserteddate)
FROM dbo.dbSpaceGrowthTracker;

IF @sdate is null
SELECT @sdate = max(inserteddate)
FROM dbo.dbSpaceGrowthTracker
WHERE inserteddate < dateAdd(day,-ISNULL(@offsetdays,90),@edate);

IF @ddate is null
SELECT @ddate = Max(inserteddate)
FROm dbo.drivespacegrowthtracker
where inserteddate <= @edate;

WITH cmp AS (
SELECT COALESCE(e.dbname, s.dbname) as dbname
    , COALESCE(e.[file_name], s.[file_name]) as [file_name]
    , COALESCE(e.[filegroup_name], s.[filegroup_name]) as [filegroup_name]
    , COALESCE(e.file_location, s.file_location) as [file_location]
    , DATEDIFF(DAY,s.inserteddate, e.inserteddate) as DaysAveraged
    , (e.usedspace_mb - s.usedspace_mb) / DATEDIFF(DAY,s.inserteddate, e.inserteddate) as mb_per_day
    , LEFT(e.File_location, CHARINDEX('\',e.File_Location, 0)) as drive 
    , CASE WHEN e.AutoGrow = 'By 0 MB - Unrestricted' THEN 0
            WHEN e.AutoGrow IS NOT NULL thEN 1
            ELSE 0 End as AutoGrowthEnabled
    , e.FileSize_MB
    , e.UsedSpace_MB
    , e.FreeSpace_MB
FROM dbo.dbSpaceGrowthTracker e
FULL OUTER JOIN dbo.dbSpaceGrowthTracker s
ON s.dbname = e.dbname
AND s.[file_name] = e.[file_name]
AND s.[filegroup_name] = e.[filegroup_name]
where s.inserteddate = @sdate
AND e.inserteddate = @edate)
,FileGroupTotal as
(SELECT dbname, [filegroup_name], sum(mb_per_day) fg_mb_per_day, sum(freespace_mb) freespace, SUM(AutoGrowthEnabled) as AutoGrowthWeight
    , sum(freespace_mb) / CASE WHEN ISNULL(sum(mb_per_day), 0) = 0 THEN 1 ELSE sum(mb_per_day) END as DaysTillGrowth
FROM cmp
GROUP BY dbname, [filegroup_name])

SELECT cmp.dbname
    , cmp.[file_name]
    , cmp.[filegroup_name]
    , cmp.drive
    , cmp.file_location
    , cmp.FileSize_mb
    , cmp.UsedSpace_mb
    , cmp.FreeSpace_mb
    , cmp.DaysAveraged
    , mb_per_day
    , fg_mb_per_day
    , DaysTillGrowth
    , CAST(AutoGrowthEnabled as decimal(4,2)) / fg.AutoGrowthWeight gw
    , dr.free_in_mb
    , case when daystillgrowth > 90 then 0
        ELSE (90 - daystillgrowth) * fg_mb_per_day * CAST(AutoGrowthEnabled as decimal(4,2)) / fg.AutoGrowthWeight
        END as p90day
        
FROM cmp
INNER JOIN FileGroupTotal fg on cmp.dbname = fg.dbname
                                AND cmp.filegroup_name = fg.filegroup_name
LEFT JOIN DriveSpaceGrowthTracker dr on cmp.drive = dr.volume_mount_point
                                        AND dr.inserteddate = @ddate
										ORDER BY fg.DaysTillGrowth;




