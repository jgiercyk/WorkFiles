$monitoringServer = 'mmcvsrvrd01'
$monitoringDatabase = 'DBA_MON'

$Groups = get-adgroup -Filter * 

$TableQuery = 
@"
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ADGroups]') AND type IN (N'U'))
DROP TABLE [dbo].[ADGroups]

CREATE TABLE [dbo].[ADGroups](
	[DistinguishedName] [NVARCHAR](500) NOT NULL,
	[GroupCategory] [NVARCHAR](50) NOT NULL,
	[GroupScope] [NVARCHAR](50) NOT NULL,
	[Name] [NVARCHAR](100) NOT NULL,
	[ObjectClass] [NVARCHAR](100) NOT NULL,
	[ObjectGUID] [NVARCHAR](50) NOT NULL,
	[SamAccountName] [NVARCHAR](100) NOT NULL,
	[SID] [NVARCHAR](50) NOT NULL
) ON [PRIMARY]
"@
## Rebuild Table
invoke-sqlcmd -ServerInstance $monitoringServer -Database $monitoringDatabase -Query $TableQuery

foreach ($group in $groups)
{
    $1 = "'" + $group.DistinguishedName + "'"
    $2 = "'" + $group.GroupCategory + "'"
    $3 = "'" + $group.GroupScope + "'"
    $4 = "'" + $group.GroupCategory + "'"
    $5 = "'" + $group.NAME + "'"
    $6 = "'" + $group.ObjectClass + "'"
    $7 = "'" + $group.SamAccountName + "'"
    $8 = "'" + $group.SID + "'"


$InsertQuery = 
@"
INSERT INTO [dbo].[ADGroups]
           ([DistinguishedName]
           ,[GroupCategory]
           ,[GroupScope]
           ,[Name]
           ,[ObjectClass]
           ,[ObjectGUID]
           ,[SamAccountName]
           ,[SID])
     VALUES
           ($1,$2,$3,$4,$5,$6,$7,$8)
          
"@
#    $InsertQuery
     TRY
    {
        Invoke-Sqlcmd -ServerInstance $monitoringServer -Database $monitoringDatabase -query $InsertQuery
    }
    CATCH
    {
    Write-Host $Group
    }
}