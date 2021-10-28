USE FreightPayment;

DECLARE @Probill_Key VARCHAR(50) = '1105559043';
DECLARE @Debug BIT = 1; -- PRINT record, 0 EXECUTE code

SELECT 'Probill record to be deleted',
       *
FROM dbo.ProBillTBL
WHERE ProBill_Key = @Probill_Key;

IF @Debug = 0
BEGIN TRY
    BEGIN TRAN;
    PRINT @Probill_Key;

    UPDATE ProBillTBL
    SET ProBillType_Key = 99
    WHERE ProBill_Key = @Probill_Key;

    EXECUTE [dbo].[DeleteByProbill_Key] @Probill_Key;

    PRINT 'Probill Deleted';
    COMMIT;
END TRY
BEGIN CATCH
    PRINT 'Rolling Back changes';
    SELECT ERROR_NUMBER() AS ErrorNumber,
           ERROR_SEVERITY() AS ErrorSeverity,
           ERROR_STATE() AS ErrorState,
           ERROR_PROCEDURE() AS ErrorProcedure,
           ERROR_LINE() AS ErrorLine,
           ERROR_MESSAGE() AS ErrorMessage;
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
END CATCH;



