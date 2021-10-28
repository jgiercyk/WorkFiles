Import-Module sqlserver
Import-Module dbatools
$server = 'pladevsql03'

$Databases = Get-DbaDatabase -SqlInstance $Server | ?{$_.IsSysterObject -ne $false -and $_.Size -ge 1000000}   #  Database 1TB or larger

foreach ($db in $Databases)
{
write-host **** $db.name ****
$tables = Get-DbaDbTable -SqlInstance $Server -Database $db.name | ?{$_.DataSpaceUsed -ge 50000000} | select Schema, Name, RowCount, DataSpaceUsed |Sort-Object DataSpaceUsed -Descending   #  DB 50GB or larger
    foreach ($table in $tables)
    {
    Write-Host $table.schema'.'$table.name
    $query = "USE " + $db.name + " DBCC CHECKTABLE('" + $table.schema + "." + $table.name + "') WITH ESTIMATEONLY, NO_INFOMSGS"
    Write-host $query
    invoke-sqlcmd -query $query -ServerInstance $Server -Database $db.name -verbose
    }
}
