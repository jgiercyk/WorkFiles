set transaction isolation level read uncommitted;

DECLARE @JiraTicket VARCHAR(100) 	
	,	@BatchID 	INT
	,   @BatchDesc  VARCHAR(1000) 	= 'Federal Mogul Post Production DOT Date Modification'
	,   @UpdateDate DATE = GETDATE()
	,   @ProcessedDate 		DATE
	,   @NewProcessedDate	DATE
	,   @DebugOnly  BIT =  1 --1 Report only, 0 Update
	
-- YOU NEED TO SET THESE!
SET @JiraTicket 		= 'PM-37'
SET @ProcessedDate		= N'11/27/2019'
SET @NewProcessedDate	= N'12/01/2019'

SET @DebugOnly = 1

--Data For Review
select c.ClientName
	,  c.ClientNo
	,  c.Client_key
	,  cl.LocName
	,  pb.probill_key
	,  pb.probillno
	,  pbp.ProcessedDatetime as OrgProcessedDateTime
	,  @NewProcessedDate AS NewProcessedDateTime
	,  pb.invoiceNo
	,  pb.statusreason
	,  pb.pbstatuscode_key
	,  sc.statuscode
	,  pb.paiddate
	,  pb.businessRuleFlag
	,  ct.scac
	,  ct.CarrierName
--INTO #tmpProBillList
FROM probillprocessedtbl pbp
INNER JOIN probilltbl pb ON pbp.probill_key = pb.probill_key
INNER JOIN clientloctbl cl on pb.clientloc_key = cl.clientloc_key
INNER JOIN clienttbl c on cl.client_key = c.client_key
LEFT JOIN carriertbl ct on pb.carrier_key = ct.carrier_key
LEFT JOIN statuscodetbl sc on pb.PBStatusCode_Key = sc.statuscode_key
WHERE cl.client_key = 286

AND pbp.processeddatetime = @ProcessedDate
--OPTION (RECOMPILE)

--Display Changes for our record and review.
select COUNT(*) from #tmpProBillList
SELECT * FROM #tmpProBillList
--Record and Make Changes
IF @DebugOnly = 0
BEGIN
--Get the next batchID
	SELECT @BatchID = MAX(BatchID)+1 FROM SQLDBA..ProbillMassUpdates
	IF @BatchID IS NULL
		SET @BatchID = 1
		
	PRINT 'BatchID ' + CAST(@BatchID AS VARCHAR(100))

	--Add Probill's to Mass Update Log
	INSERT INTO SQLDBA..ProbillMassUpdates 
		(	dbname
		, 	BatchID
		,	UpdatedDate
		,   JiraTicket
		,   BatchDesc
		,   Probill_key)
	SELECT DB_Name()
		, 	@batchID
		,   @UpdateDate
		,   @JiraTicket
		,   @BatchDesc
		,   Probill_key
	FROM #tmpProBillList

	BEGIN TRY
		BEGIN TRANSACTION
			UPDATE probillprocessedtbl
			SET ProcessedDatetime = @NewProcessedDate
			WHERE probill_key in (select probill_key from #tmpProBillList)
		COMMIT;
		PRINT 'Completed Successfully'
	END TRY
	BEGIN CATCH
		PRINT 'Rolling Back changes'
		SELECT  
			ERROR_NUMBER() AS ErrorNumber  
			,ERROR_SEVERITY() AS ErrorSeverity  
			,ERROR_STATE() AS ErrorState  
			,ERROR_PROCEDURE() AS ErrorProcedure  
			,ERROR_LINE() AS ErrorLine  
			,ERROR_MESSAGE() AS ErrorMessage; 
		IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION
	END CATCH
END

DROP TABLE #tmpProBillList
