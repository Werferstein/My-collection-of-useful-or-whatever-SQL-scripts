/*
Copyright (C) 2015
www.werferstein.org
Ingolf Hill

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

http://www.gnu.de//documents/gpl.de.html
*/



Use master;
Go


SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
Set NoCount ON
GO


DECLARE @UserDb VARCHAR(200) = 'databaseForTheLogindata'--Database in which the data is stored
DECLARE @SaveToUserDb BIT = 0							-- 1-> save the data in the local database 
														-- 0-> Reading the data from a local database and storing in the server


--If no value was entered, then the data are stored in the local database
DECLARE	@PartnerServer sysname = ''						--NameOfTheLinkedServer
--When debug is turned on, no data are written to the server but only as output text.
DECLARE @Debug bit = 1


Declare @MaxID int,
	@CurrID int,
	@SQL nvarchar(max),
	@LoginName sysname,
	@IsDisabled int,
	@Type char(1),
	@SID varbinary(85),
	@SIDString nvarchar(100),
	@PasswordHash varbinary(256),
	@PasswordHashString nvarchar(300),
	@RoleName sysname,
	@Machine sysname,
	@PermState nvarchar(60),
	@PermName sysname,
	@Class tinyint,
	@MajorID int,
	@ErrNumber int,
	@ErrSeverity int,
	@ErrState int,
	@ErrProcedure sysname,
	@ErrLine int,
	@ErrMsg nvarchar(2048)

IF  OBJECT_ID('tempdb..##tempLogins300','U') IS NOT NULL DROP TABLE ##tempLogins300
CREATE Table ##tempLogins300 (LoginID int identity(1, 1) not null primary key,
						[Name] sysname not null,
						[SID] varbinary(85) not null,
						IsDisabled int not null,
						[Type] char(1) not null,
						PasswordHash varbinary(256) null)

IF  OBJECT_ID('tempdb..##tempRoles300','U') IS NOT NULL DROP TABLE ##tempRoles300
CREATE Table ##tempRoles300  (RoleID int identity(1, 1) not null primary key,
					RoleName sysname not null,
					LoginName sysname not null)

IF  OBJECT_ID('tempdb..##tempPerms300','U') IS NOT NULL DROP TABLE ##tempPerms300
CREATE Table ##tempPerms300 (PermID int identity(1, 1) not null primary key,
					LoginName sysname not null,
					PermState nvarchar(60) not null,
					PermName sysname not null,
					Class tinyint not null,
					ClassDesc nvarchar(60) not null,
					MajorID int not null,
					SubLoginName sysname null,
					SubEndPointName sysname null)

Set NoCount On;

If CharIndex('\', @PartnerServer) > 0
  Begin
	Set @Machine = LEFT(@PartnerServer, CharIndex('\', @PartnerServer) - 1);
  End
Else
  Begin
	Set @Machine = @PartnerServer;
  End



IF @PartnerServer != ''  SET @PartnerServer = QUOTENAME(@PartnerServer) +'.' 

--true -> the data are not read from the specified Linked Server connection but from the local database
IF @PartnerServer = '' AND @UserDb != '' AND @SaveToUserDb = 0 GOTO ReadFromDb




-- Get all Windows logins from principal server
Set @SQL = 'Select P.name, P.sid, P.is_disabled, P.type, L.password_hash' + CHAR(10) +
		'From ' + @PartnerServer + 'master.sys.server_principals P' + CHAR(10) +
		'Left Join ' + @PartnerServer + 'master.sys.sql_logins L On L.principal_id = P.principal_id' + CHAR(10) +
		'Where P.type In (''U'', ''G'', ''S'')' + CHAR(10) +
		'And P.name <> ''sa''' + CHAR(10) +
		'And P.name Not Like ''##%''' + CHAR(10) +
		'And CharIndex(''' + @Machine + '\'', P.name) = 0;';

Insert Into ##tempLogins300 (Name, SID, IsDisabled, Type, PasswordHash)
Exec sp_executesql @SQL;

IF @Debug = 1 PRINT @SQL


-- Get all roles from principal server
Set @SQL = 'Select RoleP.name, LoginP.name' + CHAR(10) +
		'From ' + @PartnerServer + 'master.sys.server_role_members RM' + CHAR(10) +
		'Inner Join ' + @PartnerServer + 'master.sys.server_principals RoleP' +
		CHAR(10) + char(9) + 'On RoleP.principal_id = RM.role_principal_id' + CHAR(10) +
		'Inner Join ' + @PartnerServer + 'master.sys.server_principals LoginP' +
		CHAR(10) + char(9) + 'On LoginP.principal_id = RM.member_principal_id' + CHAR(10) +
		'Where LoginP.type In (''U'', ''G'', ''S'')' + CHAR(10) +
		'And LoginP.name <> ''sa''' + CHAR(10) +
		'And LoginP.name Not Like ''##%''' + CHAR(10) +
		'And RoleP.type = ''R''' + CHAR(10) +
		'And CharIndex(''' + @Machine + '\'', LoginP.name) = 0;';

Insert Into ##tempRoles300 (RoleName, LoginName)
Exec sp_executesql @SQL;

IF @Debug = 1 PRINT @SQL

-- Get all explicitly granted permissions
Set @SQL = 'Select P.name Collate database_default,' + CHAR(10) +
		'	SP.state_desc, SP.permission_name, SP.class, SP.class_desc, SP.major_id,' + CHAR(10) +
		'	SubP.name Collate database_default,' + CHAR(10) +
		'	SubEP.name Collate database_default' + CHAR(10) +
		'From ' + @PartnerServer + 'master.sys.server_principals P' + CHAR(10) +
		'Inner Join ' + @PartnerServer + 'master.sys.server_permissions SP' + CHAR(10) +
		CHAR(9) + 'On SP.grantee_principal_id = P.principal_id' + CHAR(10) +
		'Left Join ' + @PartnerServer + 'master.sys.server_principals SubP' + CHAR(10) +
		CHAR(9) + 'On SubP.principal_id = SP.major_id And SP.class = 101' + CHAR(10) +
		'Left Join ' + @PartnerServer + 'master.sys.endpoints SubEP' + CHAR(10) +
		CHAR(9) + 'On SubEP.endpoint_id = SP.major_id And SP.class = 105' + CHAR(10) +
		'Where P.type In (''U'', ''G'', ''S'')' + CHAR(10) +
		'And P.name <> ''sa''' + CHAR(10) +
		'And P.name Not Like ''##%''' + CHAR(10) +
		'And CharIndex(''' + @Machine + '\'', P.name) = 0;'

IF @Debug = 1 PRINT @SQL
Insert Into ##tempPerms300 (LoginName, PermState, PermName, Class, ClassDesc, MajorID, SubLoginName, SubEndPointName)
Exec sp_executesql @SQL;



------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------



ReadFromDb:

IF @PartnerServer = '' AND @UserDb != ''
BEGIN

	IF @SaveToUserDb = 1
		BEGIN
		   SET @SQL = 
		   '
			SELECT  Name, SID, IsDisabled, Type, PasswordHash  into ' + @UserDb + '.dbo.Logins FROM ##tempLogins300
			SELECT  RoleName, LoginName  into ' + @UserDb + '.dbo.Roles FROM ##tempRoles300
			SELECT  LoginName, PermState, PermName, Class, ClassDesc, MajorID, SubLoginName, SubEndPointName  into ' + @UserDb + '.dbo.Perms FROM ##tempPerms300
		   '
		   IF @Debug = 1 PRINT @SQL
		   EXEC(@SQL) 

			GOTO ENDE1

		END
	ELSE 
		BEGIN

			SET @SQL = 'SELECT LoginName, PermState, PermName, Class, ClassDesc, MajorID, SubLoginName, SubEndPointName FROM ' + @UserDb + '.dbo.Perms'
			Insert Into ##tempPerms300 (LoginName, PermState, PermName, Class, ClassDesc, MajorID, SubLoginName, SubEndPointName)
			Exec sp_executesql @SQL;


			SET @SQL = 'SELECT RoleName, LoginName FROM ' + @UserDb + '.dbo.Roles'
			Insert Into ##tempRoles300 (RoleName, LoginName)
			Exec sp_executesql @SQL;

			SET @SQL = 'SELECT Name, SID, IsDisabled, Type, PasswordHash FROM ' + @UserDb + '.dbo.Logins'
			Insert Into ##tempLogins300 (Name, SID, IsDisabled, Type, PasswordHash)
			Exec sp_executesql @SQL;
		END
END


------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------



Select @MaxID = Max(LoginID), @CurrID = 1
From ##tempLogins300;

While @CurrID <= @MaxID
  Begin
	Select @LoginName = Name,
		@IsDisabled = IsDisabled,
		@Type = [Type],
		@SID = [SID],
		@PasswordHash = PasswordHash
	From ##tempLogins300
	Where LoginID = @CurrID;
	
	If Not Exists (Select 1 From sys.server_principals
				Where name = @LoginName)
	  Begin
		Set @SQL = 'Create Login ' + quotename(@LoginName)
		If @Type In ('U', 'G')
		  Begin
			Set @SQL = @SQL + ' From Windows;'
		  End
		Else
		  Begin
			Set @PasswordHashString = '0x' +
				Cast('' As XML).value('xs:hexBinary(sql:variable("@PasswordHash"))', 'nvarchar(300)');
			
			Set @SQL = @SQL + ' With Password = ' + @PasswordHashString + ' HASHED, ';
			
			Set @SIDString = '0x' +
				Cast('' As XML).value('xs:hexBinary(sql:variable("@SID"))', 'nvarchar(100)');
			Set @SQL = @SQL + 'SID = ' + @SIDString + ';';
		  End

		If @Debug = 0
		  Begin
			Begin Try
				Exec sp_executesql @SQL;
			End Try
			Begin Catch
				Set @ErrNumber = ERROR_NUMBER();
				Set @ErrSeverity = ERROR_SEVERITY();
				Set @ErrState = ERROR_STATE();
				Set @ErrProcedure = ERROR_PROCEDURE();
				Set @ErrLine = ERROR_LINE();
				Set @ErrMsg = ERROR_MESSAGE();
				RaisError(@ErrMsg, 1, 1);
			End Catch
		  End
		Else
		  Begin
			Print @SQL;
		  End
		
		If @IsDisabled = 1
		  Begin
			Set @SQL = 'Alter Login ' + quotename(@LoginName) + ' Disable;'
			If @Debug = 0
			  Begin
				Begin Try
					Exec sp_executesql @SQL;
				End Try
				Begin Catch
					Set @ErrNumber = ERROR_NUMBER();
					Set @ErrSeverity = ERROR_SEVERITY();
					Set @ErrState = ERROR_STATE();
					Set @ErrProcedure = ERROR_PROCEDURE();
					Set @ErrLine = ERROR_LINE();
					Set @ErrMsg = ERROR_MESSAGE();
					RaisError(@ErrMsg, 1, 1);
				End Catch
			  End
			Else
			  Begin
				Print @SQL;
			  End
		  End
		End
	Set @CurrID = @CurrID + 1;
  End

Select @MaxID = Max(RoleID), @CurrID = 1
From ##tempRoles300;

While @CurrID <= @MaxID
  Begin
	Select @LoginName = LoginName,
		@RoleName = RoleName
	From ##tempRoles300
	Where RoleID = @CurrID;

	If Not Exists (Select 1 From sys.server_role_members RM
				Inner Join sys.server_principals RoleP
					On RoleP.principal_id = RM.role_principal_id
				Inner Join sys.server_principals LoginP
					On LoginP.principal_id = RM.member_principal_id
				Where LoginP.type In ('U', 'G', 'S')
				And RoleP.type = 'R'
				And RoleP.name = @RoleName
				And LoginP.name = @LoginName)
	  Begin
		If @Debug = 0
		  Begin
			Exec sp_addsrvrolemember @rolename = @RoleName,
							@loginame = @LoginName;
		  End
		Else
		  Begin
			Print 'Exec sp_addsrvrolemember @rolename = ''' + @RoleName + ''',';
			Print '		@loginame = ''' + @LoginName + ''';';
		  End
	  End

	Set @CurrID = @CurrID + 1;
  End

Select @MaxID = Max(PermID), @CurrID = 1
From ##tempPerms300;

While @CurrID <= @MaxID
  Begin
	Select @PermState = PermState,
		@PermName = PermName,
		@Class = Class,
		@LoginName = LoginName,
		@MajorID = MajorID,
		@SQL = PermState + space(1) + PermName + SPACE(1) +
			Case Class When 101 Then 'On Login::' + QUOTENAME(SubLoginName)
					When 105 Then 'On ' + ClassDesc + '::' + QUOTENAME(SubEndPointName)
					Else '' End +
			' To ' + QUOTENAME(LoginName) + ';'
	From ##tempPerms300
	Where PermID = @CurrID;
	
	If Not Exists (Select 1 From sys.server_principals P
				Inner Join sys.server_permissions SP On SP.grantee_principal_id = P.principal_id
				Where SP.state_desc = @PermState
				And SP.permission_name = @PermName
				And SP.class = @Class
				And P.name = @LoginName
				And SP.major_id = @MajorID)
	  Begin
		If @Debug = 0
		  Begin
			Begin Try
				Exec sp_executesql @SQL;
			End Try
			Begin Catch
				Set @ErrNumber = ERROR_NUMBER();
				Set @ErrSeverity = ERROR_SEVERITY();
				Set @ErrState = ERROR_STATE();
				Set @ErrProcedure = ERROR_PROCEDURE();
				Set @ErrLine = ERROR_LINE();
				Set @ErrMsg = ERROR_MESSAGE();
				RaisError(@ErrMsg, 1, 1);
			End Catch
		  End
		Else
		  Begin
			Print @SQL;
		  End
	  End

	Set @CurrID = @CurrID + 1;
  End

Set NoCount Off;


ENDE1:
