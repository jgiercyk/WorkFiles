DECLARE @accountno VARCHAR(50)
    , @client_key numeric(18)
    , @clientloc_key NUMERIC(18)
    , @LocNo VARCHAR(55)
    , @carrier_key numeric(18)
    , @scac char(4) = 'FEPL' --'UPSN'

SET @accountno = '3045-9203-6'
SET @locNo = 'HAR-LOS'

SELECT @client_key = client_key
    , @clientloc_key = clientloc_key
FROM clientloctbl (nolock)
where locno = @locno;

SELECT @carrier_key = carrier_key
FROM carriertbl (nolock)
where scac = @scac;

    INSERT INTO ParcelAccountTbl (
        Carrier_key
        ,AccountNo
        ,ShipType
        ,CLientLoc_key
        ,ActiveInd
        )
    VALUES(@carrier_key
            ,Replace(@accountno, '-','')
            ,0
            ,@CLientLoc_key
            ,1)
IF @carrier_key = 114
BEGIN
SELECT * FROM parcelfiledownloadtbl where client_key=@client_key and carrier_key=@carrier_key AND AccountNo = Replace(@accountno, '-','')
BEGIN TRAN
delete from parcelfiledownloadtbl where client_key=@client_key and carrier_key=@carrier_key AND AccountNo = Replace(@accountno, '-','')
COMMIT;
END;

IF @carrier_key = 55
BEGIN
SELECT * FROM parcelfiledownloadtbl where carrier_key=@carrier_key AND AccountNo = @accountno
BEGIN TRAN
delete from parcelfiledownloadtbl where carrier_key=@carrier_key AND AccountNo = @accountno
COMMIT;
END;
