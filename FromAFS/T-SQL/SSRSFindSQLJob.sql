select c.path,
		c.name,
		rs.scheduleid 'sql job',
		s.description,
		s.laststatus,
		s.lastruntime
		from 
reportschedule rs
join [catalog] c on rs.reportid = c.itemid
join subscriptions s on  rs.subscriptionid = s.subscriptionid
where c.name = 'Madix PDF Invoice POD Required'