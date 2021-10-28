Import-module Az -DisableNameChecking
IMPORT-module dbatools

$SourceServer = 'sqlp01'
$storageContainer = 'omisqlbackups'
$databases = ((get-dbadatabase -SqlInstance $SourceServer ) | ?{$_.name -eq 'dba'}).name


foreach ($db in $databases)
{
$sqlcmd = (Backup-dbaDatabase -SqlInstance $SourceServer -AzureBaseUrl ('https://omisqlbackups.blob.core.windows.net/' + $storageContainer) -AzureCredential AzureCredential -Database $db -Type Full -CompressBackup -OutputScriptOnly -ErrorAction SilentlyContinue) -replace('_','_FULL_')
#invoke-sqlcmd -ServerInstance $SourceServer -Query $sqlcmd -Database master -verbose -ConnectionTimeout 0 -QueryTimeout 0 -Debug
$sqlcmd
}

#Test-NetConnection -computerName https://omisqlbackups.blob.core.windows.net/mmcvsrvrd01

#Test-NetConnection -computerName mmcvsrvrd01
