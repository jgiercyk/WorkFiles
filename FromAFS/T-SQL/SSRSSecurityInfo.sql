/****** Script for SelectTopNRows command from SSMS  ******/
SELECT 
u.UserName
,r.RoleName
,c.Path
,c.Name
,c.Type
,[ID]
      ,pu.[RoleID]
      ,pu.[UserID]
      ,p.[PolicyID]
	  ,u.*
	  ,r.*
	  ,p.*
	  ,c.*
  FROM [ReportServer].[dbo].[PolicyUserRole] pu
  JOIN dbo.Policies p ON pu.PolicyID = p.PolicyID
  JOIN dbo.Roles r ON r.RoleID = pu.RoleID
  JOIN dbo.Users u ON u.UserID = pu.UserID
  JOIN dbo.Catalog c ON c.PolicyID = pu.PolicyID
  WHERE u.UserName LIKE '%davis%' AND c.type <> 1

  --SELECT TOP 1000 * FROM dbo.Catalog