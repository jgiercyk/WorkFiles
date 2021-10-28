import-module dbatools

$MonitoringServer = 'MMCVSRVRD01'
$MonitoringDatabase = 'DBA_MON'

$servers = invoke-sqlcmd -ServerInstance $MonitoringServer -Database $MonitoringDatabase -Query "select Server_Name from ServersToMonitor where monitor = 1" | select -ExpandProperty Server_Name

$changes = GET-dbaSchemaChangeHistory -SqlInstance $servers -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | ?{$_.Applicationname -notlike '*SQLAgent*' -and $_.ApplicationName -ne 'Microsoft SQL Server' -and $_.ApplicationName -ne 'IBM Cognos 10' -and $_.ApplicationName -notlike '.Net*' -and $_.ApplicationName -notlike 'SSIS*'}
 
foreach ($change in $changes)
{

    $cn = $change.ComputerName
    $db = $change.DatabaseName   
    $dm = $change.DateModified   
    $li = $change.LoginName      
    $un = $change.UserName       
    $an = $change.ApplicationName
    $do = $change.DDLOperation   
    $o  = $change.Object         
    $ot = $change.ObjectType 

   
    $exist = Invoke-Sqlcmd -ServerInstance $MonitoringServer -Database $MonitoringDatabase -query ("SELECT 1 FROM SchemaChangeHistory WHERE [ComputerName] = '" + $cn + "' AND [DateModified] = '" + $dm + "'") -debug -verbose | select -ExpandProperty Column1

    if ($exist -ne '1')
    {
        $InsertQuery = ("INSERT INTO [dbo].[SchemaChangeHistory] SELECT '" + $cn + "','" + $db + "','" + $dm + "','" + $li + "','" + $un + "','" + $an + "','" + $do + "','" + $o + "','" + $ot + "'" )
        Invoke-Sqlcmd -ServerInstance $MonitoringServer -Database $MonitoringDatabase -query $InsertQuery
    }

}

