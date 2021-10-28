###################################################################################################################################################
##  This Script Checks The warehouse_sentinal Table on BINNWLMK01 to see if the status DM2 is present indicating the Pegasus load has completed  ##
###################################################################################################################################################

import-module dbatools

$query = "select * from dbo.warehouse_sentinal Where update_status = 'DM2' and access_code Is NULL"
$Server = '192.168.31.22'
$Database = 'Warehouse'

$UpdateStatus = invoke-sqlcmd -ServerInstance $Server -Database $Database -Query $Query | select -ExpandProperty update_status


If ($UpdateStatus -eq '')
    {
    THROW "Pegasus Dataload Has Not Completed In A Timely Manner.  Check For Errors."
    }
ELSE
    {
    write-host "Pegasus Dataload Has Completed"
    }


 