Import-module dbatools
import-module importexcel

#$servername = 'mmcvsrvrssisp01'  ## Server Name Variable Needed For Report


$filedate = get-date -Format yyyyMMddhhmmss
$path =  'C:\Package Failure Reports\'
$outputfile = $path + 'PackageFailureHistory_' + $servername + '_' + $filedate + '.xlsx'


If (!(test-path $path))
    {
        md $path
    }

$servers = invoke-sqlcmd -ServerInstance mmcvsrvrd01 -Database dba -Query "select Server_Name from ServersToMonitor where monitor = 1" | select -ExpandProperty Server_Name

foreach ($server in $servers)
{
$projects = Get-DbaSsisExecutionHistory -SqlInstance $server | ?{$_.StatusCode -in ('Failed','Halted')} | select  -Unique -ExpandProperty ProjectName

    Get-DbaSsisExecutionHistory -SqlInstance $server | select * | ?{$_.StatusCode -in ('Failed','Halted')}  | export-excel -Path $outputfile -WorksheetName 'All Packages' -AutoSize -AutoFilter -FreezeTopRow 

    foreach ($project in $projects)
        {
        Get-DbaSsisExecutionHistory -SqlInstance $servername | select * | ?{$_.projectname -eq $project -and $_.StatusCode -in ('Failed','Halted')} | export-excel -Path $outputfile -WorksheetName $project -AutoSize -AutoFilter -FreezeTopRow
        }
}




