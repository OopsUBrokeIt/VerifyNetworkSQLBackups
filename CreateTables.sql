USE dbadmin
 IF OBJECT_ID('dbadmin..BackupFiles') IS NOT NULL
 DROP TABLE BackupFiles
 Create Table BackupFiles
 (
 id int identity (1,1),
 FileNamePath VARCHAR(MAX),
 dbname varchar(max),
 dbccCheck bit,
 DataLogical varchar(64),
 LogLogical varchar(64),
 DataphysicalPath varchar(130),
 LogphysicalPath varchar(130),
 dateofbackup datetime,
 restored bit

 )
 USE dbadmin
 IF OBJECT_ID('dbadmin..File_list') IS NOT NULL
 DROP TABLE File_list

 CREATE TABLE File_list (
 LogicalName VARCHAR(64),
 PhysicalName VARCHAR(130),
 [Type] VARCHAR(1),
 FileGroupName VARCHAR(64),
 Size DECIMAL(20, 0),
 MaxSize DECIMAL(25,0),
 FileID bigint,
 CreateLSN DECIMAL(25,0),
 DropLSN DECIMAL(25,0),
 UniqueID UNIQUEIDENTIFIER,
 ReadOnlyLSN DECIMAL(25,0),
 ReadWriteLSN DECIMAL(25,0),
 BackupSizeInBytes DECIMAL(25,0),
 SourceBlockSize INT,
 filegroupid INT,
 loggroupguid UNIQUEIDENTIFIER,
 differentialbaseLSN DECIMAL(25,0),
 differentialbaseGUID UNIQUEIDENTIFIER,
 isreadonly BIT,
 ispresent BIT,
 TDEThumbprint varbinary(32),
 SnapshotURL nvarchar(360))
