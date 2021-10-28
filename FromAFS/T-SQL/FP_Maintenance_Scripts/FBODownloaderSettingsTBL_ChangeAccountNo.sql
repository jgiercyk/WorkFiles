DECLARE @locno          varchar(55) 
    , @OldaccountNo     varchar(50) 
    , @NewAccountNo     varchar(50)
    , @client_key       numeric(18)
    , @clientloc_key    numeric(18)
    , @downloadersettings_key INT
    , @OldAccountNoClean   VARCHAR(50)
    , @NewAccountNoClean   VARCHAR(50)
    , @errorcnt bit = 0
	,@debug BIT = 1  -- 1 print results 0 - execute change

--SET @locno 		= 'AME-FER'
--SET @OldAccountNo 	= '1748-8397-6'
--SET @NewAccountNo 	= '1749-8397-6'

SET @locno 		= 'DEA-CLE'
SET @OldAccountNo 	= '491083'
SET @NewAccountNo 	= '491084'

SET NOCOUNT ON;
SET @OldAccountNoClean = replace(@Oldaccountno,'-','');
SET @NewAccountNoClean = replace(@Newaccountno,'-','');

SELECT @client_key = client_key
    ,   @clientloc_key = clientloc_key
FROM clientloctbl (NOLOCK) where locno = @locno

PRINT 'Location: ' + @locno + ' Account: ' + @Oldaccountno
PRINT 'Action Change AccountNo: ' + @OldAccountNo + ' -> ' + @NewAccountNo

IF exists (SELECT NULL
            FROM AuditItemCarrierModeClientSettingsTBL
            WHERE accountno = @OldAccountNoClean AND carrier_key = 114)
BEGIN
    Print 'ERROR!! AuditItemCarrierModeClientSettings Exists for old account no: ' + @OldAccountNoClean
    SET @errorcnt = 1;
END;

IF exists (SELECT NULL
            FROM AuditItemCarrierModeClientSettingsTBL
            WHERE accountno = @NewAccountNoClean AND carrier_key = 114)
BEGIN
    Print 'ERROR!! AuditItemCarrierModeClientSettings Exists for new account no: ' + @NewAccountNoClean
    SET @errorcnt = 1;
END;

IF exists (SELECT NULL
            FROM ParcelAccountTBL
            WHERE accountno = @NewAccountNoClean AND carrier_key = 114)
BEGIN
    Print 'ERROR!! ParcelAccount record already Exists for new account no: ' + @NewAccountNoClean
    SELECT * FROM ParcelAccountTBL
    WHERE accountno = @NewAccountNoClean AND carrier_key = 114
    SET @errorcnt = 1;
END;

IF exists (SELECT NULL
            FROM fbodownloadsettingstbl
            WHERE client_key = @client_key
            AND clientloc_key = @clientloc_key
            AND AccountNo = @NewAccountNo)
BEGIN
    Print 'ERROR!! FBODownloadSettingsTBL record already Exists for new account no: ' + @NewAccountNo
    SELECT * 
    FROM fbodownloadsettingstbl
    WHERE client_key = @client_key
        AND clientloc_key = @clientloc_key
        AND AccountNo = @NewAccountNo
    SET @errorcnt = 1;
END;


IF @errorcnt = 0 AND @debug = 1
BEGIN TRY
BEGIN TRAN
    --Update ParcelAccountTBL
    PRINT 'ParcelAccountTBL records to Update:'
    SELECT *
    FROM ParcelAccountTBL
    WHERE carrier_key = 114
    AND AccountNo = @OldAccountNoClean

    UPDATE ParcelAccountTBL
    SET AccountNo = @NewAccountNoClean
    WHERE carrier_key = 114
    AND AccountNo = @OldAccountNoClean

    --Update FBODownloadSettingsTBL
    PRINT 'FBODownloadSettingsTBL Records to Update:'
    SELECT *
    FROM FBODownloadSettingsTBL
    WHERE client_key = @client_key
        AND clientloc_key = @clientloc_key
        AND AccountNo = @OldAccountNo

    UPDATE FBODownloadSettingsTBL
    SET AccountNo = @NewAccountNo
    WHERE client_key = @client_key
        AND clientloc_key = @clientloc_key
        AND AccountNo = @OldAccountNo

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

