$Server = 'AZURE-PRD-SQL05'   #"10.90.1.8"
IMPORT-MODULE -name SQLPS -DisableNameChecking

########################################
###  Create datatable of PROD users  ###
########################################

$ProdServer = new-object ('microsoft.sqlserver.management.smo.server') $server
$ProdLogins = $ProdServer.Logins.name

###################
##  FIX  OPHANS  ##
###################

foreach ($database in $prodserver.Databases)
{
$db = $database.Name.ToString() 
$ProdSchemas = $database.Schemas.name 

    foreach ($user in $database.users | select name, login | where{$_.name -in $ProdLogins -and $_.login -eq ""})  # Orphaned user with login
    {
    $sqlcmd = "USE " + $db + " EXEC sp_change_users_login 'Auto_Fix','" + $user.name + "'"
    "NOW EXECUTING: " + $sqlcmd
    invoke-sqlcmd -query $sqlcmd -serverinstance $Server 
    }

}