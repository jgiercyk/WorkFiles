import-module dbatools
###   This script reads the backup history of $servername for  
###   and database that has not had a FULL backup to a device type'
###   URL for he past 18 hours.  If it finds a missing backup, 
###   it creates one in the $storageContainer specified 

###   User Variables
$servername = 'azure-prd-sql02'
$storageContainer = 'rsmccdbackups'


###   Process
$Now = Get-Date
$Yesterday = $Now.AddHours(-18)

$databaseBackups = Get-dbaBackupHistory -SqlInstance $servername -Type 'Full' -DeviceType 'URL' | ?{$_.End -ge $Yesterday} | select -ExpandProperty database
$databasesOnServer = get-dbadatabase -SqlInstance $servername | ?{$_.name -ne 'tempdb' -and $_.Status -eq 'Normal'} | select -ExpandProperty Name
$encryptedDatabases = get-dbadatabase -SqlInstance $servername | ?{$_.encryptionEnabled -eq $true} | select -ExpandProperty name

foreach ($db in $databasesOnServer)
{
    If($db -notin $databaseBackups)
        {$sqlcmd = (Backup-dbaDatabase -SqlInstance $servername -AzureBaseUrl ('https://tggsqlbackups.blob.core.windows.net/' + $storageContainer) -AzureCredential 'AzureCredential' -Database $db -Type Full -CompressBackup -OutputScriptOnly -ErrorAction SilentlyContinue) -replace(($db + '_'),($db + '_FULL_'))
            if ($db -in $encryptedDatabases)
                {
                $sqlcmd = $sqlcmd.Replace("COMPRESSION","NO_COMPRESSION") # DO NOT COMPRESS ENCRYPTED DATABASES
                }
        $sqlcmd
        invoke-sqlcmd -ServerInstance $servername -Query $sqlcmd -Database master -ConnectionTimeout 0 -QueryTimeout 0
        }
}