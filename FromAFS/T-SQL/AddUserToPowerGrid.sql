--CREATE TABLE SQLDBA.dbo.PGUserLoader
--  (PGLoginName  VARCHAR(50) NOT NULL
--  ,FirstName    VARCHAR(50)
--  ,LastName     VARCHAR(50)
--  ,Client_Key   INT NOT NULL
--  ,ClientLoc_Key  INT NULL
--  ,Email        VARCHAR(100)
--  ,Phone        VARCHAR(18)
--  ,PhoneExt     CHAR(4)
--  ,Position     VARCHAR(100))
/*** PREP WORK! ****
--TRUNCATE TABLE SQLDBA.dbo.PGUserLoader
--LOAD STAGE TABLE
INSERT INTO SQLDBA.dbo.PGUserLoader (PGLoginName, Client_key)
VALUES ('zinustsi',2037)
,('bpmtsi',2039)
,('keetsatsi',2040)
,('dcltsi',2037)
,('internationalgreetingstsi',2036)
INSERT INTO SQLDBA.dbo.PGUserLoader (PGLoginName, Client_key)
VALUES ('chromaflotsi',2013)
--Clean PGLoginName
WHILE 1 = 1 BEGIN
    UPDATE dbo.PGUserLoader
    SET PGLoginName = Replace(PGLoginName, Substring(PGLoginName, PatIndex('%[^0-9A-Z]%', PGLoginName), 1), '')
    WHERE PGLoginName LIKE '%[^0-9A-Z]%'
    If @@RowCount = 0 BREAK;
END;
**** END PREP   ***/
SET NOCOUNT ON;
USE TSS_FreightPayment
GO
DECLARE @DebugOnly BIT =0--1 Yes, 0 NO
--Temp Tables
CREATE TABLE #PGUserLoader
  (PGLoginName  VARCHAR(50) NOT NULL
  ,FirstName    VARCHAR(50)
  ,LastName     VARCHAR(50)
  ,Client_Key   INT NOT NULL
  ,ClientLoc_Key  INT NULL
  ,Email        VARCHAR(100)
  ,Phone        VARCHAR(18)
  ,PhoneExt     CHAR(4)
  ,Position     VARCHAR(100))
INSERT INTO #PGUserLoader
SELECT * FROM SQLDBA.dbo.PGUserLoader
SELECT * INTO #tmpUser_Contact_InfoTBL FROM User_Contact_InfoTBL WHERE 1=2
SELECT * INTO #tmpUser_App_AccessTBL FROM User_App_AccessTBL WHERE 1=2
SELECT * INTO #tmpUser_ClientLocTBL FROM User_ClientLocTBL WHERE 1=2
SELECT * INTO #tmpClient_Password_AssignedRulesTBL FROM Client_Password_AssignedRulesTBL WHERE 1=2
SELECT * INTO #tmpClient_App_AccessTBL FROM Client_App_AccessTBL WHERE 1=2
SELECT * INTO #tmpAdmin FROM TNAccess.dbo.Admin WHERE 1=2
/************************************************
	***** Step 1
	***** Add User_Contact_InfoTBL Records
	************************************************/
	Insert Into #tmpUser_Contact_InfoTBL (UserPwdNME,userFirstNME,userLastNME,ClientID,userEmailNME,userPhoneNBR
										,userPositionNME,accessRequestDTE,accessGrantedDTE,pwdSelectedNME
										,pwdActiveIND,pwdRenewalDTE,pwdChangeRequiredIND,updatedind,AllowUserEdit,UCIT_Pwd)
	SELECT
		PGLoginName
	  , ISNULL(FirstName,'Unknown')
	  , ISNULL(LastName,'Unknown')
	  , client_Key
	  , ISNULL(Email, 'Unknown')
	  , ISNULL(Phone, '666666666')
	  , ISNULL(Position, 'Unknown')
    , GetDate()
	  , GetDate()
	  , 'S1eep!ng'
	  , 1
	  , '2023-01-10 00:00:00.000'
	  , 0
	  , 1
	  , 1
	  , 'aaKS1DtSz5nWM'
	FROM #PGUserLoader
	/************************************************
	***** Step 2
	***** Add User_App_AccessTBL Records
	************************************************/
	INSERT INTO #tmpUser_App_AccessTBL
			(UserKeyID, ApplicationID, UserAccessCodeID, UserICodeID)
	SELECT 	userKeyID, 1, 1, 0
	FROM #tmpUser_Contact_InfoTBL u
	INNER JOIN #PGUserLoader l on u.UserPwdNME = l.PGLoginName
	/************************************************
	***** Step 3
	***** User_ClientLocTBL
	************************************************/
	INSERT INTO #tmpUser_ClientLocTBL (UserKeyID, ClientID, ClientLocID, CLientLocActiveIND, ApplicationRoleID)
	SELECT DISTINCT u.UserKeyId, u.clientid, cl.clientloc_Key, 1,0
	FROM #PGUserLoader l
	INNER JOIN (SELECT *
              FROM User_Contact_InfoTBL
              UNION ALL
              SELECT *
              FROM #tmpUser_Contact_InfoTBL) u 	on l.PGLoginName = u.UserPwdNME
	INNER JOIN clientloctbl 		cl 	    on u.clientId 	= cl.client_key
	WHERE ISNULL(l.clientloc_key, cl.clientloc_key) = cl.clientloc_key
	--Do we need a clause for only active client locs?
	/************************************************
	***** Step 4
	***** Client_Password_AssignedRulesTBL
	************************************************/
	Insert INTO #tmpClient_Password_AssignedRulesTBL (	ClientID, pwdPolicyID, pwdLengthNBR, pwdDesignID,
													pwdRotationNBR, AttemptsBeforeLockoutNBR)
	SELECT client_Key,1,8,5,12,3
	FROM #PGUserLoader l
	WHERE not exists (	SELECT cpa.ClientID
						FROM Client_Password_AssignedRulesTBL cpa
						WHERE cpa.clientID = l.client_key)
	/************************************************
	***** Step 5
	***** CLient_App_AccessTBL
	************************************************/
	INSERT INTO #tmpClient_App_AccessTBL (Client_Key,applicationID,SchemaEntityID,clientMaxDaysDtlNBR,entryServerID,updateServerID,reportServerID,imageDirNME,imagingSecurityID)
	SELECT client_key ,1,403,366,7,7,23,'images\',0  --'
	FROM #PGUserLoader l
	WHERE not exists (	SELECT caa.Client_Key
						FROM CLient_App_AccessTBL caa
						WHERE caa.client_Key = l.client_key )
	/************************************************
	***** Step 6
	***** TNSAccess.dbo.Admin
	************************************************/
	Insert INTO #tmpAdmin (CL_Name,CL_ID,CL_Pwd,CL_DBName,CL_Max_Days_Dtl,ACode
									,Server,ReportDir,QueryDir,TempDir,SQLServer,Client_Key
									,ClientLoc_Key,ImagingSecurityID,ImgDir,UpdateSQLServer,Verified, msrepl_tran_version)
	SELECT c.ClientName
		, u.UserPwdNME
		, 'aaKS1DtSz5nWM                                     '
		, 'FreightPayment                                    '
		, 365
		, 1
		, 'COR-TS-IIS-03       '
		, '\websites\trendtools30\t2\tempfiles\                                       '
		, '\websites\trendtools30\t2\tempfiles\                                       '
		, '\websites\trendtools30\t2\tempfiles\                                       '
		, 'cor-ts-sql-10       '
		, c.client_key
		, STUFF((SELECT ',' + cast(clientloc_key as varchar(100))
           FROM ClientLocTBL b
           WHERE b.Client_Key = ul.Client_Key
			AND ISNULL(ul.ClientLoc_Key, b.ClientLoc_Key) = b.clientloc_key
          FOR XML PATH('')), 1, 1, '')
		, 1
		, 'images\' --'
    , 'COR-TS-SQL-10'
		, 0
    , newid()
	FROM #PGUserLoader	ul
	INNER JOIN (SELECT *
              FROM User_Contact_InfoTBL
              UNION ALL
              SELECT *
              FROM #tmpUser_Contact_InfoTBL) u 	on ul.PGLoginName = u.UserPwdNME
	INNER JOIN ClientTBL 			c 	on u.clientID 	  = c.client_Key
Print 'New User_Contact_infoTBL Recs'
SELECT * FROM #tmpUser_Contact_InfoTBL
Print 'New User_App_AccessTBL Recs'
SELECT * FROM #tmpUser_App_AccessTBL
PRINT 'New User_ClientLocTBL Recs'
SELECT * FROM #tmpUser_ClientLocTBL
PRINT 'New Client_Password_AssignedRulesTBL Recs'
SELECT * FROM #tmpClient_Password_AssignedRulesTBL
PRINT 'New Client_App_AccessTBL Recs'
SELECT * FROM #tmpClient_App_AccessTBL
PRINT 'New Admin Recs'
SELECT * FROM #tmpAdmin
DROP TABLE #tmpUser_Contact_InfoTBL
DROP TABLE #tmpUser_App_AccessTBL
DROP TABLE #tmpUser_ClientLocTBL
DROP TABLE #tmpClient_Password_AssignedRulesTBL
DROP TABLE #tmpClient_App_AccessTBL
DROP TABLE #tmpAdmin
--Stop Here if you do not want to make changes.
--lets Make the changes
IF @DebugOnly = 0
BEGIN TRY
BEGIN TRANSACTION
	/************************************************
	***** Step 1
	***** Add User_Contact_InfoTBL Records
	************************************************/
  Print 'Inserting User_Contact_InfoTBL Recs'
  Insert Into User_Contact_InfoTBL (UserPwdNME,userFirstNME,userLastNME,ClientID,userEmailNME,userPhoneNBR
										,userPositionNME,accessRequestDTE,accessGrantedDTE,pwdSelectedNME
										,pwdActiveIND,pwdRenewalDTE,pwdChangeRequiredIND,updatedind,AllowUserEdit,UCIT_Pwd)
	SELECT
		PGLoginName
	  , ISNULL(FirstName,'Unknown')
	  , ISNULL(LastName,'Unknown')
	  , client_Key
	  , ISNULL(Email, 'Unknown')
	  , ISNULL(Phone, '666666666')
	  , ISNULL(Position, 'Unknown')
    , GetDate()
	  , GetDate()
	  , 'S1eep!ng'
	  , 1
	  , '2023-01-10 00:00:00.000'
	  , 0
	  , 1
	  , 1
	  , 'aaKS1DtSz5nWM'
	FROM #PGUserLoader
	/************************************************
	***** Step 2
	***** Add User_App_AccessTBL Records
	************************************************/
  Print 'Inserting User_App_AccessTBL Recs'
  INSERT INTO User_App_AccessTBL
			(UserKeyID, ApplicationID, UserAccessCodeID, UserICodeID)
	SELECT 	userKeyID, 1, 1, 0
	FROM User_Contact_InfoTBL u
	INNER JOIN #PGUserLoader l on u.UserPwdNME = l.PGLoginName
	/************************************************
	***** Step 3
	***** User_ClientLocTBL
	************************************************/
  Print 'Inserting User_ClientLocTBL Recs'
	INSERT INTO User_ClientLocTBL (UserKeyID, ClientID, ClientLocID, CLientLocActiveIND, ApplicationRoleID)
	SELECT DISTINCT u.UserKeyId, u.clientid, cl.clientloc_Key, 1,0
	FROM #PGUserLoader l
	INNER JOIN User_Contact_InfoTBL u 	on l.PGLoginName = u.UserPwdNME
	INNER JOIN clientloctbl 		cl 	    on u.clientId 	= cl.client_key
	WHERE ISNULL(l.clientloc_key, cl.clientloc_key) = cl.clientloc_key
	--Do we need a clause for only active client locs?
	/************************************************
	***** Step 4
	***** Client_Password_AssignedRulesTBL
	************************************************/
  Print 'Inserting Client_Password_AssignedRulesTBL Recs'
	Insert INTO Client_Password_AssignedRulesTBL (	ClientID, pwdPolicyID, pwdLengthNBR, pwdDesignID,
													pwdRotationNBR, AttemptsBeforeLockoutNBR)
	SELECT client_Key,1,8,5,12,3
	FROM #PGUserLoader l
	WHERE not exists (	SELECT cpa.ClientID
						FROM Client_Password_AssignedRulesTBL cpa
						WHERE cpa.clientID = l.client_key)
	/************************************************
	***** Step 5
	***** CLient_App_AccessTBL
	************************************************/
  Print 'Inserting CLient_App_AccessTBL Recs'
	INSERT INTO Client_App_AccessTBL (Client_Key,applicationID,SchemaEntityID,clientMaxDaysDtlNBR,entryServerID,updateServerID,reportServerID,imageDirNME,imagingSecurityID)
	SELECT client_key ,1,403,366,7,7,23,'images\',0  --'
	FROM #PGUserLoader l
	WHERE not exists (	SELECT caa.Client_Key
						FROM CLient_App_AccessTBL caa
						WHERE caa.client_Key = l.client_key )
	/************************************************
	***** Step 6
	***** TNSAccess.dbo.Admin
	************************************************/
  Print 'Inserting TNAccess.dbo.Admin Recs'
	Insert INTO TNAccess.dbo.Admin (CL_Name,CL_ID,CL_Pwd,CL_DBName,CL_Max_Days_Dtl,ACode
									,Server,ReportDir,QueryDir,TempDir,SQLServer,Client_Key
									,ClientLoc_Key,ImagingSecurityID,ImgDir,UpdateSQLServer,Verified)
	SELECT c.ClientName
		, u.UserPwdNME
		, 'aaKS1DtSz5nWM                                     '
		, 'FreightPayment                                    '
		, 365
		, 1
		, 'COR-TS-IIS-03       '
		, '\websites\trendtools30\t2\tempfiles\                                       '
		, '\websites\trendtools30\t2\tempfiles\                                       '
		, '\websites\trendtools30\t2\tempfiles\                                       '
		, 'cor-ts-sql-10       '
		, c.client_key
		, STUFF((SELECT ',' + cast(clientloc_key as varchar(100))
           FROM ClientLocTBL b
           WHERE b.Client_Key = ul.Client_Key
			AND ISNULL(ul.ClientLoc_Key, b.ClientLoc_Key) = b.clientloc_key
          FOR XML PATH('')), 1, 1, '')
		, 1
		, 'images\' --'
		, 'COR-TS-SQL-10'
		, 0
	FROM #PGUserLoader	ul
	INNER JOIN User_Contact_InfoTBL u 	on ul.PGLoginName = u.UserPwdNME
	INNER JOIN ClientTBL 			c 	on u.clientID 	  = c.client_Key
  --SELECT 1/0
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
DROP TABLE #PGUserLoader
SET NOCOUNT OFF;