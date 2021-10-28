###################################### [fact].[Coverage Detail Snapshot] ###############################################
$csv1 = Import-Csv -path "C:\Scripts\APP-5616_Table1a.csv"    ####  NEED FILENAME HERE  ####
$key1 = 'CoverageDetailSnapshotID'

foreach($line in $csv1)
{ 
    $updates = ($line | gm -MemberType NoteProperty | ?{$_.Definition -notlike '*UPDATE=*' -and $_.Definition -notlike '*'+$key1+ '*'} | select -ExpandProperty Definition) -replace "string ",""

    $sqlupdates = 'UPDATE [fact].[Coverage Detail Snapshot] SET '

        foreach($update in $updates)
        {
         $sqlupdates = $sqlupdates + '[' + ($update -replace "=","]=") + ','
        }
    $sqlupdates = $sqlupdates.substring(0,($Sqlupdates.length - 1))
    $sqlupdates = $sqlupdates + " WHERE [" + $key1 + "] = " + $line.CoverageDetailSnapshotID 
    $sqlupdates
} 

###################################### [fact].[Coveage Transaction] ###############################################
$csv2 = Import-Csv -path "C:\Scripts\APP-5616_Table2.csv"   ####  NEED FILENAME HERE  ####
$key2 = 'CoverageTransactionId'

foreach($line in $csv2)
{ 
    $updates = ($line | gm -MemberType NoteProperty | ?{$_.Definition -notlike '*UPDATE=*' -and $_.Definition -notlike '*'+$key2+ '*'} | select -ExpandProperty Definition) -replace "string ",""

    $sqlupdates = 'UPDATE [fact].[Coverage Transaction] SET '

        foreach($update in $updates)
        {
         $sqlupdates = $sqlupdates + '[' + ($update -replace "=","]=") + ','
        }
    $sqlupdates = $sqlupdates.substring(0,($Sqlupdates.length - 1))
    $sqlupdates = $sqlupdates + " WHERE [" + $key2 + "] = " + $line.CoverageTransactionId 
    $sqlupdates
} 

####################################### [fact].[Policy Summary Snapshot] ################################################# 
$csv3 = Import-Csv -path "C:\Scripts\APP-5616_Table3.csv"   ####  NEED FILENAME HERE  ####
$key3 = 'PolicySummarySnapshotID'

foreach($line in $csv3)
{ 
    $updates = ($line | gm -MemberType NoteProperty | ?{$_.Definition -notlike '*UPDATE=*' -and $_.Definition -notlike '*'+$key3+ '*'} | select -ExpandProperty Definition) -replace "string ",""

    $sqlupdates = 'UPDATE [fact].[Policy Summary Snapshot] SET '

        foreach($update in $updates)
        {
         $sqlupdates = $sqlupdates + '[' + ($update -replace "=","]=") + ','
        }
    $sqlupdates = $sqlupdates.substring(0,($Sqlupdates.length - 1))
    $sqlupdates = $sqlupdates + " WHERE [" + $key3 + "] = " + $line.PolicySummarySnapshotID
    $sqlupdates
} 