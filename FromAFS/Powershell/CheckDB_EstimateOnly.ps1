Import-Module dbatools
Import-module sqlserver


$Server = 'PLAGVLDEVSQL1'
$Databases = Get-DbaDatabase -SqlInstance $Server | ?{$_.IsSystemObject -eq $false} | select -ExpandProperty Name


 foreach ($db in $Databases)
{
$sqlcmd = 'DBCC CHECKALLOC([' + $db + ']) WITH ESTIMATEONLY'
 Invoke-Sqlcmd -query $sqlcmd  -ServerInstance $Server -Verbose
 }

 foreach ($db in $Databases)
{
$sqlcmd = 'DBCC CHECKDB([' + $db + ']) WITH ESTIMATEONLY'
 Invoke-Sqlcmd -query $sqlcmd  -ServerInstance $Server -Verbose
 }
