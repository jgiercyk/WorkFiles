<#
This script queries the DBA_MON database to get a list of DEV, PPD, and PRD servers, and pings them using the IP address

#>

$serverQuery =
@"
SELECT [Server_Name]
      ,[Qualified_Name]
      ,[IP_Address]
  FROM [DBA_Mon].[dbo].[Server_List]
  where environment in ('Production','Development','PPD')
"@

$Servers = Invoke-Sqlcmd -Query $serverQuery -Database DBA_MON -ServerInstance GVL-SQL-TGGDBA

foreach ($server in $Servers)
{
$s = $server | select -ExpandProperty Server_Name
$i = $server | select -ExpandProperty IP_Address
    if(!(Test-Connection -Cn $i -BufferSize 16 -Count 2 -ea 0 -quiet))
        { write-host $s ' FAILED TO CONNECT USING IP' -BackgroundColor Red
        }
    else 
    {
        write-host 'Server' $s 'connected successfully' -ForegroundColor Green
    }
}

