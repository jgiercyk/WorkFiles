<#
This script creates a table containing the permissions for Windows Group logins.  
Table is dba.dba.ADGroupPermissions
#>



import-module dbatools

$targetServer = 'localhost'
$BuildTable =
@"
USE [dba]

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ADGroupPermissions]') AND type in (N'U'))
DROP TABLE [dbo].[ADGroupPermissions]

CREATE TABLE [dbo].[ADGroupPermissions](
	[ADGroup] [varchar](50) NULL,
	[Database] [varchar](50) NULL,
	[Type] [varchar](50) NULL
) ON [PRIMARY]
"@

TRY
    {
    Write-Host 'Building Table' dba.dbo.ADGroupPermissions -ForegroundColor Yellow
    invoke-sqlcmd -Query $BuildTable -ServerInstance $targetServer -Database dba
    }
CATCH
    {
    write-host 'Error occurred building table' dba.dbo.ADGroupPermissions -ForegroundColor Red
    write-host $ERROR[0] -ForegroundColor red
    CONTINUE
    }

$InsertValues =
@"
USE [dba]

INSERT INTO [dbo].[ADGroupPermissions]
           ([ADGroup]
           ,[Database]
           ,[Type])

"@


$Groups = get-dbalogin -SqlInstance $targetServer | ?{$_.LoginType -eq 'WindowsGroup'} | select -ExpandProperty name
$firstRecord = 1

TRY
    {
    foreach($group in $groups)
        {
          Write-Host 'Creating Records For Group' $group -ForegroundColor yellow
          $logins = get-dbadbrolemember -SqlInstance $targetServer | ?{$_.UserName -eq $Group} | select username, database, role # | out-gridview
          foreach($login in $logins)
           {
            IF($firstRecord -eq 1)
            {
               $InsertValues = $InsertValues + " (SELECT '" + $login.username + "','"+ $login.database + "','" + $login.role + "') "
               $firstRecord = 0
            }
            ELSE
            {
               $InsertValues = $InsertValues + " UNION (SELECT '" + $login.username + "','"+ $login.database + "','" + $login.role + "') "
            }
           }
  
        }
    }
CATCH
    {
    Write-Host 'Error creating records for group' $login.username -ForegroundColor Red
    Write-Host $ERROR[0] -ForegroundColor red
    CONTINUE
    }

invoke-sqlcmd -query $InsertValues -ServerInstance $targetServer -Database dba
