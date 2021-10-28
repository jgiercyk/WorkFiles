
##  Import References  ##
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\DisasterRecoveryFunctions.psm1" -Destination 'c:\scripts\DisasterRecoveryFunctions.psm1' -force


import-module dbatools 
import-module AZURERM -DisableNameChecking
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking
import-module c:\scripts\DisasterRecoveryFunctions.psm1 -Scope Global -force -DisableNameChecking

$Database = 'SightlinesDWUpdate'
$SourceServer = 'Azure-PRD-SQL02'
$TargetServer = 'GVL-SQL-RSMDEV'
$AzureCredential = 'AzureCredential'

$LastBackupFile = get-dbabackuphistory -SqlInstance $SourceServer -Database $Database -lastfull | select Path 


foreach ($file in $LastFull)
{
$filemap = $null
$filemap = @{}
$backupFile = $file | select -ExpandProperty path
$filelist = Create-Filemap -database $database -server $TargetServer -backupFile $backupFile -AzureCredential 'AzureCredential'

'USE MASTER'
"ALTER DATABASE [$Database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
Restore-DbaDatabase -OutputScriptOnly -SqlInstance $TargetServer -DatabaseName $database -FileMapping $filelist -AzureCredential 'AzureCredential' -Path $backupFile -WithReplace
"ALTER DATABASE [$Database] SET MULTI_USER"

}