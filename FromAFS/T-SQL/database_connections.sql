USE [dba]
GO

/****** Object:  View [dbo].[database_connections]    Script Date: 8/23/2018 9:41:16 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[database_connections] AS
SELECT p.spid  'Process',
       db.NAME 'Database',
       ca.sql 'SQL Statement',
       c.host_name 'Host Name',
       c.host_process_id 'Host Process ID',
       c.login_name 'Login Name',
       c.login_time 'Login Time' --,
       --c.*
FROM   sys.sysprocesses p
       JOIN sys.databases db
         ON p.dbid = db.database_id
       JOIN sys.dm_exec_sessions c
         ON p.spid = c.session_id
       CROSS apply (SELECT text 'sql'
                    FROM   sys.Fn_get_sql(p.sql_handle)) ca
WHERE  spid > 50 


GO

