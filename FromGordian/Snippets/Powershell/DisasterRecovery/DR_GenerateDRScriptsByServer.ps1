<#

IF YOU ARE READING THIS, YOU'VE SURVIVED SOME SORT OF DR CATASTROPHY.  TAKE A DEEP BREATH AND KEEP READING.  AVOID ZOMBIES AT ALL COST.

THIS SCRIPT WILL CREATE AN OUTPUT FILE CONTAINING ALL THE SQL SCRIPTS YOU NEED TO BRING YOUR DATABASES BACK UP TO DATE USING AZURE BACKUP FILES.

>>  RUNNING THIS SCRIPT WILL NOT EXECUTE CODE.  IT WILL GENERATE A FILE IN THE C:\SCRIPTS FOLDER  <<

PREREQUISITES:
CONNECTIVITY TO GVL-SQL-TGGDBA
CONNECTIVITY TO TGGFILE4 (10.90.17.152)
CONNECTIVITY TO YOUR NEW SERVER
DATABASES TO RESTORE ARE DERIVED FROM TABLE [DBA_Mon].[dbo].[Server_List] ON GVL-SQL-TGGDBA.  HOPEFULLY YOU KEPT IT UP TO DATE.
AN AZURE CREDENTIAL MUST BE CREATED ON THE NEW SERVER TO ACCESS THE AZURE STORAGE ACCOUNT tggsqlbackups


REQUIRED INPUT VARIABLES:
$TargetServer - This is the name, FQN or IP of the new server you've created
$StorageContainer - This is the AZURE storage container where the backup files are located.  Typically rsmccdbackups or egordianbackups, but it could be any existing container
$AzureCredential - This is the credential used to access Azure storage on the $TargetServer.  YOU MUST CREATE A CREDENTIAL BEFORE RUNNING THIS SCRIPT

NOTES:
THE SCRIPT CREATES (IF NECESSARY) AND USES C:\SCRIPTS AS A WORKING DIRECTORY.  IT IS BEST NOT TO CHANGE THIS, BUT YOU CAN BY SETTING THE $ScriptFilePath VARIABLE
THE OUTPUT FILENAME IS DRScripts AND A TIMESTAMP.  YOU CAN CHANGE THE $scriptfile VARIABLE TO RENAME THE OUTPUT FILE IF LIKE TAKING RISKS
THE DATABASE FILES WILL BE PUT ON THE DEFAULT DATA AND LOG PATHS OF THE NEW SERVER.  TO PUT THEM SOMEWHERE ELSE YOU MUST MANUALLY CHANGE THE SCRIPT.
DATABASES WILL BE LEFT IN RESTORING MODE TO PREVENT USERS FROM ACCESSING THEM DURING THE REBUILD PROCESS.  EXECUTE  "RESTORE DATABASE [DBNAME] WITH RECOVERY" TO BRING THEM BACK ONLINE
  
#>

$testpath = test-path -path 'c:\SCRIPTS'    
if($testpath -eq $false) {md c:\SCRIPTS}
SET-LOCATION c:\SCRIPTS

copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\DisasterRecoveryFunctions.psm1" -Destination 'c:\scripts\DisasterRecoveryFunctions.psm1' -force


import-module dbatools -force
import-module AZURERM -DisableNameChecking
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking
import-module c:\scripts\DisasterRecoveryFunctions.psm1 -Scope Global -force -DisableNameChecking

########################
#  Set User Variables  #
########################
$TargetServer = '10.90.17.63'
$StorageContainer = 'rsmccdbackups'  # rsmccdbackups, egordianbackups 
$AzureCredential = 'AzureCredential'


$ScriptFilePath= 'c:\scripts\'
$scriptfile = $ScriptFilePath + "DRScripts_$timestamp.sql"
$DrDatabases = Get-DRDatabases -server 'azure-prd-sql02' | ?{$_.name -notin ('master','msdb','model','tempdb')} | select -ExpandProperty name 
$timestamp = Get-Date -Format yyyyMMddHHmm


$testpath = test-path -path $ScriptFilePath
    if($testpath -eq $false) {md $ScriptFilePath}
SET-LOCATION $ScriptFilePath

FUNCTION Log-Message {param($message) Add-Content $scriptfile $message}

write-host 'Gathering all the backup files.'  -ForegroundColor Green

If ($StorageContainer -eq 'rsmccdbackups')
    {
           $AzureBackups = get-rsmblobs
           $AzureLogs = get-rsmLogs
           $AzureURL = Get-RsmURL
    }
Else
    {
            $AzureBackups = get-egblobs
            $AzureLogs = get-eglogs
            $AzureURL = Get-EGURL 
    }
        write-host 'About to generate restore code' -ForegroundColor Green
        write-host 'If all goes well you will find the code in file' $scriptfile   -ForegroundColor Green


foreach ($drdb in $DrDatabases)
{
        ###############################
        #  Get Blobs To Be REstored   #
        ###############################
      
        $AllBackups = $AzureBackups | ?{$_.Name -like '*_' + $drdb + '_*' -or $_.Name -like $drdb + '_*'}
        $AllLogfiles = $AzureLogs | ?{$_.Name -like '*_' + $drdb + '_*'-or $_.Name -like $drdb + '_*'}



        $LastFullBackup = get-fullbackup -database $drdb -Blobs $AllBackups
        $LastDiffBackup = get-diffbackup -database $drdb -Blobs $AllBackups -lastFullBackup $LastFullBackup
        $LogFiles = get-LogBackups -database $drdb -Blobs $AllLogfiles -lastFullBackup $LastFullBackup -lastDiffBackup $LastDiffBackup

        #############################
        #  Get Database File Paths  #
        #############################

        $ExistingDatabases = get-dbadatabase -SqlInstance $TargetServer | select -ExpandProperty Name
        $filemap = $null
        $filemap = @{} 
        $filemap = Create-Filemap -database $drdb -server $TargetServer -backupFile ($AzureURL + '/' + $LastFullBackup.Name) -AzureCredential $AzureCredential
 
        ######################
        ##   FULL RESTORE   ##
        ######################
        IF ($ExistingDatabases -contains $drdb)
                {
                write-host '***Generating code to restore' $drdb '***' -ForegroundColor Green
                }

        $sqlcmd = Get-FullBackupSql -database $drdb -LastFullBackup ($AzureURL + '/' + $LastFullBackup.name) -AzureCredential 'AzureCredential' -Filemap $filemap
        write-host 'Generating FULL restore of' $drdb 'from file' $LastFullBackup.name
        Log-Message -message $sqlcmd -logfile $scriptfile
        Log-Message -message ' ' -logfile $scriptfile


        #####################
        ##   DIFF RESTORE  ##
        #####################
        If($LastDiffBackup.name -ne $null) {
                $sqlcmd = Get-DiffBackupSql -database $drdb -LastDiffBackup ($AzureURL + '/' + $LastDiffBackup.name) -AzureCredential 'AzureCredential' -Filemap $filemap
                write-host 'Generating DIFF restore of' $drdb 'from file' $LastDiffBackup.name
                Log-Message -message $sqlcmd -logfile $scriptfile
                Log-Message -message ' ' -logfile $scriptfile
        }


        #####################
        ##    LOG RESTORE  ##
        #####################
        foreach($log in $LogFiles)
        {
            $sqlcmd = Get-LogBackupSql -database $drdb -Logfile ($AzureURL + '/' + $log.name) -AzureCredential 'AzureCredential'
            write-host 'Generating LOG restore of' $drdb 'from file' $log.name
            Log-Message -message $sqlcmd -logfile $scriptfile
        }

       write-host ' '
       Log-Message -message ' ' -logfile $scriptfile
       Log-Message -message ' ' -logfile $scriptfile

}
BREAK

#clear-variable -name * -Force -Scope global