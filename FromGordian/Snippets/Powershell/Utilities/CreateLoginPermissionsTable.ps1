import-module dbatools

$targetServer = 'localhost'
$BuildTable =
@"
USE [dba]

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LoginPermissions]') AND type in (N'U'))
DROP TABLE [dbo].[LoginPermissions]

CREATE TABLE [dbo].[LoginPermissions](
	[Login] [varchar](50) NULL,
	[Database] [varchar](50) NULL,
	[Role] [varchar](50) NULL
) ON [PRIMARY]
"@


TRY
    {
    Write-Host 'Building Table' dba.dbo.LoginPermissions -ForegroundColor Yellow
    invoke-sqlcmd -Query $BuildTable -ServerInstance $targetServer -Database dba
    }
CATCH
    {
    write-host 'Error occurred building table' dba.dbo.LoginPermissions -ForegroundColor Red
    write-host $ERROR[0] -ForegroundColor red
    CONTINUE
    }

$Logins = get-dbalogin -SqlInstance $targetServer | ?{$_.LoginType -ne 'WindowsGroup'} | select -ExpandProperty name
$firstRecord = 1

TRY
    {
    foreach($login in $logins)
        {
         $roles = get-dbadbrolemember -SqlInstance $targetServer | ?{$_.username -eq $login} | select username, database, role # | out-gridview
         foreach($role in $roles)
             {
$InsertRecord = 
@"
USE [dba]
GO

INSERT INTO [dbo].[LoginPermissions]
           ([Login]
           ,[Database]
           ,[Role])
     VALUES
           ('$($role.username)',
           '$($role.database)',
           '$($role.role)')
GO
"@
              invoke-sqlcmd -ServerInstance $targetServer -Database dba -Query $InsertRecord
              $InsertRecord
             }
        }
    }
CATCH
    {
    Write-Host 'Error inserting records for ' $role.username -ForegroundColor Red
    Write-Host $ERROR[0] -ForegroundColor red
    CONTINUE
    }
