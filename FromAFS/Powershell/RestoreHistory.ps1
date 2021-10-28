import-module dbatools

$Server = 'PLADEVSQL03'

$Databases = Get-dbaDatabase -SqlInstance $Server | ?{$_.IsSystemObject -eq $false} | select -ExpandProperty name

foreach($db in $Databases)
{
(Get-DbadbRestoreHistory -SqlInstance $Server -Database $db -Last) # | Format-Table
}
