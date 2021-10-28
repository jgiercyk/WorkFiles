copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\DisasterRecoveryFunctions.psm1" -Destination 'c:\scripts\DisasterRecoveryFunctions.psm1' -force


import-module dbatools -force
import-module AZURERM -DisableNameChecking
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking
import-module c:\scripts\DisasterRecoveryFunctions.psm1 -Scope Global -force -DisableNameChecking

########################
#  Set User Variables  #
########################
$database = 'IODB'
$TargetServer = '10.90.17.63'

###############################
#  Get Blobs To Be REstored   #
###############################

$RSMBackups = get-rsmblobs | ?{$_.Name -like '*' + $database + '_*'}
$EGBackups = get-egblobs | ?{$_.Name -like '*' + $database + '_*'}

if($RSMBackups -ne $null)
    {
    $AllBackups = $RSMBackups
    $AzureURL = Get-RsmURL
    }
else{
    $AllBackups = $EGBackups
    $AzureURL = Get-EGURL
    }


$AllBackups = Get-AllBackups | ?{$_.Name -like '*' + $database + '_*'}
$AllLogfiles = Get-AllLogfiles | ?{$_.Name -like '*' + $database + '_*'} 

$LastFullBackup = get-fullbackup -database $database -Blobs $AllBackups
$LastDiffBackup = get-diffbackup -database $database -Blobs $AllBackups -lastFullBackup $LastFullBackup
$LogFiles = get-LogBackups -database $database -Blobs $AllLogfiles -lastFullBackup $LastFullBackup -lastDiffBackup $LastDiffBackup


#############################
#  Get Database File Paths  #
#############################

$ExistingDatabases = get-dbadatabase -SqlInstance $TargetServer | select -ExpandProperty Name
$filemap = $null
$filemap = @{} 
 
    IF ($ExistingDatabases -contains $database)
        {
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
        }
    ELSE
        {
        $BackupDatabaseFiles = (read-dbabackupheader -SqlInstance $TargetServer  -Path ($AzureURL + '/' + $LastFullBackup.Name) -AzureCredential 'eGordianCredential').filelist
        $DefaultDatafilePath = get-dbadefaultpath -SqlInstance $TargetServer | Select -ExpandProperty Data
        $DefaultLogfilePath = get-dbadefaultpath -SqlInstance $TargetServer | Select -ExpandProperty Log
            foreach($backupfile in $BackupDatabaseFiles)
            {
               
               if($backupfile.type -eq 'D' -and $backupfile.PhysicalName -like '*.mdf')
                   {$filemap.add($backupfile.Logicalname,$DefaultDatafilePath + "\" +  $backupfile.Logicalname + ".mdf")}
               Elseif($backupfile.type -eq 'L' -and $backupfile.PhysicalName -like '*.ldf')
                   {$filemap.add($backupfile.Logicalname,$DefaultDatafilePath + "\" +  $backupfile.Logicalname + ".ldf")}
               Else
                  {$filemap.add($backupfile.Logicalname,$DefaultDatafilePath + "\" +  $backupfile.Logicalname + ".ndf")}
            }
        }



##   FULL RESTORE
IF ($ExistingDatabases -contains $database)
        {
        'Executing: ' +  "ALTER DATABASE [${database}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
        Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "ALTER DATABASE [${database}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE" 
        }

$sqlcmd = Get-FullBackupSql -database $database -LastFullBackup ($AzureURL + '/' + $LastFullBackup.name) -AzureCredential 'AzureCredential' -Filemap $filemap
'>>> Executing: ' + $sqlcmd
'>>> On Server: ' + $TargetServer

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query $sqlcmd -connectiontimeout 0 -querytimeout 0 -verbose


##   DIFF RESTORE
$sqlcmd = Get-DiffBackupSql -database $database -LastDiffBackup ($AzureURL + '/' + $LastDiffBackup.name) -AzureCredential 'AzureCredential' -Filemap $filemap
'Executing: ' + $sqlcmd
Invoke-Sqlcmd -ServerInstance $TargetServer -database 'master' -query $sqlcmd -connectiontimeout 0 -querytimeout 0 -verbose 


##    LOG RESTORE
foreach($logfile in $LogFiles)
{
    $sqlcmd = Get-LogBackupSql -database $database -Logfile ($AzureURL + '/' + $logfile.name) -AzureCredential 'AzureCredential'
    'Executing: ' + $sqlcmd
    Invoke-Sqlcmd -ServerInstance $TargetServer -database 'master' -query $sqlcmd -connectiontimeout 0 -querytimeout 0 -verbose 
}


Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "RESTORE DATABASE [${database}] WITH RECOVERY" -verbose
Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "ALTER DATABASE [${database}] SET MULTI_USER" -verbose


BREAK

Invoke-Sqlcmd -ServerInstance $targetServer -Database 'master' -Query "ALTER DATABASE [${database}] SET MULTI_USER" | out-null


Get-DbaBackupHistory  -SqlInstance '192.168.1.63' -Database 'ZipCodes' -last -verbose | select filelist

Get-DbaRestoreHistory -SqlInstance '192.168.1.63' -database 'ZipCodes' -Last -verbose 