/*
A quick data comparison for specific table fields on different servers.

It is often necessary to make a statement about the data equality for certain fields of a table in distributed databases.
The fields can be determined in the small script and the various table links are also given.
It is important that linked servers are also available on the executing server.

Ein schneller Datenvergleich für bestimmte Tabellen-Felder auf verschiedenen Servern.

Oft ist es notwendig, auf verteilten Datenbanken eine Aussage über die Datengleichheit für bestimmte Felder einer Tabelle zu treffen. 
In dem kleinen Skript können die Felder bestimmt werden und weiter werden die verschiedenen Tabellen Links angegeben. 
Wichtig ist das auf dem ausführenden Server auch Linked Server vorhanden sind

ingolf hill werferstein.org 06.2022
*/


DECLARE @FieldList NVARCHAR(MAX) ='[Index], [Field 1], [Field 2].............etc'

DECLARE @DbLinkTABLE TABLE(pos int IDENTITY(1,1), dblink VARCHAR(400) COLLATE database_default,[checksum] BIGINT, [count] BIGINT, result VARCHAR(400))
INSERT INTO @DbLinkTABLE(dblink)
VALUES
('[XX.XX.XX.XX].[database].[dbo].[table]'),						--Link 1
('[XX.XX.XX.XX].[database].[dbo].[table]'),						--Link 2
('[XX.XX.XX.XX].[database].[dbo].[table]'),						--Link 3
('[XX.XX.XX.XX].[database].[dbo].[table]'),						--Link 4
('[XX.XX.XX.XX].[database].[dbo].[table]'),						--Link 5
('[XX.XX.XX.XX].[database].[dbo].[table]') 						--Link 6


DECLARE @sqlText NVARCHAR(MAX) ='', @DBlink NVARCHAR(400) ='', @checksum BIGINT = 0, @count BIGINT = 0,@checksumBefore BIGINT = -1, @countBefore BIGINT = -1,@result NVARCHAR(400) ='NO'
DECLARE @countDbLink INT = (SELECT COUNT(*) FROM @DbLinkTABLE),@pos INT = 1

PRINT 'Field list:' + @FieldList
WHILE @pos <= @countDbLink
BEGIN  
 SELECT @DBlink = dblink FROM @DbLinkTABLE WHERE pos = @pos
 IF @DBlink != ''
	BEGIN
		SET @sqlText =
N'select
	@Count = count_big(*), @Checksum = sum (convert(numeric, binary_checksum($FieldList$))) 
FROM $DBlink$ WITH (TABLOCK HOLDLOCK)
'
		SET @sqlText = REPLACE(@sqlText,'$FieldList$',@FieldList);SET @sqlText = REPLACE(@sqlText,'$DBlink$',@DBlink);
		EXEC sp_executesql @sqlText,N'@Checksum BIGINT OUTPUT,@Count BIGINT OUTPUT',@checksum OUTPUT,@count OUTPUT 
		SET @result = (CASE WHEN @checksumBefore > 0 AND @countBefore > 0 THEN (CASE WHEN @checksumBefore != @checksum OR @countBefore != @count THEN ' ERROR !!' ELSE ' OK' END)ELSE '' END);		
		PRINT 'nr: ' + CONVERT(VARCHAR(40),@pos) + ' ' + @DBlink + ' @count: ' + CONVERT(VARCHAR(40),@count) + ' checksum: ' + CONVERT(VARCHAR(40),@checksum) + @result
		UPDATE @DbLinkTABLE SET result = @result, [checksum] = @checksum,[count] = @count Where pos = @pos		
		SET @checksumBefore = @checksum
		SET @countBefore = @count
	END--IF @DBlink != ''
	SET @pos += 1;
END --WHILE @pos <= @countDbLink


SELECT * FROM @DbLinkTABLE
