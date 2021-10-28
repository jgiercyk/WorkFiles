###################################
#####  Variables Set By User  #####
###################################
$DatabaseName = 'ProgenData'
$ServerName = 'AZURE-PRD-SQL03'  #$env:Computername  
$dataFileDirectory = 'D:\MSSQL11.MSSQLSERVER\MSSQL\Data'
$logFileDirectory = 'L:\MSSQL11.MSSQLSERVER\MSSQL\LOGS'

#######################################
##### Storage Container Creation  #####
#######################################
IMPORT-MODULE -name SQLPS -DisableNameChecking
IMPORT-MODULE -name AZURERM -DisableNameChecking
$storageAccount = 'tggsqlbackups'
$storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
$storageContainer = 'egordianbackups'
$storageURL = 'https://tggsqlbackups.blob.core.windows.net'
$sqlCredential = 'EGordianCredential'
$context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue

#######################
#####  FUNCTIONS  #####
#######################

FUNCTION Get-AllDatabaseBackups{
        $AllBackups   = Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*' + $DatabaseName + '*'} | select name, lastmodified 
        RETURN $AllBackups}

FUNCTION Get-FullBackup{
        $searchPattern = '*_' + $DatabaseName + '_FULL_*'
        $LastFullBackup = $AllDatabaseBackups | sort-object LastModified -Descending | ?{$_.name -like $searchPattern} | select name, lastmodified -first 1 
        return $LastFullBackup}

FUNCTION Get-DiffBackup{
        $searchPattern = '*_' + $DatabaseName + '_DIFF_*'
        $LastDiffBackup = $AllDatabaseBackups | sort-object LastModified -Descending | ?{$_.name -like $searchPattern} | select name, lastmodified -first 1

        $diffStartTime = $LastDiffBackup.LastModified.DateTime

        if($LastDiffBackup.LastModified.DateTime -gt $LastFullBackup.LastModified.DateTime)
        {RETURN $LastDiffBackup}
        else{
        RETURN $null}
        }

FUNCTION Get-LogBackups{
        $searchPattern = '*_' + $DatabaseName + '_LOG_*'
        $logStartTime = $LastDiffBackup.LastModified.DateTime
            if($logStartTime -eq $null -or $LastDiffBackup.LastModified.DateTime -lt $LastFullBackup.LastModified.DateTime)
                {$logStartTime  = $LastFullBackup.LastModified.DateTime}
        $LogBackups   = $AllDatabaseBackups | sort-object LastModified | ?{$_.name -like $searchPattern -and $_.LastModified.DateTime -gt $logStartTime} | select name, lastmodified
        RETURN $LogBackups}

FUNCTION Get-TableExistance{
        $sqlcmd = "IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Filelist') AND type in (N'U')) SELECT 0 'Exists' ELSE SELECT 1 'Exists'"
        $tExists = invoke-sqlcmd -query $sqlcmd -ServerInstance $ServerName -Database 'dba'
        return $tExists.Exists}

FUNCTION Get-FileMoveStatements {
        $DataFiles = Invoke-Sqlcmd -Query "select LogicalName, SUBSTRING(PhysicalName,LEN(PhysicalName) - CHARINDEX('\',REVERSE(PhysicalName)) + 2, LEN(PhysicalName)) 'PhysicalName' from dba.dbo.Filelist where type = 'D'" -ServerInstance $ServerName -Database 'dba' | SELECT LogicalName, PhysicalName
        $LogFiles  = Invoke-Sqlcmd -Query "select LogicalName, SUBSTRING(PhysicalName,LEN(PhysicalName) - CHARINDEX('\',REVERSE(PhysicalName)) + 2, LEN(PhysicalName)) 'PhysicalName' from dba.dbo.Filelist where type = 'L'" -ServerInstance $ServerName -Database 'dba' | SELECT LogicalName, PhysicalName

        $DataFileMoves = 
        foreach ($datafile in $datafiles)
        {
        "MOVE N'" + $datafile.logicalname + "' TO N'" + $dataFileDirectory + "\" + $datafile.physicalName + "',`n" 
        }
        $LogFileMoves = 
        foreach ($logfile in $logfiles)
        {
        "MOVE N'" + $logfile.logicalname + "' TO N'" + $logFileDirectory + "\" + $logfile.physicalName + "'"
        }
        $FileMoves = $DataFileMoves + $LogFileMoves
        return $FileMoves}

FUNCTION Create-FileList{
$createFileListTable = 
@"
USE dba
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Filelist]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Filelist](
	[LogicalName] [varchar](255) NULL,
	[PhysicalName] [varchar](255) NULL,
	[Type] [varchar](255) NULL,
	[FileGroupName] [varchar](255) NULL,
	[Size] [varchar](255) NULL,
	[MaxSize] [varchar](255) NULL,
	[FileId] [varchar](255) NULL,
	[CreateLSN] [varchar](255) NULL,
	[DropLSN] [varchar](255) NULL,
	[UniqueId] [varchar](255) NULL,
	[ReadOnlyLSN] [varchar](255) NULL,
	[ReadWriteLSN] [varchar](255) NULL,
	[BackupSizeInBytes] [varchar](255) NULL,
	[SourceBlockSize] [varchar](255) NULL,
	[FileGroupId] [varchar](255) NULL,
	[LogGroupGUID] [varchar](255) NULL,
	[DifferentialBaseLSN] [varchar](255) NULL,
	[DifferentialBaseGUID] [varchar](255) NULL,
	[IsReadOnly] [varchar](255) NULL,
	[IsPresent] [varchar](255) NULL,
	[TDEThumbprint] [varchar](255) NULL,
	[SnapshotURL] [varchar](255) NULL
) ON [PRIMARY]
END
ELSE
BEGIN
    TRUNCATE TABLE [dbo].[filelist]
END
"@
        invoke-sqlcmd -query $createFileListTable -ServerInstance $ServerName -Database 'dba' | out-null

$createFileListSQL = 
@"
USE [MASTER] RESTORE FILELISTONLY FROM URL = ''${sourcefile}'' WITH CREDENTIAL = ''${sqlCredential}''
"@

$insertFileListRecord =
@"
USE [DBA] INSERT Filelist EXEC('${createFileListSQL}')
"@
        invoke-sqlcmd -query $insertFileListRecord -ServerInstance $ServerName -Database 'dba'
     
}

#####################
#####  PROCESS  #####
#####################

$AllDatabaseBackups = Get-AllDatabaseBackups
$LastFullBackup = Get-FullBackup
$LastDiffBackup = Get-DiffBackup
$LogBackups = Get-LogBackups

$sourcefile = $StorageURL + '/' + $StorageContainer + '/' + $LastFullBackup.name

Create-FileList
$FileMoveStatements = Get-FileMoveStatements

switch ($DatabaseName)
    {'DropThings' {$physicalDataFile = 'Dropthings.mdf'
                    $physicalLogFile = 'Dropthings.ldf'}
    'eGordianSandbox' {$physicalDataFile = 'eGordianSandbox.mdf'
                    $physicalLogFile = 'eGordianSandbox.ldf'}
    'BatchReportingScheduler' {$physicalDataFile = 'BatchReportingScheduler.mdf'
                    $physicalLogFile = 'BatchReportingScheduler.ldf'}
    }


$fullBackupSQL = 
@"
USE [MASTER]
ALTER DATABASE ${DatabaseName} SET SINGLE_USER WITH ROLLBACK IMMEDIATE
RESTORE DATABASE ${DatabaseName} 
FROM URL = '${sourcefile}' 
WITH CREDENTIAL = '${sqlCredential}', FILE = 1, NORECOVERY, 
${FileMoveStatements},
NOUNLOAD,  REPLACE,  STATS = 5

"@
    $fullBackupSQL


if ($LastDiffBackup.name -ne $null)
        {$sourcefile = $StorageURL + '/' + $StorageContainer + '/' + $LastDiffBackup.name
$diffBackupSQL = 
@"
USE [MASTER]
RESTORE DATABASE ${DatabaseName} 
FROM URL = '${sourcefile}' 
WITH CREDENTIAL = '${sqlCredential}', FILE = 1, NORECOVERY, 
${FileMoveStatements},
NOUNLOAD, STATS = 5

"@
        $diffBackupSQL
        }



foreach ($file in $logbackups)
{
        $sourcefile = $storageURL + '/' + $StorageContainer + '/' + $file.name
$logBackupSQL = 
@"
RESTORE LOG ${DatabaseName} 
FROM URL = '${sourcefile}' 
WITH CREDENTIAL = '${sqlCredential}', NORECOVERY

"@
        $logBackupSQL
}


#REMOVE-VARIABLE -NAME * -ErrorAction SilentlyContinue

     