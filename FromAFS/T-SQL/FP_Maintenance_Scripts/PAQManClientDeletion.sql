USE FreightPayment;
GO

DECLARE @debug BIT = 1  -- 1 = Print Changes / 0 = Execute Changes

DECLARE @AccountNo VARCHAR(50) = '6886-6057-2';
DECLARE @ClientKey INT = 1166;
DECLARE @SCAC VARCHAR(4) = 'FEPL';

DROP TABLE IF EXISTS #UPSloaderRecordToDelete
DROP TABLE IF EXISTS #FBOloaderRecordToDelete
DROP TABLE IF EXISTS #ParcelRecordsToDelete

    SELECT dl.[Client_Key],
           c.[LocName],
           dl.[ClientLoc_Key],
           c.[LocNo],
           @SCAC 'SCAC',
           dl.UserId,
           dl.Password,
           dl.AccountNo
	INTO #UPSloaderRecordToDelete
    FROM [FreightPayment].[dbo].[ClientLocTBL] c
        JOIN dbo.UPSEBillDownloadSettingsTBL dl
            ON c.Client_Key = dl.Client_Key
    WHERE dl.Client_Key = @ClientKey
          AND dl.AccountNo = @AccountNo;

    SELECT dl.[Client_Key],
           c.[LocName],
           dl.[ClientLoc_Key],
           c.[LocNo],
           @SCAC 'SCAC',
           dl.UserId,
           dl.Password,
           dl.AccountNo
	INTO #FBOloaderRecordToDelete
    FROM [FreightPayment].[dbo].[ClientLocTBL] c
        JOIN dbo.FBODownloadSettingsTBL dl
            ON c.Client_Key = dl.Client_Key
    WHERE dl.Client_Key = @ClientKey
          AND dl.AccountNo = @AccountNo;

		  SELECT * 
		  INTO #ParcelRecordsToDelete FROM dbo.ParcelAccountTBL
			WHERE (AccountNo = @AccountNo OR AccountNo = REPLACE(@AccountNo,'-','')) AND Carrier_key IN (55,114);


SELECT 'FEDEX Records To Delete' 'RecordType', * FROM #FBOloaderRecordToDelete
SELECT 'UPS Records To Delete' 'RecordType', * FROM #UPSloaderRecordToDelete
SELECT 'Parcel Records To Delete' 'RecordType', * FROM #ParcelRecordsToDelete


If @Debug = 0
BEGIN TRY
    BEGIN TRAN
	-- Save the record you are about to delete
	INSERT INTO [SQLDBA].[dbo].[ClientPAQDeletedAccounts]
			   ([DateAdded]
			   ,[Client_Key]
			   ,[Client]
			   ,[ClientLoc_Key]
			   ,[LocNo]
			   ,[SCAC]
			   ,[UserId]
			   ,[Password]
			   ,[AccountNo])
		 SELECT GETDATE(), Client_Key, LocName, ClientLoc_Key,LocNo, SCAC,UserId, Password, AccountNo FROM #FBOloaderRecordToDelete UNION
		 SELECT GETDATE(), Client_Key, LocName, ClientLoc_Key,LocNo, SCAC,UserId, Password, AccountNo FROM #UPSloaderRecordToDelete


		DECLARE @NumberOfFedexRecs INT = (SELECT count(*) from #FBOloaderRecordToDelete)
		DECLARE @NumberOfUPSRecs INT = (SELECT count(*) from #UPSloaderRecordToDelete)
		DECLARE @NumberOfParcelRecs INT = (SELECT count(*) from #ParcelRecordsToDelete)



		IF @NumberOfFedexRecs > 0
		BEGIN
			DELETE FROM [dbo].[FBODownloadSettingsTBL] WHERE (AccountNo = @AccountNo OR AccountNo = REPLACE(@AccountNo,'-','')) AND Client_Key = @ClientKey
		END

		IF @NumberOfUPSRecs > 0
		BEGIN
			DELETE FROM [dbo].[UPSEBillDownloadSettingsTBL] WHERE AccountNo = @AccountNo AND Client_Key = @ClientKey
		END

		IF @NumberOfParcelRecs > 0
		BEGIN
			DELETE FROM [dbo].[ParcelAccountTBL] WHERE (AccountNo = @AccountNo OR AccountNo = REPLACE(@AccountNo,'-','')) AND Carrier_key IN (55,114)
		END 
 	COMMIT;
	--ROLLBACK Transaction

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




