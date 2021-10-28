import-module dbatools

$sourceserver = 'pla-sqlpcn1-01'
$targetserver = 'plakssqldev'
$databases = 'RRAdvantage','RRAFS','RRFreightcom','RRSRC'

foreach ($db in $databases)
{
    $restorefile = Get-DbaDbBackupHistory -SqlInstance $sourceServer -lastfull -database $db | select -expandproperty Path
    Restore-DbaDatabase -OutputScriptOnly -Database $db -SqlInstance $targetserver -path $restorefile -WithReplace
    Write-Host''
}
