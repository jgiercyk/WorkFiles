#########################
##  Import References  ##
#########################
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\CommonRestoreFunctions.psm1" -Destination 'c:\scripts\CommonRestoreFunctions.psm1' -force
copy-item -path "filesystem::\\10.90.17.152\livedbbk\PowershellScripts\DisasterRecoveryFunctions.psm1" -Destination 'c:\scripts\DisasterRecoveryFunctions.psm1' -force


import-module dbatools -force
import-module AZURERM -DisableNameChecking
import-module SqlServer
import-module c:\scripts\CommonRestoreFunctions.psm1 -Scope Global -force -DisableNameChecking
import-module c:\scripts\DisasterRecoveryFunctions.psm1 -Scope Global -force -DisableNameChecking

########################
#  Set User Variables  #
########################
$database = 'ZipCodes'

#############################
#  File Location Variables  #
#############################
$TargetServer = '10.90.17.63'
$CleanseFilePath = '\\10.90.17.152\livedbbk\BackupsOnDemand\DataCleansing\' + $database + '.sql'
$BackupFilePath = '\\10.90.17.152\livedbbk\BackupsOnDemand'
$BackupFileName = $database + '.bak'

################################
#  Get Last Production Backup  #
################################
$RSMBlobs = (get-rsmblobs | ?{$_.Name -like ('*_' + $database + '_FULL*') -or $_.Name -like ($database + '_FULL.bak')})
$EGBlobs = (get-egblobs | ?{$_.Name -like ('*_' + $database + '_FULL*') -or $_.Name -like ($database + '_FULL.bak')})
 

    if ($RSMBlobs -ne $null)
        {
        $LastBackup = (Get-RSMURL) + '/' + (Get-LastFullBackup -blobs $RSMBlobs -database $database)
        }
    else
        {
        $LastBackup = (Get-EGURL) + '/' + (Get-LastFullBackup -blobs $EGBlobs -database $database)
        }



#############################
#  Get Database File Paths  #
#############################

$ExistingDatabases = get-dbadatabase -SqlInstance $TargetServer | select -ExpandProperty Name
$filemap = $null
$filemap = @{} 
 
    IF ($ExistingDatabases -contains $database)    #  If database exists on target, use the existing filepaths
        {
        $TargetDatabaseFiles = Get-DbaDatabaseFile -SqlInstance $TargetServer -Database $database
        $BackupDatabaseFiles = (read-dbabackupheader -SqlInstance $TargetServer  -Path $LastBackup -AzureCredential 'AzureCredential').filelist 
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
    ELSE    #  Create a file map from the backup files logical names and server default filepaths
        {
        $BackupDatabaseFiles = (read-dbabackupheader -SqlInstance $TargetServer  -Path $LastBackup -AzureCredential 'AzureCredential').filelist
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

#######################################
#  Restore Database To Target Server  #
#######################################

$RestoreSQL = Restore-DbaDatabase -SqlInstance $TargetServer -Path  $LastBackup -Databasename $database -AzureCredential 'AzureCredential' -FileMapping $filemap -outputscriptonly -enableException -withreplace 

'Executing the following SQL Statement: ' 
$RestoreSQL


$RestoreComplete = 'no'
IF ($RestoreComplete -eq 'no')   #   Loop needed to prevent restore from colliding with the backup
{
    invoke-sqlcmd -query ("ALTER DATABASE [" + $database + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE") -ServerInstance $TargetServer -database master -verbose #| out-null
    Invoke-Sqlcmd -query $RestoreSQL -ServerInstance $TargetServer -database master -verbose -querytimeout 0 -connectiontimeout 0
    invoke-sqlcmd -query ("ALTER DATABASE [" + $database + "] SET MULTI_USER") -ServerInstance $TargetServer -database master #| out-null
    $RestoreComplete = 'yes' 
}

##################
#  Cleanse Data  #
##################

if ((Test-path -path $CleanseFilePath) -eq $true)
    {
    'Cleansing Data with SQL file ' + $CleanseFilePath
    Invoke-Sqlcmd -ServerInstance $TargetServer -InputFile $CleanseFilePath -Database $database -Verbose
    }


################################################
#   Backup the cleansed database to TGGFILE4   #
################################################

$backupCmd = Backup-DbaDatabase -SqlInstance $TargetServer -Database $database -type Full -copyonly -BackupDirectory $BackupFilePath -BackupFileName $BackupFileName -OutputScriptOnly -CompressBackup -verbose
'Executing:  '  
$backupCmd

Invoke-Sqlcmd -ServerInstance $targetServer -Database master -Query $backupCmd -QueryTimeout 0 -ConnectionTimeout 0 -verbose


