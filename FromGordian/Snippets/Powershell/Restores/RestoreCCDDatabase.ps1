copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\DisasterRecoveryFunctions.psm1" -Destination 'c:\scripts\DisasterRecoveryFunctions.psm1' -force

import-module AZURERM -DisableNameChecking
import-module dbatools -force
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking
import-module c:\scripts\DisasterRecoveryFunctions.psm1 -Scope Global -force -DisableNameChecking

########################
##   USER VARIABLES   ##
########################

$database = 'CCD_Todd'
$TargetServer = 'DEVSQLDMAP01'
$FullBackup = '\\tggfile4\livedbbk\CCD_Reports\ccd.bak'

###############################
#  Get Blobs To Be REstored   #
###############################

##  Get database users prior to restore  ##
$TargetDBUsers = Get-DatabaseUsers -server $TargetServer -database $database

##  Create file map  ##
$filemap = $null
$filemap = @{} 
 
$TargetDatabaseFiles = Get-DbaDbFile -SqlInstance $TargetServer -Database $database
$BackupDatabaseFiles = (read-dbabackupheader -SqlInstance $TargetServer  -Path $FullBackup -AzureCredential 'AzureCredential').filelist 
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

$sqlcmd = Restore-DbaDatabase -SqlInstance $TargetServer -Path  $FullBackup -Databasename $database -AzureCredential 'AzureCredential' -FileMapping $filemap -outputscriptonly -enableException -withreplace 

'Executing:  ' + $sqlcmd

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "ALTER DATABASE [${restoreDatabase}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query $sqlcmd -verbose -QueryTimeout 0 -ConnectionTimeout 0

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "ALTER DATABASE [${restoreDatabase}] SET MULTI_USER" -verbose

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







