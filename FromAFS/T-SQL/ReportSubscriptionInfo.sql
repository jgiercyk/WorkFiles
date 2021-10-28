USE [ReportServer]
GO

/****** Object:  View [dbo].[ReportSubscriptionInfo]    Script Date: 2/11/2020 2:28:46 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[ReportSubscriptionInfo]
AS

SELECT c.Name 'Report',
       c.Path 'Path',
	   s.Description,
       rs.ScheduleID 'SQL Agent Job',
	   s.LastStatus,
	   s.LastRunTime,
	   s.ModifiedDate
FROM dbo.ReportSchedule rs
    JOIN dbo.Catalog c
        ON c.ItemID = rs.ReportID
    JOIN dbo.Subscriptions s
        ON s.SubscriptionID = rs.SubscriptionID

GO


