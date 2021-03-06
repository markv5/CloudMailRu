library MailRuCloud;

{$R *.dres}

uses
	SysUtils,
	DateUtils,
	windows,
	Classes,
	PLUGIN_TYPES,
	IdSSLOpenSSLHeaders,

	messages,
	inifiles,
	Vcl.controls,
	AnsiStrings,
	CloudMailRu in 'CloudMailRu.pas',
	MRC_Helper in 'MRC_Helper.pas',
	Accounts in 'Accounts.pas' {AccountsForm} ,
	RemoteProperty in 'RemoteProperty.pas' {PropertyForm} ,
	ConnectionManager in 'ConnectionManager.pas';

{$IFDEF WIN64}
{$E wfx64}
{$ENDIF}
{$IFDEF WIN32}
{$E wfx}
{$ENDIF}
{$R *.res}

const
{$IFDEF WIN64}
	PlatformDllPath = 'x64';
{$ENDIF}
{$IFDEF WIN32}
	PlatformDllPath = 'x32';
{$ENDIF}

var
	// PlatformDllPath: WideString;
	tmp: pchar;
	AccountsIniFilePath: WideString;
	SettingsIniFilePath: WideString;
	GlobalPath, PluginPath: WideString;
	FileCounter: integer = 0;
	{ Callback data }
	PluginNum: integer;
	CryptoNum: integer;
	MyProgressProc: TProgressProcW;
	MyLogProc: TLogProcW;
	MyRequestProc: TRequestProcW;
	MyCryptProc: TCryptProcW;

	CurrentListing: TCloudMailRuDirListing;

	ConnectionManager: TConnectionManager;

function CloudMailRuDirListingItemToFindData(DirListing: TCloudMailRuDirListingItem): tWIN32FINDDATAW;
begin
	if (DirListing.type_ = TYPE_DIR) then
	begin
		Result.ftCreationTime.dwLowDateTime := 0;
		Result.ftCreationTime.dwHighDateTime := 0;
		Result.ftLastWriteTime.dwHighDateTime := 0;
		Result.ftLastWriteTime.dwLowDateTime := 0;
		Result.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY
	end else begin
		Result.ftCreationTime := DateTimeToFileTime(UnixToDateTime(DirListing.mtime));
		Result.ftLastWriteTime := DateTimeToFileTime(UnixToDateTime(DirListing.mtime));

		Result.dwFileAttributes := 0;
	end;

	if (DirListing.size > MAXDWORD) then Result.nFileSizeHigh := DirListing.size div MAXDWORD
	else Result.nFileSizeHigh := 0;
	Result.nFileSizeLow := DirListing.size;

	strpcopy(Result.cFileName, DirListing.name);
end;

function FindData_emptyDir(DirName: WideString = '.'): tWIN32FINDDATAW;
begin
	strpcopy(Result.cFileName, DirName);
	Result.ftCreationTime.dwLowDateTime := 0;
	Result.ftCreationTime.dwHighDateTime := 0;
	Result.ftLastWriteTime.dwHighDateTime := 0;
	Result.ftLastWriteTime.dwLowDateTime := 0;
	Result.nFileSizeHigh := 0;
	Result.nFileSizeLow := 0;
	Result.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
end;

function FindListingItemByName(DirListing: TCloudMailRuDirListing; ItemName: WideString): TCloudMailRuDirListingItem;
var
	I: integer;
begin
	ItemName := '/' + StringReplace(ItemName, WideString('\'), WideString('/'), [rfReplaceAll, rfIgnoreCase]);
	for I := 0 to Length(DirListing) - 1 do
	begin
		if DirListing[I].home = ItemName then
		begin
			exit(DirListing[I]);
		end;
	end;
end;

procedure FsGetDefRootName(DefRootName: PAnsiChar; maxlen: integer); stdcall; // ��������� ���������� ���� ��� ��� ��������� �������
Begin
	AnsiStrings.StrLCopy(DefRootName, PAnsiChar('CloudMailRu'), maxlen);
	messagebox(FindTCWindow, PWideChar('Installation succeful'), 'Information', mb_ok + mb_iconinformation);
End;

function FsGetBackgroundFlags: integer; stdcall;
begin
	Result := 0; // BG_DOWNLOAD + BG_UPLOAD; // + BG_ASK_USER;
end;

{ ANSI PEASANTS }

function FsInit(PluginNr: integer; pProgressProc: TProgressProc; pLogProc: TLogProc; pRequestProc: TRequestProc): integer; stdcall;
Begin
	{ PluginNum := PluginNr;
		MyProgressProc := pProgressProc;
		MyLogProc := pLogProc;
		MyRequestProc := pRequestProc; }
	// ���� � ������.
	Result := 0;

end;

procedure FsStatusInfo(RemoteDir: PAnsiChar; InfoStartEnd, InfoOperation: integer); stdcall;
begin
	SetLastError(ERROR_NOT_SUPPORTED);
end;

function FsFindFirst(path: PAnsiChar; var FindData: tWIN32FINDDATAA): thandle; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := ERROR_INVALID_HANDLE; // Ansi-��������
end;

function FsFindNext(Hdl: thandle; var FindData: tWIN32FINDDATAA): bool; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := false; // Ansi-��������
end;

function FsExecuteFile(MainWin: thandle; RemoteName, Verb: PAnsiChar): integer; stdcall; // ������ �����
Begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := FS_EXEC_ERROR; // Ansi-��������
End;

function FsGetFile(RemoteName, LocalName: PAnsiChar; CopyFlags: integer; RemoteInfo: pRemoteInfo): integer; stdcall; // ����������� ����� �� �������� ������� �������
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := FS_FILE_NOTSUPPORTED; // Ansi-��������
end;

function FsPutFile(LocalName, RemoteName: PAnsiChar; CopyFlags: integer): integer; stdcall; // ����������� ����� � �������� ������� �������
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := FS_FILE_NOTSUPPORTED; // Ansi-��������
end;

function FsDeleteFile(RemoteName: PAnsiChar): bool; stdcall; // �������� ����� �� �������� �������� �������
Begin
	SetLastError(ERROR_INVALID_FUNCTION); // Ansi-��������
	Result := false;
End;

function FsRenMovFile(OldName: PAnsiChar; NewName: PAnsiChar; Move: Boolean; OverWrite: Boolean; ri: pRemoteInfo): integer;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := FS_FILE_NOTSUPPORTED; // Ansi-��������
end;

function FsDisconnect(DisconnectRoot: PAnsiChar): bool; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := false; // ansi-��������
end;

function FsMkDir(path: PAnsiChar): bool; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := false; // ansi-��������
end;

function FsRemoveDir(RemoteName: PAnsiChar): bool; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := false; // ansi-��������
end;

procedure FsSetCryptCallback(PCryptProc: TCryptProcW; CryptoNr: integer; Flags: integer); stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
end;

function FsContentGetSupportedField(FieldIndex: integer; FieldName: PAnsiChar; Units: PAnsiChar; maxlen: integer): integer; stdcall;
begin
	Result := ft_nomorefields;
	case FieldIndex of
		0:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'tree');
				Result := ft_stringw;
			end;
		1:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'name');
				Result := ft_stringw;
			end;
		2:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'grev');
				Result := ft_numeric_32;
			end;
		3:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'size');
				Result := ft_numeric_64;
			end;
		4:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'kind');
				Result := ft_stringw;
			end;
		5:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'weblink');
				Result := ft_stringw;
			end;
		6:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'rev');
				Result := ft_numeric_32;
			end;
		7:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'type');
				Result := ft_stringw;
			end;
		8:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'home');
				Result := ft_stringw;
			end;
		9:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'mtime');
				Result := ft_datetime;
			end;
		10:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'hash');
				Result := ft_stringw;
			end;
		11:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'virus_scan');
				Result := ft_stringw;
			end;
		12:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'folders_count');
				Result := ft_numeric_32;
			end;
		13:
			begin
				System.AnsiStrings.strpcopy(FieldName, 'files_count');
				Result := ft_numeric_32;
			end;
	end;
end;

function FsContentGetValue(FileName: PAnsiChar; FieldIndex: integer; UnitIndex: integer; FieldValue: Pointer; maxlen: integer; Flags: integer): integer; stdcall;
begin

	SetLastError(ERROR_INVALID_FUNCTION);
	Result := ft_nosuchfield;
end;

{ GLORIOUS UNICODE MASTER RACE }

function FsInitW(PluginNr: integer; pProgressProc: TProgressProcW; pLogProc: TLogProcW; pRequestProc: TRequestProcW): integer; stdcall; // ���� � ������.
Begin
	PluginNum := PluginNr;
	MyProgressProc := pProgressProc;
	MyLogProc := pLogProc;
	MyRequestProc := pRequestProc;
	Result := 0;
	ConnectionManager := TConnectionManager.Create(AccountsIniFilePath, PluginNum, MyProgressProc, MyLogProc);
end;

procedure FsStatusInfoW(RemoteDir: PWideChar; InfoStartEnd, InfoOperation: integer); stdcall; // ������ � ����� �������� FS
begin
	if (InfoStartEnd = FS_STATUS_START) then
	begin
		case InfoOperation of
			FS_STATUS_OP_LIST:
				begin
				end;
			FS_STATUS_OP_GET_SINGLE:
				begin
				end;
			FS_STATUS_OP_GET_MULTI:
				begin
				end;
			FS_STATUS_OP_PUT_SINGLE:
				begin
				end;
			FS_STATUS_OP_PUT_MULTI:
				begin
				end;
			FS_STATUS_OP_RENMOV_SINGLE:
				begin
				end;
			FS_STATUS_OP_RENMOV_MULTI:
				begin
				end;
			FS_STATUS_OP_DELETE:
				begin
				end;
			FS_STATUS_OP_ATTRIB:
				begin
				end;
			FS_STATUS_OP_MKDIR:
				begin
				end;
			FS_STATUS_OP_EXEC:
				begin
				end;
			FS_STATUS_OP_CALCSIZE:
				begin
				end;
			FS_STATUS_OP_SEARCH:
				begin
				end;
			FS_STATUS_OP_SEARCH_TEXT:
				begin
				end;
		end;
		exit;
	end;
	if (InfoStartEnd = FS_STATUS_END) then
	begin
		case InfoOperation of
			FS_STATUS_OP_LIST:
				begin
				end;
			FS_STATUS_OP_GET_SINGLE:
				begin
				end;
			FS_STATUS_OP_GET_MULTI:
				begin
				end;
			FS_STATUS_OP_PUT_SINGLE:
				begin
				end;
			FS_STATUS_OP_PUT_MULTI:
				begin
				end;
			FS_STATUS_OP_RENMOV_SINGLE:
				begin
				end;
			FS_STATUS_OP_RENMOV_MULTI:
				begin
				end;
			FS_STATUS_OP_DELETE:
				begin
				end;
			FS_STATUS_OP_ATTRIB:
				begin
				end;
			FS_STATUS_OP_MKDIR:
				begin
				end;
			FS_STATUS_OP_EXEC:
				begin
				end;
			FS_STATUS_OP_CALCSIZE:
				begin
				end;
			FS_STATUS_OP_SEARCH:
				begin
				end;
			FS_STATUS_OP_SEARCH_TEXT:
				begin
				end;
		end;
		exit;
	end;
end;

function FsFindFirstW(path: PWideChar; var FindData: tWIN32FINDDATAW): thandle; stdcall;
var // ��������� ������� ����� � �����. Result ������� �� ������������ (����� ������������ ��� ������ �������).
	Sections: TStringList;
	RealPath: TRealPath;
	getResult: integer;
begin
	Result := 0;
	GlobalPath := path;
	if GlobalPath = '\' then
	begin // ������ ����������
		Sections := TStringList.Create;
		GetAccountsListFromIniFile(AccountsIniFilePath, Sections);

		if (Sections.Count > 0) then
		begin
			FindData := FindData_emptyDir(Sections.Strings[0]);
			FileCounter := 1;
		end else begin
			Result := INVALID_HANDLE_VALUE; // ������ ������������ exit
			SetLastError(ERROR_NO_MORE_FILES);
		end;
		Sections.Free;
	end else begin
		RealPath := ExtractRealPath(GlobalPath);

		if RealPath.account = '' then RealPath.account := ExtractFileName(ExcludeTrailingBackslash(GlobalPath));

		if not ConnectionManager.get(RealPath.account, getResult).getDir(RealPath.path, CurrentListing) then SetLastError(ERROR_PATH_NOT_FOUND);
		if getResult <> CLOUD_OPERATION_OK then exit(getResult);

		if Length(CurrentListing) = 0 then
		begin
			FindData := FindData_emptyDir(); // ���������� ���� � �������������� ����� � ������ �������, ��. http://www.ghisler.ch/board/viewtopic.php?t=42399
			Result := 0;
			SetLastError(ERROR_NO_MORE_FILES);
		end else begin
			FindData := CloudMailRuDirListingItemToFindData(CurrentListing[0]);
			FileCounter := 1;
			Result := 1;
		end;
	end;
end;

function FsFindNextW(Hdl: thandle; var FindData: tWIN32FINDDATAW): bool; stdcall;
var
	Sections: TStringList;
begin
	if GlobalPath = '\' then
	begin
		Sections := TStringList.Create;
		GetAccountsListFromIniFile(AccountsIniFilePath, Sections);
		if (Sections.Count > FileCounter) then
		begin
			FindData := FindData_emptyDir(Sections.Strings[FileCounter]);
			inc(FileCounter);
			Result := true;
		end
		else Result := false;
		Sections.Free;
	end else begin
		// ��������� ����������� ������ � ����� (���������� �� ��� ���, ���� �� ������ false).
		if (Length(CurrentListing) > FileCounter) then
		begin
			FindData := CloudMailRuDirListingItemToFindData(CurrentListing[FileCounter]);
			Result := true;
			inc(FileCounter);
		end else begin
			FillChar(FindData, SizeOf(WIN32_FIND_DATA), 0);
			FileCounter := 0;
			Result := false;
		end;
	end;
end;

function FsFindClose(Hdl: thandle): integer; stdcall;
Begin // ���������� ��������� ������ ������. Result ������� �� ������������ (������ ����� 0)
	SetLength(CurrentListing, 0); // ����� �����
	Result := 0;
	FileCounter := 0;
end;

function FsExecuteFileW(MainWin: thandle; RemoteName, Verb: PWideChar): integer; stdcall; // ������ �����
var
	RealPath: TRealPath;
	CurrentItem: TCloudMailRuDirListingItem;
	Cloud: TCloudMailRu;
	getResult: integer;
Begin
	RealPath := ExtractRealPath(RemoteName);
	Result := FS_EXEC_OK;
	if Verb = 'open' then
	begin
		exit(FS_EXEC_YOURSELF);
	end else if Verb = 'properties' then
	begin
		if RealPath.path = '' then
		begin
			TAccountsForm.ShowAccounts(MainWin, AccountsIniFilePath, SettingsIniFilePath, MyCryptProc, PluginNum, CryptoNum, RemoteName);
		end else begin
			if ConnectionManager.get(RealPath.account, getResult).statusFile(RealPath.path, CurrentItem) then
			begin
				Cloud := ConnectionManager.get(RealPath.account, getResult);
				if CurrentItem.home <> '' then TPropertyForm.ShowProperty(MainWin, CurrentItem, Cloud)
				else
				begin
					MyLogProc(PluginNum, msgtype_importanterror, PWideChar('Cant find file under cursor!'));
				end;
			end; // �� ���������, ��� ����� ������� ����

		end;
	end else if copy(Verb, 1, 5) = 'chmod' then
	begin
	end else if copy(Verb, 1, 5) = 'quote' then
	begin
	end;
End;

function FsGetFileW(RemoteName, LocalName: PWideChar; CopyFlags: integer; RemoteInfo: pRemoteInfo): integer; stdcall; // ����������� ����� �� �������� ������� �������
var
	RealPath: TRealPath;
	getResult: integer;
begin
	Result := FS_FILE_NOTSUPPORTED;
	RealPath := ExtractRealPath(RemoteName);

	MyProgressProc(PluginNum, RemoteName, LocalName, 0);

	if CopyFlags = FS_FILE_OK then
	begin
		if FileExists(LocalName) then
		begin
			exit(FS_FILE_EXISTS);
		end else begin
			Result := ConnectionManager.get(RealPath.account, getResult).getFile(WideString(RealPath.path), WideString(LocalName));
		end;
	end;

	if CheckFlag(FS_COPYFLAGS_MOVE, CopyFlags) then
	begin
		Result := ConnectionManager.get(RealPath.account, getResult).getFile(WideString(RealPath.path), WideString(LocalName));
		if Result = FS_FILE_OK then
		begin
			ConnectionManager.get(RealPath.account, getResult).deleteFile(RealPath.path);
		end;

	end;
	if CheckFlag(FS_COPYFLAGS_RESUME, CopyFlags) then
	begin { NEVER CALLED HERE }
		Result := FS_FILE_NOTSUPPORTED;
	end;
	if CheckFlag(FS_COPYFLAGS_OVERWRITE, CopyFlags) then
	begin
		Result := ConnectionManager.get(RealPath.account, getResult).getFile(WideString(RealPath.path), WideString(LocalName));
	end;
	if Result = FS_FILE_OK then
	begin
		MyProgressProc(PluginNum, LocalName, RemoteName, 100);
		MyLogProc(PluginNum, MSGTYPE_TRANSFERCOMPLETE, PWideChar(RemoteName + '->' + LocalName));
	end;

end;

function FsPutFileW(LocalName, RemoteName: PWideChar; CopyFlags: integer): integer; stdcall;
var
	RealPath: TRealPath;
	getResult: integer;
begin
	Result := FS_FILE_NOTSUPPORTED;
	RealPath := ExtractRealPath(RemoteName);
	if RealPath.account = '' then exit(FS_FILE_NOTSUPPORTED);
	MyProgressProc(PluginNum, LocalName, PWideChar(RealPath.path), 0);
	if CheckFlag(FS_COPYFLAGS_OVERWRITE, CopyFlags) then
	begin
		if ConnectionManager.get(RealPath.account, getResult).deleteFile(RealPath.path) then // ����������, ��� ������������ ���� ���� API, �� �� ����� ��� �������
		begin
			Result := ConnectionManager.get(RealPath.account, getResult).putFile(WideString(LocalName), RealPath.path);
			if Result = FS_FILE_OK then
			begin
				MyProgressProc(PluginNum, LocalName, PWideChar(RealPath.path), 100);
				MyLogProc(PluginNum, MSGTYPE_TRANSFERCOMPLETE, PWideChar(LocalName + '->' + RemoteName));
			end;

		end else begin
			Result := FS_FILE_NOTSUPPORTED;

		end;

	end;
	if CheckFlag(FS_COPYFLAGS_RESUME, CopyFlags) then
	begin // NOT SUPPORTED
		exit(FS_FILE_NOTSUPPORTED);
	end;

	if CheckFlag(FS_COPYFLAGS_EXISTS_SAMECASE, CopyFlags) or CheckFlag(FS_COPYFLAGS_EXISTS_DIFFERENTCASE, CopyFlags) then // ������ �� ������������ ������ ��������
	begin
		exit(FS_FILE_EXISTS);
	end;
	if CheckFlag(FS_COPYFLAGS_MOVE, CopyFlags) then
	begin
		Result := ConnectionManager.get(RealPath.account, getResult).putFile(WideString(LocalName), RealPath.path);
		if Result = FS_FILE_OK then
		begin
			MyProgressProc(PluginNum, LocalName, PWideChar(RealPath.path), 100);
			MyLogProc(PluginNum, MSGTYPE_TRANSFERCOMPLETE, PWideChar(LocalName + '->' + RemoteName));
		end;
		if not DeleteFileW(LocalName) then
		begin // �� ���������� �������
			exit(FS_FILE_NOTSUPPORTED);
		end;
	end;

	if CopyFlags = 0 then
	begin
		Result := ConnectionManager.get(RealPath.account, getResult).putFile(WideString(LocalName), RealPath.path);
		if Result = FS_FILE_OK then
		begin
			MyProgressProc(PluginNum, LocalName, PWideChar(RealPath.path), 100);
			MyLogProc(PluginNum, MSGTYPE_TRANSFERCOMPLETE, PWideChar(LocalName + '->' + RemoteName));
		end;
	end;

end;

function FsDeleteFileW(RemoteName: PWideChar): bool; stdcall; // �������� ����� �� �������� �������� �������
var
	RealPath: TRealPath;
	getResult: integer;
Begin
	RealPath := ExtractRealPath(WideString(RemoteName));
	if RealPath.account = '' then exit(false);
	Result := ConnectionManager.get(RealPath.account, getResult).deleteFile(RealPath.path);
End;

function FsMkDirW(path: PWideChar): bool; stdcall;
var
	RealPath: TRealPath;
	getResult: integer;
Begin
	RealPath := ExtractRealPath(WideString(path));
	if RealPath.account = '' then exit(false);
	Result := ConnectionManager.get(RealPath.account, getResult).createDir(RealPath.path);
end;

function FsRemoveDirW(RemoteName: PWideChar): bool; stdcall;
var
	RealPath: TRealPath;
	getResult: integer;
Begin
	RealPath := ExtractRealPath(WideString(RemoteName));
	Result := ConnectionManager.get(RealPath.account, getResult).removeDir(RealPath.path);
end;

function FsRenMovFileW(OldName: PWideChar; NewName: PWideChar; Move: Boolean; OverWrite: Boolean; ri: pRemoteInfo): integer; stdcall;
var
	OldRealPath: TRealPath;
	NewRealPath: TRealPath;
	getResult: integer;
Begin
	OldRealPath := ExtractRealPath(WideString(OldName));
	NewRealPath := ExtractRealPath(WideString(NewName));
	if OverWrite then // ���������, �� TC �� ���������� ������ ���������� ��� FS_FILE_EXISTS
	begin
		if ConnectionManager.get(OldRealPath.account, getResult).deleteFile(OldRealPath.path) then // �� �� ����� ��������������, �� �� ����� ������� ������� ����
		begin
			Result := ConnectionManager.get(OldRealPath.account, getResult).mvFile(OldRealPath.path, NewRealPath.path);
		end else begin
			Result := FS_FILE_NOTSUPPORTED;
		end;
	end else begin
		Result := ConnectionManager.get(OldRealPath.account, getResult).mvFile(OldRealPath.path, NewRealPath.path);
	end;
	if (Result = FS_FILE_OK) and Move then
	begin
		ConnectionManager.get(OldRealPath.account, getResult).deleteFile(OldRealPath.path);
	end;

end;

function FsDisconnectW(DisconnectRoot: PWideChar): bool; stdcall;
begin
	ConnectionManager.freeAll;
	Result := true;
end;

procedure FsSetCryptCallbackW(PCryptProc: TCryptProcW; CryptoNr: integer; Flags: integer); stdcall;
begin
	MyCryptProc := PCryptProc;
	CryptoNum := CryptoNr;
	ConnectionManager.CryptoNum := CryptoNum;
	ConnectionManager.MyCryptProc := MyCryptProc;
end;

function FsContentGetValueW(FileName: PWideChar; FieldIndex: integer; UnitIndex: integer; FieldValue: Pointer; maxlen: integer; Flags: integer): integer; stdcall;
var
	Item: TCloudMailRuDirListingItem;
	RealPath: TRealPath;
	Filetime: TFileTime;
	getResult: integer;
begin
	Result := ft_nosuchfield;
	RealPath := ExtractRealPath(FileName);
	if (RealPath.path = '') then exit(ft_nosuchfield);

	Item := FindListingItemByName(CurrentListing, RealPath.path); // ������� ��������� ����� ���� � ��������� ������
	if Item.home = '' then // ���� ��� ��� ��� (������ ������ �� �����, ��������), �� �������� � ������ ��������
	begin
		if ConnectionManager.get(RealPath.account, getResult).statusFile(RealPath.path, Item) then
		begin
			if Item.home = '' then
			begin
				MyLogProc(PluginNum, msgtype_importanterror, PWideChar('Cant find file ' + RealPath.path)); { ������ ���� �� �����, ��... }
				exit(ft_nosuchfield);
			end;
		end; // �� ���������, ��� ����� ������� ����
	end;
	case FieldIndex of
		0:
			begin
				if Item.mtime <> 0 then exit(ft_nosuchfield);
				strpcopy(FieldValue, Item.tree);
				Result := ft_stringw;
			end;
		1:
			begin
				strpcopy(FieldValue, Item.name);
				Result := ft_stringw;
			end;
		2:
			begin
				if Item.mtime <> 0 then exit(ft_nosuchfield);
				Move(Item.grev, FieldValue^, SizeOf(Item.grev));
				Result := ft_numeric_32;
			end;
		3:
			begin
				Move(Item.size, FieldValue^, SizeOf(Item.size));
				Result := ft_numeric_64;
			end;
		4:
			begin
				strpcopy(FieldValue, Item.kind);
				Result := ft_stringw;
			end;
		5:
			begin
				strpcopy(FieldValue, Item.weblink);
				Result := ft_stringw;
			end;
		6:
			begin
				if Item.mtime <> 0 then exit(ft_nosuchfield);
				Move(Item.rev, FieldValue^, SizeOf(Item.rev));
				Result := ft_numeric_32;
			end;
		7:
			begin
				strpcopy(FieldValue, Item.type_);
				Result := ft_stringw;
			end;
		8:
			begin
				strpcopy(FieldValue, Item.home);
				Result := ft_stringw;
			end;
		9:
			begin
				if Item.mtime = 0 then exit(ft_nosuchfield);
				Filetime.dwHighDateTime := 0;
				Filetime.dwLowDateTime := 0;
				Filetime := DateTimeToFileTime(UnixToDateTime(Item.mtime));
				Move(Filetime, FieldValue^, SizeOf(Filetime));
				Result := ft_datetime;
			end;
		10:
			begin
				strpcopy(FieldValue, Item.hash);
				Result := ft_stringw;
			end;
		11:
			begin
				strpcopy(FieldValue, Item.virus_scan);
				Result := ft_stringw;
			end;
		12:
			begin
				if Item.mtime <> 0 then exit(ft_nosuchfield);
				Move(Item.folders_count, FieldValue^, SizeOf(Item.folders_count));
				Result := ft_numeric_32;
			end;
		13:
			begin
				if Item.mtime <> 0 then exit(ft_nosuchfield);
				Move(Item.files_count, FieldValue^, SizeOf(Item.files_count));
				Result := ft_numeric_32;
			end;
	end;

end;

exports FsGetDefRootName, FsInit, FsInitW, FsFindFirst, FsFindFirstW, FsFindNext, FsFindNextW, FsFindClose, FsGetFile, FsGetFileW, FsDisconnect, FsDisconnectW, FsStatusInfo, FsStatusInfoW, FsPutFile, FsPutFileW, FsDeleteFile, FsDeleteFileW, FsMkDir, FsMkDirW, FsRemoveDir, FsRemoveDirW, FsSetCryptCallback, FsSetCryptCallbackW, FsExecuteFileW, FsRenMovFile, FsRenMovFileW, FsGetBackgroundFlags, FsContentGetSupportedField, FsContentGetValue, FsContentGetValueW;

begin
	GetMem(tmp, max_path);
	GetModuleFilename(hInstance, tmp, max_path);
	PluginPath := tmp;
	freemem(tmp);
	PluginPath := IncludeTrailingbackslash(ExtractFilePath(PluginPath));
	AccountsIniFilePath := PluginPath + 'MailRuCloud.ini';
	SettingsIniFilePath := PluginPath + 'MailRuCloud.global.ini';
	if not FileExists(AccountsIniFilePath) then FileClose(FileCreate(AccountsIniFilePath));
	if GetPluginSettings(SettingsIniFilePath).LoadSSLDLLOnlyFromPluginDir then
	begin
		if DirectoryExists(PluginPath + PlatformDllPath) then
		begin // try to load dll from platform subdir
			IdOpenSSLSetLibPath(PluginPath + PlatformDllPath);
		end else begin // else try to load it from plugin dir
			IdOpenSSLSetLibPath(PluginPath);
		end;

	end;

end.
