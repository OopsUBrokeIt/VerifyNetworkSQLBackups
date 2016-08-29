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
restored bit,
backuptype varchar(10), --new column
primarybackup int, --new column
Servername varchar(20) -- new column
,Diffbackup int --new column
,Dateadded Datetime NULL CONSTRAINT [DF_BackupFiles_TimeStamp] DEFAULT (GETDATE())
,DateofDbcccheck datetime
)
IF OBJECT_ID('dbadmin..File_list') IS NOT NULL
DROP TABLE File_list
--This table finds out information about the back up file
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
 
IF OBJECT_ID('dbadmin..[dbcc_history]') IS NOT NULL
DROP TABLE [dbcc_history]
--This table is for tracking the dbcc output.
CREATE TABLE [dbo].[dbcc_history](
[Error] [int] NULL,
[Level] [int] NULL,
[State] [int] NULL,
[MessageText] [varchar](7000) NULL,
[RepairLevel] [int] NULL,
[Status] [int] NULL,
[DbId] [int] NULL,
[DbIdFragId] [int] NULL,
[ObjectId] [int] NULL,
[IndexId] [int] NULL,
[PartitionId] [int] NULL,
[AllocUnitId] [int] NULL,
[RidDblD] [int] NULL,
[RidPruld] [int] NULL,
[File] [int] NULL,
[Page] [int] NULL,
[Slot] [int] NULL,
[RefDblD] [int] NULL,
[RefPruld] [int] NULL,
[RefFile] [int] NULL,
[RefPage] [int] NULL,
[RefSlot] [int] NULL,
[Allocation] [int] NULL,
[Databasename] varchar(50) NULL,
[ServerName] varchar(50) NULL,
[TimeStamp] [datetime] NULL CONSTRAINT [DF_dbcc_history_TimeStamp] DEFAULT (GETDATE())
) ON [PRIMARY]
GO
