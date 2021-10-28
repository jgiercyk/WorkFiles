--WHEN LEN(ltrim(rtrim(REPLACE(an.accountnumber,'-','')))) = 9 THEN SUBSTRING(an.accountnumber,1,4) + '-' + SUBSTRING(an.accountnumber,5,4) + '-' + SUBSTRING(an.accountnumber,9,1)

DROP TABLE IF EXISTS #tmp
DROP TABLE IF EXISTS #tmp2

DECLARE @accountno VARCHAR(50)
    , @client_key numeric(18)
    , @clientloc_key NUMERIC(18)
--    , @client_key NUMERIC(18)
    , @LocNo VARCHAR(55)
    , @carrier_key numeric(18)
    , @scac char(4) = 'UPSN'
    , @debug BIT = 1

SET @accountno = '6A0Y21'
SET @locNo = 'WAT-LAK'

SELECT @client_key = client_key
    , @clientloc_key = clientloc_key
	, @client_key = Client_Key
FROM clientloctbl (nolock)
where locno = @locno;

SELECT @carrier_key = carrier_key
FROM carriertbl (nolock)
where scac = @scac;

SELECT @carrier_key;
SELECT @clientloc_key;
SELECT @client_key

PRINT 'Loader (Parcel Account) to Remove'
SELECT * FROM parcelaccounttbl
where clientloc_key = @clientloc_key
AND carrier_key = @carrier_key
AND accountno = replace(@accountno,'-','');

IF @carrier_key = 114
BEGIN
    PRINT 'Downloader to removed'
    SELECT * FROM FBODownLoadSettingsTBL
    WHERE clientloc_key = @clientloc_key
    AND accountno = @accountno;
END;

IF @carrier_key = 55
BEGIN
    PRINT 'Downloader to removed'
    SELECT * FROM dbo.UPSEBillDownloadSettingsTBL
    WHERE clientloc_key = @clientloc_key
    AND accountno = @accountno;
END;

SELECT probill_key 
INTO #tmp
FROM probilltbl
--WHERE clientloc_key = 1761 --@clientloc_key
--AND carrier_key = @carrier_key
--AND shipperaccount = replace(@accountno,'-','')
WHERE InvoiceNo IN        ( '6A0Y21399', '6A0Y21499', '6A0Y21509', '6A0Y21499', '6A0Y21469', '6A0Y21479', '6A0Y21489',
                           '6A0Y21469', '6A0Y21479', '6A0Y21369', '6A0Y21379', '6A0Y21389', '6A0Y21469', '6A0Y21369',
                           '6A0Y21379', '6A0Y21389', '6A0Y21399', '6A0Y21459', '6A0Y21439', '6A0Y21449', '6A0Y21429',
                           '6A0Y21439', '6A0Y21419', '6A0Y21429', '6A0Y21409', '6A0Y21419', '6A0Y21409'
                         );


PRINT 'Probill Count:'
SELECT COUNT(*) FROM #tmp;

SELECT * FROM #tmp

SELECT probill_key
INTO #tmp2
FROM ProbillAuditItemBillingTBL
WHERE probill_key in (select probill_key from #tmp);

PRINT 'Audit Count'
SELECT COUNT(*) FROM #tmp2;

PRINT 'Sage Billing Reversal'
SELECT    c.clientname
        , AccountNumber     = RTRIM(x.SageIDCUST)
        , ItemCode          = CASE WHEN b.Carrier_Key = 114 AND pb.ModeCode_Key= 12 THEN '0225'
                                   WHEN b.Carrier_Key = 114 AND pb.ModeCode_Key= 13 THEN '0226'
                                   WHEN b.Carrier_key IN (55,100)      THEN '0224' END
        , ItemDescription   = CASE WHEN b.Carrier_Key = 114 AND pb.ModeCode_Key= 12 THEN 'FAP - Parcel - Fed Ex Air'
                                   WHEN b.Carrier_Key = 114 AND pb.ModeCode_Key= 13 THEN 'FAP - Parcel - Fed Ex Ground'
                                   WHEN b.Carrier_key IN (55,100)      THEN 'FAP - Parcel - UPS Air & Ground' END
        , BOLCount          = FORMAT(ROUND(SUM(b.RefundAmount),2), 'F2')
        , CostPerBOL        = FORMAT(ROUND(r.rate,2),'F3')
        , ExtendedAmount    = FORMAT(ROUND(SUM(AmountDue),2),'F2')
        , TEXTDESC          = 'Processing Week ' + FORMAT(b.ProcessedDate,'M-d-yyyy') + '; Account ' + ShipperAccount
    FROM ProbillAuditItemBillingTBL b
    INNER JOIN ClientGainShareRateTBL r on b.clientgainsharerate_key = r.clientgainsharerate_key
    INNER JOIN ProbillTbl pb (NOLOCK) on b.probill_key = pb.probill_key
    INNER JOIN Clienttbl c (NOLOCK) on r.client_key = c.client_key
    LEFT JOIN Sage.ClientXRef x ON r.client_key = x.client_key
    WHERE AFSClaim = 1
    AND pb.probill_key IN (SELECT probill_key from #tmp2)
    GROUP BY c.clientname, x.SageIDCUST, b.Carrier_key, r.Rate, b.Processeddate, ShipperAccount, CASE WHEN b.Carrier_Key = 114 AND pb.ModeCode_Key= 12 THEN '0225'
                                   WHEN b.Carrier_Key = 114 AND pb.ModeCode_Key= 13 THEN '0226'
                                   WHEN b.Carrier_key IN (55,100)      THEN '0224' END,CASE WHEN b.Carrier_Key = 114 AND pb.ModeCode_Key= 12 THEN 'FAP - Parcel - Fed Ex Air'
                                   WHEN b.Carrier_Key = 114 AND pb.ModeCode_Key= 13 THEN 'FAP - Parcel - Fed Ex Ground'
                                   WHEN b.Carrier_key IN (55,100)      THEN 'FAP - Parcel - UPS Air & Ground' END;

IF @debug = 0
BEGIN
    BEGIN TRY
        BEGIN TRAN
            PRINT 'Deleting Parcel Account'
            DELETE FROM parcelaccounttbl
            where clientloc_key = @clientloc_key
            AND carrier_key = @carrier_key
            AND accountno = replace(@accountno,'-','');

            IF @carrier_key = 114
            BEGIN
                PRINT 'Deleting FBO Downloader Settings'
                DELETE FROM FBODownLoadSettingsTBL
                WHERE clientloc_key = @clientloc_key
                AND accountno = @accountno;
            END;
            IF @carrier_key = 55
            BEGIN
                PRINT 'Deleting UPS Downloader Settings'
                DELETE FROM dbo.UPSEBillDownloadSettingsTBL
                WHERE clientloc_key = @clientloc_key
                AND accountno = @accountno;
            END;

        COMMIT;
        PRINT 'Downloader/Loader Settings Removed'
    END TRY
    BEGIN CATCH
	    PRINT 'Downloader/Loader Failed - Rolling Back changes'
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

    PRINT 'Deleting probills'
    DECLARE @probill_key NUMERIC(18,0)

    DECLARE cur CURSOR 
    FOR SELECT probill_key FROM #tmp

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


    BEGIN TRAN
    Print 'Deleting ProbillAuitItemBillingTBL'
    DELETE FROM ProbillAuditItemBillingTBL
    WHERE probill_key in (SELECT probill_key from #tmp)
    COMMIT;
END;

DROP TABLE #tmp;
DROP TABLE #tmp2;
