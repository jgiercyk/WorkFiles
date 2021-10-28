import-module dbatools

$monitoringServer = 'mmcvsrvrd01'
$monitoringDatabase = 'DBA_MON'

$users = get-aduser -filter *

$TableQuery =
@"
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ADUsers]') AND type IN (N'U'))
DROP TABLE [dbo].[ADUsers]

CREATE TABLE [dbo].[ADUsers](
	[DistinguishedName] [NVARCHAR](150) NOT NULL,
	[Enabled] [BIT] NOT NULL,
	[GivenName] [NVARCHAR](150) NULL,
	[Name] [NVARCHAR](150) NOT NULL,
	[ObjectClass] [NVARCHAR](150) NOT NULL,
	[ObjectGUID] [NVARCHAR](150) NOT NULL,
	[SamAccountName] [NVARCHAR](150) NOT NULL,
	[SID] [NVARCHAR](150) NOT NULL,
	[Surname] [NVARCHAR](150) NULL,
	[UserPrincipalName] [NVARCHAR](150) NULL
) ON [PRIMARY]
"@
Invoke-Sqlcmd -ServerInstance $monitoringServer -Database $monitoringDatabase -Query $TableQuery

foreach ($user in $users)
    {

$UserQuery =
@"
INSERT INTO [dbo].[ADUsers]
           ([DistinguishedName]
           ,[Enabled]
           ,[GivenName]
           ,[Name]
           ,[ObjectClass]
           ,[ObjectGUID]
           ,[SamAccountName]
           ,[SID]
           ,[Surname]
           ,[UserPrincipalName])
     VALUES
           ('$($user.DistinguishedName)'
           ,'$($user.ENABLED)'
           ,'$($user.GivenName)'
           ,'$($uer.NAME)'
           ,'$($user.ObjectClass)'
           ,'$($user.ObjectGUID)'
           ,'$($user.SamAccountName)'
           ,'$($user.SID)'
           ,'$($user.Surname)'
           ,'$($user.UserPrincipalName)')


"@
    Invoke-sqlcmd -ServerInstance $monitoringServer -Database DBA_MON -Query $UserQuery
    
    }
