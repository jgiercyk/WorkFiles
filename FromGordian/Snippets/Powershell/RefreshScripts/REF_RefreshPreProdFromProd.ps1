##  Import References  ##
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force

import-module dbatools
import-module AZURERM -DisableNameChecking
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking

$BackupURL = 'https://tggsqlbackups.blob.core.windows.net/egordianbackups/'
$LogFileDirectory = 'L:\LogFiles\'


$timestamp = Get-Date -Format yyyyMMddHHmm
$logfile = $LogFileDirectory + "PreProdRefresh_$timestamp.txt"

$AG = get-dbaavailabilitygroup -SqlInstance $env:COMPUTERNAME
$AGReplicas = $AG.AvailabilityReplicas
$AGPrimary = $AGReplicas | ?{$_.role -eq 'Primary'} | Select name -ExpandProperty name
$AGSecondary = $AGReplicas | ?{$_.role -eq 'Secondary'} | Select name -ExpandProperty name
$AGIgnore = Get-DatabasesToIgnore -server $AGPrimary
#$AGDatabases = $AG.AvailabilityDatabases | ?{$_.name -like 'SightlinesViews_*' -and $_.name -notin $AGIgnore}
$AGDatabases = $AG.AvailabilityDatabases | ?{$_.name -notin $AGIgnore}

$Blobs = Get-EGBlobs

Save-AGDatabasesToTable -databases $AGDatabases.name -server $AGPrimary

FUNCTION Log-Message {param($message) Add-Content $logfile $message}

Log-Message -message ('Refreshing databases in Availability Group ' + $AG.name)
Log-Message -message ($AGDatabases.name)
 
foreach ($agdb in $AGDatabases)
{
    $AG = get-dbaavailabilitygroup -SqlInstance $env:COMPUTERNAME
    $AGReplicas = $AG.AvailabilityReplicas
    $AGPrimary = $AGReplicas | ?{$_.role -eq 'Primary'} | Select name -ExpandProperty name
    $AGSecondary = $AGReplicas | ?{$_.role -eq 'Secondary'} | Select name -ExpandProperty name

   
    Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Processing'
    $searchPattern = '*_' + $agdb.name + '_FULL*'
    $BackupFile = (($Blobs | sort-object LastModified -Descending | ?{$_.name -like $searchPattern} | select name -first 1).name)
    $LastFullBackup = $BackupURL + $BackupFile

    $SQLRemoveFromAG = Remove-DatabaseFromAG -database $agdb -availabilitygroup $ag -verbose
    $SQLDropFromSecondary = 'DROP DATABASE ' +  ${agdb}

    $databaseFiles = Get-DatabaseFiles -database $agdb -server $AGPrimary
    $fileMoves = Get-FileMoveStatements -files $databaseFiles
    $SQLRestorePrimary = Create-EGRestoreSQL -database $agdb -backup $LastFullBackup -filemoves $fileMoves

    IF ($BackupFile -ne $null)
    {
        TRY {
            Log-Message -message ('Refreshing Database ' + $agdb + ' At ' + (get-date -format g))
            Log-Message -message $SQLRemoveFromAG  
            Invoke-Sqlcmd -query $SQLRemoveFromAG -ServerInstance $AGPrimary -Database 'master'  -ErrorAction SilentlyContinue -verbose  -QueryTimeout 0 -ConnectionTimeout 0  4>> $logfile

            Foreach ($secondary in $AGSecondary)
            {
                Log-message -message $SQLDropFromSecondary
                Invoke-Sqlcmd -query $SQLDropFromSecondary -ServerInstance $secondary -Database 'master'  -ErrorAction SilentlyContinue -verbose  -QueryTimeout 0 -ConnectionTimeout 0  4>> $logfile
            }

            Log-Message -message $SQLRestorePrimary
            Invoke-Sqlcmd -query $SQLRestorePrimary -ServerInstance $AGPrimary -Database 'master' -ErrorAction STOP -verbose  -QueryTimeout 0 -ConnectionTimeout 0  4>> $logfile
       
            Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Successful'

            }
        CATCH{
            Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Error'
            Invoke-sqlcmd -query "UPDATE DBToRefresh SET Status = 'Successful' WHERE DatabaseName = '$($agdb.name)'"  -ServerInstance $AGPrimary -Database 'dba' -ErrorAction stop -verbose  4>> $logfile
            $ERROR[0] | select * 4>> $LogFile
            }
    }
 
}

BREAK
