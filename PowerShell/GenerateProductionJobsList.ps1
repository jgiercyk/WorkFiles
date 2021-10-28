import-module dbatools
import-module importexcel
$Path = 'C:\Developer Scripts\ProductionJobsList.xlsx'
$servers = invoke-sqlcmd -ServerInstance mmcvsrvrd01 -Database dba -Query "select Server_Name from ServersToMonitor where monitor = 1" | select -ExpandProperty Server_Name

Get-DbaAgentJob -SqlInstance $servers | ?{$_.enabled -eq $true -and $_.category -ne 'Report Server' -and $_.Name -notlike '*syspol*'} | select ComputerName,Name,LastRunDate,LastRunOutcome,NextRunDate,category,description  | Sort-Object LastRunDate -Descending | Export-Excel -path $path -WorksheetName 'All Servers' -AutoSize -AutoFilter -FreezeTopRow

foreach ($server in $servers)
{
Get-DbaAgentJob -SqlInstance $server | ?{$_.enabled -eq $true -and $_.category -ne 'Report Server' -and $_.Name -notlike '*syspol*'} | select ComputerName,Name,LastRunDate,LastRunOutcome,NextRunDate,category,description  | Sort-Object ComputerName -Descending | Export-Excel -path $path -WorksheetName $server -AutoSize -AutoFilter -FreezeTopRow 
}


