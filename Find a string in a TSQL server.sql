/*
A specific string is searched for in all functions, triggers, etc. The result is output in a table.

In allen Funktionen, Trigger usw. wird eine bestimmter String gesucht. Das Ergebnis wird in einer Tabelle ausgegeben.

Ingolf Hill 16.08.2017
*/
USE master
go



DECLARE  @SEARCHSTRING VARCHAR(255)= 'AdressSelect',
		 @notcontain VARCHAR(255) = ''



IF OBJECT_ID('tempdb..##ResultFind', 'U') is not null DROP TABLE ##ResultFind
CREATE TABLE ##ResultFind (DatabaseName VARCHAR(MAX),[Object Name] VARCHAR(MAX), [Object Type] VARCHAR(MAX), StepName VARCHAR(MAX) )

DECLARE @DbName VARCHAR(100), @SqlText VARCHAR(max) = ''

DECLARE myCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases
OPEN myCursor

FETCH NEXT FROM myCursor INTO @DbName
WHILE @@FETCH_STATUS = 0 BEGIN
    
    IF (SELECT top 1 state_desc FROM sys.databases WHERE name = @DbName) = 'OFFLINE' FETCH NEXT FROM myCursor INTO @DbName
    PRINT  @DbName

SET @SqlText =
'
	--------------------------------------------------------------------------
    --------------------------------------------------------------------------
	--------------------------------------------------------------------------
		DECLARE  @SEARCHSTRING VARCHAR(255) = ''' + @SEARCHSTRING + '''
		,@notcontain VARCHAR(255) = ''' + @notcontain+ '''

		INSERT INTO ##ResultFind (DatabaseName,[Object Name], [Object Type])		
		SELECT DISTINCT 
				''' + @DbName + ''' as Datatbase,
				
				t1.name AS [Object Name],
				
				
				--t1.xtype,		
				CASE 
				WHEN t1.xtype = ''FN''
					THEN ''Skalar Func.''
				WHEN t1.xtype = ''P''
					THEN ''Stored Proc''
				WHEN t1.xtype = ''TF''
					THEN ''Function''
				WHEN t1.xtype = ''TR''
					THEN ''Trigger''
				WHEN t1.xtype = ''V''
					THEN ''View'' END AS [Object Type]

		FROM [' + @DbName + '].dbo.sysobjects as t1
		LEFT JOIN [' + @DbName + '].dbo.syscomments as t2 ON t2.id = t1.id

		WHERE 

			 t1.type IN (''P'',''TF'',''TR'',''V'',''FN'')
			AND t1.category = 0
			AND CHARINDEX(UPPER(@SEARCHSTRING), UPPER(t2.text)) > 0
			AND (CHARINDEX(@notcontain, t2.text) = 0 OR CHARINDEX(@notcontain, t2.text) <> 0)
	--------------------------------------------------------------------------
    --------------------------------------------------------------------------
	--------------------------------------------------------------------------
'
EXEC(@SqlText)

    FETCH NEXT FROM myCursor INTO @DbName
END

CLOSE myCursor
DEALLOCATE myCursor



INSERT INTO ##ResultFind (DatabaseName,[Object Name], [Object Type], StepName)	
SELECT			js.database_name as Datatbase,                 
				jobs.name as [Object Name],
				'AgentenJob' AS [Object Type],
				 
                 --js.step_id as StepID,
                 js.step_name as StepName
                 --js.command as StepCommand
FROM     msdb.dbo.sysjobs as jobs
                INNER JOIN msdb.dbo.sysjobsteps as js ON jobs.job_id = js.job_id
WHERE  
		jobs.[enabled] = 1 AND 
		CHARINDEX(UPPER(@SEARCHSTRING), UPPER(js.command)) > 0 AND
		(CHARINDEX(@notcontain, js.command) = 0 OR CHARINDEX(@notcontain, js.command) <> 0)      
ORDER BY jobs.name,js.step_id


SELECT * FROM ##ResultFind
Order BY 1,2,3
IF OBJECT_ID('tempdb..##ResultFind', 'U') is not null DROP TABLE ##ResultFind
