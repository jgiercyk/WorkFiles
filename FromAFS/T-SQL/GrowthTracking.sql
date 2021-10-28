

DECLARE @FileTable TABLE (
	[Id] [INT] IDENTITY(1,1) NOT NULL,
	[File_Name] [VARCHAR](500) NULL
) 

DECLARE @GrowthTable TABLE
(
    [Id] [INT] IDENTITY(1, 1) NOT NULL,
    [DBNAME] [VARCHAR](500) NULL,
    [File_Name] [VARCHAR](500) NULL,
	[FileGroup_Name] [VARCHAR](500) NULL,
    UsedSpace INT,
    PrevUsedSpace INT,
    [FREESPACE_MB] INT,
    [FREESPACE_%] INT,
    [AutoGrow] VARCHAR(500),
    InsertedDate DATETIME
);

DECLARE @ResultsTable TABLE
(
    [Id] [INT] IDENTITY(1, 1) NOT NULL,
    [DBNAME] [VARCHAR](500) NULL,
    [File_Name] [VARCHAR](500) NULL,
	[FileGroup_Name] [VARCHAR](500) NULL,
    UsedSpace INT,
    PrevUsedSpace INT,
	DailyGrowth INT,
    [FREESPACE_MB] INT,
    [FREESPACE_%] INT,
    [AutoGrow] VARCHAR(500),
    InsertedDate DATETIME
);

INSERT @FileTable
SELECT DISTINCT [File_Name]
FROM [dbo].[DBSpaceGrowthTracker]

DECLARE @NumberOfFiles INT = (SELECT COUNT(*) FROM @FileTable),
		@FileCounter INT = 1,
		@DBNAME [VARCHAR](500), 
		@File_Name [VARCHAR](500), 
		@UsedSpace INT,
		@PrevUsedSpace INT

WHILE @FileCounter <= @NumberOfFiles
BEGIN
	SET @File_Name = (SELECT File_Name FROM @FileTable WHERE ID = @FileCounter)

	INSERT @GrowthTable
	(
		DBNAME,
		File_Name,
		[FileGroup_Name],
		UsedSpace,
		PrevUsedSpace,
		[FREESPACE_MB],
		[FREESPACE_%],
		[AutoGrow],
		InsertedDate
	)
	SELECT DBNAME,
			File_Name,
			[FileGroup_Name],
			[USEDSPACE_MB],
			0,
			[FREESPACE_MB],
			[FREESPACE_%],
			[AutoGrow],
			InsertedDate
	FROM [dbo].[DBSpaceGrowthTracker]
	WHERE [File_Name] = @File_Name
	ORDER BY Id

	UPDATE t1 
	SET t1.PrevUsedSpace = t2.UsedSpace
	FROM @GrowthTable t1
	JOIN @GrowthTable t2
	ON t1.File_Name = t2.File_Name
	WHERE t1.ID - 1 = t2.ID AND t1.InsertedDate -1 = t2.InsertedDate

	UPDATE t1 
	SET t1.PrevUsedSpace = t2.UsedSpace
	FROM @GrowthTable t1
	JOIN @GrowthTable t2
	ON t1.File_Name = t2.File_Name
	WHERE t1.ID - 1 = t2.ID AND t1.InsertedDate -1 = t2.InsertedDate

	DELETE @GrowthTable WHERE PrevUsedSpace = 0

	INSERT @ResultsTable
	SELECT DBNAME 'Database',
		File_Name 'FileName',
		[FileGroup_Name] 'File Group',
		UsedSpace 'Used Space',
		PrevUsedSpace 'Previously Used',
		(UsedSpace - PrevUsedSpace) 'Daily Growth In MB',
		[FREESPACE_MB] 'Free Space MB',
		[FREESPACE_%] 'Free Space %',
		[AutoGrow] 'AutoGrow',
		InsertedDate 'Insert Date'

	FROM @GrowthTable
	GROUP BY DBNAME,
			File_Name,
			[FileGroup_Name],
			PrevUsedSpace,
			UsedSpace,
			[FREESPACE_MB],
			[FREESPACE_%],
			[AutoGrow],
			InsertedDate



DELETE FROM @GrowthTable


SET @FileCounter = @FileCounter + 1
END

SELECT DBNAME 'Database',
       File_Name 'FileName',
	   [FileGroup_Name] 'File Group Name',
       PrevUsedSpace 'Previously Used',
       UsedSpace 'Used Space',
       (UsedSpace - PrevUsedSpace) 'Daily Growth In MB',
       [FREESPACE_MB] 'Free Space MB',
       [FREESPACE_%] 'Free Space %',
       [AutoGrow] 'AutoGrow',
       InsertedDate 'Insert Date'
FROM @ResultsTable
ORDER BY File_Name,
         InsertedDate;
