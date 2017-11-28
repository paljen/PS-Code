EXEC susdb.dbo.spGetObsoleteUpdatesToCleanup

USE SUSDB
GO
IF object_id('tempdb..#MyTempTable') is not null  DROP TABLE #MyTempTable
GO
IF (SELECT CURSOR_STATUS('global','myCursor')) >= -1
BEGIN
DEALLOCATE myCursor
END
GO
sp_configure 'Show Advanced Options', 1
GO
RECONFIGURE
GO
sp_configure 'Ad Hoc Distributed Queries', 1
GO
RECONFIGURE
GO

SELECT TOP (5000) * INTO #MyTempTable
    FROM OPENROWSET('SQLNCLI', 'Server=(local);Trusted_Connection=yes;', 'EXEC susdb.dbo.spGetObsoleteUpdatesToCleanup')

DECLARE myCursor CURSOR FOR
SELECT LocalUpdateID FROM #MyTempTable

DECLARE @x INT	
DECLARE @Msg VARCHAR(50)
DECLARE @Count INT
SELECT @Count = COUNT(*) FROM #MyTempTable

SELECT @msg = 'Number of updates to be deleted:' +  CAST( @Count AS VARCHAR(10))
RAISERROR(@msg, 0, 1) WITH NOWAIT

OPEN myCursor
FETCH NEXT FROM myCursor INTO @x

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @msg = 'Deleting update with ID:' + CAST (@x AS VARCHAR(10))
    RAISERROR(@msg, 0, 1) WITH NOWAIT
    EXEC spDeleteUpdate @localUpdateID=@x
   
    FETCH NEXT FROM myCursor INTO @x
END
CLOSE myCursor;
DEALLOCATE myCursor;
DROP TABLE #MyTempTable;
SELECT @msg = 'Deletion completed'
    RAISERROR(@msg, 0, 1) WITH NOWAIT