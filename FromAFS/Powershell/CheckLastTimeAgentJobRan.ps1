param($interval,$jobname)   ###  MUST BE THE FIRST LINE OF THE SCRIPT
<#
$interval - the number of minutes between scheduled jobs.  It is recommended that you add an extra minute to avoid job overlap.
$jobname - the name of the job to check the schedule

If the last run date is less than the current datetime - interval. the script will throw an error
#>

import-module dbatools

############   CHECK PARAMETER VALUES
if ($interval -eq $null)
    {Throw 'INTERVAL PARAMETER CANNOT BE NULL.  Invalid parameter passed to script. Use the -interval parameter to indicate the time between scheduled runs in minutes'
    'Interval is invalid'}

if ($interval -isnot [int])
    {THROW 'INTERVAL MUST BE A NUMERIC VALUE. Use the -interval parameter to indicate the time between scheduled runs in minutes'}

if ($jobname -eq $null)
    {Throw 'JOBNAME PARAMETER CANNOT BE NULL.  Invalid parameter passed to script. Use the -jobname parameter to indicate the name of the job to check'
    'Jobname is invalid'}

$ValidJobNames = Get-DbaAgentJob -SqlInstance localhost | select -ExpandProperty Name
IF ($jobname -notin $ValidJobNames)
    {THROW 'JOBNAME PARAMETER IS NOT A VALID JOBNAME ON THIS SERVER.'}

#############   SCRIPT BEGINS HERE
$LastRunDate = Get-SqlAgentJobHistory -ServerInstance localhost -JobName $jobname | Sort-Object -property RunDate -Descending | ?{$_.StepID -eq 0} | select -ExpandProperty rundate -first 1
$ExpectedRunDate = (Get-Date).AddMinutes($Interval*-1)

'Job Name: ' + $jobname
'Last Run Date: ' + $LastRunDate 
'Current datetime minus interval: ' + $ExpectedRunDate

IF ($LastRunDate -le $ExpectedRunDate)
    {THROW 'ERROR: JOB HAS NOT RUN ON SCHEDULE.'}
ELSE
    {'Job is running on schedule.'}

RETURN
 