import-module dbatools

$server = 'mmcvsrvrp01'

$databases = get-dbadatabase -SqlInstance $server | ?{$_.owner -ne 'sa'} | select -ExpandProperty name

foreach ($db in $databases)
{
    set-dbadbowner -SqlInstance $server -Database $db 
}


$SimpleDatabases = get-dbadatabase -SqlInstance $server | ?{$_.recoverymodel -eq 'full' -and $_.IsSystemObject -eq $false} | select -ExpandProperty name

foreach ($db in $SimpleDatabases)
{
    Set-DbaDbRecoveryModel -SqlInstance $server -Database $db -RecoveryModel simple
}