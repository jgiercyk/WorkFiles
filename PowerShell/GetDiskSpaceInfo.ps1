import-module dbatools -DisableNameChecking
import-module sqlserver -DisableNameChecking

$ServerInfoTable = 'MMCVSRVRD01'
$Database = 'DBA'   

$ServersToCheck = (invoke-sqlcmd -query "SELECT * FROM [dba].[dbo].[ServersToMonitor]  where Monitor = 1" -ServerInstance $ServerInfoTable -WarningAction SilentlyContinue)
Invoke-Sqlcmd -ServerInstance $serverInfoTable  -Database 'dba' -Query 'Truncate Table DriveSpaceInfo' 

TRY{
Foreach ($server in $ServersToCheck)
    {

    $Drives = Get-DbaDiskSpace -ComputerName $server.{server_name}  -WarningAction Stop | select Server, Name, Label, Capacity, Free, PercentFree

    
    Foreach ($drive in $Drives)
        {
            $srv = $drive.server
            $name = $drive.Name
            $label = $drive.Label
            $capacity = $drive.Capacity
            $free = $drive.Free
            $PctFree = $drive.PercentFree
$sqlcmd = 
@"
USE [dba]

INSERT INTO [dbo].[DriveSpaceInfo]
           ([ServerName]
           ,[DriveLetter]
           ,[DriveLabel]
           ,[DiskCapacity]
           ,[FreeSpace]
           ,[PercentFree])
     VALUES
           ('$srv'
           ,'$Name'
           ,'$Label'
           ,'$Capacity'
           ,'$Free'
           ,$PctFree)

"@
  invoke-sqlcmd -query $sqlcmd -ServerInstance $ServerInfoTable -Database $Database

        }    
    }
}
CATCH
{
    $ERROR[0]
    THROW
}
