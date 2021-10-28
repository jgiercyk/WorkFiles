import-module dbatools
import-module importexcel
$Path = 'C:\Developer Scripts\ProductionDatabaseList.xlsx'
$servers = invoke-sqlcmd -ServerInstance mmcvsrvrd01 -Database dba -Query "select Server_Name from ServersToMonitor where monitor = 1" | select -ExpandProperty Server_Name

foreach ($server in $servers)
{
Get-DbaDatabase -SqlInstance $server | select computername,name,owner,RecoveryModel,SizeMB,CompatibilityLevel,Collation,PrimaryFilePath,LastFullBackup,LastDiffBackup  | Sort-Object Name  | Export-Excel -path $path -WorksheetName $server -AutoSize -AutoFilter -FreezeTopRow 
}

