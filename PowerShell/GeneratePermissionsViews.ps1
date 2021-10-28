import-module sqlserver

$servername = 'mmcvsdb01\WEBSRV'
$targetDatabase = 'dba'

$sqlcmd =
@"
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[database_connections]'))
EXEC dbo.sp_executesql @statement = N'




CREATE VIEW [dbo].[database_connections] AS
SELECT p.spid  ''Process'',
       db.NAME ''Database'',
       ca.sql ''SQL Statement'',
       c.host_name ''Host Name'',
	   c.program_name,
       c.host_process_id ''Host Process ID'',
       c.login_name ''Login Name'',
       c.login_time ''Login Time'' 
      -- c.*
FROM   sys.sysprocesses p
       JOIN sys.databases db
         ON p.dbid = db.database_id
       JOIN sys.dm_exec_sessions c
         ON p.spid = c.session_id
       CROSS APPLY (SELECT text ''sql''
                    FROM   sys.Fn_get_sql(p.sql_handle)) ca
WHERE  spid > 50 



' 
GO



IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[DatabasePermissions]'))
EXEC dbo.sp_executesql @statement = N'

CREATE VIEW [dbo].[DatabasePermissions]
AS
SELECT u.[DatabaseName]
      ,u.[UserName]
      ,u.[DatabaseRole]
	  ,m.WindowsGroup
	  ,u.[LoginName]
  FROM [dbo].[WindowsUsers] u
  left join GroupMembers m on u.[UserName] = m.[LoginName]
  union
  SELECT [DatabaseName]
      ,[UserName]
      ,[DatabaseRole]
	  ,[UserName]
	  ,[LoginName]
  FROM [dbo].[WindowsGroups]
      
' 
GO

IF NOT EXISTS (SELECT * FROM sys.fn_listextendedproperty(N'MS_DiagramPane1' , N'SCHEMA',N'dbo', N'VIEW',N'DatabasePermissions', NULL,NULL))
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'DatabasePermissions'
GO

IF NOT EXISTS (SELECT * FROM sys.fn_listextendedproperty(N'MS_DiagramPaneCount' , N'SCHEMA',N'dbo', N'VIEW',N'DatabasePermissions', NULL,NULL))
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'DatabasePermissions'
GO



"@



invoke-sqlcmd -ServerInstance $servername -Database $targetDatabase -Query $sqlcmd



