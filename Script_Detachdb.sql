
DECLARE @dbName varchar(255); -- To store database name 
DECLARE DBCURSOR CURSOR FOR
    SELECT name
    FROM sys.databases 
    WHERE len(owner_sid)>1; -- All user databases
 
OPEN DBCURSOR
FETCH Next from DBCURSOR INTO @dbName
WHILE @@FETCH_STATUS = 0 
BEGIN
     EXEC sp_detach_db  @dbName 
	PRINT CHAR(10) -- CHAR(10) for newline 
    + 'GO' + CHAR(10) 
    + 'Detach of ' + @dbName + ' database completed successfully'''
    + CHAR(10) + 'GO'
    FETCH NEXT FROM DBCURSOR INTO @dbName
END
 
CLOSE DBCURSOR    
DEALLOCATE DBCURSOR