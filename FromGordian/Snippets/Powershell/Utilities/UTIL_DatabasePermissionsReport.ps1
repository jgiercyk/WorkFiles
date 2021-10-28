<###############################################################################################
Script checks user security above db_datareader by database and outputs the result to a table

$database - If the variable is set to a database name, only that database will be reported
$allDatabases - if $database is set to '' then all databases will be reported on
$server can be set to any server

################################################################################################>
import-module dbatools 

$server = $env:COMPUTERNAME
$database = ''

$allDatabases = get-dbadatabase -SqlInstance $server | select -ExpandProperty Name


If ($database -eq '')
    {
    get-dbadbrolemember -SqlInstance $server | ?{$_.Role -ne 'db_datareader'} | select ComputerName, UserName, Database, Role | ?{$_.Database -in $allDatabases} | Out-GridView
    }
    else
    {
    get-dbadbrolemember -SqlInstance $server | ?{$_.Role -ne 'db_datareader'} | select UserName, Database, Role | ?{$_.Database -eq $Database} | Out-GridView
    }

<#
Get-DbaDbRoleMember -SqlInstance $server -excluderole 'db_owner' | select computername, database, role, username 
get-dbaserverrole -SqlInstance $server | select login |  role | ?{$login -eq $null}  #gm  -ServerRole 'sysadmin'
#>

(Get-dbaServerRole -SqlInstance $server -ServerRole sysadmin).EnumMemberNames() | out-Gridview