import-module dbatools

$Server = 'PLA-SQLPCN1-02'

$Databases = Get-dbaDatabase -SqlInstance $Server | ?{$_.IsSystemObject -eq $false} | select -ExpandProperty name

foreach($db in $Databases)
{
 (get-dbadbbackuphistory -SqlInstance $Server -Database $db -lastFull) 
}

