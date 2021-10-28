import-module dbatools
Import-Module sqlserver

$servername = 'mmcvsrvrp01'

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

"@
invoke-sqlcmd -ServerInstance $servername -Query $TableSQL -Database master


foreach ($user in $WindowsUsers)
    {
    $s = $user.SqlInstance
    $db = $user.Database
    $dr = $user.Role
    $u = $user.UserName
    $l = $user.Login
    $sqlcmd = "INSERT INTO [dbo].[WindowsUsers] SELECT '" + $s + "','" + $db + "','" + $dr + "','" + $u + "','" + $l + "'"
    invoke-sqlcmd -ServerInstance $servername -Query $sqlcmd -Database master
    }

foreach ($group in $WindowsGroups)
    {
    $s = $group.SqlInstance
    $db = $group.Database
    $dr = $group.Role
    $u = $group.UserName
    $l = $group.Login
    $sqlcmd = "INSERT INTO [dbo].[WindowsGroups] SELECT '" + $s + "','" + $db + "','" + $dr + "','" + $u + "','" + $l + "'"
    invoke-sqlcmd -ServerInstance $servername -Query $sqlcmd -Database master
    }


$sqlcmd = "SELECT DISTINCT LoginName FROM [dbo].[WindowsGroups]"
$ADgroups = invoke-sqlcmd -ServerInstance $servername -query $sqlcmd -database master | select -ExpandProperty LoginName

foreach ($ADgroup in $ADGroups)
    {
    $sqlcmd = "EXEC xp_logininfo @acctname = '" + $ADgroup + "', @option = 'members'"
    $members = Invoke-Sqlcmd -ServerInstance $servername -Query $sqlcmd -Database master
    foreach ($member in $members)
        {
        $a = $member.{account name}
        $t = $member.{type}
        $p = $member.{privilege}
        $l = $member.{mapped login name}
        $p = $member.{permission path}
        $sqlcmd = "INSERT INTO [dbo].[GroupMembers] SELECT '" + $a + "','" + $t + "','" + $p + "','" + $l + "','" + $p + "'"
        Invoke-Sqlcmd -ServerInstance $servername -Query $sqlcmd -Database master
        }
    }
