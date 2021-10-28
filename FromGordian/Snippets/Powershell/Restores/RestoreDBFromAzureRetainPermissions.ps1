copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\DisasterRecoveryFunctions.psm1" -Destination 'c:\scripts\DisasterRecoveryFunctions.psm1' -force

import-module AZURERM -DisableNameChecking
import-module dbatools -force
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking
import-module c:\scripts\DisasterRecoveryFunctions.psm1 -Scope Global -force -DisableNameChecking

########################
##   USER VARIABLES   ##
########################

$database = 'DmapCatalogs'
$TargetServer = 'DEVSQLDMAP01'

###############################
#  Get Blobs To Be REstored   #
###############################

$RSMBackups = get-rsmblobs | ?{$_.Name -like '*' + $database + '_*'}
$EGBackups = get-egblobs | ?{$_.Name -like '*' + $database + '_*'}

if($RSMBackups -ne $null)
    {
    $FullBackups = $RSMBackups
    $AzureURL = Get-RsmURL
    }
else{
    $FullBackups = $EGBackups
    $AzureURL = Get-EGURL
    }

$LastFullBackup = get-fullbackup -database $database -Blobs $FullBackups

##  Get database users prior to restore  ##
$TargetDBUsers = Get-DatabaseUsers -server $TargetServer -database $database

##  Create file map  ##
$filemap = $null
$filemap = @{} 
 
$TargetDatabaseFiles = Get-DbaDatabaseFile -SqlInstance $TargetServer -Database $database
$BackupDatabaseFiles = (read-dbabackupheader -SqlInstance $TargetServer  -Path ($AzureURL + '/' + $LastFullBackup.Name) -AzureCredential 'AzureCredential').filelist 
If ($TargetDatabaseFiles.PhysicalName -ne $BackupDatabaseFiles.physicalName)
        {
        foreach($targetfile in $TargetDatabaseFiles)
            {
                foreach($backupefile in $BackupDatabaseFiles) 
                { 
                if ($targetfile.logicalname -eq $backupefile.logicalname)
                    {
                    $filemap.add($targetfile.LogicalName,$targetfile.PhysicalName)
                    }
                }
            }
        }

########################
##  Restore Database  ##
########################

$sqlcmd = Get-FullBackupSql -database $database -LastFullBackup ($AzureURL + '/' + $LastFullBackup.name) -AzureCredential 'AzureCredential' -Filemap $filemap

'Executing:  ' + $sqlcmd

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "ALTER DATABASE [${database}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query $sqlcmd -verbose -QueryTimeout 0 -ConnectionTimeout 0

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "RESTORE DATABASE [${database}] WITH RECOVERY" -verbose

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "ALTER DATABASE [${database}] SET MULTI_USER" -verbose

##   Get Database Users After Restore   ###
$ExistingDBUsers = Get-DatabaseUsers -server $TargetServer -database $database

##  Recreate Missing Users  ##
foreach ($user in $TargetDBUsers)
    {
    IF ($user -notin $ExistingDBUsers)
        {
        New-DbaDbUser -SqlInstance $TargetServer -Database $database -Username $user
        }
    }

##  Fix orphans  ###
$logins = get-dbalogin -SqlInstance $TargetServer | select -ExpandProperty name
$orphans = Get-dbaOrphanUser -SqlInstance $TargetServer | ?{$_.DatabaseName -eq $database -and $_.user -in $logins} | select user

foreach ($orphan in $orphans)
{
    $user = $orphan.user
    $sqlcmd = "USE [" + $database + "] EXEC sp_change_users_login 'Auto_Fix','" + $user + "'"
    "NOW EXECUTING: " + $sqlcmd
    invoke-sqlcmd -query $sqlcmd -serverinstance $TargetServer -verbose

}







