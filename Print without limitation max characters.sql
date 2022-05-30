--USE []
--GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




/*
Author: Ingolf Hill
Date:   February 2015
Notes: 
https://stackoverflow.com/questions/7850477/how-to-print-varcharmax-using-print-statement
*/
ALTER PROCEDURE [dbo].[PrintAll] (@String VARCHAR(MAX))
AS
BEGIN
	
	
    -- SET NOCOUNT ON reduces network overhead
    SET NOCOUNT ON;

    DECLARE @MsgLen int;
    DECLARE @CurrLineStartIdx int = 1;
    DECLARE @CurrLineEndIdx int;
    DECLARE @CurrLineLen int;   
    DECLARE @SkipCount int;
	DECLARE @MaxLen INT =  8000;

    -- Normalise line end characters.
    SET @String = REPLACE(@String, char(13) + char(10), char(10));
    SET @String = REPLACE(@String, char(13), char(10));

    -- Store length of the normalised string.
    SET @MsgLen = LEN(@String);        

    -- Special case: Empty string.
    IF @MsgLen = 0
    BEGIN
        PRINT '';
        RETURN;
    END

    -- Find the end of next substring to print.
    SET @CurrLineEndIdx = CHARINDEX(CHAR(10), @String);
    
	IF @CurrLineEndIdx BETWEEN 1 AND @MaxLen
    BEGIN
        SET @CurrLineEndIdx = @CurrLineEndIdx - 1
        SET @SkipCount = 2;
    END
    ELSE
    BEGIN
        SET @CurrLineEndIdx = @MaxLen;
        SET @SkipCount = 1;
    END     

    -- Loop: Print current substring, identify next substring (a do-while pattern is preferable but TSQL doesn't have one).
    WHILE @CurrLineStartIdx < @MsgLen
    BEGIN
        -- Print substring.
        PRINT SUBSTRING(@String, @CurrLineStartIdx, (@CurrLineEndIdx - @CurrLineStartIdx)+1);

        -- Move to start of next substring.
        SET @CurrLineStartIdx = @CurrLineEndIdx + @SkipCount;

        -- Find the end of next substring to print.
        SET @CurrLineEndIdx = CHARINDEX(CHAR(10), @String, @CurrLineStartIdx);
        SET @CurrLineLen = @CurrLineEndIdx - @CurrLineStartIdx;

        -- Find bounds of next substring to print.              
        IF @CurrLineLen BETWEEN 1 AND @MaxLen
        BEGIN
            SET @CurrLineEndIdx = @CurrLineEndIdx - 1
            SET @SkipCount = 2;
        END
        ELSE
        BEGIN
            SET @CurrLineEndIdx = @CurrLineStartIdx + @MaxLen + 1;
            SET @SkipCount = 1;
        END
    END --@CurrLineStartIdx < @MsgLen
END
