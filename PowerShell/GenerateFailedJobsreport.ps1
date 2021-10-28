import-module dbatools
import-module importexcel


$filedate = get-date -Format yyyyMMddhhmmss
$path =  'C:\Job Failure Reports\'
$outputfile = $path + 'JobFailureHistory_' + $servername + '_' + $filedate + '.xlsx'


If (!(test-path $path))
    {
        md $path
    }

$servers = invoke-sqlcmd -ServerInstance mmcvsrvrd01 -Database dba -Query "select Server_Name from ServersToMonitor where monitor = 1" | select -ExpandProperty Server_Name

foreach ($server in $servers)
    {
    $jobs = Get-DbaAgentJob -SqlInstance $server | ?{$_.IsEnabled -eq $true -and $_.HasSchedule -eq $true} |   select -expandproperty name #| out-gridview
    $failedJobs = $failedJobs + (Get-DbaAgentJobHistory -SqlInstance $server | ?{$_.job -in $jobs -and $_.status -ne 'Succeeded' -and $_.stepid -eq 0})
    }


#####   RUN REPORT  ######
$failedJobs | select * -Unique | Sort-Object RunDate -Descending | Export-excel -Path $outputfile -FreezeTopRow -AutoSize -WorksheetName 'All Job Failures' -AutoFilter

foreach ($server in $servers)
    {
    $jobsThisServer = $failedJobs | select * -Unique | ?{$_.ComputerName -eq $server} 
    if ($jobsThisServer.Count -gt 0)
        {
        $jobsThisServer | Sort-Object RunDate -Descending | Export-excel -Path $outputfile -FreezeTopRow -AutoSize -WorksheetName $server -AutoFilter
        }
    }
EXIT
 
#    $failedjobs | select ComputerName,InstanceName,JobName,RunDate,Duration,Status,InstanceID,Message,OperatorEmailed,OperatorNetsent,OperatorPaged,RetriesAttempted -Unique | export-excel -Path 'C:\Job Failure Reports\Initial Report.xlsx'
