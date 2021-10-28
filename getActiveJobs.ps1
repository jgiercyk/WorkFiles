import-module dbatools -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

$MonitoringServer = 'MMCVSRVRD01'
$MonitoringDatabase = 'DBA_MON'
$Prodservers = invoke-sqlcmd -ServerInstance $MonitoringServer -Database $MonitoringDatabase -Query "select Server_Name from ServersToMonitor where monitor = 1" | select -ExpandProperty Server_Name
#$ProdServers = 'mmcvsrvrd01' 

$ActiveJobs = Get-DbaRunningJob -SqlInstance $Prodservers  | select ComputerName,JobID,Name   ##  Jobs currently active

$ActiveJobsOnTable = Invoke-Sqlcmd -ServerInstance $MonitoringServer -Database $MonitoringDatabase -Query "SELECT ComputerName,JobId,JobName FROM ActiveJobs" ## Jobs that were on the ActiveJobs table last time this script ran

##  Check if the jobs on the ActiveJobs table have completed  ##
Foreach ($tableJob in $ActiveJobsOnTable)
    {
        $tcn = $tableJob.ComputerName
        $tji = $tableJob.jobid
        $tn = $tableJob.name

        IF ($tji -notin $ActiveJobs.JobID)   ##  If the job is on the ActiveJobs table but it has completed since the last run, delete it from the table
            {

                "DELETE FROM ActiveJobs WHERE JobID = '" + $tji + "'"
           }
    }


##  Insert new and update the duration of existing active jobs  ##
foreach ($job in $ActiveJobs)
    {
        $cn = $job.ComputerName
        $ji = $job.jobid
        $n = $job.name
        $startDate = invoke-sqlcmd -ServerInstance $cn -Query ("select start_execution_date from msdb.dbo.sysjobactivity where start_execution_date is not null and stop_execution_date is null and job_id = '" + $ji + "'") | SELECT -ExpandProperty start_execution_date
        $duration = Invoke-Sqlcmd -ServerInstance $MonitoringServer -Database $MonitoringDatabase -query ("select [dbo].[fn_getActiveJobDuration]('" + $startDate.tostring('MM/dd/yyyy HH:mm:ss') + "')") | select -ExpandProperty Column1
        $recordCount = Invoke-Sqlcmd -ServerInstance $MonitoringServer -database $MonitoringDatabase -Query ("select count(*) from [dbo].[ActiveJobs] WHERE  StartDate = '" + $startDate + "' and jobid = '" + $ji + "'") | select -expandproperty Column1
        
        IF ($recordCount -gt 0)
            {    #  UPDATE

                Invoke-Sqlcmd -ServerInstance $MonitoringServer -Database $MonitoringDatabase -Query ("UPDATE [dbo].[ActiveJobs] SET [Duration] = " + $duration + " WHERE ComputerName = '" + $cn + "' AND JobID = '" + $ji + "' AND StartDate = '" + $startDate + "'")
            }
            else
            {    #  INSERT
                Invoke-Sqlcmd -ServerInstance $MonitoringServer -Database $MonitoringDatabase -Query ("INSERT INTO [dbo].[ActiveJobs] VALUES('$cn','$ji','$n','$startDate',$duration,'0')")

            }
        
    }
    



