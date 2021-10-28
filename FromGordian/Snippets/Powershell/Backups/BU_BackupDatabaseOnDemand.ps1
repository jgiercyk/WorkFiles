Import-module Azurerm -DisableNameChecking
IMPORT-module dbatools

$SourceServer = $env:Computername
$storageContainer = 'egordianbackups'
$databases = ((get-dbadatabase -SqlInstance $SourceServer ) | ?{$_.name -eq 'ProgenData'}).name


foreach ($db in $databases)
{
$sqlcmd = (Backup-dbaDatabase -SqlInstance $SourceServer -AzureBaseUrl ('https://tggsqlbackups.blob.core.windows.net/' + $storageContainer) -AzureCredential eGordianCredential -Database $db -Type Full -CompressBackup -OutputScriptOnly -ErrorAction SilentlyContinue) -replace('_','_FULL_')
invoke-sqlcmd -ServerInstance $env:Computername -Query $sqlcmd -Database master -verbose -ConnectionTimeout 0 -QueryTimeout 0
}