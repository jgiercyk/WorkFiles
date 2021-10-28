import-module dbatools -DisableNameChecking -ErrorAction SilentlyContinue

$failedJobs = @()

$servers = invoke-sqlcmd -ServerInstance mmcvsrvrd01 -Database dba -Query "select Server_Name from ServersToMonitor where monitor = 1" | select -ExpandProperty Server_Name
foreach ($server in $servers)
    {
    $jobs = Get-DbaAgentJob -SqlInstance $server | ?{$_.IsEnabled -eq $true} |   select -expandproperty name 
    $failures = (Get-DbaAgentJobHistory -SqlInstance $server | ?{$_.job -in $jobs -and $_.status -ne 'Succeeded' -and $_.stepid -eq 0})
    $failedJobs = $FailedJobs + $failures
    }

$jobsFromServerHistory = $failedJobs | select ComputerName,InstanceName,JobName,RunDate,Duration,Status,InstanceID,Message,OperatorEmailed,OperatorNetsent,OperatorPaged,RetriesAttempted -Unique


$SelectQuery =
@"
SELECT [ComputerName]
      ,[InstanceName]
      ,[JobName]
      ,[RunDate]
      ,[Duration]
      ,[Status]
      ,[InstanceID]
      ,[Message]
      ,[OperatorEmailed]
      ,[OperatorNetsent]
      ,[OperatorPaged]
      ,[RetriesAttempted]
  FROM [DBA_MON].[dbo].[JobFailures]
"@

$InsertQuery =
@"
INSERT INTO [DBA_MON].[dbo].[JobFailures]           
VALUES    ('$ComputerName',
           '$InstanceName',
           '$JobName',
           '$RunDate',
           '$Duration',
           '$Status',
           $InstanceID,
           '$Message',
           '$OperatorEmailed',
           '$OperatorNetsent',
           '$OperatorPaged',
           '$RetriesAttempted',
           '0')
"@

$jobsFromTable = Invoke-Sqlcmd -ServerInstance mmcvsrvrd01 -Query $SelectQuery


    foreach ($job in $jobsFromServerHistory)
    {
        $ComputerName = $job.ComputerName
        $InstanceName = $job.InstanceName
        $JobName = $job.JobName
        $RunDate = $job.RunDate
        $Duration = $job.Duration
        $Status  = $job.Status
        $InstanceID = $job.InstanceID
        $Message = $job.Message
        $OperatorEmailed = $job.OperatorEmailed
        $OperatorNetsent = $job.OperatorNetsent
        $OperatorPaged = $job.OperatorPaged
        $RetriesAttempted = $job.RetriesAttempted

        $exists = (Invoke-Sqlcmd -ServerInstance mmcvsrvrd01 -query "SELECT '1' FROM [DBA_MON].[dbo].[JobFailures] where instanceid = $instanceId and ComputerName = '$ComputerName'") | select Column1
        if ($exists.column1 -ne 1) 
            {
                $InsertQuery = "INSERT INTO [DBA_MON].[dbo].[JobFailures] VALUES ('$ComputerName','$InstanceName','$JobName','$RunDate','$Duration','$Status',$InstanceID,'$Message','$OperatorEmailed','$OperatorNetsent','$OperatorPaged','$RetriesAttempted','0')"
                Invoke-Sqlcmd -ServerInstance mmcvsrvrd01 -Query $InsertQuery
            }
    }



