import-module dbatools

$targetServer = 'localhost'

$GroupMembers = find-dbaloginingroup -SqlInstance $targetServer | select  memberof, login

$BuildTable = 
@"
USE [dba]
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ADGroupUsers]') AND type in (N'U'))
DROP TABLE [dbo].[ADGroupUsers]

CREATE TABLE [dbo].[ADGroupUsers](
	ADGroup [varchar](200) NULL,
	[User] [varchar](200) NULL
) ON [PRIMARY]
"@

Invoke-Sqlcmd -ServerInstance $targetServer -Database dba -Query $BuildTable

foreach ($member in $GroupMembers)
    {
    $memberof = $member.Memberof
    $userlogin = $member.Login
    $InsertRecord =
@"

INSERT INTO [dbo].[ADGroupUsers]
           ([ADGroup]
           ,[User])
     VALUES
           ('$memberof',
           '$userlogin')
"@
$InsertRecord
 Invoke-Sqlcmd -Query $InsertRecord -Database dba -ServerInstance $targetServer

    }
