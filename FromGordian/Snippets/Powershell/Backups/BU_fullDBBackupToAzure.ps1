Import-module Azurerm -DisableNameChecking
IMPORT-module dbatools

$storageContainer = 'egordianbackups'
$databases = ((get-dbadatabase -SqlInstance $env:Computername ) | ?{$_.name -ne ('tempdb')}).name  

foreach ($db in $databases)
{
$sqlcmd = (Backup-dbaDatabase -SqlInstance $env:COMPUTERNAME -AzureBaseUrl ('https://tggsqlbackups.blob.core.windows.net/' + $storageContainer) -AzureCredential eGordianCredential -Database $db -Type Full -CompressBackup -OutputScriptOnly -ErrorAction SilentlyContinue) -replace('_','_FULL_')
invoke-sqlcmd -ServerInstance $env:Computername -Query $sqlcmd -Database master -verbose -ConnectionTimeout 0 -QueryTimeout 0
}
