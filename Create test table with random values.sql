--Preset the variables
DECLARE 
	@NoOfRows INT = 10000,
	@StartVal INT = 50000,
	@EndVal	  INT = 1000000
DECLARE 
	@Range	  INT = (@EndVal - @StartVal + 1)

--Create the test table with "random values" integers and floats
IF OBJECT_ID('tempdb..#tempTestData', 'U') is not null DROP TABLE #tempTestData
SELECT TOP (@NoOfRows) 	
	RandomInteger =  ABS(CHECKSUM(NEWID())) % @Range + @StartVal, 
	RandomFloat = RAND(CHECKSUM(NEWID())) * @Range + @StartVal	
INTO #tempTestData
FROM sys.all_columns ac1
CROSS JOIN sys.all_columns ac2


IF OBJECT_ID('tempdb..##tempTestData', 'U') is not null DROP TABLE ##tempTestData
SELECT 
	ROW_NUMBER() OVER (ORDER BY RandomInteger)  No,
	RandomInteger,
	RandomFloat
INTO ##tempTestData
FROM #tempTestData
IF OBJECT_ID('tempdb..#tempTestData', 'U') is not null DROP TABLE #tempTestData


SELECT 
* 
FROM ##tempTestData
