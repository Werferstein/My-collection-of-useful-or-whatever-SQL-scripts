--#########################################################################################
--Comparing two tables using the primary key and displaying possible differences in the tables.
--The primary columns are read from the schema and correctly linked to the target table,
--if no blacklist for fields was specified, all remaining fields are compared.
--I.Hill 11.2024
--#########################################################################################

DECLARE @ProcessId NVARCHAR(10) = 'Test'
--Source -->basis of comparison<--
DECLARE @tableName NVARCHAR(100) = 'table name'
DECLARE @DatabaseName NVARCHAR(100) = 'database name'
DECLARE @FieldNameBlackList NVARCHAR(MAX) = ''


--Target
DECLARE @ServerLink NVARCHAR(300) = '' --optional linked server
DECLARE @TargetDatabaseName NVARCHAR(100) = 'database (compare)'
DECLARE @TargetTableName NVARCHAR(100) = 'table name (compare)'
	
--Limiting the different lines --> TOP (XXX)
DECLARE @ifDiff_TOP NVARCHAR(300) = 'TOP (1000)'
DECLARE @DatabaseSchema NVARCHAR(100) = 'dbo'


--#########################################################################################
--#########################################################################################
SET @ServerLink = CASE WHEN @ServerLink != '' THEN '[' + @ServerLink + '].' ELSE '' END
DECLARE @SourceTableLink NVARCHAR(300) =  '[' + @DatabaseName + '].[' + @DatabaseSchema + '].[' + @tableName + ']';
DECLARE @TargetTableLink NVARCHAR(300) =  @ServerLink + '[' + @TargetDatabaseName + '].[' + @DatabaseSchema + '].[' + @TargetTableName + ']';
DECLARE @line NVARCHAR(300) = '--#########################################################################################' + char(13)
if OBJECT_ID(@SourceTableLink, 'U') is null  
BEGIN
	Print '@SourceTableLink ?' + @SourceTableLink;
	return
END 
if OBJECT_ID(@TargetTableLink, 'U') is null  
BEGIN
	
	DECLARE @SqlStr NVARCHAR(300) = '', @rcount INT = 0
	IF @ServerLink <> ''
    BEGIN
    SET  @SqlStr ='SET @rcount = (SELECT TOP(1) COUNT(1) IsExist  FROM '+ @TargetTableLink + ')'
    EXEC sp_executesql @SqlStr,
     N'@rcount INT OUTPUT',@rcount OUTPUT
	END
	if @rcount = 0
	BEGIN
		Print '@TargetTableLink ? ' + @TargetTableLink;	
		return
	END
END 


if @FieldNameBlackList IS NOT NULL AND @FieldNameBlackList != ''
BEGIN
	if OBJECT_ID('tempdb..##columnBlacklist', 'U') is not null  drop table ##columnBlacklist
	CREATE TABLE ##columnBlacklist (cname VARCHAR(100))
	DECLARE @index INT, @tempBlackList VARCHAR(max), @columnBlacklistCount INT = 0
	SET @index = - 1; SET @tempBlackList = @FieldNameBlackList;
	WHILE (LEN(@tempBlackList) > 0)
	BEGIN
		SET @index = CHARINDEX(',', @tempBlackList)
		IF (@index = 0)	AND (LEN(@tempBlackList) > 0)
		BEGIN
			INSERT INTO ##columnBlacklist
			VALUES (@tempBlackList)
			BREAK
		END

		IF (@index > 1)
		BEGIN
			INSERT INTO ##columnBlacklist
			VALUES (LEFT(@tempBlackList, @index - 1))
			SET @tempBlackList = RIGHT(@tempBlackList, (LEN(@tempBlackList) - @index))
		END
		ELSE
			SET @tempBlackList = RIGHT(@tempBlackList, (LEN(@tempBlackList) - @index))
	END--WHILE (LEN(@tempBlackList) > 0)
	SET @columnBlacklistCount  = (SELECT COUNT (*) FROM ##columnBlacklist)
	IF @columnBlacklistCount = 0
	BEGIN
		PRINT 'View field names in blacklist !'
		return;
	END
END
ELSE 
	SET @columnBlacklistCount  = 0

DECLARE @columnBlacklistFilter NVARCHAR(400) = ''
IF @columnBlacklistCount > 0
BEGIN
	SET @columnBlacklistFilter = '##columnBlacklist'
END



DECLARE @SQLtext NVARCHAR(MAX)
if OBJECT_ID('tempdb..##TempTablePkList', 'U') is not null  drop table ##TempTablePkList
--Get the pk(s) from specific table
Set @SQLtext =
'
USE [' + @DatabaseName + ']
select 
	ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS pos,
	schema_name(tab.schema_id) as [schema_name],     
	pk.[name] as pk_name,
    ic.index_column_id as column_id,
    col.[name] as column_name, 
    tab.[name] as table_name
INTO ##TempTablePkList
from sys.tables as tab
    inner join sys.indexes pk
        on tab.object_id = pk.object_id 
        and pk.is_primary_key = 1
    inner join sys.index_columns ic
        on ic.object_id = pk.object_id
        and ic.index_id = pk.index_id
    inner join sys.columns col
        on pk.object_id = col.object_id
        and col.column_id = ic.column_id
	' + (CASE WHEN @columnBlacklistFilter != '' THEN 'LEFT JOIN ' + @columnBlacklistFilter + ' AS filter on filter.cname = col.[name]' ELSE '' END) + '
where tab.[name] = ''' + @tableName + ''' ' + (CASE WHEN @columnBlacklistFilter != '' THEN 'AND filter.cname IS NULL' ELSE '' END) + '
order by schema_name(tab.schema_id),
    pk.[name],
    ic.index_column_id
'
--PRINT @SQLtext
EXEC(@SQLtext)

if OBJECT_ID('tempdb..##TempTablePkList', 'U') is null  OR (SELECT COUNT(*) FROM ##TempTablePkList) = 0
BEGIN
	PRINT 'No primary keys found in source table!'
	return;
END
--SELECT * FROM ##TempTablePkList
--#########################################################################################
if OBJECT_ID('tempdb..##TempTablecolumn_names', 'U') is not null  drop table ##TempTablecolumn_names
--get the rest
Set @SQLtext =
'
SELECT 
			ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS pos,
			t1.name as column_name, 	 
			t1.system_type_name as toTbl_Datatype, 	
			t1.is_nullable as toTbl_is_nullable, 		
			t1.is_identity_column as toTbl_is_identity,
			CASE WHEN t1.collation_name IS NOT NULL THEN t1.collation_name ELSE '''' END as collation_name,
			t1.max_length
INTO ##TempTablecolumn_names
FROM sys.dm_exec_describe_first_result_set (N''Select * From ' + @SourceTableLink + ''', NULL, 0) AS t1
LEFT JOIN ##TempTablePkList as t2 ON t2.column_name COLLATE DATABASE_DEFAULT = t1.name
' + (CASE WHEN @columnBlacklistFilter != '' THEN 'LEFT JOIN ' + @columnBlacklistFilter + ' AS filter on filter.cname COLLATE DATABASE_DEFAULT = t1.name' ELSE '' END) + '
WHERE t1.name != ''timestamp'' AND  t2.column_name is NULL ' + (CASE WHEN @columnBlacklistFilter != '' THEN 'AND filter.cname IS NULL' ELSE '' END) + '
'
PRINT @SQLtext
EXEC(@SQLtext)
if OBJECT_ID('tempdb..##TempTablecolumn_names', 'U') is null  OR (SELECT COUNT(*) FROM ##TempTablecolumn_names) = 0
BEGIN
	PRINT 'No column names found in source table!'
	return;
END
--SELECT * FROM ##TempTablecolumn_names
--#########################################################################################
--p. key names
--#########################################################################################
DECLARE @PK_STR_list NVARCHAR(MAX) = ''
DECLARE @PK_STR NVARCHAR(MAX) = ''
DECLARE @PK_STR_IS_NULL NVARCHAR(MAX) = ''

DECLARE @PkCount INT = (SELECT COUNT(*) FROM ##TempTablePkList)
DECLARE @Pos INT = 0
DECLARE @pk_name NVARCHAR(100) = ''

WHILE @Pos < @PkCount                          
BEGIN   
    select top(1)  @pk_name = '[' + column_name + ']' from ##TempTablePkList where pos = (@Pos+1)    
	--Print @pk_name    
	SET @PK_STR_list += 't1.' + @pk_name + ',' --(CASE WHEN @Pos < (@PkCount-1) THEN ', ' ELSE '' END)
	SET @PK_STR += 't1.' + @pk_name + ' = ' + 't2.' + @pk_name  + (CASE WHEN @Pos < (@PkCount-1) THEN ' AND ' ELSE '' END) + CHAR(13)	
	SET @PK_STR_IS_NULL += 't1.' + @pk_name + ' IS NULL ' + (CASE WHEN @Pos < (@PkCount-1) THEN ' AND ' ELSE '' END) + CHAR(13)		
	SET @Pos += 1;
END

if @PK_STR = '' OR @PK_STR_IS_NULL = ''
BEGIN
	PRINT '@PK_STR or @PK_STR_IS_NULL is empty!'
	return;
END
--#########################################################################################
--column names
--#########################################################################################
DECLARE @column_name_compare NVARCHAR(MAX) = ''
DECLARE @column_name_compareView NVARCHAR(MAX) = ''
DECLARE @column_name_list NVARCHAR(MAX) = ''
DECLARE @column_nameCount INT = (SELECT COUNT(*) FROM ##TempTablecolumn_names)
SET @Pos = 0
DECLARE @column_name NVARCHAR(100) = ''

WHILE @Pos < @column_nameCount                          
BEGIN   
    select top(1)  @column_name = '[' + column_name + ']' from ##TempTablecolumn_names where pos = (@Pos+1)    
	--Print @column_name   
	SET @column_name_list += 't1.' + @column_name + ', ' --+ (CASE WHEN @Pos < (@column_nameCount-1) THEN ', ' ELSE '' END)
	SET @column_name_compare += 't2.' + @column_name + ' != ' + 't1.' + @column_name  + (CASE WHEN @Pos < (@column_nameCount-1) THEN ' OR ' ELSE '' END) + CHAR(13)	
	SET @column_name_compareView += 't1.' + @column_name + ',' + CHAR(13) + 't2.' + @column_name + ' AS [T_' + REPLACE(REPLACE(@column_name,'[',''),']','') + '],' + CHAR(13) + ' (CASE WHEN t1.' + @column_name + ' != t2.' + @column_name + ' THEN ''X'' ELSE '''' END) AS [DIF' + CONVERT(Varchar(10),@Pos) + ']' + (CASE WHEN @Pos < (@column_nameCount-1) THEN ',' ELSE '' END)  + CHAR(13)
	SET @Pos += 1;
END
if @column_name_compare = ''
BEGIN
	PRINT '@column_name_compare is empty!'
	return;
END
--#########################################################################################
--#########################################################################################
--Count field diff
DECLARE @FieldDiff INT = 0;
Set @SQLtext =
'
--Count field diff
SET @FieldDiff = (
SELECT COUNT(*)
FROM $TargetTableLink$ AS t1 WITH (NOLOCK)
LEFT JOIN $SourceTableLink$ AS t2 WITH (NOLOCK) ON
(
$PK_STR$
)
WHERE 
$column_name_compare$
)
'
SET @SQLtext = REPLACE(@SQLtext,'$PK_STR$',@PK_STR);
SET @SQLtext = REPLACE(@SQLtext,'$column_name_compare$',@column_name_compare);
SET @SQLtext = REPLACE(@SQLtext,'$SourceTableLink$', @SourceTableLink );
SET @SQLtext = REPLACE(@SQLtext,'$TargetTableLink$',@TargetTableLink);
--PRINT @SQLtext
EXEC sp_executesql @SQLtext,
     N'        
      @FieldDiff INT OUTPUT
	  ',
	  @FieldDiff OUTPUT
--#########################################################################################
--#########################################################################################
--table count diff
DECLARE @CountDiff INT = 0;
PRINT @line + @line;
Set @SQLtext =
'
--table count diff

DECLARE @targetCount INT =
(SELECT COUNT(*) [Diff count to Source] FROM $TargetTableLink$ AS t1 WITH (NOLOCK))
PRINT''$TargetTableLink$ count:'' 
PRINT @targetCount
DECLARE @sourceCount INT =
(SELECT COUNT(*) FROM $SourceTableLink$ AS t1 WITH (NOLOCK))
PRINT''$SourceTableLink$ count:'' 
PRINT @sourceCount
SET @CountDiff  = @targetCount - @sourceCount
'
SET @SQLtext = REPLACE(@SQLtext,'$PK_STR$',@PK_STR);
SET @SQLtext = REPLACE(@SQLtext,'$column_name_compare$',@column_name_compare);
SET @SQLtext = REPLACE(@SQLtext,'$SourceTableLink$', @SourceTableLink );
SET @SQLtext = REPLACE(@SQLtext,'$TargetTableLink$',@TargetTableLink);
--PRINT @SQLtext
EXEC sp_executesql @SQLtext,
     N'        
      @CountDiff INT OUTPUT
	  ',
	  @CountDiff OUTPUT
--#########################################################################################
--#########################################################################################


Set @SQLtext =
'
SELECT DISTINCT ''$ProcessId$'' AS ProcessId,
	@FieldDiff AS [Diff Fields],
	@CountDiff AS [Diff count to Source],
	COUNT(*) AS [Diff PKEY count to Source]	
FROM $TargetTableLink$ AS t1 WITH (NOLOCK)
LEFT JOIN $SourceTableLink$ AS t2 WITH (NOLOCK) ON 
(
$PK_STR$
)
WHERE 
$PK_STR_IS_NULL$
'
SET @SQLtext = REPLACE(@SQLtext,'$column_name_list$',@column_name_list);
SET @SQLtext = REPLACE(@SQLtext,'$PK_STR$',@PK_STR);
SET @SQLtext = REPLACE(@SQLtext,'$PK_STR_IS_NULL$',@PK_STR_IS_NULL);
SET @SQLtext = REPLACE(@SQLtext,'$column_name_compare$',@column_name_compare);
SET @SQLtext = REPLACE(@SQLtext,'$SourceTableLink$', @SourceTableLink );
SET @SQLtext = REPLACE(@SQLtext,'$TargetTableLink$',@TargetTableLink);
SET @SQLtext = REPLACE(@SQLtext,'$ProcessId$',@ProcessId);
SET @SQLtext = @line + @line + @SQLtext + @line + @line
PRINT @SQLtext
EXEC sp_executesql @SQLtext,
     N'        
      @FieldDiff INT,
	  @CountDiff INT
	  ',
	  @FieldDiff,
	  @CountDiff


--#########################################################################################
--#########################################################################################
IF @CountDiff != 0
BEGIN
	IF @CountDiff < 0
	BEGIN	
	Set @SQLtext =
		'
		--View count diff. in table
		SELECT	
			''Source'' AS ORIGIN,
			$PK_STR_list$
			$column_name_list$	
			FROM  $SourceTableLink$ AS t1 WITH (NOLOCK)
			LEFT JOIN $TargetTableLink$ AS t2 WITH (NOLOCK) ON
			(
		$PK_STR$
			)
			WHERE 
		$PK_STR_IS_NULL$		
		'
	END
	ELSE
	BEGIN
	Set @SQLtext =
		'
		--View count diff. in table
		SELECT	
			''Target'' AS ORIGIN,
			$PK_STR_list$
			$column_name_list$	
			FROM  $TargetTableLink$ AS t1 WITH (NOLOCK)
			LEFT JOIN $SourceTableLink$ AS t2 WITH (NOLOCK) ON
			(
		$PK_STR$
			)
			WHERE 
		$PK_STR_IS_NULL$		
		'	
	END
		
		SET @column_name_list = SUBSTRING(@column_name_list,0,LEN(@column_name_list))
		SET @PK_STR_IS_NULL = REPLACE(@PK_STR_IS_NULL,'t1','t2')

		SET @SQLtext = REPLACE(@SQLtext,'$column_name_list$',@column_name_list);
		SET @SQLtext = REPLACE(@SQLtext,'$PK_STR$',@PK_STR);
		SET @SQLtext = REPLACE(@SQLtext,'$PK_STR_IS_NULL$',@PK_STR_IS_NULL);
		SET @SQLtext = REPLACE(@SQLtext,'$column_name_compare$',@column_name_compare);
		SET @SQLtext = REPLACE(@SQLtext,'$SourceTableLink$', @SourceTableLink );
		SET @SQLtext = REPLACE(@SQLtext,'$TargetTableLink$',@TargetTableLink);
		SET @SQLtext = REPLACE(@SQLtext,'$ProcessId$',@ProcessId);
		SET @SQLtext = REPLACE(@SQLtext,'$column_name_compareView$',@column_name_compareView);
		SET @SQLtext = REPLACE(@SQLtext,'$PK_STR_list$',@PK_STR_list);
		SET @SQLtext = REPLACE(@SQLtext,'$ifDiff_TOP$',@ifDiff_TOP);
		--PRINT @SQLtext
		EXEC sp_executesql @SQLtext
END
--#########################################################################################
--#########################################################################################
--View diff. in table
IF @FieldDiff = 0 GOTO EndProg
Set @SQLtext =
'
--View diff. in table
SELECT	
	DISTINCT 
	$ifDiff_TOP$
	''$ProcessId$'' AS ProcessId, 
$PK_STR_list$	
$column_name_compareView$		
	FROM $TargetTableLink$ AS t1 WITH (NOLOCK)
	LEFT JOIN $SourceTableLink$ AS t2 WITH (NOLOCK) ON
	(
$PK_STR$
	)
	WHERE 
$column_name_compare$		
'
SET @SQLtext = REPLACE(@SQLtext,'$column_name_list$',@column_name_list);
SET @SQLtext = REPLACE(@SQLtext,'$PK_STR$',@PK_STR);
SET @SQLtext = REPLACE(@SQLtext,'$PK_STR_IS_NULL$',@PK_STR_IS_NULL);
SET @SQLtext = REPLACE(@SQLtext,'$column_name_compare$',@column_name_compare);
SET @SQLtext = REPLACE(@SQLtext,'$SourceTableLink$', @SourceTableLink );
SET @SQLtext = REPLACE(@SQLtext,'$TargetTableLink$',@TargetTableLink);
SET @SQLtext = REPLACE(@SQLtext,'$ProcessId$',@ProcessId);
SET @SQLtext = REPLACE(@SQLtext,'$column_name_compareView$',@column_name_compareView);
SET @SQLtext = REPLACE(@SQLtext,'$PK_STR_list$',@PK_STR_list);
SET @SQLtext = REPLACE(@SQLtext,'$ifDiff_TOP$',@ifDiff_TOP);

PRINT @line + @line + @SQLtext + @line + @line
EXEC sp_executesql @SQLtext

EndProg:

Print 'PKeys:'
Print @PK_STR_list
Print 'Fields:'
Print @column_name_list

--clean up
if OBJECT_ID('tempdb..##TempTablePkList', 'U') is not null  drop table ##TempTablePkList
if OBJECT_ID('tempdb..##TempTablecolumn_names', 'U') is not null  drop table ##TempTablecolumn_names
if OBJECT_ID('tempdb..##columnBlacklist', 'U') is not null  drop table ##columnBlacklist
