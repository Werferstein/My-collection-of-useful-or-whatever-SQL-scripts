/*
The procedure checks whether another process has already called it (@Jobname);
if an instance of the procedure is already running, the current instance waits for the current one to complete.
A timeout can be set. You can also specify whether the process is restarted after the waiting time has elapsed.

In a team it is often necessary to start certain jobs on the SQL server in order to test certain operations.
It can happen that certain jobs run at the same time. Blockages, deadlocks, etc. occur... In the script
I took the idea from https://www.sqlteam.com/articles/centralized-asynchronous-auditing-with-service-broker 
and modified it so that it can be quickly can be used for various tasks. I also defined a table as feedback
so I can use it in my SQL testing tool (C#) as well.


In einem Team ist es oft notwendig, bestimmte Jobs auf dem SQL Server zu starten, um bestimmte Vorgänge
zu testen. Es kann dann passieren, dass bestimmte Jobs gleichzeitig laufen. Es kommt zu Blockaden,
Deadlocks usw...  In dem Skript habe ich die Idee von 
https://www.sqlteam.com/articles/centralized-asynchronous-auditing-with-service-broker
aufgenommen und so verändert, dass man es schnell für verschiedene Aufgaben einsetzen kann.
Ich habe auch eine Tabelle als Rückmeldung definiert,
sodass ich sie in meinem SQL Testwerkzeug (C#) auch verwenden kann.

Ingolf Hill 07.2021 werferstein.org
*/

--bookmark @Jobname
DECLARE 
 @Jobname VARCHAR(200) = 'ImportTest'
,@SystemGuid UNIQUEIDENTIFIER =  NEWID()	
,@StartTime DATETIME = GETDATE(),@PartStartTime DATETIME 
,@PartName VARCHAR(200) = ''
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--A single table is expected as the result. Exactly in the format shown. The table can hold multiple rows
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @Result TABLE ([Nr] INT IDENTITY(1,1), [Date] DATETIME default GETDATE(),[Name] VARCHAR(200) DEFAULT '',[PartName] VARCHAR(200) DEFAULT '',  [Count] INT DEFAULT -1,[Runtime] INT DEFAULT -1, [Message] VARCHAR(200) DEFAULT '', [ERROR] INT DEFAULT -1)
DECLARE 
@Msg NVARCHAR(MAX),
--0 = no error, 1-9 =  Warning, 10 >= Error in (one) parameter, 20 >= Error in single part, 30 >= Fatal ERROR stopp script
@ERRORresult INT = 0, @COUNTresult INT = 0;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


--bookmark Process mod
--@timeoutMin = 0 -->then the process waits for the process that is already running to complete 
--@timeoutMin > 0 -->if the timeout has expired, the process is terminated with an error 
DECLARE @timeoutMin INT = 0;

-- @StartMod = 0 -->Wait until the process that has already started has ended -->exit all
-- @StartMod = 1 -->after the already running process has ended, start the process again
DECLARE @StartMod BIT = 0



---------------------------------------------------------------------------------------------------------------------------------------------------------------
--https://www.sqlteam.com/articles/centralized-asynchronous-auditing-with-service-broker
--Get info from service-broker
---------------------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @tcount INT = 0;
WHILE (EXISTS (SELECT * FROM master..sysprocesses WITH (NOLOCK) WHERE context_info=CAST(@Jobname AS VARBINARY)))
BEGIN
	 WAITFOR DELAY '00:00:01';
	 if @tcount >= 2147483646 SET @tcount = 1; SET @tcount += 1;	--max and next sec.
	 IF @timeoutMin > 0 AND @tcount >= (@timeoutMin * 60) 
	 BEGIN
		SET @Msg= 'Job ' + @Jobname + ' is already running, wait timeout after ' + CONVERT(VARCHAR(10), DATEDIFF(MINUTE,@StartTime,GETDATE())) + ' min. !';
		RAISERROR(@Msg, 16, 1); SET @ERRORresult = 30;
		INSERT INTO @Result ([Name],[PartName],[Count],[Runtime],[Message],[ERROR]) VALUES (@Jobname,'Wait timeout!',-1,DATEDIFF(MINUTE,@StartTime,GETDATE()),@Msg,30);
		GOTO ENDPROG
		--THROW 60000, @ErrMsg, 1;		
		--PRINT 'Timeout after ' + CONVERT(VARCHAR(10), @timeoutMin) + 'min. (' + @Jobname + ')'		
	END
END--WHILE (EXISTS ( 
IF @StartMod = 0 AND @tcount > 0
BEGIN
	SET @Msg= 'The job ' + @Jobname + ' that was already started has been completed. ' + CONVERT(VARCHAR(10), DATEDIFF(MINUTE,@StartTime,GETDATE())) + ' min.'; PRINT @Msg;
	INSERT INTO @Result ([Name],[PartName],[Count],[Runtime],[Message],[ERROR]) VALUES (@Jobname,@Jobname,1,@tcount/60,@Msg,6);--Warning
	GOTO ENDPROG;
END

IF @tcount > 60 PRINT 'Start after ' + CONVERT(VARCHAR(10), (@tcount/60)) + 'min. wait time! (' + @Jobname + ')' ELSE PRINT 'Start job ' + @Jobname + '!'; 
---------------------------------------------------------------------------------------------------------------------------------------------------------------
--Information to the service-broker the task has started 
---------------------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @context_info VARBINARY(30)
SET @context_info = CAST(@Jobname AS VARBINARY)
SET CONTEXT_INFO @context_info
---------------------------------------------------------------------------------------------------------------------------------------------------------------
--bookmark sql code start




--deley for testing
SET @PartStartTime = GETDATE();
WAITFOR DELAY '0:02';
SET @PartName = 'Part A';
INSERT INTO @Result ([Name],[PartName],[Count],[Runtime],[Message],[ERROR]) VALUES (@Jobname,@PartName,23475489,DATEDIFF(MINUTE,@PartStartTime,GETDATE()),'Message Part A',0);
SET @COUNTresult += 23475489;

--deley for testing
SET @PartStartTime = GETDATE();
WAITFOR DELAY '0:01';
SET @PartName = 'Part B';
INSERT INTO @Result ([Name],[PartName],[Count],[Runtime],[Message],[ERROR]) VALUES (@Jobname,@PartName,0,DATEDIFF(MINUTE,@PartStartTime,GETDATE()),'Message Part B',3);
SET @COUNTresult += 0;

--deley for testing
SET @PartStartTime = GETDATE();
WAITFOR DELAY '0:02';
SET @PartName = 'Part C';
INSERT INTO @Result ([Name],[PartName],[Count],[Runtime],[Message],[ERROR]) VALUES (@Jobname,@PartName,497887,DATEDIFF(MINUTE,@PartStartTime,GETDATE()),'Message Part C',0);
SET @COUNTresult += 497887;

--deley for testing
SET @PartStartTime = GETDATE();
WAITFOR DELAY '0:01';
SET @PartName = 'Part D';
INSERT INTO @Result ([Name],[PartName],[Count],[Runtime],[Message],[ERROR]) VALUES (@Jobname,@PartName,0,DATEDIFF(MINUTE,@PartStartTime,GETDATE()),'Message Part D',30);
SET @COUNTresult += 0;






--bookmark sql code end
---------------------------------------------------------------------------------------------------------------------------------------------------------------
--Information to the service-broker the task was terminated 
SET CONTEXT_INFO 0x0;
INSERT INTO @Result ([Name],[PartName],[Count],[Runtime],[Message],[ERROR]) VALUES (@Jobname,@Jobname,@COUNTresult,DATEDIFF(MINUTE,@StartTime,GETDATE()),'End Job',@ERRORresult);
PRINT 'End job ' + @Jobname + ' ' + CONVERT(VARCHAR(10), DATEDIFF(MINUTE,@StartTime,GETDATE())) + ' min. !';
ENDPROG:
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--bookmark output result
SELECT * From @Result ORDER BY  [Date]
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
