import-module dbatools -DisableNameChecking
Import-Module sqlserver -DisableNameChecking

$servername = 'mmcvsdb01\WEBSRV'
$targetDatabase = 'dba'


$databases = get-dbadatabase -SqlInstance $servername | select -ExpandProperty name
$WindowsUsers = Get-DbaDbRoleMember -SqlInstance $servername  |  ?{$_.LoginType -eq 'WindowsUser'} | select Sqlinstance,Database,Role,Username, Login 
$WindowsGroups = Get-DbaDbRoleMember -SqlInstance $servername  |  ?{$_.LoginType -eq 'WindowsGroup'} | select Sqlinstance,Database,Role,Username, Login 

$TableSQL=
@"
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GroupMembers]') AND type in (N'U'))
DROP TABLE [dbo].[GroupMembers]

CREATE TABLE [dbo].[GroupMembers](
	[UserName] [varchar](50) NULL,
	[type] [varchar](50) NULL,
	[privilege] [varchar](50) NULL,
	[LoginName] [varchar](50) NULL,
	[WindowsGroup] [varchar](50) NULL
) ON [PRIMARY]

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[WindowsGroups]') AND type in (N'U'))
DROP TABLE [dbo].[WindowsGroups]

CREATE TABLE [dbo].[WindowsGroups](
	[Server] [varchar](50) NULL,
	[DatabaseName] [varchar](50) NULL,
	[DatabaseRole] [varchar](50) NULL,
	[UserName] [varchar](50) NULL,
	[LoginName] [varchar](50) NULL
) ON [PRIMARY]

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[WindowsUsers]') AND type in (N'U'))
DROP TABLE [dbo].[WindowsUsers]

CREATE TABLE [dbo].[WindowsUsers](
	[Server] [varchar](50) NULL,
	[DatabaseName] [varchar](50) NULL,
	[DatabaseRole] [varchar](50) NULL,
	[UserName] [varchar](50) NULL,
	[LoginName] [varchar](50) NULL
) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseConnections]') AND type IN (N'U'))
BEGIN
CREATE TABLE [dbo].[DatabaseConnections](
	[process] [SMALLINT] NOT NULL,
	[database] [sysname] NOT NULL,
	[sql statement] [TEXT] NULL,
	[host name] [NVARCHAR](128) NULL,
	[program_name] [NVARCHAR](128) NULL,
	[host process id] [INT] NULL,
	[login name] [NVARCHAR](128) NOT NULL,
	[login time] [DATETIME] NOT NULL,
	[CollectionDate] [DATETIME] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO
"@
invoke-sqlcmd -ServerInstance $servername -Query $TableSQL -Database $targetDatabase 


foreach ($user in $WindowsUsers)
    {
    $s = $user.SqlInstance
    $db = $user.Database
    $dr = $user.Role
    $u = $user.UserName
    $l = $user.Login
    $sqlcmd = "INSERT INTO [dbo].[WindowsUsers] SELECT '" + $s + "','" + $db + "','" + $dr + "','" + $u + "','" + $l + "'"
    invoke-sqlcmd -ServerInstance $servername -Query $sqlcmd -Database $targetDatabase 
    }

foreach ($group in $WindowsGroups)
    {
    $s = $group.SqlInstance
    $db = $group.Database
    $dr = $group.Role
    $u = $group.UserName
    $l = $group.Login
    $sqlcmd = "INSERT INTO [dbo].[WindowsGroups] SELECT '" + $s + "','" + $db + "','" + $dr + "','" + $u + "','" + $l + "'"
    invoke-sqlcmd -ServerInstance $servername -Query $sqlcmd -Database $targetDatabase 
    }


$sqlcmd = "SELECT DISTINCT LoginName FROM [dbo].[WindowsGroups]"
$ADgroups = invoke-sqlcmd -ServerInstance $servername -query $sqlcmd -database $targetDatabase | select -ExpandProperty LoginName

foreach ($ADgroup in $ADGroups)
    {
    $sqlcmd = "EXEC xp_logininfo @acctname = '" + $ADgroup + "', @option = 'members'"
    $members = Invoke-Sqlcmd -ServerInstance $servername -Query $sqlcmd -Database $targetDatabase 
    foreach ($member in $members)
        {
        $a = $member.{account name}
        $t = $member.{type}
        $p = $member.{privilege}
        $l = $member.{mapped login name}
        $p = $member.{permission path}
        $sqlcmd = "INSERT INTO [dbo].[GroupMembers] SELECT '" + $a + "','" + $t + "','" + $p + "','" + $l + "','" + $p + "'"
        Invoke-Sqlcmd -ServerInstance $servername -Query $sqlcmd -Database $targetDatabase 
        }
    }
