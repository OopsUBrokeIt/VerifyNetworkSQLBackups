Use dbadmin

DECLARE @BakcupFolder as varchar(max) = '\\Backups\SQLBackups$\' --This is the network location of backups
 DECLARE @BackupDirectory SYSNAME = @BakcupFolder

  IF OBJECT_ID('tempdb..#DirTree') IS NOT NULL
    DROP TABLE #DirTree

  CREATE TABLE #DirTree (
    Id int identity(1,1),
    SubDirectory nvarchar(255),
    Depth smallint,
    FileFlag bit,
    ParentDirectoryID int
   )

INSERT INTO #DirTree (SubDirectory, Depth, FileFlag)
EXEC master..xp_dirtree @BackupDirectory, 10, 1
--Don't want to look at the files with DIFF in them or .trn, or .txt files.
DELETE FROM #DirTree
where SubDirectory Like( '%DIFF%')
DELETE FROM #DirTree
where SubDirectory Like( '%.trn')
DELETE FROM #DirTree
where SubDirectory Like( '%.txt')
DELETE FROM #DirTree
where SubDirectory Like( '%.SQL')

--I am going to ignore Master, Model, MSDB, DBadmin mostly because I already have these on the server and don't want to deal with renaming of databases.
DELETE FROM #DirTree
where SubDirectory Like( '%Master%') 
or SubDirectory Like( '%Model%') 
or SubDirectory Like( '%MSDB%') 
or SubDirectory Like( '%Dbadmin%')


   UPDATE #DirTree
   SET ParentDirectoryID = (
    SELECT MAX(Id) FROM #DirTree d2
    WHERE Depth = d.Depth - 1 AND d2.Id < d.Id
   )
   FROM #DirTree d

  DECLARE 
    @ID INT,
    @BackupFile VARCHAR(MAX),
    @Depth TINYINT,
    @FileFlag BIT,
    @ParentDirectoryID INT,
    @wkSubParentDirectoryID INT,
    @wkSubDirectory VARCHAR(MAX),
	@counter int

	--First time using a cursor. Purpose is to go through each of the rows in #DirTree
  DECLARE FileCursor CURSOR LOCAL FORWARD_ONLY FOR
  SELECT * FROM #DirTree WHERE FileFlag = 1

  OPEN FileCursor
  FETCH NEXT FROM FileCursor INTO 
    @ID,
    @BackupFile,
    @Depth,
    @FileFlag,
    @ParentDirectoryID  

  SET @wkSubParentDirectoryID = @ParentDirectoryID

  WHILE @@FETCH_STATUS = 0
  BEGIN
    --loop to generate path in reverse, starting with backup file then prefixing subfolders in a loop
    WHILE @wkSubParentDirectoryID IS NOT NULL
    BEGIN
      SELECT @wkSubDirectory = SubDirectory, @wkSubParentDirectoryID = ParentDirectoryID 
      FROM #DirTree 
      WHERE ID = @wkSubParentDirectoryID

      SELECT @BackupFile = @wkSubDirectory + '\' + @BackupFile
    END

    --no more subfolders in loop so now prefix the root backup folder
    SELECT @BackupFile = @BackupDirectory + @BackupFile

	SELECT @counter = Count(*) FROM BackupFiles where FileNamePath = @BackupFile
	If(@counter = 0)
	Begin
    --put backupfile into a table and then later work out which ones are log and full backups  
		INSERT INTO BackupFiles (FileNamePath, dbname) VALUES(@BackupFile, @BackupDirectory)
		--print @backupfile + ' ' + @backupdirectory
	END
    FETCH NEXT FROM FileCursor INTO 
      @ID,
      @BackupFile,
      @Depth,
      @FileFlag,
      @ParentDirectoryID 

    SET @wkSubParentDirectoryID = @ParentDirectoryID      
  END

  CLOSE FileCursor
  DEALLOCATE FileCursor
  --These files are one offs, or don't follow our normal naming conventions was making it harder to loop through and get the info I need.
  DELETE FROM BackupFiles WHERE FileNamePath LIKE '%SQL Archives - DO NOT DELETE%'
  DELETE FROM BackupFiles WHERE FileNamePath LIKE '%Copy_only%'
  DELETE FROM BackupFiles WHERE FileNamePath LIKE '%.sqlaudit'
  DELETE FROM BackupFiles WHERE FileNamePath LIKE '%PowerShell_%'
  DELETE FROM BackupFiles WHERE FileNamePath Not LIKE '%.bak'
  
  Select *
  --DELETE
  from BackupFiles
  where restored IS NULL


 Declare  @idbackup int
		,@idbackupMax int
		,@dbname varchar(max)
		,@TodbRestored varchar(max)
		, @FileName varchar(max)
		, @executestring varchar(max)
		,@datafile varchar(MAX)
		,@logFile varchar(max)
		,@LogicalNameData varchar(max)
		,@LogicalNameLog varchar(max)
		,@datebackup varchar(max)
	
 Select @idbackup = min(id) from BackupFiles   where restored IS NULL 
  
 Select @idbackupMax = MAX(id) from BackupFiles   where restored IS NULL

 --SET @idbackupMax = 1
 WHILE (@idbackup <= @idbackupMax)
 BEGIN
		--Trying to start working out the database name that is in the string of the backup.
		Select @dbname = REPLACE (filenamepath , '\\Backups\SQLBackups$\', ''), @filename = FileNamePath  FROM BackupFiles where id = @idbackup
		--PRINT @dbname
		--Print  CHARINDEX('\FULL',@dbname)-1
		--SET @dbname = Right(@dbname, CHARINDEX('\', Reverse(@dbname))-1)
		SET @dbname =  LEFT(@dbname, CHARINDEX('\FULL',@dbname)-1)
		--print CHARINDEX('\',@dbname)
		--PRINT @dbname
		SET @dbname = Right(@dbname, CHARINDEX('\', Reverse(@dbname))-1)
		--SET @dbname = REPLACE(@dbname, substring(@dbname, 0,Charindex('\',@dbname)+1), '')
	--	Print @dbname
		
	 update BackupFiles 
	 set dbname = @dbname
	 where id = @idbackup
	
	Set @TodbRestored = @dbname
				print @filename

			INSERT INTO FILE_LIST EXEC ('RESTORE FILELISTONLY FROM DISK = ''' + @filename + '''')
	
		--SELECT *
		--FROM File_list

		Select @datafile = PhysicalName, @LogicalNameData = LogicalName From File_List where Type = 'D'
		Select @logFile = PhysicalName, @LogicalNameLog = LogicalName From File_List where Type = 'L'


		--Set @datafile = Replace(@datafile,'U:\', 'S:\SQL_Mounts\Data\')
		--Set @logFile = Replace(@logFile,'V:\', 'S:\SQL_Mounts\Logs\')

		SET @datafile = Right(@datafile, CHARINDEX('\', Reverse(@datafile))-1)
		--Print @datafile
		SET @logFile = Right(@logFile, CHARINDEX('\', Reverse(@logFile))-1)
		--Print @logFile
		--Select @datafile, @logFile
		SET @datafile = 'S:\SQL_Mounts\Data\' + @datafile
		Set @logfile = 'S:\SQL_Mounts\Logs\' + @logFile

		SET @datebackup = Right(@FileName, CHARINDEX('_LLUF_', Reverse(@FileName))-1) --Since the string is in reverse needed to look for FULL but in reverse. Not pretty but it worked for me.
		SET @datebackup = LEFT(@datebackup, CHARINDEX('_', @datebackup)-1)
		print @datebackup

	update BackupFiles 
	 set DataLogical = @LogicalNameData,
	 LogLogical = @LogicalNameLog,
	 DataphysicalPath = @datafile,
	 LogphysicalPath = @logFile,
	 dateofbackup = convert(datetime,@datebackup,112)
	 where id = @idbackup
	 
		 SET @idbackup = @idbackup + 1

 END

 SELECT *
 FROM BackupFiles
--Used these variables below for testing the second portion of the code.
 Declare  @idbackup int
		,@idbackupMax int
		,@dbname nvarchar(max)
		,@TodbRestored nvarchar(max)
		, @FileName nvarchar(max)
		, @executestring nvarchar(max)
		,@datafile nvarchar(MAX)
		,@logFile nvarchar(max)
		,@LogicalNameData nvarchar(max)
		,@LogicalNameLog nvarchar(max)
		,@datebackup nvarchar(max)
	
 Select @idbackup = min(id) from BackupFiles where restored is null
 --set @idbackup = 253
 Select @idbackupMax = MAX(id) from BackupFiles where restored is null
 --set @idbackupMax = 252
 WHILE (@idbackup <= @idbackupMax)
 BEGIN
		Select @dbname =dbname, @datafile = DataphysicalPath, @LogicalNameData = DataLogical, @logFile = LogphysicalPath, @LogicalNameLog = LogLogical, @FileName = FileNamePath  FROM BackupFiles where id = @idbackup


	RESTORE DATABASE  @dbname 
	FROM DISK = @FileName 
	WITH FILE = 1 ,MOVE @LogicalNameData TO @datafile ,MOVE @LogicalNameLog TO @logFile
	,NOUNLOAD
	,REPLACE
	,STATS = 5
	--Print @executestring
	--Exec @executestring
	
	EXEC( 'DBCC CHECKDB ('+ @dbname +')')

		update BackupFiles
		SET restored = 1, dbccCheck = 1
		WHERE id = @idbackup

		
EXEC ('DROP DATABASE ' + @dbname)


		 SET @idbackup = @idbackup + 1

 END
 --SELECT *
 --FROM BackupFiles
 --ORDER by ID

