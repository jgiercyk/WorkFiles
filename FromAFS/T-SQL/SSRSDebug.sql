USE ReportServer

SELECT catalog.name AS report, 
		catalog.path 'Path',
       e.username AS [User], 
       e.timestart, 
       e.timeend,  
       Datediff(mi,e.timestart,e.timeend) AS 'Time In Minutes', 
	   e.status 'Status',
	   e.Parameters 'Parameters',
	   e.AdditionalInfo 'Info',
	   e.*,
       catalog.modifieddate AS [Report Last Modified], 
       users.username 
FROM   catalog  (nolock) 
       INNER JOIN executionlogstorage e (nolock) 
         ON catalog.itemid = e.Reportid 
       INNER JOIN users (nolock) 
         ON catalog.modifiedbyid = users.userid 
WHERE  --e.timestart >= Dateadd(s, -1, '09/01/2015') 
       --AND e.timeend <= Dateadd(DAY, 1, '01/09/2016')  
	    catalog.name = 'Madix Daily Shipment Invoice Report - POD Not Required'
--	   AND parameters like 'ordnum=0049701512&client_id=SGROUP&wh_id=CTN&partnum=019323387000001'
	   --AND Status = 'rsProcessingAborted'
	   --AND e.UserName NOT IN ('COLINX\klockart','COLINX\jtaube','NT Service\ReportServer')
	   ORDER BY e.TimeStart desc