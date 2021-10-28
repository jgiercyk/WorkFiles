Import-Module sqlserver
Import-Module dbatools
$server = 'pladevsql03'

$Databases = Get-DbaDatabase -SqlInstance $Server | ?{$_.IsSysterObject -ne $false -and $_.Size -ge 1000000}   #  Database 1TB or larger

foreach ($db in $Databases)
{
write-host **** $db.name ****
    $query = "USE " + $db.name + " DBCC CHECKALLOC('" + $db.name + "') WITH ESTIMATEONLY, NO_INFOMSGS"
    Write-host $query
    invoke-sqlcmd -query $query -ServerInstance $Server -Database $db.name -verbose

}
