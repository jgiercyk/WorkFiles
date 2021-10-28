import-module dbatools -DisableNameChecking
import-module sqlserver -DisableNameChecking

$ServerInfoTable = 'PLAGVLPRDSSIS01'
$Database = 'SQLDBA_DATA'   

$ServersToCheck = (invoke-sqlcmd -query "SELECT * FROM [SQLDBA_DATA].[dbo].[ServerInfo]  where Monitor = 1" -ServerInstance $ServerInfoTable -WarningAction SilentlyContinue)

Foreach ($server in $ServersToCheck)
    {

    $Drives = Get-DbaDiskSpace -ComputerName $server.{server name}  -WarningAction SilentlyContinue | select Server, Name, Label, Capacity, Free, PercentFree
    
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
USE [SQLDBA_DATA]

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
