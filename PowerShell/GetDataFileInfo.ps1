import-module dbatools -DisableNameChecking
import-module sqlserver -DisableNameChecking

$ServerInfoTable = 'MMCVSRVRD01'
$Db = 'DBA'   

#Get-DbaDbFile -SqlInstance localhost -Database dba | Out-GridView

$ServersToCheck = (invoke-sqlcmd -query "SELECT * FROM [dba].[dbo].[ServersToMonitor]  where Monitor = 1" -ServerInstance $ServerInfoTable -WarningAction SilentlyContinue)
Invoke-Sqlcmd -ServerInstance $serverInfoTable  -Database $db -Query 'Truncate Table DataFileSpaceInfo' 

TRY{
Foreach ($server in $ServersToCheck)
    {

    $databases = Get-DbaDatabase -SqlInstance $server.Server_name | select -ExpandProperty name

#    $Drives = Get-DbaDiskSpace -ComputerName $server.{server_name}  -WarningAction Stop | select Server, Name, Label, Capacity, Free, PercentFree

    
    Foreach ($database in $databases)
        {
            $DBFiles = Get-DbaDbFile -SqlInstance $server.Server_name -Database $database | select Computername,InstanceName,Database,PhysicalName,LogicalName,Size,UsedSpace,AvailableSpace,NextGrowthEventSize,MaxSize 
            foreach($file in $DBFiles)
            {
           
            $srv = $file.computername
            $inst = $file.instancename
            $dbname = $file.database
            $Pn = $file.PhysicalName
            $Ln = $file.LogicalName
            $Size = $file.Size
            $us = $file.UsedSpace
            $free = $file.AvailableSpace
            $ge = $file.NextGrowthEventSize
            $max = $file.MaxSize

$sqlcmd =
@"
USE [dba]

INSERT INTO [dbo].[DataFileSpaceInfo]
           ([ServerName]
           ,[InstanceName]
           ,[DatabaseName]
           ,[PhysicalName]
           ,[LogicalName]
           ,[Size]
           ,[UsedSpace]
           ,[AvailableSpace]
           ,[MaxSize]
           ,[NextGrowthEvent])
     VALUES
           ('$srv'
           ,'$inst'
           ,'$dbname'
           ,'$pn'
           ,'$ln'
           ,'$size'
           ,'$us'
           ,'$free'
           ,'$max'
           ,'$ge')
"@

            invoke-sqlcmd -query $sqlcmd -ServerInstance $ServerInfoTable -Database $db
            }
        }   
    } 
}
CATCH
{
    $ERROR[0]
    THROW
}
