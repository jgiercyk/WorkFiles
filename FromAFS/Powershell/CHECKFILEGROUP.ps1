Import-Module sqlserver
Import-Module dbatools


$filegroups = Get-dbadatabase -SqlInstance pladevsql03 | ?{$_.IsSystemObject -eq $false} | ?{$_.Size -ge 1000000} | Get-DbaDbFileGroup -SqlInstance pladevsql03 | ?{$_.Size -ge 10000000} |select Parent, Name, Size   # Databases greater than 1TB

foreach ($group in $filegroups)
{
    Write-Host $group.parent.name :    $group.name
    $query = "USE " + $group.parent.name + " DBCC CHECKFILEGROUP('" + $group.name + "') WITH ESTIMATEONLY, NO_INFOMSGS"
    Write-host $query
    invoke-sqlcmd -query $query -ServerInstance PLADEVSQL03 -Database $group.Parent.name -verbose
}
