USE FreightPayment;
GO

DECLARE @client_key       numeric(18)
    , @UserID varchar(50)
    , @Password varchar(50)
    , @DebugOnly int = 1
SET NOCOUNT ON;

SET @client_key = 1598
SET @UserID = 'prioRL1'
SET @Password = 'Audit123'

--INSERT INTO #tmp
SELECT EbillDownloaderSettings_Key
    , dl.Client_key
    , c.clientname
    , dl.UserID as OldUserID
    , @UserID as NewUserID
    , dl.Password as OldPassword
    , @Password as NewPassword
    , dl.accountno
FROM UPSEBillDownloadSettingsTBL dl (NOLOCK)
INNER JOIN clienttbl c (NOLOCK) on dl.client_key = c.client_key
WHERE dl.client_key = @client_key;

IF @debugonly = 0
BEGIN TRY
BEGIN TRAN

    UPDATE UPSEBilldownloadsettingstbl
    SET userid = @UserID, [Password] = @Password
    WHERE client_key = @client_key

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
