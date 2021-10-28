import-module dbatools

$server = 'plakssqldev'
$databases = 'RRAdvantage','RRAFS','RRFreightcom','RRSRC'

foreach ($db in $databases)
{
    $Path = '\\PLABACKUP01.TRENDSETINC.COM\SQLBackups$\Data_Backups\SQLPC-01$SQLPCDG1-01\' + $db + '\FULL\' 
    Backup-DbaDatabase -SqlInstance $server -database $db -path $path -type Full -OutputScriptOnly
}

