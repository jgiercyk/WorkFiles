<##########################################################################################################################
This Script Refreshes all databses on the PPD Availability Group from the latest backup in Azure.  The following variables
must be set when running in a new environment

$debug - 0 = Run Scripts, 1 = Just generate scripts
$AzureCredential - The Credential defined on the server used to access Azure storage
$AzureURL - Either Get-RSMURL to access RSM blobs or GET-EGURL to access EG blobs
$LogFileDirectory - the location of the log file written by the script

#######################################################################################################################>

##  Import References  ##
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\DisasterRecoveryFunctions.psm1" -Destination 'c:\scripts\DisasterRecoveryFunctions.psm1' -force


import-module dbatools
import-module AZURERM -DisableNameChecking
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking
import-module c:\scripts\DisasterRecoveryFunctions.psm1 -Scope Global -force -DisableNameChecking
$debug = 1    ## 1 = just generate code / 0 = run scripts
$AzureCredential = 'AzureCredential'
$AzureURL = Get-RSMURL

$LogFileDirectory = 'L:\LogFiles\'
$timestamp = Get-Date -Format yyyyMMddHHmm
$logfile = $LogFileDirectory + "PreProdRefresh_v2_$timestamp.txt"


$AG = get-dbaavailabilitygroup -SqlInstance $env:COMPUTERNAME
$AGReplicas = $AG.AvailabilityReplicas
$AGPrimary = $AGReplicas | ?{$_.role -eq 'Primary'} | Select name -ExpandProperty name
$AGSecondary = $AGReplicas | ?{$_.role -eq 'Secondary'} | Select name -ExpandProperty name
$AGIgnore = Get-DatabasesToIgnore -server $AGPrimary
$AGDatabases = $AG.AvailabilityDatabases | ?{$_.name -notin $AGIgnore} 

Save-AGDatabasesToTable -databases $AGDatabases.name -server $AGPrimary

$sbcmd = 'SELECT name FROM sys.databases where is_broker_enabled = 1'
$ServiceBrokerEnabled = invoke-sqlcmd -query $sbcmd -ServerInstance $AGPrimary -database master | ?{$_.name -in $AGDatabases.name} | select -ExpandProperty name

#####  THIS IS FOR TESTING ONLY ###########################
#$AGDatabases = $AGDatabases | ?{$_.name -in ('CDMS-TEMP')}
############################################################

###  Function to log messages
FUNCTION Log-Message {param($message) Add-Content $logfile $message}

if ($debug -eq 1) {Log-Message -message ('SCRIPT IN DEBUG MODE.  NO CODE WILL BE EXECUTED')}

Log-Message -message ('Refreshing databases in Availability Group ' + $AG.name)
Log-Message -message ($AGDatabases.name)


Foreach ($agdb in $AGDatabases)
{
        if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Processing'}
        else {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Successful'}

        Log-Message -message ('STARTING FULL RESTORE OF DATABASE ' + $agdb.name + ' At ' + (get-date -format g) + '`n')


        #######################################################
        #  DEFENSIVE BACK - Check if a backup is needed       #
        #######################################################
        if ($debug -ne 1)
        {
            $lastRestore = get-lastfullazurerestore -database $agdb.name -server $AGPrimary
            $Now = Get-Date
            $LastValidBackupDate = $Now.AddDays(-6)

            if ($lastRestore.BackupFinishDate -gt $LastValidBackupDate)
                {
                write-host 'Skipping database' $agdb.name 'because it has already been restored'
                Log-Message -message ('++ Defensive Back Stopped Database ' + $agdb.name + ' From Restoring.  A current restore already exists')
                CONTINUE
                }
            ELSE
                {
                write-host 'Restoring database' $agdb.name
                Log-Message -message ('++ Database ' + $agdb.name + ' Beat The Defensive Back And Will Be Restored')
                }
        }

        ###############################
        #  Get Blobs To Be Restored   #
        ###############################
        TRY
        {
            $AGPrimary = $AGReplicas | ?{$_.role -eq 'Primary'} | Select name -ExpandProperty name
            $AllBackups = Get-RSMBackups | ?{$_.Name -like '*_' + $agdb.name + '_*' -or $_.Name -like $agdb.name + '_*'}   ##<<<< COMMANDLET Get-RSMBlobs OR Get-EGBlobs
           $AllLogfiles = $AllBackups | ?{$_.Name -like '*.trn'}


            $LastFullBackup = get-fullbackup -database $agdb.name -Blobs $AllBackups
            $LastDiffBackup = get-diffbackup -database $agdb.name -Blobs $AllBackups -lastFullBackup $LastFullBackup
            $LogFiles = get-LogBackups -database $agdb.name -Blobs $AllLogfiles -lastFullBackup $LastFullBackup -lastDiffBackup $LastDiffBackup
           # $DBUsers = Get-DatabaseUsers -database $agdb.name -server $AGPrimary
            
        }
        CATCH
        {
            write-host 'ERROR FINDING BACKUP FILES FOR DATABASE' $agdb.name -ForegroundColor 'Yellow'
            if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Failed'}
            Log-Message -message ('++ ERROR FINDING BACKUP FILES FOR DATABASE ' + $agdb.name)
            Log-Message -message ($ERROR[0] | select * )
            CONTINUE
        }

        IF ($LastFullBackup -eq $null)
        {
            Log-Message -message ('++ NO FULL BACKUP FILE FOUND FOR ' + $agdb.name + '.  SKIPPING TO THE NEXT DATABASE')
            CONTINUE
        }  ##  If we do not have a backup, bail and try the next db

        
        ######################
        #   REMOVE FROM AG   #
        ######################
        $SQLRemoveFromAG = Remove-DatabaseFromAG -database $agdb.name -availabilitygroup $ag.name 

        TRY
        {
            IF ($debug -eq 1) 
                {$SQLRemoveFromAG}
            ELSE 
                {
                Log-Message -message ('EXECUTING STATEMENT: ' + $SQLRemoveFromAG)
                invoke-sqlcmd -ServerInstance $AGPrimary -database master -query $SQLRemoveFromAG -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 | out-null
                }

        }
        CATCH
        {
            write-host 'ERROR DROPPING' $agdb.name 'FROM AG' -ForegroundColor 'Yellow'
            if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Failed'}
            Log-Message -message ('++ ERROR DROPPING DATABASE ' + $agdb.name + ' FROM AG SECONDARY')
            Log-Message -message ('++ SQL STATEMENT: ' + $SQLRemoveFromAG)
            Log-Message -message ($ERROR[0] | select * )
            CONTINUE
        }


        ####################################
        ###  RESTORE LATEST FULL BACKUP  ###
        ####################################
        TRY
        {
            $FullFileName = $AzureURL + '/' + $LastFullBackup.name
            $filemap = $null
            $filemap = @{}
            $filemap = Create-FileMap -database $agdb.name -server $AGPrimary -backupFile $FullFileName -AzureCredential $AzureCredential
            
            $sqlcmd = "USE [MASTER] ALTER DATABASE [" +  $agdb.name + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
            IF ($debug -eq 1) 
                {$sqlcmd}
            ELSE 
                {
                Log-Message -message ('EXECUTING STATEMENT: ' + $sqlcmd)
                invoke-sqlcmd -ServerInstance $AGPrimary -database master -query $sqlcmd -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 -verbose 4>> $logfile
                Log-Message -message ('`n')
                }



            $sqlcmd = Restore-dbaDatabase -OutputScriptOnly -SqlInstance $AGPrimary -DatabaseName $agdb.name -FileMapping $filemap -path $FullFileName -withReplace -noRecovery -AzureCredential $AzureCredential -ErrorAction Stop
          
            IF ($debug -eq 1) 
                {$sqlcmd}
            ELSE 
                {
                Log-Message -message ('EXECUTING STATEMENT: ' + $sqlcmd)
                invoke-sqlcmd -ServerInstance $AGPrimary -database master -query $sqlcmd -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 -verbose 4>> $logfile
                Log-Message -message ('`n')
                }
        }
        CATCH
        {
            Write-host 'ERROR DURING FULL RESTORE OF' $agdb.name -ForegroundColor 'Yellow'
            if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Failed'}
            Log-Message -message ('++ ERROR DURING FULL RESTORE OF ' + $agdb.name)
            Log-Message -message ('++ SQL STATEMENT: ' + $sqlcmd)
            Log-Message -message ($ERROR[0] | select * )
            CONTINUE
        }


        ####################################
        ###  RESTORE LATEST DIFF BACKUP  ###
        ####################################

        IF ($LastDiffBackup -ne $null)
        {
            TRY
            {
                Log-Message -message ('STARTING DIFF RESTORE OF DATABASE ' + $agdb.name + ' At ' + (get-date -format g) + '`n')
                $DiffFileName = $AzureURL + '/' + $LastDiffBackup.name
                $sqlcmd = Get-DiffBackupSql -database $agdb.name -LastDiffBackup $DiffFileName -AzureCredential $AzureCredential
                IF ($debug -eq 1) 
                    {$sqlcmd}
                ELSE 
                    {
                    Log-Message -message ('EXECUTING STATEMENT ' + $sqlcmd) 
                    invoke-sqlcmd -ServerInstance $AGPrimary -database master -query $sqlcmd -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 -verbose  4>> $logfile
                    Log-Message -message ('`n') 
                    }
            }
            CATCH
            {
                Write-host 'ERROR DURING DIFF RESTORE OF' $agdb.name -ForegroundColor 'Yellow'
                if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Failed'}
                Log-Message -message ('++ ERROR DURING DIFF RESTORE OF ' + $agdb.name)
                Log-Message -message ('++ SQL STATEMENT: ' + $sqlcmd)
                Log-Message -message ($ERROR[0] | select * )
                CONTINUE
            }
        }
        ELSE
        {
                Log-Message -message ('++ NO DIFF BACKUPS FOUND FOR ' + $agdb.name + '.  JUST LETTING YOU KNOW')
        }



        ####################################
        ###  RESTORE LOG BACKUPS         ###
        ####################################
        IF ($logfiles -ne $null)
        {
            TRY
            {
                Log-Message -message ('STARTING LOG RESTORES OF DATABASE ' + $agdb.name + ' At ' + (get-date -format g) + '`n')
                foreach ($file in $logfiles)
                {
                    $LogFileName = $AzureURL + '/' + $file.name
                    $sqlcmd = Get-LogBackupSql -database $agdb.name -logfile $LogFileName -AzureCredential $AzureCredential
                    IF ($debug -eq 1) 
                        {$sqlcmd}
                    ELSE 
                        {
                        Log-Message -message ('EXECUTING STATEMENT ' + $sqlcmd) 
                        invoke-sqlcmd -ServerInstance $AGPrimary -database master -query $sqlcmd -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 -verbose 4>> $logfile
                        Log-Message -message ('`n')
                        }
                }
            }
            CATCH
            {
                Write-host 'ERROR DURING LOG RESTORE OF' $agdb.name -ForegroundColor 'Yellow'
                if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Failed'}
                Log-Message -message ('++ ERROR DURING LOG RESTORE OF ' + $agdb.name)
                Log-Message -message ('++ SQL STATEMENT: ' + $sqlcmd)
                Log-Message -message ($ERROR[0] | select * )
                CONTINUE
            }
        }
        ELSE
        {
                Log-Message -message ('++ NO LOG BACKUPS FOUND FOR ' + $agdb.name + '.  JUST LETTING YOU KNOW')
        }

        ####################################
        ###  RESTORE WITH RECOVERY       ###
        ####################################
        TRY
        {
            Log-Message -message ('RECOVERING DATABASE ' + $agdb.name + ' At ' + (get-date -format g) + '`n')
            $sqlcmd = "USE [MASTER]; RESTORE DATABASE ["  +  $agdb.name + "] WITH RECOVERY; ALTER DATABASE [" +  $agdb.name + "] SET MULTI_USER"
            IF ($debug -eq 1) 
                {$sqlcmd}
            ELSE 
                {
                invoke-sqlcmd -ServerInstance $AGPrimary -database master -query $sqlcmd -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 4>> $logfile
                Log-Message -message ('EXECUTING STATEMENT ' + $sqlcmd)
                }
        }
        CATCH
        {
            Write-host 'ERROR DURING RECOVERY OF' $agdb.name -ForegroundColor 'Yellow'
            if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Failed'}
            Log-Message -message ('++ ERROR DURING RECOVERY OF ' + $agdb.name)
            Log-Message -message ('++ SQL STATEMENT: ' + $sqlcmd)
            Log-Message -message ($ERROR[0] | select * )
            CONTINUE
        }

        IF($agdb.name -in $ServiceBrokerEnabled)
        {
            TRY
            {
                Log-Message -message ('ENABLING SERVICE BROKER FOR ' + $agdb.name + ' At ' + (get-date -format g) + '`n')
                $sqlcmd = "USE [MASTER]; ALTER DATABASE "  +  $agdb.name + " SET ENABLE_BROKER "
                IF ($debug -eq 1) 
                    {
                    Log-Message -message ('EXECUTING STATEMENT ' + $sqlcmd)
                    $sqlcmd}
                ELSE 
                    {
                    invoke-sqlcmd -ServerInstance $AGPrimary -database master -query $sqlcmd -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 4>> $logfile
                    Log-Message -message ('EXECUTING STATEMENT ' + $sqlcmd)
                    }
            }
            CATCH
            {
                Write-host 'ERROR ENABLING SERVICE BROKER ON ' $agdb.name -ForegroundColor 'Yellow'
                if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Failed'}
                Log-Message -message ('++ ERROR ENABLING SERVICE BROKER ON ' + $agdb.name)
                Log-Message -message ('++ SQL STATEMENT: ' + $sqlcmd)
                Log-Message -message ($ERROR[0] | select * )
                CONTINUE
            }
        }


        ################################
        ##   ADD DATABASE BACK TO AG  ##
        ################################

        TRY
        {
        Log-Message -message ('ADDING DATABASE ' + $agdb.name + ' BACK TO AG ' + $ag.name)
        if ($debug -ne 1) {Add-DatabaseToAG -servername $AGPrimary -agname $AG.name -dbname $agdb.name}
        }
        CATCH
        {
            Write-host 'ERROR ADDING' $agdb.name 'TO AG' -ForegroundColor 'Yellow'
            if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Failed'}
            Log-Message -message ('++ ERROR ADDING ' + $agdb.name + ' TO AG')
            Log-Message -message ($ERROR[0] | select * )
            CONTINUE
        }

        if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Successful'}

        Log-Message -message ('COMPLETING RESTORE OF DATABASE ' + $agdb.name + ' At ' + (get-date -format g) + '`n')


        #############################
        #   REMOVE FROM SECONDARY   #
        #############################
        $SQLDropFromSecondary = 'DROP DATABASE IF EXISTS [' +  $agdb.name + ']'

        TRY 
        {
            foreach ($secondary in $AGSecondary)
            {
            Log-Message -message ('DROPPING DATABASE ' + $agdb.name + ' FROM SECONDARY NODE ' + $secondary)
            IF ($debug -eq 1) 
                {$SQLDropFromSecondary}
            ELSE
                {
                Log-Message -message ('EXECUTING STATEMENT: ' + $SQLDropFromSecondary + ' ON SERVER ' + $secondary)
                invoke-sqlcmd -ServerInstance $secondary -database master -query $SQLDropFromSecondary -ErrorAction Stop -ConnectionTimeout 0 -QueryTimeout 0 4>> $logfile}
            }
        }
        CATCH
        {
            write-host 'ERROR DROPPING' $agdb.name 'FROM SECONDARY' -ForegroundColor 'Yellow'
            if ($debug -ne 1) {Set-RestoreStatus -server $AGPrimary -database $agdb.name -status 'Failed'}
            Log-Message -message ('++ ERROR DROPPING DATABASE ' + $agdb.name + ' FROM SECONDARY')
            Log-Message -message ('++ SQL STATEMENT: ' + $SQLDropFromSecondary)
            Log-Message -message ($ERROR[0] | select * )
            CONTINUE
        }



}

## Clear-variable *   

