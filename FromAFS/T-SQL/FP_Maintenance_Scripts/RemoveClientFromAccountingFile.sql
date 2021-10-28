DECLARE @client_key NUMERIC(18, 0) = 1259;
DECLARE @effectEndDate DATE = '2020-01-28';
DECLARE @debug BIT = 0; -- 1 = print results, 0 = execute

BEGIN TRANSACTION;
BEGIN TRY

    SELECT g.Client_Key,
           c.ClientName,
           g.EffectiveStartDate,
           g.EffectiveEndDate
    FROM dbo.ClientGainShareRateTBL (NOLOCK) g
        JOIN dbo.ClientTBL c
            ON c.Client_Key = g.Client_Key
    WHERE g.Client_Key = @client_key;

    UPDATE dbo.ClientGainShareRateTBL
    SET EffectiveEndDate = @effectEndDate
    WHERE Client_Key = @client_key;

    SELECT g.Client_Key,
           c.ClientName,
           g.EffectiveStartDate,
           g.EffectiveEndDate
    FROM dbo.ClientGainShareRateTBL (NOLOCK) g
        JOIN dbo.ClientTBL c
            ON c.Client_Key = g.Client_Key
    WHERE g.Client_Key = @client_key;


    IF @debug = 0
    BEGIN
        COMMIT;
    END;
    ELSE
    BEGIN
        PRINT 'DEBUG MODE - TRANSACTION ROLLED BACK';
        ROLLBACK;
    END;

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