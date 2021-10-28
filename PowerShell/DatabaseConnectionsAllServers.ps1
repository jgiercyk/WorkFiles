import-module dbatools

$hostserver = 'mmcvsrvrd01'
$hostdatabase = 'dba'
$serversToMonitor = 'mmcvsrover' ,'mmcvsrvrp01','mmcvsirdbp01','sv-au','infsql01', 'mmcvsscdbp01.ormutual.com','mmcvsrvrssisp01','mmcvsdb01\WEBSRV'


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
    FROM [dba].[dbo].[database_connections])
SELECT c.*
FROM connections c
    LEFT JOIN [dbo].[DatabaseConnections] d
        ON c.Process = d.Process
           AND CONVERT(VARCHAR,c.[Login Time],120) = CONVERT(VARCHAR,d.[Login Time],120)
WHERE c.Process <> @@SPID
      AND d.Process IS NULL;
"@

TRY
{
    foreach ($server in $serversToMonitor)
    {
        $connections = invoke-sqlcmd -ServerInstance $server -Database dba -Query $sqlcmd  -ErrorAction stop
        $server

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
#            '+++' + $connection


                   invoke-sqlcmd -ServerInstance $server -Database dba -Query $insertStatement  -ErrorAction SilentlyContinue

      
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
                invoke-sqlcmd -ServerInstance $hostserver -Database dba -Query $insertStatement  -ErrorAction SilentlyContinue

        }
    }
}
CATCH
{ 
    $ERROR[0]
    THROW 
}

