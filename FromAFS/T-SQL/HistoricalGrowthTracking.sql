DECLARE @FileTable TABLE (
	[Id] [INT] IDENTITY(1,1) NOT NULL,
	[File_Name] [VARCHAR](500) NULL
) 

DECLARE @GrowthTable TABLE(
	[DBNAME] [VARCHAR](50) NULL,
	[File_Name] [VARCHAR](500) NULL,
	[FileGroup_Name] [VARCHAR](500) NULL,
	[File_Location] [VARCHAR](500) NULL,
	[InsertedDate] [DATE] NULL,
	FileSize [INT] NULL,
	FreeSpace [INT] NULL,
	UsedSpace [INT] NULL,
	PctFreeSpace[INT] NULL,
	NextGrowthSize INT,
	Autogrowth VARCHAR(500),
	[90 Day Daily Trend MB] INT NULL,
	DaysUntilGrowth INT,
	Status VARCHAR(500),
	DateOfGrowth DATETIME,
	[UsedSpace - Prev 30 Days] [INT] NULL,
	[UsedSpace - Prev 60 Days]  [INT] NULL,
	[UsedSpace - Prev 90 Days]  [INT] NULL,
	[FreeSpace Prev 30 Days] [INT] NULL,
	[FreeSpace Prev 60 Days] [INT] NULL,
	[FreeSpace Prev 90 Days] [INT] NULL,
	[FreeSpacePct Prev 30 Days] [INT] NULL,
	[FreeSpacePct Prev 60 Days] [INT] NULL,
	[FreeSpacePct Prev 90 Days] [INT] NULL
)

INSERT @FileTable SELECT DISTINCT file_name FROM [dbo].[DBSpaceGrowthTracker]

--SELECT * FROM @FileTable

DECLARE @recordCounter INT = 1,
		@NumberOfRecords INT = (SELECT COUNT(*) FROM @FileTable),
		@FileName varchar(500),
		@maxdate DATETIME,
		@mindate DATETIME

WHILE @recordCounter <= @NumberOfRecords
BEGIN
	SELECT @FileName = File_Name FROM @FileTable WHERE @recordCounter = ID
	SELECT @maxdate = MAX(InsertedDate), @mindate = MIN(InsertedDate) FROM [dbo].[DBSpaceGrowthTracker] WHERE file_name = @filename
 
	INSERT @GrowthTable
	SELECT t1.[DBNAME],
		   t1.[File_Name],
		   t1.[FileGroup_Name],
		   t1.[File_Location],
		   t1.[InsertedDate],
		   t1.[FILESIZE_MB] 'File Size',
		   t1.[FREESPACE_MB] 'Free Space',
		   t1.[USEDSPACE_MB] 'Used space',
		   t1.[FREESPACE_%] 'Pct Free Space',
		   REPLACE(CAST(SUBSTRING(t1.AutoGrow, 4, CHARINDEX(' ', t1.[AutoGrow], 4) - 4) AS INT),'%','PCT') AS 'Next Growth Size MB',
		   t1.AutoGrow,
		   (t1.USEDSPACE_MB - t3.USEDSPACE_MB) / 90 '90 Day Trend',
		   CASE
				WHEN (((t1.USEDSPACE_MB - t4.USEDSPACE_MB) / 90) > 0) THEN ((t1.USEDSPACE_MB - t4.USEDSPACE_MB) / 90) 
				ELSE 0 
		   END AS 'Days Until Growth',
		   CASE
				WHEN t1.FREESPACE_MB < (REPLACE(CAST(SUBSTRING(t1.AutoGrow, 4, CHARINDEX(' ', t1.[AutoGrow], 4) - 4) AS INT),'%','PCT')) THEN 'ALERT'
				ELSE 'Adequate Space For Growth'
			END,
		   CASE
				WHEN (((t1.USEDSPACE_MB - t4.USEDSPACE_MB) / 90) > 0) THEN DATEADD(DAY,((t1.USEDSPACE_MB - t4.USEDSPACE_MB) / 90),GETDATE())
				ELSE 0 
		   END AS 'Forecast Growth Date',
		   t2.[USEDSPACE_MB] 'Used Space 30 days',
		   t3.[USEDSPACE_MB] 'Used Space 60 days',
		   t4.[USEDSPACE_MB] 'Used Space 90 days',
		   t2.[FREESPACE_MB] 'Prev 30 FreeSpace MB',
		   t3.[FREESPACE_MB] 'Prev 60 FreeSpace MB',
		   t4.[FREESPACE_MB] 'Prev 90 FreeSpace MB',
		   t2.[FREESPACE_%] 'Prev 30 FreeSpace %',
		   t3.[FREESPACE_%] 'Prev 60 FreeSpace %',
		   t4.[FREESPACE_%] 'Prev 90 FreeSpace %'
	FROM [SQLDBA].[dbo].[DBSpaceGrowthTracker] t1
		JOIN [SQLDBA].[dbo].[DBSpaceGrowthTracker] t2
			ON t1.File_Name = t2.File_Name
		JOIN [SQLDBA].[dbo].[DBSpaceGrowthTracker] t3
			ON t1.File_Name = t3.File_Name
		JOIN [SQLDBA].[dbo].[DBSpaceGrowthTracker] t4
			ON t1.File_Name = t4.File_Name
	WHERE t1.File_Name = @FileName
		  AND t1.InsertedDate = @maxdate
		  AND t1.InsertedDate = DATEADD(DAY, 30, t2.InsertedDate)
		  AND t1.InsertedDate = DATEADD(DAY, 60, t3.InsertedDate)
		  AND t1.InsertedDate = DATEADD(DAY, 90, t4.InsertedDate)
		  AND t1.autogrow NOT LIKE '%[%]%'
	ORDER BY t1.InsertedDate DESC
  
  --SELECT CAST(SUBSTRING(t1.AutoGrow, 4, CHARINDEX(' ', t1.[AutoGrow], 4) - 4) AS INT) AS 'Next Growth Size MB' FROM [SQLDBA].[dbo].[DBSpaceGrowthTracker] t1  WHERE t1.File_Name = @FileName

	  SET @recordCounter = @recordCounter + 1
  END

  SELECT * FROM @GrowthTable
  WHERE [90 Day Daily Trend MB] > 0
 ORDER BY PctFreeSpace 