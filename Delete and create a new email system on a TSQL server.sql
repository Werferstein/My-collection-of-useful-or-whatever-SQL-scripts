/*
The script deletes all mail profiles, mail accounts and operators on the SQL Server.
A new mail account is then created and assigned to the profile.
A new operator is also created.

All existing mail connections of the jobs are redirected to a new account.
The table at the end shows the jobs that still have to be changed manually.

Das Skript löscht alle Mail-Profile, Mailkonten und Operatoren auf dem SQL Server.
Anschließend wird ein neues Mailkonto angelegt und dem Profil zugeordnet.
Auch wird ein neuer Operator erstellt.

Alle bestehenden Mailverbindungen der Jobs werden auf ein neues Konto umgeleitet.
Die Tabelle am Ende, zeigt die Jobs an die noch per Hand geändert werden müssen.

I.Hill 09.11.2016

*/
USE [msdb]
GO
DECLARE @EMAILFrom_name VARCHAR(MAX)	= @@SERVERNAME + '-> my server name',
		@email_address VARCHAR(MAX)		= @@SERVERNAME + '@myaddress.com',
		@replyto_address VARCHAR(MAX)	= 'sql-info@myaddress.com',

		@test_email_address VARCHAR(MAX)= 'test@myaddress.com',

		@EMAILprofile_name SYSNAME		= 'Send-SQL-INFO',
		@EMAILkonto_name SYSNAME		= 'SQL-INFO-' + @@SERVERNAME,
		@mailserver_name SYSNAME		= 'XX.XX.XX.XX',
		@port INT						= 25,


		@OperatorName SYSNAME			= 'MyOperator'



DECLARE @Text VARCHAR(MAX) = ''
DECLARE @debug BIT = 0


/*
--------------------------------------------------------------------------------------
Delete all mail profiles and mail accounts
--------------------------------------------------------------------------------------   
*/


PRINT'Initial Cleanup:'
DECLARE @ProfileName VARCHAR(MAX), @AccountName VARCHAR(MAX)

DECLARE  @pos INT = 0,  @count INT = (SELECT COUNT(*) FROM [msdb].[dbo].[sysmail_profileaccount])

IF @count > 0 
BEGIN
	
	--Profile in Temp. Tabelle
	IF OBJECT_ID('tempdb..##tempMailProfile', 'U') is not null DROP TABLE ##tempMailProfile
	SELECT  
			ROW_NUMBER() OVER (ORDER BY pa.profile_id) AS POS
			,p.name AS ProfileName
		    ,a.name AS AccountName 
	INTO ##tempMailProfile
	FROM msdb.dbo.sysmail_profileaccount pa
			JOIN msdb.dbo.sysmail_profile p ON pa.profile_id = p.profile_id
			JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id
	
	--Loop
	WHILE (@count > 0)
	BEGIN
		SELECT TOP(1) @pos = POS, @ProfileName = ProfileName, @AccountName  = AccountName  FROM ##tempMailProfile WHERE POS = @count
		
		IF  @ProfileName IS NOT NULL AND  @ProfileName != '' AND 
			@AccountName IS NOT NULL AND  @AccountName != '' 
		BEGIN
			PRINT '-----------------------------------------------------------------------------------------------------------------'
			PRINT 'Deleting Profile: ' + @ProfileName
			PRINT 'Deleting Account: ' + @AccountName
			PRINT '-----------------------------------------------------------------------------------------------------------------'

				IF EXISTS(
				SELECT * FROM msdb.dbo.sysmail_profileaccount pa
					  JOIN msdb.dbo.sysmail_profile p ON pa.profile_id = p.profile_id
					  JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id
				WHERE
					  p.name = @ProfileName AND
					  a.name = @AccountName
						)
					BEGIN
						  PRINT 'Deleting Profile: ' + @ProfileName
						  PRINT 'Deleting Account: ' + @AccountName
						  IF @debug = 0
						  BEGIN
							  EXECUTE msdb.dbo.sysmail_delete_profileaccount_sp
							  @profile_name = @ProfileName,
							  @account_name = @AccountName
						  END
						  
						  SET @Text +=	'Phase1: ' + @ProfileName + CHAR(13)
						  SET @Text +=	'Deleting Profile: ' + @ProfileName + CHAR(13)
						  SET @Text +=	'Deleting Account: ' + @AccountName + CHAR(13)
					END

					IF EXISTS(
					SELECT * FROM msdb.dbo.sysmail_profile p
					WHERE p.name = @ProfileName)
					BEGIN
						  PRINT 'Deleting Profile. ' + @ProfileName
						  IF @debug = 0
						  BEGIN
							  EXECUTE msdb.dbo.sysmail_delete_profile_sp
							  @profile_name = @ProfileName

							  SET @Text +=	'Phase2: ' + @ProfileName + CHAR(13)
							  SET @Text +=	'Deleting Profile: ' + @ProfileName + CHAR(13)						  
						  END						 
					END
 
					IF EXISTS(
					SELECT * FROM msdb.dbo.sysmail_account a
					WHERE a.name = @AccountName)
					BEGIN
						  PRINT 'Deleting Account. ' + @AccountName
						  
						  IF @debug = 0
						  BEGIN
							  EXECUTE msdb.dbo.sysmail_delete_account_sp
							  @account_name = @AccountName

							SET @Text +=	'Phase2: ' + @ProfileName + CHAR(13)						  
							SET @Text +=	'Deleting Account: ' + @AccountName + CHAR(13)
						  END
					END

		END
		SET @count -= 1
	
	END --WHILE (@count > 0)
END	

/*
--------------------------------------------------------------------------------------
End Delete all mail profiles and mail accounts
--------------------------------------------------------------------------------------   
*/


/*
--------------------------------------------------------------------------------------
Create new accounts and profiles
--------------------------------------------------------------------------------------   
*/


--// Create a Database Mail account
EXECUTE msdb.dbo.sysmail_add_account_sp
    @account_name = @EMAILkonto_name,
    @description = 'Mail account for administrative e-mail.',
    @email_address = @email_address,
    @replyto_address = @replyto_address,
    @display_name = @EMAILFrom_name,
    @mailserver_name = @mailserver_name,
    @port = @port
    --@username = 'xyz',
    --@password = 'xxyyzz',
    --@enable_ssl = 1
 
-- Create a Database Mail profile
EXECUTE msdb.dbo.sysmail_add_profile_sp
    @profile_name = @EMAILprofile_name,
    @description = 'Profile used for administrative mail.'
 
-- Add the account to the profile
EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = @EMAILprofile_name,
    @account_name = @EMAILkonto_name,
    @sequence_number =1
 
-- Grant access to the profile to the DBMailUsers role
EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
    @profile_name = @EMAILprofile_name,
    @principal_name = 'public',
    @is_default = 1	

DECLARE @xbody VARCHAR(MAX) = 'Test Email From ' + @@SERVERNAME + @Text
DECLARE @xsubject VARCHAR(MAX) = 'Test Email Subject From ' + @@SERVERNAME
--Send mail
EXEC msdb.dbo.sp_send_dbmail
    @recipients=@test_email_address,
    @body= @xbody,
    @subject = @xsubject,
    @profile_name = @EMAILprofile_name

--Send mail with attachment
EXEC msdb.dbo.sp_send_dbmail
     @profile_name = @EMAILprofile_name
    ,@recipients = @test_email_address
    --,@from_address = @EMAILkonto_name 
    ,@query = 'SELECT resource_type, resource_database_id,
               request_mode, request_session_id
               FROM sys.dm_tran_locks
              WHERE request_mode IN (''IX'', ''X'')'
    ,@subject = 'Exclusive Locks'
    ,@attach_query_result_as_file = 1 ;


/*
--------------------------------------------------------------------------------------
End Create new accounts and profiles
--------------------------------------------------------------------------------------   
*/



/*
--------------------------------------------------------------------------------------
Create new operator
--------------------------------------------------------------------------------------   
*/

DECLARE @Find VARCHAR(MAX) = (SELECT top(1) name FROM [dbo].[sysoperators] WHERE name = @OperatorName)
--falls vorhanden löschen
IF @Find IS NOT NULL AND @Find != ''
BEGIN
	PRINT 'DELETE'
	EXEC msdb.dbo.sp_delete_operator @name = @OperatorName 
END

EXEC msdb.dbo.sp_add_operator @name= @OperatorName,		-- Operator name
@enabled =1,
@pager_days =0,
@email_address =@email_address




--Redirect all notifications
SET @pos = 0
DECLARE @id INT = 0,  @name VARCHAR(max) = ''

SET @count = (SELECT COUNT(*) FROM [dbo].[sysoperators])
IF @count > 0 
BEGIN
	IF OBJECT_ID('tempdb..##tempOperator', 'U') is not null DROP TABLE ##tempOperator
	SELECT ROW_NUMBER() OVER (ORDER BY id) AS POS,  id, name INTO ##tempOperator FROM [dbo].[sysoperators]	
	--Loop [sysoperators]
	WHILE (@count > 0)
	BEGIN
		SELECT TOP(1) @pos = POS, @id = id, @name = name FROM ##tempOperator WHERE POS = @count
		
		IF @name IS NOT NULL AND  @name != '' AND  @name != @OperatorName
		BEGIN
			PRINT 'DELETE Operator:' + @name
			EXEC sp_delete_operator @name = @name,  
				@reassign_to_operator = @OperatorName;  
		END
		SET @count -= 1
	END
END

/*
--------------------------------------------------------------------------------------
End Create new operator
--------------------------------------------------------------------------------------   
*/


/*
--------------------------------------------------------------------------------------
Turn on agent notification
--------------------------------------------------------------------------------------   
*/


EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1

EXEC master.dbo.xp_instance_regwrite 
	N'HKEY_LOCAL_MACHINE', 
    N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
	N'UseDatabaseMail', 
    N'REG_DWORD', 1

EXEC master.dbo.xp_instance_regwrite 
	N'HKEY_LOCAL_MACHINE', 
    N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
	N'DatabaseMailProfile', 
    N'REG_SZ', 
	N'Send-SQL-INFO'
	--@EMAILprofile_name

/*
--------------------------------------------------------------------------------------
End Turn on agent notification
--------------------------------------------------------------------------------------   
*/

--------------------------------------------------------------------------------------   
--------------------------------------------------------------------------------------   
--------------------------------------------------------------------------------------   
--Which jobs need to be changed
--------------------------------------------------------------------------------------   
--------------------------------------------------------------------------------------   
--------------------------------------------------------------------------------------   
USE [msdb]
GO
 
SET NOCOUNT ON;
 
SELECT 'SQL Agent job(s) without notification operator found:' AS [Message]
 
SELECT j.[name] AS [JobName]
FROM [dbo].[sysjobs] j
LEFT JOIN [dbo].[sysoperators] o ON (j.[notify_email_operator_id] = o.[id])
WHERE j.[enabled] = 1
    AND j.[notify_level_email] NOT IN (1, 2, 3)
GO
