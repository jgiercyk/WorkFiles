##  Import References  ##
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force

import-module dbatools 
import-module AZURERM -DisableNameChecking
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking

$debug = 0    ## 1 = just generate code / 0 = run scripts
$AG = get-dbaavailabilitygroup -SqlInstance $env:COMPUTERNAME
$AGReplicas = $AG.AvailabilityReplicas
$AGPrimary = $AGReplicas | ?{$_.role -eq 'Primary'} | Select name -ExpandProperty name
$AGSecondary = $AGReplicas | ?{$_.role -eq 'Secondary'} | Select name -ExpandProperty name
$AGBackupServer = $AGSecondary | Select name -ExpandProperty name -first 1
$AGIgnore = Get-DatabasesToIgnore -server $AGPrimary
$AGDatabases = $AG.AvailabilityDatabases | ?{$_.name -notin $AGIgnore} # and $_.name -eq 'ZipCodes'}
$SecondaryDatabases = Get-dbaDatabase -SqlInstance $AGBackupServer | select -ExpandProperty name
$AGName = $AG.Name

$LogFileDirectory = 'L:\LogFiles\'
$BackupFilePath = '\\' + $AGBackupServer + '\backups01\RebuildAG'

$timestamp = Get-Date -Format yyyyMMddHHmm
$logfile = $LogFileDirectory + "RebuildAG_v2_$timestamp.txt"


$testpath = test-path -path $BackupFilePath
if($testpath -eq $false) {md $BackupFilePath}
SET-LOCATION $BackupFilePath 


###  Function to log messages
FUNCTION Log-Message {param($message) Add-Content $logfile $message}
If ($debug -eq 1) {Log-Message -message ('+++ Script in Debug Mode.  No Code Will Be Executed +++')}


foreach ($db in $AGDatabases)
{

    #######################################################################################################################
    ##  If the database exists it was already restored.  The restore script would have dropped it if it were successful  ##
    #######################################################################################################################

    If ($db.name -in $SecondaryDatabases -and $debug -ne 1)
    {
    write-host 'DEFENSIVE BACK IN ACTION: Database' $db 'has already been added.  Moving to next database'
    Log-Message -message ('DEFENSIVE BACK IN ACTION: Database ' + $db + ' has already been added.  Moving to next database')
    CONTINUE
    }

    $FilePath = $BackupFilePath + '\' + $db.name
    $testpath = test-path -path $FilePath
    if($testpath -eq $false) {md $FilePath}
    SET-LOCATION $FilePath 

    IF ($debug -ne 1) 
            {
            remove-item ($db.name + '.*')
            }


    $BackupDBSql = Backup-DbaDatabase -Type Full -SqlInstance $AGPrimary -Database $db.name -BackupDirectory $FilePath -BackupFileName ($db.name + '.bak') -CopyOnly -OutputScriptOnly 


     TRY
        {
            IF ($debug -eq 1) 
                {
                $BackupDBSql
                Log-Message -message ('EXECUTING STATEMENT: ' + $BackupDBSql)
                }
            ELSE 
                {
                Log-Message -message ('EXECUTING STATEMENT: ' + $BackupDBSql)
                invoke-sqlcmd -ServerInstance $AGPrimary -database master -query $BackupDBSql -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 4>> $logfile
                }
        }
    CATCH
        {
            write-host 'ERROR BACKING UP DATABASE' $db.name 'FROM PRIMARY' -ForegroundColor 'Yellow'
            if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $db.name -status 'Failed'}
            Log-Message -message ('++ ERROR BACKING UP DATABASE ' + $db.name + ' FROM PRIMARY')
            Log-Message -message ('++ SQL STATEMENT: ' + $BackupDBSql)
            Log-Message -message ($ERROR[0] | select * )
            CONTINUE
        }

    foreach ($Secondary in $AGSecondary)
    {
        TRY
            {
                if ($db.name -eq 'ProgenCatalogs') 
           
                {$RestoreDBSql = 
@"
RESTORE DATABASE [ProgenCatalogs] FROM  DISK = N'\\AZURE-PPD-ESQL2\b$\backups01\RebuildAG\ProgenCatalogs\ProgenCatalogs.bak' WITH  FILE = 1,  
MOVE N'ProgenCatalogs_Data' TO N'E:\MSSQL11.MSSQLSERVER\MSSQL\DATA\ProgenCatalogs_Data.mdf',  
MOVE N'ProgenCatalogs_Log' TO N'E:\MSSQL11.MSSQLSERVER\MSSQL\LOGS\ProgenCatalogs_Log.ldf',  
NORECOVERY,  NOUNLOAD,  STATS = 5
"@                
                }
                else {$RestoreDBSql = Restore-DbaDatabase -SqlInstance $Secondary -Path $FilePath -DatabaseName $db.name -NoRecovery -useDestinationDefaultDirectories -WithReplace -OutputScriptOnly}
                 $AddToAGSql = 'ALTER DATABASE [' + $db.name + '] SET HADR AVAILABILITY GROUP = ' + $AGName

                IF ($debug -eq 1) 
                    {$RestoreDBSql
                    Log-Message -message ('RESTORING DATABASE : ' + $db.name + ' TO SECONDARY NODE ' + $Secondary)
                    Log-Message -message ('EXECUTING STATEMENT: ' + $RestoreDBSql)

                    $AddToAGSql
                    Log-Message -message ('ADDING DATABASE : ' + $db.name + ' TO AVAILABILITY GROUP ' + $AGName)
                    Log-Message -message ('EXECUTING STATEMENT: ' + $AddToAGSql)                     
                    }
                ELSE
                { 
                    Log-Message -message ('RESTORING DATABASE : ' + $db.name + ' TO SECONDARY NODE ' + $Secondary)
                    Log-Message -message ('EXECUTING STATEMENT: ' + $RestoreDBSql)
                    invoke-sqlcmd -ServerInstance $Secondary -database master -query $RestoreDBSql -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 4>> $logfile

                    
                    Log-Message -message ('ADDING DATABASE : ' + $db.name + ' TO AG ON SECONDARY NODE ' + $Secondary)
                    Log-Message -message ('EXECUTING STATEMENT: ' + $RestoreDBSql)
                    invoke-sqlcmd -ServerInstance $Secondary -database master -query $AddToAGSql -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 4>> $logfile

                }
            }
        CATCH
            {
                write-host 'ERROR RESTORING DATABASE' $db.name 'TO SECONDARY' $Secondary -ForegroundColor 'Yellow'
                if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $db.name -status 'Failed'}
                Log-Message -message ('++ ERROR RESTORING ' + $db.name + ' TO SECONDARY ' + $Secondary)
                Log-Message -message ('++ SQL STATEMENT: ' + $RestoreDBSql)
                Log-Message -message ($ERROR[0] | select * )
                CONTINUE
            }

    }
}


