--https://www.mssqltips.com/sqlservertip/4824/easy-way-to-compare-sql-server-table-schemas/
--By: Matteo Lorini
--A mapping of table names has been added, I.Hill

DECLARE @TableFromLink  VARCHAR(MAX) = '[sourceServer].[database].[dbo].[sourceTable]'
DECLARE @TableToLink  VARCHAR(MAX) = '[ImportToServer].[database].[dbo].[ImportToTable]'
DECLARE @LinkMapping  VARCHAR(MAX) = '[Test].[dbo].[TempMappingTable]'

DECLARE @DynSql nvarchar(max) = ''
DECLARE @NewMappingTable BIT = 1 


IF @NewMappingTable = 1
BEGIN
		----------------------------------------------------------------------------------------------------------
		--Create a mapping table and save the field data
		IF OBJECT_ID(@LinkMapping , 'U') is not null	BEGIN SET @DynSql = 'DROP TABLE ' + @LinkMapping; EXEC(@DynSql); END
		SET @DynSql = 
		'
		CREATE TABLE ' + @LinkMapping + '( 
			ColumnName VARCHAR(MAX) NOT NULL, 
			ColumnNameMapping VARCHAR(MAX) DEFAULT '''',
			Import BIT DEFAULT 1,
			Datatype VARCHAR(MAX) NOT NULL, 
			IsNullable BIT,
			IsIdentity BIT,
			MaxLength INT,
			collation_name VARCHAR(MAX) DEFAULT '''',
			ConvertStr VARCHAR(MAX) DEFAULT ''''	
			)

		INSERT INTO ' + @LinkMapping + ' (ColumnName, ColumnNameMapping, Datatype, IsNullable, IsIdentity, collation_name ,MaxLength)
		SELECT 
			toTbl.name as toTbl_ColumnName, 	 
			toTbl.name as toTbl_ColumnName,
			toTbl.system_type_name as toTbl_Datatype, 	
			toTbl.is_nullable as toTbl_is_nullable, 		
			toTbl.is_identity_column as toTbl_is_identity,
			CASE WHEN toTbl.collation_name IS NOT NULL THEN toTbl.collation_name ELSE '''' END,
			toTbl.max_length
		FROM sys.dm_exec_describe_first_result_set (N''Select * From ' + @TableFromLink + ''', NULL, 0) AS toTbl		
		----------------------------------------------------------------------------------------------------------
		----------------------------------------------------------------------------------------------------------
		'
		PRINT @DynSql
		EXEC(@DynSql)
END

IF OBJECT_ID('tempdb..##MappingTable', 'U') is not null	DROP TABLE ##MappingTable
SET @DynSql = 'SELECT * INTO ##MappingTable FROM ' + @LinkMapping; EXEC(@DynSql);



SELECT 
		
	
	Source.ColumnName as Source_ColumnName, 	
	Source.ColumnNameMapping AS SourceMapping,
	toTbl.name as toTbl_ColumnName,
	
	CASE WHEN Source.ColumnNameMapping != toTbl.name THEN 'X' ELSE '' END AS nameDIff,	 
	Source.IsNullable as Source_is_nullable,
	toTbl.is_nullable as toTbl_is_nullable,
	CASE WHEN toTbl.is_nullable != Source.IsNullable THEN 'X' ELSE '' END AS nullDIff,
	Source.Datatype as Source_Datatype,
	toTbl.system_type_name as toTbl_Datatype, 	 	
	CASE WHEN Source.Datatype  != toTbl.system_type_name THEN 'X' ELSE '' END AS typeDIff,
	Source.MaxLength AS Source_length,
	toTbl.max_length AS toTbl_length,			
	CASE WHEN Source.MaxLength  != toTbl.max_length THEN 'X' ELSE '' END AS lengthDIff,
	Source.IsIdentity as Source_is_identity,
	toTbl.is_identity_column as toTbl_is_identity, 	
	CASE WHEN toTbl.is_identity_column != Source.IsIdentity THEN 'X' ELSE '' END AS idenDIff,	
	Source.collation_name AS Source_collation_name, 
	CASE WHEN toTbl.collation_name  IS NOT NULL THEN toTbl.collation_name  ELSE '' END AS toTbl_collation_name,
	CASE WHEN toTbl.collation_name != Source.collation_name THEN 'X' ELSE '' END AS collationDIff

FROM sys.dm_exec_describe_first_result_set (N'Select * From ' + @TableToLink, NULL, 0) AS toTbl 
FULL OUTER JOIN  ##MappingTable AS Source 
ON UPPER(toTbl.name) = UPPER(Source.ColumnNameMapping) 
WHERE 
		Source.Import = 1 
		--AND
		--Source.ColumnName IS NOT NULL AND 
		--(
		--toTbl.name IS NULL OR
		--Source.ColumnNameMapping IS NULL OR
		--toTbl.name != Source.ColumnNameMapping OR
		--toTbl.is_nullable != Source.IsNullable OR
		--toTbl.system_type_name != Source.Datatype OR
		--toTbl.max_length != Source.MaxLength OR
		--toTbl.is_identity_column != Source.IsIdentity OR
		--toTbl.collation_name != Source.collation_name
		--)
