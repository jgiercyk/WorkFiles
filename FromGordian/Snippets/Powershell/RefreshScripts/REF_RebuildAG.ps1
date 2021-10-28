##  Import References  ##
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force

import-module dbatools 
import-module AZURERM -DisableNameChecking
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking

$AG = get-dbaavailabilitygroup -SqlInstance $env:COMPUTERNAME
$AGReplicas = $AG.AvailabilityReplicas
$AGPrimary = $AGReplicas | ?{$_.role -eq 'Primary'} | Select name -ExpandProperty name
$AGSecondary = $AGReplicas | ?{$_.role -eq 'Secondary'} | Select name -ExpandProperty name
$AGBackupServer = $AGSecondary | Select name -ExpandProperty name -first 1
$AGDatabases = Get-AGDatabasesFromTable -server $AGPrimary
$AGName = $AG.Name



$LogFileDirectory = 'L:\LogFiles\'
$BackupFilePath = '\\' + $AGBackupServer + '\backups01\RebuildAG'

$timestamp = Get-Date -Format yyyyMMddHHmm
$logfile = $LogFileDirectory + "RebuildAG_$timestamp.txt"


$testpath = test-path -path $BackupFilePath
if($testpath -eq $false) {md $BackupFilePath}
SET-LOCATION $BackupFilePath 
remove-item *.*


foreach ($db in $AGDatabases)
{
   Add-DatabaseToAG -servername $AGPrimary -agname $AG.name -dbname $db  4>> $logfile
   Backup-DbaDatabase -Type Full -SqlInstance $AGPrimary -Database $db -BackupDirectory $BackupFilePath -BackupFileName "${db}.bak" -CopyOnly -verbose  4>> $logfile
    
    foreach ($Secondary in $AGSecondary)
    {
        Restore-DbaDatabase -SqlInstance $Secondary -Path $BackupFilePath -verbose -NoRecovery -useDestinationDefaultDirectories -WithReplace 4>> $logfile
        invoke-sqlcmd -query "ALTER DATABASE [${db}] SET HADR AVAILABILITY GROUP = [${AGName}]" -ServerInstance $Secondary -Database 'master' -verbose 4>> $logfile
    }
}
