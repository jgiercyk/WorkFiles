   
IMPORT-MODULE -name AZURERM -DisableNameChecking

$storageAccount = 'tggsqlbackups'
$storageAccessKey = '0JqxsxUOb9kJQa2oAqlGFjalB78vieOqySMdValN+fpYfrSu2XtZz8VNaS/iEb5KqdVySsSFYtLKQe+/imDnEw=='
$context = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccessKey
$storageContainer = 'egordianbackups'

New-AzureStorageContainer -Name $storageContainer -Context $context -Permission Blob -ErrorAction SilentlyContinue

$BlobFiles = get-childitem -path 'B:\Backups01\egordianbackups' -recurse | ?{$_.Name -like '*.bak'} 

    
foreach ($file in $BlobFiles)
{

Set-AzureStorageBlobContent -file $file.fullname -Container $storageContainer  -Blob $file.name -context $context -force -blobType Page

}



   
