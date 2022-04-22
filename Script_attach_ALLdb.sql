USE master
GO
 
CREATE PROCEDURE [dbo].[usp_MultiAttachSingleMDFFiles] ( @mdfTempDir nvarchar(500) )
AS
BEGIN  
   DECLARE @dirstmt       nvarchar(1000)
   DECLARE @currFile      nvarchar(160)
   DECLARE @db_name       nvarchar(256)
   DECLARE @phys_name     nvarchar(520)
   DECLARE @dbccstmt      nvarchar(1000)
   DECLARE @db2attch_ver  INT
   DECLARE @curr_srv_ver  INT  
   DECLARE @mdfFileNames  TABLE (mdfFile nvarchar(260))
   DECLARE @mdfFileATTR   TABLE (attrName sql_variant, attrValue sql_variant)
   
   DECLARE cf CURSOR FOR SELECT mdfFile FROM @mdfFileNames

   SET NOCOUNT ON

   -- get all mdf file names only , in bare format.
   SET @dirstmt = 'dir /b "' + @mdfTempDir + '"\*.mdf'

   INSERT into @mdfFileNames 
   EXEC xp_cmdshell @dirstmt
   
   DELETE from @mdfFileNames where mdfFile IS NULL or mdfFile = 'File Not Found'

   -- if file is already attached skip it
   DELETE FROM @mdfFileNames 
   WHERE mdfFile IN (SELECT mdfFile FROM @mdfFileNames a INNER JOIN sys.master_files b ON lower(@mdfTempDir + '\' + a.mdfFile) = lower(b.physical_name) )

   -- if no files exist then exit process
   IF not exists (SELECT TOP 1 * FROM @mdfFileNames)
   BEGIN
      PRINT 'No files found to process'
      RETURN
   END

   -- get the current server database version
   SELECT  @curr_srv_ver = CONVERT (int,DATABASEPROPERTYEX('master', 'version'))

   BEGIN TRY

      OPEN cf

      FETCH NEXT FROM cf INTO @currFile

      WHILE @@FETCH_STATUS = 0 
      BEGIN 
 
         SET @phys_name =  @mdfTempDir + '\' + @currFile
         SET @dbccstmt = 'DBCC checkprimaryfile (' + '"' + @phys_name + '"' + ',2)'

         INSERT INTO @mdfFileATTR 
         EXEC (@dbccstmt)
         
         SELECT @db_name = convert (nvarchar(256), attrValue)
         FROM @mdfFileATTR
         WHERE attrName = 'Database name'
      
         -- get the candidate to be attached db version
         SELECT @db2attch_ver = convert (int, attrValue)
         FROM @mdfFileATTR
         WHERE attrName = 'Database version'

         -- if the current server database version is less that the attached db version 
         -- OR
         -- if the database already exists then skip the attach 
         -- print an appropriate message message
         IF (@db2attch_ver > @curr_srv_ver)
            OR
            (exists (SELECT 1 
                     FROM sys.databases d 
                     WHERE RTRIM(LTRIM(lower(d.name))) = RTRIM(LTRIM(lower(@db_name)))))
         BEGIN 
            PRINT ''
            PRINT ' Attach for database ' + @db_name + ' was not performed! '
            PRINT ' Possible reasons : ' 
            PRINT '1. ' +  @db_name + ' DB version is higher that the currnet server version.'
            PRINT '2. ' +  @db_name + ' DB already exists on server.'
            PRINT ''
         END 
         ELSE 
         BEGIN 
            EXEC sp_attach_single_file_db @dbname= @db_name , @physname = @phys_name
            PRINT ''
            PRINT 'Database "' + @db_name + '" attached to server OK using file ' + @currFile + '".'
            PRINT ''
            DELETE FROM @mdfFileATTR
         END 

         FETCH NEXT FROM cf INTO @currFile

      END 
    
      CLOSE cf
      DEALLOCATE cf
   END TRY
   BEGIN CATCH
      PRINT 'Error while attaching FILE ' + @phys_name + ',...Exiting procedure'
      CLOSE cf
      DEALLOCATE cf
   END CATCH 

   SET NOCOUNT OFF
END 
GO


-- how to use
		
		1--  ENABEL sys.xp_cmdshell

EXECUTE sp_configure 'show advanced options', 1;  
GO  
---- To update the currently configured value for advanced options.  
RECONFIGURE;  
GO  
---- To enable the feature.  
EXECUTE sp_configure 'xp_cmdshell', 1;  
GO  
---- To update the currently configured value for this feature.  
RECONFIGURE;  
GO  


-----------------------------------------------------------------
	-- 2  RUN THE PROCEDURE

 USE master
 GO
 EXEC dbo.usp_MultiAttachSingleMDFFiles 'E:\DATABASES'
 GO 

 -- IF YOU GOT THIS 
 --"An error occurred when attaching the database(s). Click the hyperlink in the Message colum"
 -- MAKE SURE YOU  GIVE Full Control access to the Users for those .mdf and .ldf