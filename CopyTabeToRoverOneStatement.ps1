import-module dbatools

Invoke-Sqlcmd -ServerInstance mmcvsssisq01.ormutual.com -Database homeowner -Username 'sql-rover-qa' -Password 'PU.@{]CGjdJKKq4h' -query 'TRUNCATE TABLE UploadUnderwritingRules_test2'

$Recs = invoke-sqlcmd -ServerInstance '(localdb)\MainframeTest' -Database homeowner -query 'SELECT top 5000 * from UploadUnderwritingRules_test2'
$RecordCounter = 1

$InsertCmd = 'INSERT INTO [dbo].[UploadUnderwritingRules_test2]'
foreach ($rec in $recs)
{
$a =        $rec.COMPANY
$b =        $rec.POLICY
$c =        $rec.EXPIRATION_DATE
$d =        $rec.EFFECTIVE_DATE
$e =        $rec.AMEND_DATE
$f =        $rec.OPERATOR_ID
$g =        $rec.A_DATE
$h =        $rec.A_TIME
$i =        $rec.BLZ_CALLTYPE
$j =        $rec.BLZ_CALLGROUP
$k =        $rec.BLZ_MSG_FINAL
$l =        $rec.BLZ_MSG_RULESET
$m =        $rec.BLZ_MSG_RULE
$n =        $rec.BLZ_MSG_TYPE
$o =        $rec.BLZ_MSG_REAS_NO
$p =        $rec.BLZ_MSG_TASK_NO
$q =        $rec.BLZ_MSG_ASSOC
$r =        $rec.MISC1
$s =        $rec.MISC2
$t =        $rec.MISC3
$u =        $rec.MISC4
$v =        $rec.MISC5_DATE
$w =        $rec.MISC6_DATE
$x =        $rec.MISC7_DATE

$InsertCmd =  $Insertcmd + ' ' +

@"
SELECT
        '$a','$b','$c','$d','$e','$f','$g','$h','$i','$j','$k','$l','$m','$n','$o','$p','$q','$r','$s','$t','$u',$v,$w,$x UNION
"@

#Invoke-Sqlcmd -ServerInstance mmcvsssisq01.ormutual.com -Database homeowner -Username 'sql-rover-qa' -Password 'PU.@{]CGjdJKKq4h' -query $InsertCmd



#$RecordCounter = $RecordCounter + 1
#$RecordCounter

}

$InsertCmd = $insertCmd.substring(0,$InsertCmd.length-5)

Add-Content $InsertCmd -path 'C:\Packages\SqlCmd5000.sql'

'Starting Insert'
$starttime = get-date 

Invoke-Sqlcmd -ServerInstance mmcvsssisq01.ormutual.com -Database homeowner -Username 'sql-rover-qa' -Password 'PU.@{]CGjdJKKq4h' -inputfile 'C:\Packages\SqlCmd5000.sql' -QueryTimeout 0

'Insert complete'
'Start time: ' 
 $starttime
'End time: ' 
Get-Date