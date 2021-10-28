--DROP TABLE sqldba.dbo.ClientBulkPAQSetup

--CREATE TABLE sqldba.dbo.ClientBulkPAQSetup
--(RowID INT IDENTITY(1,1) NOT NULL
--,LocNo VARCHAR(55)
--,SCAC CHAR(4)
--,UserID VARCHAR(50)
--,[Password] VARCHAR(50)
--,AccountNumber1 VARCHAR(50)
--,AccountNumber2 VARCHAR(50)
--,AccountNumber3 VARCHAR(50)
--,AccountNumber4 VARCHAR(50)
--,AccountNumber5 VARCHAR(50)
--,AccountNumber6 VARCHAR(50)
--,AccountNumber7 VARCHAR(50)
--,AccountNumber8 VARCHAR(50)
--,AccountNumber9 VARCHAR(50)
--,AccountNumber10 VARCHAR(50)
--,AccountNumber11 VARCHAR(50)
--,AccountNumber12 VARCHAR(50)
--,AccountNumber13 VARCHAR(50)
--,AccountNumber14 VARCHAR(50)
--,AccountNumber15 VARCHAR(50)
--,AccountNumber16 VARCHAR(50)
--,AccountNumber17 VARCHAR(50)
--,AccountNumber18 VARCHAR(50)
--,AccountNumber19 VARCHAR(50)
--,AccountNumber20 VARCHAR(50));

--ALTER TABLE sqldba.dbo.ClientBulkPAQSetup ADD AccountNumber16 VARCHAR(50), AccountNumber17 VARCHAR(50), AccountNumber18 VARCHAR(50), AccountNumber19 VARCHAR(50), AccountNumber20 VARCHAR(50)

/**
TRUNCATE TABLE sqldba.dbo.ClientBulkPAQSetup;
--Bulk Load Data (import export wizard or insert statements)



INSERT INTO  sqldba.dbo.ClientBulkPAQSetup (LocNo, SCAC, UserID, [Password],AccountNumber1)
VALUES('AGM-DOR','FEPL','agmhRL','Audit123','6886-6057-2')


INSERT INTO  sqldba.dbo.ClientBulkPAQSetup (LocNo, SCAC, UserID, [Password],AccountNumber1)
 SELECT 'CHROM-USD','FEPL','Chrom1','Audit123','044108569' UNION
  SELECT 'CHROM-USD','FEPL','Chrom2','Audit123','402755326' UNION
   SELECT 'CHROM-USD','FEPL','Chrom3','Audit123','452309017' UNION
    SELECT 'CHROM-USD','FEPL','Chrom5','Audit123','562140646' UNION
	 SELECT 'CHROM-USD','FEPL','Chrom6','Audit123','719445063' UNION
	  SELECT 'CHROM-USD','FEPL','Chrom7','Audit123','898470369'

INSERT INTO  sqldba.dbo.ClientBulkPAQSetup (LocNo, SCAC, UserID, [Password],AccountNumber1)
 SELECT 'KAM-NEW','UPSN','KamwoRL','Pa55word$','6AX617'

SELECT * FROM sqldba.dbo.ClientBulkPAQSetup

TRUNCATE TABLE sqldba.dbo.ClientBulkPAQSetup;
*/
/*********** START OF THE SCRIPT!! ***********/
USE FreightPayment;
GO

DROP TABLE IF EXISTS #ClientBulkPAQSetup
DROP TABLE IF EXISTS #ClientXRef;
DROP TABLE IF EXISTS #CarrierXRef;
DROP TABLE IF EXISTS #AccountNbr;
DROP TABLE IF EXISTS #ErrorLog;
DROP TABLE IF EXISTS #tmpClientCarrierSettingsTBL;
DROP TABLE IF EXISTS #tmpupsebilldownloadsettingstbl;
DROP TABLE IF EXISTS #tmpFBODOwnloadSettingsTBL;
DROP TABLE IF EXISTS #tmpParcelAccountTbl;

SET NOCOUNT ON;

DECLARE @FBODownLoadSettingsParentFolder VARCHAR(500)
DECLARE @UPSDownLoadSettingsParentFolder VARCHAR(500)

DECLARE @serverName NVARCHAR(256)
DECLARE @env VARCHAR(5)
DECLARE @StartDate DATE
DECLARE @debugonly bit;

select @servername = @@servername;
IF @servername = 'PLADEVSQL03'
    SET @env = 'DEV';
ELSE IF @servername = 'PLA-SQLPCN1-02'
    SET @env = 'PROD';
    
/*********  SETTINGS ************/
SET @debugonly =1  --1 Print Changes, --0 Apply Changes

--Setting env variables
IF @env = 'PROD'
BEGIN 
    SET @FBODownLoadSettingsParentFolder = '\\gr2k8prdfs02\edi\INBOUND\FlatFileInvoices\FedEx\FBODownloads\';
    SET @UPSDownLoadSettingsParentFolder = '\\gr2k8prdfs02\edi\INBOUND\UPS\EBillDownloads\';
    SET @StartDate = N'2020-02-17'
END
ELSE IF @env = 'DEV'
BEGIN
    SET @FBODownLoadSettingsParentFolder = '\\gr2k8prdfs02\EDI\INBOUND\FlatFileInvoices\FedEx\FBODownloads\dev\';
    SET @UPSDownLoadSettingsParentFolder = '\\gr2k8prdfs02\edi\INBOUND\UPS\EBillDownloads\dev\';
    SET @StartDate = N'2019-08-24'
END;
ELSE
    RAISERROR ('Error setting env variables',16,1);


--Make a temp copy of this table so we dont have to re-write the script if we change its location.
SELECT * INTO #ClientBulkPAQSetup FROM sqldba.dbo.ClientBulkPAQSetup;

--Clean Data
UPDATE #ClientBulkPAQSetup
SET AccountNumber1 = CASE WHEN LTRIM(RTRIM(AccountNumber1)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber1)) END
,AccountNumber2 = CASE WHEN LTRIM(RTRIM(AccountNumber2)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber2)) END
,AccountNumber3 = CASE WHEN LTRIM(RTRIM(AccountNumber3)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber3)) END
,AccountNumber4 = CASE WHEN LTRIM(RTRIM(AccountNumber4)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber4)) END
,AccountNumber5 = CASE WHEN LTRIM(RTRIM(AccountNumber5)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber5)) END
,AccountNumber6 = CASE WHEN LTRIM(RTRIM(AccountNumber6)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber6)) END
,AccountNumber7 = CASE WHEN LTRIM(RTRIM(AccountNumber7)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber7)) END
,AccountNumber8 = CASE WHEN LTRIM(RTRIM(AccountNumber8)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber8)) END
,AccountNumber9 = CASE WHEN LTRIM(RTRIM(AccountNumber9)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber9)) END
,AccountNumber10 = CASE WHEN LTRIM(RTRIM(AccountNumber10)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber10)) END
,AccountNumber11 = CASE WHEN LTRIM(RTRIM(AccountNumber11)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber11)) END
,AccountNumber12 = CASE WHEN LTRIM(RTRIM(AccountNumber12)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber12)) END
,AccountNumber13 = CASE WHEN LTRIM(RTRIM(AccountNumber13)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber13)) END
,AccountNumber14 = CASE WHEN LTRIM(RTRIM(AccountNumber14)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber14)) END
,AccountNumber15 = CASE WHEN LTRIM(RTRIM(AccountNumber15)) = '' THEN NULL ELSE LTRIM(RTRIM(AccountNumber15)) END
,UserID = LTRIM(RTRIM(UserID))
,[Password] = LTRIM(RTRIM([Password]))



--Lookup client by scac
SELECT RowID, Client_key, ClientLoc_key
INTO #ClientXref
FROM #ClientBulkPAQSetup ps
INNER JOIN freightpayment..clientloctbl cl (nolock) on ps.locno = cl.locno

--Lookup carrier by scac
SELECT RowID, Carrier_Key
INTO #CarrierXref
FROM #ClientBulkPAQSetup ps
INNER JOIN freightpayment..carriertbl cl (nolock) on ps.scac = cl.scac

--Normalize the AccountNumbers
CREATE TABLE #AccountNbr
(RowID INT, AccountNumber VARCHAR(50))


INSERT INTO #AccountNbr
SELECT rowID, accountnumber1
FROM #ClientBulkPAQSetup
WHERE AccountNumber1 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber2
FROM #ClientBulkPAQSetup
WHERE AccountNumber2 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber3
FROM #ClientBulkPAQSetup
WHERE AccountNumber3 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber4
FROM #ClientBulkPAQSetup
WHERE AccountNumber4 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber5
FROM #ClientBulkPAQSetup
WHERE AccountNumber5 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber6
FROM #ClientBulkPAQSetup
WHERE AccountNumber6 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber7
FROM #ClientBulkPAQSetup
WHERE AccountNumber7 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber8
FROM #ClientBulkPAQSetup
WHERE AccountNumber8 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber9
FROM #ClientBulkPAQSetup
WHERE AccountNumber9 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber10
FROM #ClientBulkPAQSetup
WHERE AccountNumber10 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber11
FROM #ClientBulkPAQSetup
WHERE AccountNumber11 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber12
FROM #ClientBulkPAQSetup
WHERE AccountNumber12 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber13
FROM #ClientBulkPAQSetup
WHERE AccountNumber13 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber14
FROM #ClientBulkPAQSetup
WHERE AccountNumber14 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber15
FROM #ClientBulkPAQSetup
WHERE AccountNumber15 is not null;

INSERT INTO #AccountNbr
SELECT rowID, accountnumber16
FROM #ClientBulkPAQSetup
WHERE AccountNumber16 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber17
FROM #ClientBulkPAQSetup
WHERE AccountNumber17 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber18
FROM #ClientBulkPAQSetup
WHERE AccountNumber18 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber19
FROM #ClientBulkPAQSetup
WHERE AccountNumber19 is not null;
INSERT INTO #AccountNbr
SELECT rowID, accountnumber20
FROM #ClientBulkPAQSetup
WHERE AccountNumber20 is not null;







CREATE TABLE #ErrorLog
    (RowID INT
    ,ErrorMSG VARCHAR(100))

DECLARE @ErrorCount INT = 0
DECLARE @ErrorFlag BIT = 0

INSERT INTO #ErrorLog
SELECT RowID, 'A Client Location does not exists for this location number'
FROM #ClientBulkPAQSetup ps
WHERE not exists (SELECT NULL FROM #ClientXref x WHERE x.rowid = ps.rowid)

SET @ErrorCount = @ErrorCount + @@ROWCOUNT

INSERT INTO #ErrorLog
SELECT RowID, 'A Carrier Record does not exists for this SCAC'
FROM #ClientBulkPAQSetup ps
WHERE not exists (SELECT NULL FROM #CarrierXref x WHERE x.rowid = ps.rowid)

SET @ErrorCount = @ErrorCount + @@ROWCOUNT

INSERT INTO #ErrorLog
SELECT RowID, 'No Account Numbers for this row...'
FROM #ClientBulkPAQSetup ps
WHERE not exists (SELECT NULL FROM #AccountNbr x WHERE x.rowid = ps.rowid)

SET @ErrorCount = @ErrorCount + @@ROWCOUNT

IF @ErrorCount > 0
    Print 'Some records did not get imported due to errors';

--Make some temp tables to record what we plan on doing.
SELECT * INTO #tmpClientCarrierSettingsTBL FROM ClientCarrierSettingsTBL WHERE 1=2;
SELECT * INTO #tmpupsebilldownloadsettingstbl FROM upsebilldownloadsettingstbl WHERE 1=2;
SELECT * INTO #tmpFBODOwnloadSettingsTBL FROM FBODOwnloadSettingsTBL WHERE 1=2;
SELECT * INTO #tmpParcelAccountTbl FROM ParcelAccountTbl WHERE 1=2;

--Enable PAQAudit
--UPS
IF Exists (SELECT NULL FROM #CarrierXref WHERE Carrier_key = 55)
BEGIN
    INSERT INTO #tmpClientCarrierSettingsTBL
    (Carrier_key
    ,ModeCode_key
    ,Client_key
    ,ClientLoc_key
    ,AuditStatusID
    ,GuaranteeContactTypeID
    ,AuditContactTypeID
    ,AuditSendToName
    ,AuditSendToEmail
    ,AuditAgent_key
    ,GuaranteeRemitTypeID
    ,AuditRemitTypeID)
    SELECT Carrier_key
        , ModeCode_key
        , Client_Key
        , NULL
        , 40
        , 10
        , 10
        , NULL
        , 'preferred.us@ups.com'
        , 1
        , 0
        , 0
    FROM (
    SELECT DISTINCT cl.client_key, cr.carrier_key, modecode_key
    FROM #ClientXref cl
    INNER JOIN #CarrierXref cr on cl.rowid = cr.rowid
    cross join (
    select 10 as modecode_key -- Parcel
    union
    select 12 as modecode_key -- Parcel Air
    union
    select 13 as modecode_key -- Parcel Ground
    ) modecodetbl
    WHERE Carrier_key = 55
    EXCEPT
    SELECT Client_key, carrier_key, modecode_key
    FROM ClientCarrierSettingsTBL) x
	
	
	--Add UPS Supply Chain Solutions
	INSERT INTO #tmpClientCarrierSettingsTBL
    (Carrier_key
    ,ModeCode_key
    ,Client_key
    ,ClientLoc_key
    ,AuditStatusID
    ,GuaranteeContactTypeID
    ,AuditContactTypeID
    ,AuditSendToName
    ,AuditSendToEmail
    ,AuditAgent_key
    ,GuaranteeRemitTypeID
    ,AuditRemitTypeID)
    SELECT 100
        , ModeCode_key
        , Client_Key
        , NULL
        , 40
        , 10
        , 10
        , NULL
        , 'preferred.us@ups.com'
        , 1
        , 0
        , 0
    FROM (
    SELECT DISTINCT cl.client_key, cr.carrier_key, modecode_key
    FROM #ClientXref cl
    INNER JOIN #CarrierXref cr on cl.rowid = cr.rowid
    cross join (
    select 10 as modecode_key -- Parcel
    union
    select 12 as modecode_key -- Parcel Air
    union
    select 13 as modecode_key -- Parcel Ground
    ) modecodetbl
    WHERE Carrier_key = 55
    EXCEPT
    SELECT Client_key, carrier_key, modecode_key
    FROM ClientCarrierSettingsTBL) x
	
END;

--FED Ex
IF Exists (SELECT NULL FROM #CarrierXref WHERE Carrier_key = 114)
BEGIN
    INSERT INTO #tmpClientCarrierSettingsTBL
    (Carrier_key
    ,ModeCode_key
    ,Client_key
    ,ClientLoc_key
    ,AuditStatusID
    ,GuaranteeContactTypeID
    ,AuditContactTypeID
    ,AuditSendToName
    ,AuditSendToEmail
    ,AuditAgent_key
    ,GuaranteeRemitTypeID
    ,AuditRemitTypeID)
    SELECT Carrier_key
        , ModeCode_key
        , Client_Key
        , NULL
        , 40
        , 0
        , 0
        , NULL
        , NULL
        , NULL
        , 0
        , 0
    FROM (
    SELECT DISTINCT cl.client_key, cr.carrier_key, modecode_key
    FROM #ClientXref cl
    INNER JOIN #CarrierXref cr on cl.rowid = cr.rowid
    cross join (
    select 10 as modecode_key -- Parcel
    union
    select 12 as modecode_key -- Parcel Air
    union
    select 13 as modecode_key -- Parcel Ground
    ) modecodetbl
    WHERE Carrier_key = 114
    EXCEPT
    SELECT Client_key, carrier_key, modecode_key
    FROM ClientCarrierSettingsTBL) x
END;


--Add UPS Download settings
IF Exists (SELECT NULL FROM #CarrierXref WHERE Carrier_key = 55)
BEGIN
insert into #tmpupsebilldownloadsettingstbl (
   client_key
  ,clientloc_key
  ,userid
  ,password
  ,accountno
  ,workingfolder
  ,loadingfolder
  ,archivefolder
  ,active
  ,loaderkey
  ,accounttype
  ,startdate
)
select
   cx.client_key
  ,cx.clientloc_key
  ,ps.userid
  ,ps.password
  ,ISNULL(an.accountnumber,'ALL')
  ,@UPSDownLoadSettingsParentFolder + replace(replace(replace(replace(c.clientname, '''', ''), ',', ''), '.', ''), ' ', '_')+'\Working'  --'
  ,@UPSDownLoadSettingsParentFolder + replace(replace(replace(replace(c.clientname, '''', ''), ',', ''), '.', ''), ' ', '_')+'\Loading'  --'
  ,@UPSDownLoadSettingsParentFolder + replace(replace(replace(replace(c.clientname, '''', ''), ',', ''), '.', ''), ' ', '_')+'\Archive'  --'
  ,1 -- 4. Active=1
  ,'UPSEBillDownloaderLDR'+format(ps.rowid%4+4, 'D2')
  ,1 -- 6. AccountType=1
  ,@StartDate -- 7. StartDate=2019-08-22
from #ClientBulkPAQSetup ps
INNER JOIN #clientxref cx on ps.rowid = cx.rowid
INNER JOIN #carrierxref crx on ps.rowid = crx.rowid
INNER JOIN clientloctbl cl (NOLOCK) on cx.clientloc_key = cl.clientloc_key
INNER JOIN clienttbl c (NOLOCK) on cx.client_key = c.client_key
LEFT JOIN #AccountNbr an ON ps.rowid = an.rowid
WHERE crx.carrier_key = 55
AND NOT EXISTS (SELECT NULL FROM upsebilldownloadsettingstbl x 
                WHERE x.client_key = cx.client_key
                AND x.ClientLoc_key = cx.ClientLoc_Key
                AND x.AccountNo = ISNULL(an.AccountNumber,'ALL'))

END;

--Add FedEx Download settings
IF Exists (SELECT NULL FROM #CarrierXref WHERE Carrier_key = 114)
BEGIN
    insert into #tmpFBODownloadSettingsTBL (
       client_key
      ,clientloc_key
      ,userid
      ,password
      ,accountno
      ,workingfolder
      ,loadingfolder
      ,archivefolder
      ,active
      ,loaderkey
      ,startdate
    )
    select
       cx.client_key
      ,cx.clientloc_key
      ,ps.userid
      ,ps.password
      ,CASE
        WHEN an.accountnumber is null THEN 'ALL'
        WHEN LEN(ltrim(rtrim(an.accountnumber))) = 9 THEN SUBSTRING(an.accountnumber,1,4) + '-' + SUBSTRING(an.accountnumber,5,4) + '-' + SUBSTRING(an.accountnumber,9,1)
		WHEN LEN(ltrim(rtrim(REPLACE(an.accountnumber,'-','')))) = 9 THEN SUBSTRING(an.accountnumber,1,4) + '-' + SUBSTRING(an.accountnumber,6,4) + '-' + SUBSTRING(an.accountnumber,11,1)--        WHEN LEN(ltrim(rtrim(REPLACE(an.accountnumber,'-','')))) = 9 THEN SUBSTRING(an.accountnumber,1,4) + '-' + SUBSTRING(an.accountnumber,5,4) + '-' + SUBSTRING(an.accountnumber,9,1)
        ELSE an.accountnumber END
      ,@FBODownLoadSettingsParentFolder + replace(replace(replace(replace(c.clientname, '''', ''), ',', ''), '.', ''), ' ', '_')+'\Working'  --'
      ,@FBODownLoadSettingsParentFolder + replace(replace(replace(replace(c.clientname, '''', ''), ',', ''), '.', ''), ' ', '_')+'\Loading'  --'
      ,@FBODownLoadSettingsParentFolder + replace(replace(replace(replace(c.clientname, '''', ''), ',', ''), '.', ''), ' ', '_')+'\Archive'  --'
      ,1 -- 4. Active=1
      ,'FBODownloaderLDR'+format(ps.rowid%4+4, 'D2')
      ,@StartDate -- 7. StartDate=2019-08-22
    from #ClientBulkPAQSetup ps
    INNER JOIN #clientxref cx on ps.rowid = cx.rowid
    INNER JOIN #carrierxref crx on ps.rowid = crx.rowid
    INNER JOIN clientloctbl cl (NOLOCK) on cx.clientloc_key = cl.clientloc_key
    INNER JOIN clienttbl c (NOLOCK) on cx.client_key = c.client_key
    LEFT JOIN #AccountNbr an ON ps.rowid = an.rowid
    WHERE crx.carrier_key = 114
    AND NOT EXISTS (SELECT NULL FROM FBODownloadSettingsTBL x 
                WHERE x.client_key = cx.client_key
                AND x.ClientLoc_key = cx.ClientLoc_Key
                AND x.AccountNo = CASE
        WHEN an.accountnumber is null THEN 'ALL'
        WHEN LEN(ltrim(rtrim(an.accountnumber))) = 9 THEN SUBSTRING(an.accountnumber,1,4) + '-' + SUBSTRING(an.accountnumber,5,4) + '-' + SUBSTRING(an.accountnumber,9,1)
		WHEN LEN(ltrim(rtrim(REPLACE(an.accountnumber,'-','')))) = 9 THEN SUBSTRING(an.accountnumber,1,4) + '-' + SUBSTRING(an.accountnumber,6,4) + '-' + SUBSTRING(an.accountnumber,11,1)
--        WHEN LEN(ltrim(rtrim(REPLACE(an.accountnumber,'-','')))) = 9 THEN SUBSTRING(an.accountnumber,1,4) + '-' + SUBSTRING(an.accountnumber,5,4) + '-' + SUBSTRING(an.accountnumber,9,1)
        ELSE an.accountnumber END)
END; 

--insert into: ParcelAccountTbl
    INSERT INTO #tmpParcelAccountTbl
    (Carrier_key
    ,AccountNo
    ,ShipType
    ,CLientLoc_key
    ,ActiveInd)
    SELECT 
       crx.carrier_key
       ,REPLACE(an.accountnumber,'-','')
       ,0
       ,cx.clientloc_key
       , 1
    FROM
        #CarrierXRef crx
    INNER JOIN #ClientXRef cx on crx.rowid = cx.rowid
    INNER JOIN #AccountNbr an on crx.rowid = an.rowid
    EXCEPT
    SELECT 
        carrier_key
        ,accountno
        ,shiptype
        ,clientloc_key
        ,ActiveInd
    FROM ParcelAccountTBL;

--Handling Duplicated Carrier Account numbers.
INSERT INTO #ErrorLog
SELECT 0, 'ParcelAccountTbl Record not added due to Key Duplication - Carrier_Key:' + Cast(tpc.carrier_key as varchar(20)) + ' AccountNo: ' + tpc.accountno 
FROM #tmpParcelAccountTbl tpc
INNER JOIN ParcelAccountTBL pc (NOLOCK) on tpc.carrier_key = pc.carrier_key and tpc.accountno = REPLACE(pc.accountno,'-','');

DELETE FROM #tmpParcelAccounttbl
WHERE EXISTS (SELECT NULL FROM ParcelAccountTBL pc (NOLOCK) where pc.carrier_key = #tmpParcelAccounttbl.carrier_key and pc.accountno = #tmpParcelAccounttbl.accountno);

PRINT 'Errors:'
SELECT E.*, ps.* FROM #errorlog e LEFT JOIN #ClientBulkPAQSetup ps on e.rowid = ps.rowid
PRINT 'New ClientCarrierSettings:'
select * from #tmpClientCarrierSettingsTBL
PRINT 'New UPSEBillDownloadSettings:'
SELECT * FROM #tmpupsebilldownloadsettingstbl
PRINT 'New FBODownloadSettings:'
SELECT * FROM #tmpFBODOwnloadSettingsTBL
PRINT 'New ParcelAccount:'
SELECT * FROM #tmpParcelAccountTbl;

--Time to make the changes

IF @DebugOnly = 0
BEGIN TRY
    BEGIN TRAN
    
    INSERT INTO ClientCarrierSettingsTBL
    (Carrier_key
    ,ModeCode_key
    ,Client_key
    ,ClientLoc_key
    ,AuditStatusID
    ,GuaranteeContactTypeID
    ,AuditContactTypeID
    ,AuditSendToName
    ,AuditSendToEmail
    ,AuditAgent_key
    ,GuaranteeRemitTypeID
    ,AuditRemitTypeID)
    SELECT Carrier_key
    ,ModeCode_key
    ,Client_key
    ,ClientLoc_key
    ,AuditStatusID
    ,GuaranteeContactTypeID
    ,AuditContactTypeID
    ,AuditSendToName
    ,AuditSendToEmail
    ,AuditAgent_key
    ,GuaranteeRemitTypeID
    ,AuditRemitTypeID
    FROM #tmpClientCarrierSettingsTBL

    INSERT INTO UPSEBillDownloadSettingstbl (
           client_key
          ,clientloc_key
          ,userid
          ,password
          ,accountno
          ,workingfolder
          ,loadingfolder
          ,archivefolder
          ,active
          ,loaderkey
          ,accounttype
          ,startdate
        )
    SELECT client_key
          ,clientloc_key
          ,userid
          ,password
          ,accountno
          ,workingfolder
          ,loadingfolder
          ,archivefolder
          ,active
          ,loaderkey
          ,accounttype
          ,startdate
    FROM #tmpUPSEBillDownloadSettingstbl;

    INSERT INTO FBODownloadSettingsTBL (
       client_key
      ,clientloc_key
      ,userid
      ,password
      ,accountno
      ,workingfolder
      ,loadingfolder
      ,archivefolder
      ,active
      ,loaderkey
      ,startdate
    )
    SELECT client_key
          ,clientloc_key
          ,userid
          ,password
          ,accountno
          ,workingfolder
          ,loadingfolder
          ,archivefolder
          ,active
          ,loaderkey
          ,startdate
    FROM #tmpFBODOwnloadSettingsTBL;

    INSERT INTO ParcelAccountTbl (
        Carrier_key
        ,AccountNo
        ,ShipType
        ,CLientLoc_key
        ,ActiveInd
        )
    SELECT  Carrier_key
            ,AccountNo
            ,ShipType
            ,CLientLoc_key
            ,ActiveInd
    FROM #tmpParcelAccountTbl;

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

------Clean up;
DROP TABLE IF EXISTS #ClientBulkPAQSetup
DROP TABLE IF EXISTS #ClientXRef;
DROP TABLE IF EXISTS #CarrierXRef;
DROP TABLE IF EXISTS #AccountNbr;
DROP TABLE IF EXISTS #ErrorLog;
DROP TABLE IF EXISTS #tmpClientCarrierSettingsTBL;
DROP TABLE IF EXISTS #tmpupsebilldownloadsettingstbl;
DROP TABLE IF EXISTS #tmpFBODOwnloadSettingsTBL;
DROP TABLE IF EXISTS #tmpParcelAccountTbl;


--Use freightpayment;
--GO

--SELECT * FROM clientloctbl where locno = 'MET-ENG'

--SELECT * FROM ClientCarrierSettingsTBL WHERE client_key =2023
--SELECT * FROM FBODownloadSettingsTBL WHERE clientloc_key = 7554
--SELECT * FROM ParcelAccountTbl WHERE clientloc_key = 7554