######################################################################
###  This makes the AzureRM code available regardless of the user  ###
######################################################################
$p = [Environment]::GetEnvironmentVariable("PSModulePath")
$p += ";C:\Program Files\WindowsPowerShell\Modules\"
[Environment]::SetEnvironmentVariable("PSModulePath",$p)

import-module AzureRM

$daysToKeepFull = 25
$daysToKeepDiff = 7
$daysToKeepLog = 7

$storageAccount = 'tggsqlbackups'
$storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
$storageContainer = 'egordianbackups'

$context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey
New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue
$EGBlobs = Get-AzureStorageBlob -Container $storageContainer -Context $context | sort-object LastModified | select lastmodified, name

$FullBlobs = $EGBlobs | select lastmodified, name | ?{$_.name -like '*FULL*.bak' -and $_.lastmodified -lt (get-date).AddDays($daysToKeepFull*-1)}
$DiffBlobs = $EGBlobs | select lastmodified, name | ?{$_.name -like '*DIFF*.bak' -and $_.lastmodified -lt (get-date).AddDays($daysToKeepDiff*-1)}
$LogBlobs =  $EGBlobs | select lastmodified, name | ?{$_.name -like '*LOG*.trn' -and $_.lastmodified -lt (get-date).AddDays($daysToKeepLog*-1)}


foreach($blob in $FullBlobs)
{
        'Deleting File: ' + $blob.name
        Remove-AzureStorageBlob -Blob $blob.name -Container $storageContainer -Context $context
}


foreach($blob in $DiffBlobs)
{
        'Deleting File: ' + $blob.name
        Remove-AzureStorageBlob -Blob $blob.name -Container $storageContainer -Context $context
}


foreach($blob in $LogBlobs)
{
        'Deleting File: ' + $blob.name
        Remove-AzureStorageBlob -Blob $blob.name -Container $storageContainer -Context $context
}


