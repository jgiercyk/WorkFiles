param([string] $TargetServer,
        [string] $database,
        [string] $CleanseFilePath,
        [string] $CleanseFileName,
        [string] $BlobContainer,
        [string] $BackupFilePath,
        [string] $BackupFileName,
        [string] $LogFileDirectory,
        [string] $debugMode)

##  TESTING ONLY  ##
##$database = 'ZipCodes'
##$BlobContainer = 'egordianbackups'

#########################
##  Import References  ##
#########################
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\DisasterRecoveryFunctions.psm1" -Destination 'c:\scripts\DisasterRecoveryFunctions.psm1' -force


import-module dbatools -force
import-module AZURERM -DisableNameChecking

import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking
import-module c:\scripts\DisasterRecoveryFunctions.psm1 -Scope Global -force -DisableNameChecking

#############################
##   Function for logging  ##
#############################

if ($LogFileDirectory -eq '')
    {
    $LogFileDirectory = Get-Location | select -ExpandProperty Path
    }

$timestamp = Get-Date -Format yyyyMMddHHmm
$logfile = $LogFileDirectory + "\AutomatedRestore_$timestamp.txt"
FUNCTION Log-Message {param($message) Add-Content $logfile $message}


##############################
#  Validate Input Variables  #
##############################

IF ($TargetServer -eq '')
    {
    $TargetServer = '192.168.1.63'   ##   SET DEFAULT TARGET IS NOT GIVEN
    write-host 'Using default server because -TargetServer parameter not specified' -ForegroundColor 'Yellow' 
    Log-Message -message ('Using default server because -TargetServer parameter not specified')
    }

IF ($CleanseFilePath -eq '' -and $database -ne '')
    {
    $CleanseFilePath = '\\192.168.1.152\livedbbk\BackupsOnDemand\DataCleansing\' + $database + '.sql'
    write-host 'Using default path to cleansing file. -CleanseFilePath parameter was not specified.' -ForegroundColor 'Yellow' 
    Log-Message -message ('Using default path to cleansing file. -CleanseFilePath parameter was not specified.')
    }
IF ($database -eq '')
    {
    write-host '-Database parameter not specified. Unable to continue' -ForegroundColor 'Red' 
    Log-Message -message ('-Database parameter not specified. Unable to continue')
    $paramError = 1
    }

IF ($BlobContainer -eq '')
    {
    write-host '-BlobContainer parameter not specified. Unable to continue' -ForegroundColor 'Red' 
    Log-Message -message ('-BlobContainer parameter not specified. Unable to continue')
    $paramError = 1
    }

IF ($debugMode -eq '')
    {
    $debugMode = 0
    }

If ($paramError -eq 1)
    {
    write-host 'Fatal Errors Occurred.  Exiting' -ForegroundColor 'Red' 
    Log-Message -message ('Fatal errors occurred.  Exiting')
    BREAK
    }



#############################
#  File Location Variables  #
#############################
$CleanseFilePath = '\\192.168.1.152\livedbbk\BackupsOnDemand\DataCleansing\' + $database + '.sql'
$BackupFilePath = '\\192.168.1.152\livedbbk\BackupsOnDemand'
$BackupFileName = $database + '.bak'
$AzureCredential = 'AzureCredential'

write-host 'Target: '  $TargetServer  ' Database: '  $database -ForegroundColor 'Yellow'
write-host 'Cleanse File ' $CleanseFilePath
#write-host 'Blob Container ' $BlobContainer

Log-Message -message (' Source: ' + $SourceServer + ' Target: ' + $TargetServer +  ' Database: ' +  $database)
Log-Message -message ('Cleanse File Path: ' + $CleanseFilePath)
#Log-Message -message ('Blob Container ' + $BlobContainer)

################################
#  Get Last Production Backup  #
################################

TRY
    {
        If ($BlobContainer -eq 'rsmccdbackups')
            {
            $RSMBlobs = (get-rsmblobs | ?{$_.Name -like ('*_' + $database + '_FULL*') -or $_.Name -like ($database + '_FULL.bak')})
            $LastBackup = (Get-RSMURL) + '/' + (Get-LastFullBackup -blobs $RSMBlobs -database $database)
            }
        ELSEIF ($BlobContainer -eq 'egordianbackups')
            {
            $EGBlobs = (get-egblobs | ?{$_.Name -like ('*_' + $database + '_FULL*') -or $_.Name -like ($database + '_FULL.bak')})
            $LastBackup = (Get-EGURL) + '/' +  (Get-FullBackup -Blobs $EGBlobs -database $database).name   #(Get-LastFullBackup -blobs $EGBlobs -database $database)
            } 
        ELSE 
        {
            write-host 'INVALID BLOB CONTAINER' $BlobContainer -ForegroundColor 'Yellow'
            Log-Message -message ('++ INVALID BLOB CONTAINER ' + $BlobContainer)
            CONTINUE
        }

    }
CATCH
    {
            write-host 'ERROR FINDING BACKUP FILES FOR DATABASE' -ForegroundColor 'Yellow'
            Log-Message -message ('++ ERROR FINDING BACKUP FILES FOR DATABASE ' + $agdb.name)
            Log-Message -message ($ERROR[0] | select * )
            CONTINUE
    }
If ($LastBackup -notlike '*.bak')   ##  Make sure the URL contains a file name
    {
            write-host 'BACKUP FILE IS NOT VALID' -ForegroundColor 'Yellow'
            Log-Message -message ('++ BACKUP FILE NOT FOUND FOR DATABASE ' + $Database)
            CONTINUE
    }

        write-host 'Last backup file found:' $LastBackup
        Log-Message -message ('Last Production Backup Found: ' + $LastBackup)

#############################
#  Get Database File Paths  #
#############################

$ExistingDatabases = get-dbadatabase -SqlInstance $TargetServer | select -ExpandProperty Name
$filemap = $null
$filemap = @{} 
$filemap = Create-FileMap -database $database -server $TargetServer -backupFile $LastBackup -AzureCredential $AzureCredential
 
#######################################
#  Restore Database To Target Server  #
#######################################

$RestoreSQL = Restore-DbaDatabase -SqlInstance $TargetServer -Path  $LastBackup -Databasename $database -AzureCredential 'AzureCredential' -FileMapping $filemap -outputscriptonly -enableException -withreplace 
$SetSingleUser = "ALTER DATABASE [" + $database + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
$SetMultiUser = "ALTER DATABASE [" + $database + "] SET MULTI_USER"

<#
'Executing the following SQL Statement on ' + $TargetServer 
$SetSingleUser
$RestoreSQL
$SetMultiUser

#>

TRY
{
$RestoreComplete = 'no'
    IF ($RestoreComplete -eq 'no' -and $debugMode -eq 0)   #   Loop needed to prevent restore from colliding with the backup
        {
            write-host 'Executing the following SQL:' $SetSingleUser
            Log-Message -message('Executing the following SQL: ' + $SetSingleUser)
            invoke-sqlcmd -query $SetSingleUser -ServerInstance $TargetServer -database master -verbose
            
            write-host 'Executing the following SQL:' $RestoreSQL 
            Log-Message -message('Executing the following SQL: ' + $RestoreSQL)
            Invoke-Sqlcmd -query $RestoreSQL -ServerInstance $TargetServer -database master -verbose -querytimeout 0 -connectiontimeout 0

            write-host 'Executing the following SQL:' $SetMultiUser
            Log-Message -message('Executing the following SQL: ' + $SetMultiUser)
            invoke-sqlcmd -query $SetMultiUser -ServerInstance $TargetServer -database master -verbose

            $RestoreComplete = 'yes' 
        }
    IF ($debugMode -eq 1)
    {
        Log-Message -message('SCRIPT IN DEBUG MODE!!  NO CODE WILL BE EXECUTED')

        Log-Message -message('Would be executing the following SQL: ' + $SetSingleUser)
        write-host 'Would be executing the following SQL:' $SetSingleUser
            
        write-host 'Would be executing the following SQL:' $RestoreSQL 
        Log-Message -message('Would be executing the following SQL: ' + $RestoreSQL)

        write-host 'Would be executing the following SQL:' $SetMultiUser
        Log-Message -message('Would be executing the following SQL: ' + $SetMultiUser)
    }
}
CATCH
{
        write-host 'ERROR RESTORING PRODUCTION BACKUP TO' $TargetServer -ForegroundColor 'Yellow'
        Log-Message -message ('++ ERROR RESTORING PRODUCTION BACKUP TO ' + $TargetServer)
        Log-Message -message ($ERROR[0] | select * )
        CONTINUE
}

BREAK

##################
#  Cleanse Data  #
##################
$CleanseComplete = 'no'
if ((Test-path -path $CleanseFilePath) -eq $true -and $CleanseComplete -eq 'no')
    {
    'Cleansing Data with SQL file ' + $CleanseFilePath
    Invoke-Sqlcmd -ServerInstance $TargetServer -InputFile $CleanseFilePath -Database $database -Verbose
    $CleanseComplete = 'yes'
    }

BREAK

################################################
#   Backup the cleansed database to TGGFILE4   #
################################################

$backupCmd = Backup-DbaDatabase -SqlInstance $TargetServer -Database $database -type Full -copyonly -BackupDirectory $BackupFilePath -BackupFileName $BackupFileName -OutputScriptOnly -CompressBackup -verbose
'Executing:  '  
$backupCmd

Invoke-Sqlcmd -ServerInstance $targetServer -Database master -Query $backupCmd -QueryTimeout 0 -ConnectionTimeout 0 -verbose


