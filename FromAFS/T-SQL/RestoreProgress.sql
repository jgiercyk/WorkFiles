SELECT 
       session_id AS SPID
       , command
       , a.TEXT AS Query
       , start_time
       , percent_complete
       , DATEADD(SECOND, estimated_completion_time/1000, GETDATE()) AS estimated_completion_time 
FROM 
       sys.dm_exec_requests r 
CROSS APPLY 
       sys.dm_exec_sql_text(r.sql_handle) a 
WHERE 
       r.command in ('BACKUP DATABASE','RESTORE DATABASE', 'BACKUP LOG')  
