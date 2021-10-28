FUNCTION Get-RsmBlobs {
    $storageAccount = 'tggsqlbackups'
    $storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
    $storageContainer = 'rsmccdbackups'
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/rsmccdbackups'
    $sqlCredential = 'RSMeansCredential'
    $context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
    New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
    $Blobs   = Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.bak'} | select lastmodified, name
    RETURN $Blobs
}

FUNCTION Get-EGBlobs {
    $storageAccount = 'tggsqlbackups'
    $storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
    $storageContainer = 'egordianbackups'
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/egordianbackups'
    $sqlCredential = 'egordianCredential'
    $context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
    New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
    $Blobs   = Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.bak'} | select lastmodified, name
    RETURN $Blobs
}

FUNCTION Get-RsmLogs {
    $storageAccount = 'tggsqlbackups'
    $storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
    $storageContainer = 'rsmccdbackups'
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/rsmccdbackups'
    $sqlCredential = 'RSMeansCredential'
    $context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
    New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
    $Blobs   = Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.trn'} | select lastmodified, name
    RETURN $Blobs
}

FUNCTION Get-EGLogs {
    $storageAccount = 'tggsqlbackups'
    $storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
    $storageContainer = 'egordianbackups'
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/egordianbackups'
    $sqlCredential = 'egordianCredential'
    $context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
    New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
    $Blobs   = Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.trn'} | select lastmodified, name
    RETURN $Blobs
}

FUNCTION Get-RsmURL {
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/rsmccdbackups'
    RETURN $storageURL
}

FUNCTION Get-EGURL {
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/egordianbackups'
    RETURN $storageURL
}

FUNCTION Get-LastFullBackup{param($Blobs,
                                    [string]$database)
    $searchPattern = '*_' + $database + '_FULL_*'
    $file = (($Blobs | sort-object LastModified -Descending | ?{$_.name -like $searchPattern} | select name -first 1).name)
    return $file
}


FUNCTION Get-ServerFromListener {param([string] $Listener)
    $Server = (invoke-sqlcmd -query 'SELECT @@SERVERNAME "Server"' -server $Listener -database 'master') | select server -expandproperty server
RETURN $Server
}

FUNCTION Get-DatabaseFiles {param([string] $database,
                                    [string] $server)
    $DatafileSQL = 'USE ' + $database + ' SELECT name "name", physical_name "physical_name", type "Type" FROM sys.database_files'
    $Files = (Invoke-Sqlcmd -Query $DatafileSQL -ServerInstance $server) # -database $database)
RETURN $Files
}

FUNCTION Get-FileMoveStatements {param($files)
        $FileMoves = 
        foreach ($file in $files)
        {
        "MOVE N'" + $file.name + "' TO N'" + $file.physical_Name + "'," 
        }
return $FileMoves
}

FUNCTION Create-RSMRestoreSQL{param($database,$backup,$filemoves)
$sqlcmd = 
@"

USE [MASTER]
ALTER DATABASE ${database} SET SINGLE_USER WITH ROLLBACK IMMEDIATE
RESTORE DATABASE ${database} 
FROM URL = '${backup}' 
WITH CREDENTIAL = 'RSMeansCredential', FILE = 1,  
${filemoves}
NOUNLOAD,  REPLACE,  STATS = 5
ALTER DATABASE ${database} SET MULTI_USER

"@
RETURN $sqlcmd
}

FUNCTION Create-EGRestoreSQL{param($database,$backup,$filemoves)
$sqlcmd = 
@"

USE [MASTER]
ALTER DATABASE ${database} SET SINGLE_USER WITH ROLLBACK IMMEDIATE
RESTORE DATABASE ${database} 
FROM URL = '${backup}' 
WITH CREDENTIAL = 'EGordianCredential', FILE = 1,  
${filemoves}
NOUNLOAD,  REPLACE,  STATS = 5
ALTER DATABASE ${database} SET MULTI_USER

"@
RETURN $sqlcmd
}

FUNCTION Remove-DatabaseFromAG{param($database,$availabilitygroup)
$sqlcmd = 
@"
ALTER AVAILABILITY GROUP ${availabilitygroup} REMOVE DATABASE [${database}] 
"@
RETURN $sqlcmd
}

FUNCTION Add-DatabaseToAG {param($servername,
                                 $agname,
                                 $dbname)
    $Sql = "ALTER AVAILABILITY GROUP [${agname}] ADD DATABASE [${dbname}]"
    invoke-sqlcmd -query $sql -ServerInstance $server -Database 'master'
}

FUNCTION Save-AGDatabasesToTable {param($databases,$server)  
$SQLBuildTable = 
@"
USE DBA
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DBToRefresh]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DBToRefresh](
	[DatabaseName] varchar(100),
	[Status] Varchar(100)
) ON [PRIMARY]
END
DELETE FROM DBToRefresh WHERE Status <> 'Ignore'
"@
INVOKE-SQLCMD -Query $SQLBuildTable -ServerInstance $server -Database 'dba'
$DatabasesToIgnore = (invoke-Sqlcmd -Query "SELECT DatabaseName FROM DBToRefresh" -ServerInstance $server -database 'dba').DatabaseName

foreach ($db in $databases)
    {
    $SQLInsert = 'INSERT INTO DBToRefresh VALUES(''' + $db + ''',''Pending'')' 
    Invoke-Sqlcmd -Query $SQLInsert -ServerInstance $server -database 'dba'
    }
}

FUNCTION Get-AGDatabasesFromTable {param($server)
    $AGDB = INVOKE-SQLCMD -Query "SELECT DatabaseName FROM DBToRefresh WHERE Status = 'Successful'" -ServerInstance $server -Database 'dba' | select DatabaseName -ExpandProperty DatabaseName
RETURN $AGDB
}

FUNCTION Get-DatabasesToIgnore {param($server)
    $IgnoreDBs = (INVOKE-SQLCMD -Query "SELECT DatabaseName FROM DBToRefresh WHERE Status = 'Ignore'" -ServerInstance $server -Database 'dba').DatabaseName 
RETURN $IgnoreDBs
}

FUNCTION Set-RestoreStatus {param($server,$database,$status)
    $UpdateSQL = "UPDATE DBToRefresh SET STATUS = '${status}' WHERE DatabaseName = '${database}'"
    INVOKE-SQLCMD -Query $UpdateSQL -ServerInstance $server -Database 'dba'
RETURN 
}

FUNCTION Get-DatabaseUsers {param($server,$database)

$DBUsers = get-dbadbrolemember -SqlInstance $server | ?{$_.Role -ne 'db_datareader'} | select UserName, Database, Role | ?{$_.Database -eq $database} 
RETURN $DBUsers

}

FUNCTION Get-LastFullAzureRestore {param($database,$server)
$LastRestore = get-dbarestorehistory -SqlInstance $server -database $database  | ?{$_.RestoreType -eq 'Database' -and $_.From -like '*https*'} | sort-object BackupFinishDate -Descending | select -first 1 Database, From, BackupFinishDate
RETURN $LastRestore
}

FUNCTION Create-Filemap {param($database,$server,$backupFile,$AzureCredential)
$filemap = $null
$filemap = @{}
$ExistingDatabases = get-dbadatabase -SqlInstance $server | select -ExpandProperty Name

 
    IF ($ExistingDatabases -contains $database)
        {
        $TargetDatabaseFiles = Get-DbaDbFile -SqlInstance $server -Database $database
        $BackupDatabaseFiles = (read-dbabackupheader -SqlInstance $server  -Path $backupFile -AzureCredential $AzureCredential).filelist 
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
        $BackupDatabaseFiles = (read-dbabackupheader -SqlInstance $server  -Path $backupFile -AzureCredential $AzureCredential).filelist
        $DefaultDatafilePath = get-dbadefaultpath -SqlInstance $server | Select -ExpandProperty Data
        $DefaultLogfilePath = get-dbadefaultpath -SqlInstance $server | Select -ExpandProperty Log
            foreach($backupfile in $BackupDatabaseFiles)
            {
               
                if($backupfile.type -eq 'D' -and $backupfile.PhysicalName -like '*.mdf')
                    {$filemap.add($backupfile.Logicalname,$DefaultDatafilePath + "\" +  $backupfile.Logicalname + ".mdf")}
                Elseif($backupfile.type -eq 'L' -and $backupfile.PhysicalName -like '*.ldf')
                    {$filemap.add($backupfile.Logicalname,$DefaultLogfilePath + "\" +  $backupfile.Logicalname + ".ldf")}
                Else
                    {$filemap.add($backupfile.Logicalname,$DefaultDatafilePath + "\" +  $backupfile.Logicalname + ".ndf")}
            }
        }
RETURN $filemap
}
FUNCTION Get-RestoreStatus {param($server)

if ($server -eq $null)
    {
    $server = 'localhost'
    }

$sqlcmd = 
@"
SELECT 
       session_id as SPID
       , command
       , a.text AS Query
       , start_time
       , percent_complete
       , dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time 
FROM 
       sys.dm_exec_requests r 
CROSS APPLY 
       sys.dm_exec_sql_text(r.sql_handle) a 
WHERE 
       r.command in ('BACKUP DATABASE','RESTORE DATABASE', 'BACKUP LOG')
"@ 

$result = invoke-sqlcmd -Query $sqlcmd -ServerInstance $server
RETURN $result
}


Export-ModuleMember -function *
