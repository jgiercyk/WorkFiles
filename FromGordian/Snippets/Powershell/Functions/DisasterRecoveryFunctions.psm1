FUNCTION Get-AllBackups{$storageAccount = 'tggsqlbackups'
    $storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
    $storageContainer = 'egordianbackups'
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/egordianbackups'
    $sqlCredential = 'egordianCredential'
    $context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
    New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
    $Blobs   = Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.bak'} | select lastmodified, name

    $storageContainer = 'rsmccdbackups'
    $Blobs = $Blobs + (Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.bak'} | select lastmodified, name)

    RETURN $Blobs}

FUNCTION Get-RsmBackups {
    $storageAccount = 'tggsqlbackups'
    $storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
    $storageContainer = 'rsmccdbackups'
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/rsmccdbackups'
    $sqlCredential = 'RSMeansCredential'
    $context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
    New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
    $Blobs   = Get-AzureStorageBlob -Container $storageContainer -Context $context | select lastmodified, name
    RETURN $Blobs
}

FUNCTION Get-EGBackups {
    $storageAccount = 'tggsqlbackups'
    $storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
    $storageContainer = 'egordianbackups'
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/egordianbackups'
    $sqlCredential = 'egordianCredential'
    $context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
    New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
    $Blobs   = Get-AzureStorageBlob -Container $storageContainer -Context $context | select lastmodified, name
    RETURN $Blobs
}

FUNCTION Get-BackupsDetails{$storageAccount = 'tggsqlbackups'
    $storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
    $storageContainer = 'egordianbackups'
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/egordianbackups'
    $sqlCredential = 'egordianCredential'
    $context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
    New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
    $Blobs   = Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.bak'}

    $storageContainer = 'rsmccdbackups'
    $Blobs = $Blobs + (Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.bak'})

    RETURN $Blobs}

FUNCTION Get-AllLogfiles{$storageAccount = 'tggsqlbackups'
    $storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
    $storageContainer = 'egordianbackups'
    $storageURL = 'https://tggsqlbackups.blob.core.windows.net/egordianbackups'
    $sqlCredential = 'egordianCredential'
    $context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey 
    New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
    $Blobs   = Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.trn'} | select lastmodified, name

    $storageContainer = 'rsmccdbackups'
    $Blobs = $Blobs + (Get-AzureStorageBlob -Container $storageContainer -Context $context | ?{$_.name -like '*.trn'} | select lastmodified, name)

    RETURN $Blobs}

FUNCTION Get-FullBackup{param($Blobs,
                             [string]$database)
        #$searchPattern = '*_' + $database + '_FULL_*'
        $searchPattern = '*' + $database + '_FULL_*'
        $LastFullBackup = $Blobs | sort-object LastModified -Descending | ?{$_.name -like $searchPattern} | select name, lastmodified -first 1 
        return $LastFullBackup}

FUNCTION Get-DiffBackup{param($Blobs,
                             [string]$database,
                             $LastFullBackup)
        #$searchPattern = '*_' + $database + '_DIFF_*'
        $searchPattern = '*' + $database + '_DIFF_*'
        $LastDiffBackup = $Blobs | sort-object LastModified -Descending | ?{$_.name -like $searchPattern} | select name, lastmodified -first 1

        $diffStartTime = $LastDiffBackup.LastModified.DateTime

        if($LastDiffBackup.LastModified.DateTime -gt $LastFullBackup.LastModified.DateTime)
        {RETURN $LastDiffBackup}
        else{
        RETURN $null}
        }

FUNCTION Get-LogBackups{param($Blobs,
                             [string]$database,
                             $LastDiffBackup,
                             $LastFullBackup)
        #$searchPattern = '*_' + $database + '_LOG_*'
        $searchPattern = '*' + $database + '_LOG_*'
        $logStartTime = $LastDiffBackup.LastModified.DateTime
            if($logStartTime -eq $null -or $LastDiffBackup.LastModified.DateTime -lt $LastFullBackup.LastModified.DateTime)
                {$logStartTime  = $LastFullBackup.LastModified.DateTime}
        $LogBackups   = $Blobs | sort-object LastModified | ?{$_.name -like $searchPattern -and $_.LastModified.DateTime -gt $logStartTime} | select name, lastmodified
        RETURN $LogBackups}

FUNCTION Get-FullBackupSql{param($database,
                                $LastFullBackup,
                                $AzureCredential,
                                $filemap)

$fileMoveStatements =
foreach($file in $filemap.GetEnumerator())
    {
"MOVE '$($file.name)' TO '$($file.value)',"
    }

$fullBackupSQL =
@"
USE [MASTER]
RESTORE DATABASE ${database} 
FROM URL = '${LastFullBackup}' 
WITH CREDENTIAL = '${AzureCredential}', FILE = 1, NORECOVERY, 
${FileMoveStatements}
NOUNLOAD,  REPLACE,  STATS = 5
"@
       RETURN $fullBackupSQL}

FUNCTION Get-DiffBackupSql{param($database,
                                $LastDiffBackup,
                                $AzureCredential)

$diffBackupSQL = 
@"
USE [MASTER]
RESTORE DATABASE [${database}] 
FROM URL = '${LastDiffBackup}' 
WITH CREDENTIAL = '${AzureCredential}', FILE = 1, NORECOVERY, 
NOUNLOAD, STATS = 5
"@
       RETURN $diffBackupSQL}

FUNCTION Get-LogBackupSQL{param($database,
                                $logfile,
                                $AzureCredential) 
"RESTORE LOG [${database}] FROM URL = '${logfile}' WITH CREDENTIAL = '${AzureCredential}', NORECOVERY"

}
FUNCTION Get-DRDatabases{param($ServerToRestore)
        $Now = Get-Date
        $Yesterday = $Now.AddHours(-24)

        $sqlcmd = "SELECT [name] FROM [DBA_Mon].[dbo].[DBInfo] where record_date > '${Yesterday}' and SERVER_NAME = '${ServerToRestore}'"

        $databasesToRestore = Invoke-Sqlcmd -Query $sqlcmd -ServerInstance '10.90.17.63' -database master
RETURN $databasesToRestore}

 Export-ModuleMember -function *