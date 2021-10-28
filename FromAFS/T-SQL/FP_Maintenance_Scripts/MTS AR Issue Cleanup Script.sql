SELECT clientloc_key, probillno, probill_key FROM probilltbl (NOLOCK)
WHERE probillno = '0007873AR'
OR probillno = '0007873'



DROP TABLE IF EXISTS #tmp

DECLARE @PaidDate DATE = GETDATE();
DECLARE @ClientLoc_key NUMERIC(18,0) = 6416 --6394  --6421

SELECT AP.ClientLoc_key
  , AP.probill_key AP_Probill_key
  , AP.ProbillNo    AP_ProbillNo
  , AP.Carrier_key AP_Carrier_key
  , AP.PaidDate    AP_PaidDate
  , AR.ClientLoc_key AR_ClientLoc_key
  , AR.Probill_key AR_Probill_key
  , AR.ProbillNo   AR_ProbillNo
  , AR.PaidDate    AR_PaidDate
  , AR.Carrier_key AR_Carrier_key
  , AP.pbstatuscode_key AS APStatus
  , AR.PBstatusCode_key as ARStatus
INTO #tmp
FROM probilltbl AP (NOLOCK)
--INNER JOIN clientloctbl cl (NOLOCK) on pb.clientloc_key = cl.clientloc_key
INNER JOIN probilltbl AR (NOLOCK) ON AP.ProbillNo + 'AR' = AR.Probillno
                                AND AP.Carrier_key = AR.Carrier_key
WHERE 1=1
--AND AP.PBStatusCode_Key = 2 
AND (AP.PaidDate is null OR AP.PaidDate = @PaidDate)
AND AR.PaidDate is not null
AND AP.clientloc_key = @ClientLoc_key

SELECT * FROM #tmp

select c.ClientName
	,  c.ClientNo
	,  c.Client_key
	,  cl.LocName
  , cl.Clientloc_key
	,  pb.probill_key
	,  pb.probillno
	,  pb.invoiceNo
	,  pb.statusreason
	, pb.pbstatuscode_key
	, sc.statuscode
	, pb.paiddate
	, pb.businessRuleFlag
	, ct.scac
	, ct.CarrierName
  , pb.probilltype_key
--INTO #tmpProBillList
FROM probilltbl pb
INNER JOIN clientloctbl cl on pb.clientloc_key = cl.clientloc_key
INNER JOIN clienttbl c on cl.client_key = c.client_key
INNER JOIN carriertbl ct on pb.carrier_key = ct.carrier_key
INNER JOIN statuscodetbl sc on pb.PBStatusCode_Key = sc.statuscode_key
where pb.probill_key IN (SELECT AR_probill_key FROM #tmp)

DECLARE @probill_key NUMERIC(18,0)

DECLARE cur CURSOR 
FOR SELECT AR_probill_key FROM #tmp

OPEN cur

FETCH NEXT FROM cur into @Probill_key

WHILE @@Fetch_Status =0
BEGIN 
  BEGIN TRY
    BEGIN TRAN
      PRINT @probill_key

      UPDATE probilltbl
      set probilltype_key = 99
      where probill_key = @Probill_key

     EXECUTE [dbo].[DeleteByProbill_Key] @Probill_key
    COMMIT;
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
  
  FETCH NEXT FROM cur into @Probill_key
END

CLOSE cur
DEALLOCATE cur
