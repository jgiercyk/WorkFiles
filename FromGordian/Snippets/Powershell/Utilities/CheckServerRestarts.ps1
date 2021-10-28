<#
This script queries the DBA_MON database to get a list of DEV, PPD, and PRD servers, and pings them using the IP address
It then reports the last time the servers were restarted in a grid view

#>
	
$Restarttable = New-Object System.Data.DataTable
$Restarttable.Columns.Add("ServerName","String") | out-null
$Restarttable.Columns.Add("User","String") | out-null
$Restarttable.Columns.Add("Time","String") | out-null
$Restarttable.Columns.Add("Message","String") | out-null


$serverQuery =
@"
SELECT [Server_Name]
      ,[Qualified_Name]
      ,[IP_Address]
  FROM [DBA_Mon].[dbo].[Server_List]
  where environment in ('Production','Development','PPD')
  AND Server_Name not like '%USPS%'
"@

$Servers = Invoke-Sqlcmd -Query $serverQuery -Database DBA_MON -ServerInstance GVL-SQL-TGGDBA
$RestartList = $null
$RestartList = @{}

write-host 'Testing connectivity'
foreach ($server in $Servers)
{
$s = $server | select -ExpandProperty Server_Name
$i = $server | select -ExpandProperty IP_Address
    if(!(Test-Connection -Cn $i -BufferSize 16 -Count 2 -ea 0 -quiet))
        { write-host $s ' FAILED TO CONNECT USING IP.'  $s 'WILL NOT BE USED.' -BackgroundColor Red
        }
    else 
    {
        write-host 'Server' $s 'connected successfully' -ForegroundColor Green
        $r = $Restarttable.NewRow()
        $result = gwmi win32_ntlogevent -ComputerName $i  -filter "LogFile='System' and EventCode='1074' and Message like '%restart%'"  | 	select -first 1  PSComputerName, User,@{n="Time";e={$_.ConvertToDateTime($_.TimeGenerated)}}, message 
        $r.ServerName = $result.PSComputerName
        $r.User = $result.User
        $r.Time = $result.Time
        $r.message = $result.message
        $Restarttable.Rows.Add($r)
    }
}

$Restarttable | select servername,user,time,message | out-gridview

BREAK
