#invoke-sqlcmd -ServerInstance mmcvsrvrd01 -Database dba_mon -query "Select * from ADUsers where surname = 'Maskey'"


$Servers = Invoke-Sqlcmd -ServerInstance mmcvsrvrd01 -Database DBA_MON -query "select server_name from ServersToMonitor WHERE Instance_Name = 'MSSQLSERVER'" | select -ExpandProperty server_name 


foreach ($server in $servers)  ### Check for connectivity ###
    {
        $connections = Test-NetConnection  -ComputerName $server -OutVariable $result -WarningAction SilentlyContinue | select ComputerName, PingSucceeded | ?{$_.PingSucceeded -eq $true}

    foreach ($connection in $connections)
        {
            $DefaultLog = invoke-sqlcmd -ServerInstance $connection.ComputerName -query "(SELECT CAST ((SELECT TOP 1 f.[value] FROM    sys.fn_trace_getinfo(NULL) f WHERE   f.property = 2 ) AS VARCHAR(300)))"
            $DefaultLog
        }
    }
