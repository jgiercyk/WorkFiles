import-module dbatools

$hostserver = 'mmcvsrover'
$serversToMonitor = 'mmcvsrover' ,'mmcvsrvrp01' 

$sqlcmd =
@"
WITH connections
AS (SELECT [Process],
           [Database],
           [SQL Statement],
           [Host Name],
           [program_name],
           [Host Process ID],
           [Login Name],
           [Login Time],
           GETDATE() 'CollectionDate'
    FROM [master].[dbo].[database_connections])
SELECT c.*
FROM connections c
    LEFT JOIN [dbo].[DatabaseConnections] d
        ON c.Process = d.Process
           AND c.[Login Time] = d.[Login Time]
WHERE c.Process <> @@SPID
      AND d.Process IS NULL;
"@

foreach ($server in $serversToMonitor)
{
    $connections = invoke-sqlcmd -ServerInstance $server -Database master -Query $sqlcmd

    foreach ($connection in $connections)
    {
        $1 = $connection.process
        $2 = $connection.database
        $3 = $connection.{sql statement}.replace("'", "``")
        $4 = $connection.{host name} 
        $5 = $connection.programname
        $6 = $connection.{host process id}
        $7 = $connection.{login name}
        $8 = $connection.{login time}
        $9 = $connection.CollectionDate

$insertStatement =
@"
INSERT INTO [dbo].[DatabaseConnections]            
            ([Process]
           ,[Database]
           ,[SQL Statement]
           ,[Host Name]
           ,[program_name]
           ,[Host Process ID]
           ,[Login Name]
           ,[Login Time]
           ,[CollectionDate])
            VALUES ($1,'$2','$3','$4','$5',$6,'$7','$8','$9')
"@

         invoke-sqlcmd -ServerInstance $server -Database master -Query $insertStatement -debug
      
$insertStatement =
@"
INSERT INTO [dbo].[DatabaseConnectionsAllServers]            
            ([ServerName]
           ,[Process]
           ,[Database]
           ,[SQL Statement]
           ,[Host Name]
           ,[program_name]
           ,[Host Process ID]
           ,[Login Name]
           ,[Login Time]
           ,[CollectionDate])
            VALUES ('$server',$1,'$2','$3','$4','$5',$6,'$7','$8','$9')
"@
         invoke-sqlcmd -ServerInstance $hostserver -Database master -Query $insertStatement -debug

    }
}
