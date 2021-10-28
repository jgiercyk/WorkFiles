import-module dbatools
import-module importexcel

###  This script collects the duration of all jobs that run on PROD servers and saves them to [DBA_MON].[dbo].[JobRunTimes] ###

$servers = invoke-sqlcmd -ServerInstance mmcvsrvrd01 -Database dba -Query "select Server_Name from ServersToMonitor where monitor = 1" | select -ExpandProperty Server_Name

foreach ($server in $Servers)
{
    $jobs = Get-DbaAgentJob -SqlInstance $server | ?{$_.IsEnabled -eq $true -and $_.category -ne 'Report Server'} |  select name -Unique |  select -expandproperty name
    $jobhistory = Get-DbaAgentJobHistory -SqlInstance $Server | ?{$_.stepid -eq 0 -and $_.JobName -in $Jobs} | select ComputerName, SqlInstance,JobName, InstanceID, RunDate, Duration, RunDuration, Status  | ?{$_.status -eq 'Succeeded'} 

    foreach ($job in $jobhistory)
        {
            $srv = $job.computername
            $si = $job.SqlInstance
            $jn = $job.jobname
            $i = $job.instanceID
            $rdte = $job.RunDate 
            $d = $job.Duration 
            $rd = $job.RunDuration
            $st = $job.Status 
            $exists = (Invoke-Sqlcmd -ServerInstance mmcvsrvrd01 -Database DBA_MON -Query "SELECT '1'  FROM [DBA_MON].[dbo].[JobRunTimes] WHERE [ComputerName] = '$srv' AND [JobName] = '$jn' AND [InstanceID] = $i" | select -ExpandProperty Column1)
            if ($exists -ne '1')
                {
                    Invoke-Sqlcmd -ServerInstance mmcvsrvrd01 -Database DBA_MON -Query "INSERT [dbo].[JobRunTimes] SELECT [ComputerName]='$srv',SqlInstance='$si',JobName='$jn',InstanceID=$i,RunDate='$rdte',Duration='$d',RunDuration=$rd,Status='$st'"
                }
        }

}



