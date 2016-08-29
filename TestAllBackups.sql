/*
Allow restore level to determine how many files it will find and search for.
Allow the ability to exlude databases.
Look into how to have it cycle through all databases.
*/
/*
Thank you to Ross Presser that pointed me towards the stack overflow site:
http://stackoverflow.com/questions/5946813/how-to-catch-the-output-of-a-dbcc-statement-in-a-temptable/5950913#5950913
for the answer
*/
SET NOCOUNT ON;
USE dbadmin
 
DECLARE @servername AS VARCHAR(20)
,@DatabaseName AS VARCHAR(20) --To be a variable set by end user
,@RestoreLevel AS VARCHAR(20)
,@LatestOnly BIT
,@BackupFolder AS VARCHAR(max)
,@count INT
,@counter INT
,@startdate DATETIME
,@enddate DATETIME
,@ID INT
,@BackupFile VARCHAR(MAX)
,@Depth TINYINT
,@FileFlag BIT
,@ParentDirectoryID INT
,@wkSubParentDirectoryID INT
,@wkSubDirectory VARCHAR(MAX)
,@filetype VARCHAR(10)
,@idbackup INT
,@idbackupMax INT
,@dbname VARCHAR(max) --variable to be set by system while do functions through the code.
,@TodbRestored VARCHAR(max)
,@FileName VARCHAR(max)
,@executestring VARCHAR(max)
,@datafile VARCHAR(MAX)
,@logFile VARCHAR(max)
,@LogicalNameData VARCHAR(max)
,@LogicalNameLog VARCHAR(max)
,@datebackup VARCHAR(200)
,@backupType VARCHAR(2)
,@diffbackup INT
,@numDiffs INT
,@diffID INT
 
SET @LatestOnly = 1 --1 for getting the most reacent backup only.
SET @servername = 'SQLBOX1'
SET @DatabaseName = 'Databasename'
SET @BackupFolder = '\\Backups\SQLBackups$\' --This is the network location of backups
--SET @RestoreLevel = 'D' --F, D, L depending on how deep you want to restore it too. Not Functional yet.
--Restorelevel does nothing at this point
IF OBJECT_ID('tempdb..#dbnames') IS NOT NULL
DROP TABLE #dbnames;
 
CREATE TABLE #dbnames (dbname VARCHAR(50))
 
IF OBJECT_ID('tempdb..#tempfull') IS NOT NULL
DROP TABLE #tempfull;
 
CREATE TABLE #tempfull (
ID INT
,dbname VARCHAR(20)
,Dateofbackup DATETIME
,Servername VARCHAR(50)
,restored BIT
)
 
IF OBJECT_ID('tempdb..#DirTree') IS NOT NULL
DROP TABLE #DirTree
 
CREATE TABLE #DirTree (
Id INT identity(1, 1)
,SubDirectory NVARCHAR(255)
,Depth SMALLINT
,FileFlag BIT
,ParentDirectoryID INT
)
 
IF OBJECT_ID('tempdb..#tmpF') IS NOT NULL
DROP TABLE #tmpF;
 
CREATE TABLE #tmpF (
ID INT
,startdate DATETIME
,enddate DATETIME
,Servername VARCHAR(20)
,dbname VARCHAR(20)
)
 
IF OBJECT_ID('tempdb..#tmpD') IS NOT NULL
DROP TABLE #tmpD;
 
CREATE TABLE #tmpd (
ID INT
,startdate DATETIME
,enddate DATETIME
,Servername VARCHAR(20)
,dbname VARCHAR(20)
)
 
IF (
@servername IS NOT NULL
AND @DatabaseName IS NULL
)
BEGIN
SET @BackupFolder = @BackupFolder + @servername + '\'
END
 
IF (
@servername IS NOT NULL
AND @DatabaseName IS NOT NULL
)
BEGIN
SET @BackupFolder = @BackupFolder + @servername + '\' + @DatabaseName + '\'
END
 
--SET @BackupFolder = '\\Backups\SQLBackups$\' --This is the network location of backups
DECLARE @BackupDirectory SYSNAME = @BackupFolder
 
--SELECT @BackupDirectory
INSERT INTO #DirTree (
SubDirectory
,Depth
,FileFlag
)
EXEC master..xp_dirtree @BackupDirectory
,10
,1
 
DELETE
FROM #DirTree
WHERE SubDirectory LIKE ('%.txt')
 
DELETE
FROM #DirTree
WHERE SubDirectory LIKE ('%.SQL')
 
--I am going to ignore Master, Model, MSDB, DBadmin mostly because I already have these on the server and don't want to deal with renaming of databases.
DELETE
FROM #DirTree
WHERE SubDirectory LIKE ('%Master%')
OR SubDirectory LIKE ('%Model%')
OR SubDirectory LIKE ('%MSDB%')
OR SubDirectory LIKE ('%Dbadmin%')
 
UPDATE #DirTree
SET ParentDirectoryID = (
SELECT MAX(Id)
FROM #DirTree d2
WHERE Depth = d.Depth - 1
AND d2.Id &amp;amp;lt; d.Id
)
FROM #DirTree d
 
--First time using a cursor. Purpose is to go through each of the rows in #DirTree
--Got this code from a coworker not sure where he got it. So credit for the cursor to an internet stranger.
DECLARE FileCursor CURSOR LOCAL FORWARD_ONLY
FOR
SELECT *
FROM #DirTree
WHERE FileFlag = 1
 
OPEN FileCursor
 
FETCH NEXT
FROM FileCursor
INTO @ID
,@BackupFile
,@Depth
,@FileFlag
,@ParentDirectoryID
 
SET @wkSubParentDirectoryID = @ParentDirectoryID
 
WHILE @@FETCH_STATUS = 0
BEGIN
--loop to generate path in reverse, starting with backup file then prefixing subfolders in a loop
WHILE @wkSubParentDirectoryID IS NOT NULL
BEGIN
SELECT @wkSubDirectory = SubDirectory
,@wkSubParentDirectoryID = ParentDirectoryID
FROM #DirTree
WHERE ID = @wkSubParentDirectoryID
 
SELECT @BackupFile = @wkSubDirectory + '\' + @BackupFile
END
 
--no more subfolders in loop so now prefix the root backup folder
SELECT @BackupFile = @BackupDirectory + @BackupFile
 
SELECT @counter = Count(*)
FROM BackupFiles
WHERE FileNamePath = @BackupFile
 
IF (@counter = 0)
BEGIN
IF (
@servername IS NOT NULL
AND @DatabaseName IS NULL
)
BEGIN
INSERT INTO BackupFiles (
FileNamePath
,dbname
,Servername
)
VALUES (
@BackupFile
,@BackupDirectory
,@servername
)
END
 
IF (
@servername IS NOT NULL
AND @DatabaseName IS NOT NULL
)
BEGIN
INSERT INTO BackupFiles (
FileNamePath
,dbname
,Servername
)
VALUES (
@BackupFile
,@DatabaseName
,@servername
)
END
 
IF (
@servername IS NULL
AND @DatabaseName IS NULL
)
BEGIN
INSERT INTO BackupFiles (
FileNamePath
,dbname
)
VALUES (
@BackupFile
,@BackupDirectory
)
END
--put backupfile into a table and then later work out which ones are log and full backups
--print @backupfile + ' ' + @backupdirectory
END
 
FETCH NEXT
FROM FileCursor
INTO @ID
,@BackupFile
,@Depth
,@FileFlag
,@ParentDirectoryID
 
SET @wkSubParentDirectoryID = @ParentDirectoryID
END
 
CLOSE FileCursor
 
DEALLOCATE FileCursor
 
--These files are one offs, or don't follow our normal naming conventions was making it harder to loop through and get the info I need.
DELETE
FROM BackupFiles
WHERE FileNamePath LIKE '%SQL Archives - DO NOT DELETE%'
 
DELETE
FROM BackupFiles
WHERE FileNamePath LIKE '%Copy_only%'
 
DELETE
FROM BackupFiles
WHERE FileNamePath LIKE '%.sqlaudit'
 
DELETE
FROM BackupFiles
WHERE FileNamePath LIKE '%PowerShell_%'
 
-- DELETE FROM BackupFiles WHERE FileNamePath Not LIKE '%.bak' OR FileNamePath NOT LIKE '%.trn'
--Select *
--from BackupFiles
SELECT @idbackup = min(id)
FROM BackupFiles
WHERE restored IS NULL
 
SELECT @idbackupMax = MAX(id)
FROM BackupFiles
WHERE restored IS NULL
 
--SET @idbackupMax = 1
WHILE (@idbackup &amp;amp;lt;= @idbackupMax)
BEGIN
--Trying to start working out the database name that is in the string of the backup.
SELECT @dbname = REPLACE(filenamepath, '\\Backups\SQLBackups$\', '') --Could probably change out that backup path to be a variable instead.
,@filename = FileNamePath
FROM BackupFiles
WHERE id = @idbackup
 
IF CHARINDEX('\FULL', @FileName) &amp;amp;gt; 0
BEGIN
SET @dbname = LEFT(@dbname, CHARINDEX('\FULL', @dbname) - 1)
SET @backupType = 'F'
END
 
IF CHARINDEX('\DIFF', @FileName) &amp;amp;gt; 0
BEGIN
SET @dbname = LEFT(@dbname, CHARINDEX('\DIFF', @dbname) - 1)
SET @backupType = 'D'
END
 
IF CHARINDEX('\LOG', @FileName) &amp;amp;gt; 0
BEGIN
SET @dbname = LEFT(@dbname, CHARINDEX('\LOG', @dbname) - 1)
SET @backupType = 'L'
END
 
SET @dbname = Right(@dbname, CHARINDEX('\', Reverse(@dbname)) - 1)
 
UPDATE BackupFiles
SET dbname = @dbname
WHERE id = @idbackup
 
SET @TodbRestored = @dbname
 
IF CHARINDEX('FULL', @FileName) &amp;amp;gt; 0
BEGIN
INSERT INTO FILE_LIST
EXEC ('RESTORE FILELISTONLY FROM DISK = ''' + @filename + '''')
IF((SELECT Count(*) FROM File_List WHERE Type = 'D')&amp;amp;gt; 1)
BEGIN
Print 'More than one data file panic'
--will need to add a new table that we can keep track of the datafiles for each database and have that key tie into the backup.
Break
END
SELECT @datafile = PhysicalName
,@LogicalNameData = LogicalName
FROM File_List
WHERE Type = 'D'
 
SELECT @logFile = PhysicalName
,@LogicalNameLog = LogicalName
FROM File_List
WHERE Type = 'L'
END
 
SET @datafile = Right(@datafile, CHARINDEX('\', Reverse(@datafile)) - 1)
SET @logFile = Right(@logFile, CHARINDEX('\', Reverse(@logFile)) - 1)
--The following could be an issue if you are dealing with multiple ndf files on top of the standard Mdf.
SET @datafile = 'S:\SQL_Mounts\Data\' + @datafile
SET @logfile = 'S:\SQL_Mounts\Logs\' + @logFile
 
IF CHARINDEX('FULL', @FileName) &amp;amp;gt; 0
BEGIN
SET @datebackup = Right(@FileName, CHARINDEX('_LLUF_', Reverse(@FileName)) - 1) --Since the string is in reverse needed to look for FULL but in reverse. Not pretty but it worked for me.
SET @datebackup = Replace(@datebackup, '_', ' ')
END
 
IF CHARINDEX('_DIFF_', @FileName) &amp;amp;gt; 0
BEGIN
SET @datebackup = Right(@FileName, CHARINDEX('_FFID_', Reverse(@FileName)) - 1) --Since the string is in reverse needed to look for DIFF but in reverse. Not pretty but it worked for me.
SET @datebackup = Replace(@datebackup, '_', ' ')
END
 
IF CHARINDEX('_LOG_', @FileName) &amp;amp;gt; 0
BEGIN
SET @datebackup = Right(@FileName, CHARINDEX('_GOL_', Reverse(@FileName)) - 1) --Since the string is in reverse needed to look for LOG but in reverse. Not pretty but it worked for me.
SET @datebackup = Replace(@datebackup, '_', ' ')
END
 
SET @datebackup = Replace(@datebackup, '.bak', '')
SET @datebackup = LTRIM(@datebackup)
SET @datebackup = SUBSTRING(@datebackup, 1, 4) + '-' + SUBSTRING(@datebackup, 5, 2) + '-' + SUBSTRING(@datebackup, 7, 2) + ' ' + SUBSTRING(@datebackup, 10, 2) + ':' + SUBSTRING(@datebackup, 12, 2) + ':' + SUBSTRING(@datebackup, 14, 2)
 
UPDATE BackupFiles
SET DataLogical = @LogicalNameData
,LogLogical = @LogicalNameLog
,DataphysicalPath = @datafile
,LogphysicalPath = @logFile
,dateofbackup = convert(DATETIME, @datebackup, 120)
,backuptype = @backupType
WHERE id = @idbackup
 
SET @idbackup = @idbackup + 1
END
 
--SELECT *
--FROM BackupFiles
INSERT INTO #tmpF (
ID
,startdate
,enddate
,Servername
,dbname
)
SELECT ID
,Dateofbackup AS startdate
,isnull(lead(dateofbackup) OVER (
ORDER BY dateofbackup ASC
), '9999-12-31') AS enddate
,Servername
,dbname
FROM backupfiles bf
WHERE backuptype = 'F'
 
INSERT INTO #tmpD (
ID
,startdate
,enddate
,Servername
,dbname
)
SELECT ID
,Dateofbackup AS startdate
,isnull(lead(dateofbackup) OVER (
ORDER BY dateofbackup ASC
), '9999-12-31') AS enddate
,Servername
,dbname
FROM backupfiles bf
WHERE backuptype = 'D'
 
SELECT @count = Count(*)
FROM #tmpF
 
WHILE (@count &amp;amp;gt; 0)
BEGIN
SELECT @id = id
FROM #tmpF
WHERE startdate = (
SELECT MIN(startdate)
FROM #tmpF
)
 
PRINT @id
 
SELECT @startdate = startdate
,@enddate = enddate
,@servername = servername
,@dbname = dbname
FROM #tmpF
WHERE ID = @id
 
UPDATE BackupFiles
SET primarybackup = tf.ID
FROM #tmpF tf
WHERE dateofbackup &amp;amp;gt; @startdate
AND dateofbackup &amp;amp;lt; @enddate
AND tf.dbname = @dbname
AND @servername = @servername
 
DELETE
FROM #tmpF
WHERE ID = @id
 
SET @count = @count - 1;
END
 
SELECT @count = Count(*)
FROM #tmpD
 
WHILE (@count &amp;amp;gt; 0)
BEGIN
SELECT @id = id
FROM #tmpD
WHERE startdate = (
SELECT MIN(startdate)
FROM #tmpD
)
 
PRINT @id
 
SELECT @startdate = startdate
,@enddate = enddate
,@servername = servername
,@dbname = dbname
FROM #tmpD
WHERE ID = @id
 
UPDATE BackupFiles
SET Diffbackup = tD.ID
FROM #tmpD tD
WHERE dateofbackup &amp;amp;gt; @startdate
AND dateofbackup &amp;amp;lt; @enddate
AND td.dbname = @dbname
AND @servername = @servername
 
DELETE
FROM #tmpd
WHERE ID = @id
 
SET @count = @count - 1;
END
 
IF (@LatestOnly = 1)
BEGIN
IF (@DatabaseName IS NOT NULL)
BEGIN
SET @Count = 1
END
ELSE
BEGIN
INSERT INTO #dbnames (dbname)
SELECT DISTINCT dbname from BackupFiles WHERE servername = @servername
SElECT @Count = count(*) from #dbnames
END
WHILE(@count &amp;amp;gt; 0)
IF (@idbackup IS NOT NULL)
BEGIN
IF (@DatabaseName IS NOT NULL)
BEGIN
SELECT TOP 1 @idbackup = ID
FROM BackupFiles
WHERE backuptype = 'F'
AND dbname = @DatabaseName
ORDER BY dateofbackup DESC
 
SELECT @numDiffs = Count(*)
FROM BackupFiles
WHERE backuptype = 'D'
AND primarybackup = @idbackup
 
END
ELSE
/*
If we enter the else loop it will dbcc check all the latest databases backups
*/
BEGIN
SELECT TOP 1 @dbname = dbname from #dbnames
Delete from #dbnames where dbname = @dbname
 
SELECT TOP 1 @idbackup = ID
FROM BackupFiles
WHERE backuptype = 'F'
AND dbname = @dbname
ORDER BY dateofbackup DESC
SELECT @idbackup
SELECT @numDiffs = Count(*)
FROM BackupFiles
WHERE backuptype = 'D'
AND primarybackup = @idbackup
SELECT @numDiffs
END
IF (@numDiffs &amp;amp;gt; 0)
BEGIN
--Put in a check to see if a restore is necessary, Meaning if we just checked both the full and the diff we don't need to check it again.
IF (
(
SELECT TOP 1 restored
FROM BackupFiles
WHERE primarybackup = @idbackup
AND backuptype = 'D'
ORDER BY dateofbackup DESC
) IS NULL
)
BEGIN
SELECT @dbname = dbname
,@datafile = DataphysicalPath
,@LogicalNameData = DataLogical
,@logFile = LogphysicalPath
,@LogicalNameLog = LogLogical
,@FileName = FileNamePath
FROM BackupFiles
WHERE id = @idbackup
 
RESTORE DATABASE @dbname
FROM DISK = @FileName
WITH FILE = 1
,MOVE @LogicalNameData TO @datafile
,MOVE @LogicalNameLog TO @logFile
,NOUNLOAD
,NORECOVERY
,REPLACE
,STATS = 5
 
SELECT TOP 1 @diffid = id
,@dbname = dbname
,@FileName = FileNamePath
FROM BackupFiles
WHERE primarybackup = @idbackup
AND backuptype = 'D'
ORDER BY dateofbackup DESC
 
RESTORE DATABASE @dbname
FROM DISK = @FileName
WITH FILE = 1
,NOUNLOAD
,STATS = 5
END
END
ELSE
BEGIN
IF (
(
SELECT TOP 1 restored
FROM BackupFiles
WHERE primarybackup = @idbackup
AND backuptype = 'F'
ORDER BY dateofbackup DESC
) IS NULL
)
BEGIN
SELECT @dbname = dbname
,@datafile = DataphysicalPath
,@LogicalNameData = DataLogical
,@logFile = LogphysicalPath
,@LogicalNameLog = LogLogical
,@FileName = FileNamePath
FROM BackupFiles
WHERE id = @idbackup
 
RESTORE DATABASE @dbname
FROM DISK = @FileName
WITH FILE = 1
,MOVE @LogicalNameData TO @datafile
,MOVE @LogicalNameLog TO @logFile
,NOUNLOAD
,REPLACE
,STATS = 5
END
 
END
IF EXISTS (Select name from Sys.Databases where name = @dbname)
BEGIN
INSERT INTO dbcc_history (
[Error]
,[Level]
,[State]
,[MessageText]
,[RepairLevel]
,[Status]
,[DbId]
,[DbIdFragId]
,[ObjectId]
,[IndexId]
,[PartitionId]
,[AllocUnitId]
,[RidDblD]
,[RidPruld]
,[File]
,[Page]
,[Slot]
,[RefDblD]
,[RefPruld]
,[RefFile]
,[RefPage]
,[RefSlot]
,[Allocation]
)
EXEC ('dbcc checkdb(''' + @dbname + ''') with tableresults')
 
UPDATE dbcc_history
SET databaseName = @dbname
,servername = @servername
WHERE databaseName IS NULL
 
UPDATE BackupFiles
SET restored = 1
,dbccCheck = 1
WHERE id = @idbackup
IF (@diffID IS NOT NULL)
UPDATE BackupFiles
SET restored = 1
,dbccCheck = 1
WHERE id = @diffID
 
EXEC ('DROP DATABASE ' + @dbname)
END
ELSE Print 'Most recent backup already checked'
SET @count = @count - 1
END
END
