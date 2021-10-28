import-module dbatools

$servername = 'PLA-SQLPCN1-01','PLA-SQLPCN1-02','PLA-SQLPCN1-03','PLA-SQLPCN1-04','PLA-SQLPCN1-05','PLA-SQLPS3-DB'

foreach ($s in $servername)
{
TRY {
    $time = get-date -format "MM/dd/yyyy HH:mm:ss"
    $sqlcmd =
@"
SELECT '$s' 'Server',
       '$time' 'CollectionTime',
       p.spid  'Process',
       db.NAME 'Database',
	   c.login_name 'Login Name',
       c.host_name 'Host Name',
	   c.program_name,
       c.login_time 'Login Time' 
FROM   sys.sysprocesses p
       JOIN sys.databases db
         ON p.dbid = db.database_id
       JOIN sys.dm_exec_sessions c
         ON p.spid = c.session_id
WHERE  spid > 50
AND (c.login_name LIKE '%TRENDSETINC%' OR c.login_name LIKE '%AFSLOGISTICS%')
AND  c.login_name NOT IN ('AFSLOGISTICS\SW_DPA',
                        'AFSLOGISTICS\jgiercyk',
                        'TRENDSETINC\ediuser',
                        'AFSLOGISTICS\sa_AutoGLCoder',
                        'AFSLOGISTICS\tmswebsites',
                        'AFSLOGISTICS\TFSServices',
                        'AFSLOGISTICS\sa_autorating',
                        'AFSLOGISTICS\sa_GvlEDILoader',
                        'AFSLOGISTICS\sa_GvlDownloader')
AND c.program_name NOT LIKE '%Management Studio%'
AND c.host_name <> @@SERVERNAME
"@

    $connections = Invoke-Sqlcmd -query $sqlcmd -ServerInstance $s 

            foreach ($c in $connections)
            {
                $ser = $c.server
                $ct = $c.CollectionTime
                $pr = $c.Process
                $db = $c.Database
                $ln = $c.'Login Name'
                $hn = $c.'Host Name'
                $pgm = $c.program_name
                $lt = $c.'Login Time'

        $InsertCmd =
@"
IF NOT EXISTS (SELECT 1 FROM ServerConnections WHERE process = $pr AND [Login Time] = '$lt')
INSERT INTO ServerConnections
VALUES('$ser','$ct','$pr','$db','$ln','$hn','$pgm','$lt')

"@
        invoke-sqlcmd -ServerInstance 'PLAGVLPRDSSIS01' -database SQLDBA_DATA -query $InsertCmd

        }
    }
CATCH 
    {
    $err = 1 
    'ERROR HAS OCCURRED'
    'Server: ' + $s
    'ERROR: ' + $ERROR[0]
    ''
    CONTINUE
    }
}

if ($err -gt 0)   #  If there were errors we want to stop a SQL Agent job if it is running the script
    {
        THROW 'Job ended with errors. '
    }



