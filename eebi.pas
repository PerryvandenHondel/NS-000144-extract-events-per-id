{
	
	Extract Events by ID from LPR export files. (EEBI)

							
	R:\GitRepos\NS-000144-extract-events-by-id\NS00DC012\08db66346664a0b5.lpr					

	
}



program ExtracEventsById;



{$MODE OBJFPC} // Do not forget this ever
{$M+}



uses
	DateUtils,
	Dos,
	Process,
	SysUtils,
	StrUtils,
	UTextFile,
	UTextSeparated,
	USupportLibrary,
	ODBCConn,
	SqlDb;				
	


type
	// Type definition of the Event Records
	REventFile = record
		EventId: integer;			// What's the current
		FilePointer: TextFile;		// File pointer to the file.
		Header: AnsiString;			// Store the header line in this.
		HeaderCount: integer;		// Number of items in the header;
		count: integer;				// Count the number of records
		Path: string;				// Path to the export file. D:\folder\events-XXXX.tsv.
	end;
	AEventFile = array of REventFile;



const
	TAB = 				#9;
	SEP = 				'|';
	DEBUG = 			false;
	TBL_E4625 = 		'event_4625';
	FLD_E4625_ID = 		'record_id';
	FLD_E4625_DC = 		'dc_system';
	FLD_E4625_LPR =  	'lpr_name';
	FLD_E4625_TG = 		'time_generated';
	FLD_E4625_AN = 		'account_name';
	FLD_E4625_AD = 		'account_domain';
	FLD_E4625_IP = 		'ip_address';
	FLD_E4625_PROC = 	'process';
	FLD_E4625_PROT = 	'protocol';
	FLD_E4625_LFC = 	'logon_failure_code';
	FLD_E4625_SLFC = 	'sub_logon_failure_code';
	FLD_E4625_LT = 		'logon_type';
	FLD_E4625_RCD = 	'rcd';
	FLD_E4625_RLU = 	'rlu';
	DSN = 				'DSN_ADBEHEER_32';

	

var
	//gintLineCount: integer;
	//gtfTsv: TextFile;
	//gstrEventId: string;
	//arrEventFile: AEventFile;
	//gblnAppend: boolean;
	conn: TODBCConnection; 			// uses ODBCConn.
	transaction: TSQLTransaction;   // uses SqlDb.
	//query: TSQLQuery; 			// uses SqlDb.
	gintCountEvent: integer;
	gblnDebug: boolean;


procedure DatabaseOpen();
begin
	conn := TODBCCOnnection.Create(nil);
	//query := TSQLQuery.Create(nil);
	transaction := TSQLTransaction.Create(nil);
	
	WriteLn('Database open DNS: ', DSN);
	
	conn.DatabaseName := DSN;				 				// Data Source Name (DSN)
	//conn.UserName:= 'ADBEHEER_USER'; 						//replace with your user name
    //conn.Password:= 'WG5X6AHVUM2ZgQL-0O_gVmFAVcTucSzJ'; 	//replace with your password
	conn.Transaction := transaction;
end;



procedure DatabaseClose();
begin
	transaction.Free;
	conn.Free;
end;


function EncloseSingleQuote(const s: string): string;
{
	Enclose the string s with single quotes: s > 's'.
}
var
	r: string;
begin
	if s[1] <> '''' then
		r := '''' + s
	else
		r := s;
		
	if r[Length(r)] <> '''' then
		r := r + '''';

	EncloseSingleQuote := r;
end; // of function EncloseSingleQuote


function FixStr(const s: string): string;
var
	r: string;
begin
	if Length(s) = 0 then
		r := 'Null'
	else
		r := EncloseSingleQuote(s);

	FixStr := r;
end; // of function FixStr



function FixNum(const s: string): string;
var
	r: string;
	i: integer;
	code: integer;
begin
	i := 0;
	Val(s, i, code);
	if code <> 0 then
		r := 'Null'
	else
		r := s;
		
	FixNum := r;
end; // of function FixNum




procedure AddRecord4624(const intLineCount: integer; const strLprName: string; const strDcName: string; strLine: AnsiString);
const
	TBL_E4624 = 				'event_4624';
	FLD_E4624_LPR = 			'lpr_name';
	FLD_E4624_DC = 				'dc_system';
	FLD_E4624_TG = 				'time_generated';
	FLD_E4624_AN = 				'account_name';
	FLD_E4624_AD = 				'account_domain';
	FLD_E4624_LT = 				'logon_type';
	FLD_E4624_PROC = 			'process';
	FLD_E4624_PROT = 			'protocol';
	FLD_E4624_IP = 				'ip_address';
var
	arrLine: TStringArray;
	q: AnsiString;			// Query String, length needs to be longer then string 
	i: integer;
begin
	SetLength(arrLine, 0);
	arrLine := SplitString(strLine, '|');
	
	if gblnDebug = true then
		WriteLn(intLineCount, ': ', strLine)
	else
		Write('.'); // Write a point to the screen for action still working
	
					
	
	if gblnDebug = true then
	begin
		for i := 0 to High(arrLine) do
		begin 
			WriteLn(#9, i, ':', #9, arrLine[i]);
		end; // of for
	end;
	
	//	0: Time Generated
	//	8:	Account Name
	//	9: 	Account Domain
	//	22:	IP Address

	q := 'INSERT INTO ' + TBL_E4624 + ' ';
	q := q + 'SET ';
	q := q + FLD_E4624_LPR + '=' + FixStr(strLprName) + ',';	// Source LPR file (16 chars long)
	q := q + FLD_E4624_DC + '=' + FixStr(strDcName) + ',';		// Source DC Server
	q := q + FLD_E4624_TG + '=' + FixStr(arrLine[0]) + ',';		// Time Generated
	q := q + FLD_E4624_AN + '=' + FixStr(arrLine[8]) + ',';		// Account Name
	q := q + FLD_E4624_AD + '=' + FixStr(arrLine[9]) + ',';		// Account Domain
	q := q + FLD_E4624_LT + '=' + FixNum(arrLine[11]) + ',';	// Logon Type
	q := q + FLD_E4624_PROC + '=' + FixStr(arrLine[12]) + ',';	// Process
	q := q + FLD_E4624_PROT + '=' + FixStr(arrLine[13]) + ',';	// Protocol
	q := q + FLD_E4625_IP + '=' + FixStr(arrLine[21]) + ';';	// IP Address
	
	if gblnDebug = true then
		WriteLn(q);
	
	//try
	conn.ExecuteDirect(q);
	transaction.Commit;
	
	Inc(gintCountEvent);
	{except
		WriteLn;
		WriteLn('Error running query:');
		WriteLn;
		WriteLn(q);
		WriteLn;
	end;
	}
end;



procedure AddRecord4625(const intLineCount: integer; const strLprName: string; const strDcName: string; strLine: AnsiString);
var
	arrLine: TStringArray;
	q: AnsiString;			// Query String, length needs to be longer then string 
	i: integer;
begin
	SetLength(arrLine, 0);
	arrLine := SplitString(strLine, '|');
	
	if gblnDebug = true then
		WriteLn(intLineCount, ': ', strLine)
	else
		Write('.'); // Write a point to the screen for action still working
	
					
	
	if gblnDebug = true then
	begin
		for i := 0 to High(arrLine) do
		begin 
			WriteLn(#9, i, ':', #9, arrLine[i]);
		end; // of for
	end;
	
	//	0: Time Generated
	//	8:	Account Name
	//	9: 	Account Domain
	//	22:	IP Address

	q := 'INSERT INTO ' + TBL_E4625 + ' ';
	q := q + 'SET ';
	q := q + FLD_E4625_LPR + '=' + FixStr(strLprName) + ',';	// Source LPR file (16 chars long)
	q := q + FLD_E4625_DC + '=' + FixStr(strDcName) + ',';		// Source DC Server
	q := q + FLD_E4625_TG + '=' + FixStr(arrLine[0]) + ',';		// Time Generated
	q := q + FLD_E4625_AN + '=' + FixStr(arrLine[8]) + ',';		// Account Name
	q := q + FLD_E4625_AD + '=' + FixStr(arrLine[9]) + ',';		// Account Domain
	q := q + FLD_E4625_LFC + '=' + FixStr(arrLine[10]) + ',';	// Logon Failure Code
	q := q + FLD_E4625_SLFC + '=' + FixStr(arrLine[12]) + ',';	// Sub Logon Failure Code
	q := q + FLD_E4625_PROC + '=' + FixStr(arrLine[14]) + ',';	// Process
	q := q + FLD_E4625_PROT + '=' + FixStr(arrLine[15]) + ',';	// Protolcol
	q := q + FLD_E4625_LT + '=' + FixNum(arrLine[13]) + ',';	// Logon Type
	q := q + FLD_E4625_IP + '=' + FixStr(arrLine[22]) + ';';	// IP Address
	
	if gblnDebug = true then
		WriteLn(q);
	
	//try
	conn.ExecuteDirect(q);
	transaction.Commit;
	
	Inc(gintCountEvent);
	{except
		WriteLn;
		WriteLn('Error running query:');
		WriteLn;
		WriteLn(q);
		WriteLn;
	end;
	}
end;



function GetEventIdFromLine(const strLine: string): integer;
begin
	//          1         2
	// 123456789012345678901234567890
	// 2015-07-07 04:12:00|4769|8|NS00DT0261
	GetEventIdFromLine := StrToInt(Copy(strLine, 21, 4)); // Get the Event from the line
end; // of function GetEventIdFromLine



procedure ExtractEventsFromFile(const strPath: string);
var
	f: TextFile;
	intLineCount: integer;
	strLine: AnsiString;
	strDcName: string;
	arrPath: TStringArray;
	strLprName: string;
	intEventFoundInLine: integer;
	//s: string;
	//x: integer;
	//intWhatEvent: integer;
begin
	WriteLn;
	WriteLn('ExtractEventsFromFile(): ', strPath);
	//WriteLn(intEventId, '  ', strPath);
	
	// Get the DC name from the path.
	SetLength(arrPath, 0);
	arrPath := SplitString(strPath, '\');
	
	// Get the last folder name from the epath, that contains the DC name and the LPR export name.
	strDcName := arrPath[High(arrPath) - 1];
	strLprName := LeftStr(arrPath[High(arrPath)], 16);
	
	intLineCount := 0;
	
	AssignFile(f, strPath);
	{I+}
	try 
		Reset(f);
		repeat
			Inc(intLineCount);
			ReadLn(f, strLine);
			//WriteLn(intLineCount, ': ', strLine);
			if intLineCount > 1 then
			begin
				// Skip the header.

				// Get the current event id in the line.
				intEventFoundInLine := GetEventIdFromLine(strLine);
				
				if intEventFoundInLine = 4624 then
					AddRecord4624(intLineCount, strLprName, strDcName, strLine);
				{
				if intEventFoundInLine = 4625 then
					AddRecord4625(intLineCount, strLprName, strDcName, strLine);
				}	
					
			end;
		until Eof(f);
		CloseFile(f);
	except
		on E: EInOutError do
			WriteLn('ProcessLprFile(): file ', strPath, ' handling error occurred, Details: ', E.ClassName, '/', E.Message);
	end;	
		
end; // of procedure ExtractEventsFromFile



procedure FindFilesRecur(strFolderStart: string);
var
	sr: TSearchRec;
	//strPath: string;
	strFileSpec: string;
	intValid: integer;
	strFolderChild: string;
	strPathFoundFile: string;
begin
	//strPath := ExtractFilePath(strFolderStart); {keep track of the path ie: c:\folder\}
	strFileSpec := strFolderStart + '\*.*'; {keep track of the name or filter}
	WriteLn('FindFilesRecur(): ', strFolderStart);
	
	intValid := FindFirst(strFileSpec, faAnyFile, sr); { Find first file}
	//Writeln(intValid);
	
	while intValid = 0 do 
	begin
		if (sr.Name[1] <> '.') then
		begin
			if sr.Attr = faDirectory then
			begin
				//WriteLn('Dir:    ', sr.Name);
				strFolderChild := strFolderStart + '\' + sr.Name;
				//WriteLn('strFolderChild=', strFolderChild);
				FindFilesRecur(strFolderChild);
			end
			else
			begin
				strPathFoundFile := strFolderStart + '\' + sr.Name;
				//WriteLn('strPathFoundFile:   ', strPathFoundFile);
				//ProcessLprFile(strPathFoundFile);
				ExtractEventsFromFile(strPathFoundFile);
			end;
		end;
		intValid := FindNext(sr);
	end; // of while.
end;



procedure ProgUsage();
begin
	WriteLn('Usage:');
	WriteLn('  ' + ParamStr(0) + ' <full path to file>');
	WriteLn;
	{WriteLn;
	WriteLn('  --file <path>         Convert a single file.');
	WriteLn('  --dir <directory>     Convert all files in a directory.');
	WriteLn('  --append              Append to existing output files.');
	WriteLn;}
end;



procedure ProgInit();
begin
	//gblnAppend := false;
	gintCountEvent := 0;
	gblnDebug := DEBUG;
	DatabaseOpen();
end;



procedure ProgRun();
begin
	FindFilesRecur('\\vm70as006.rec.nsint\000134-LPR\2015-07-14');
	
	
	//if ParamCount <> 1 then
	//	ProgUsage()
	//else
	//	ProcessLprFile(ParamStr(1));
end;



procedure ProgTest();
begin
	ExtractEventsFromFile('\\vm70as006.rec.nsint\000134-LPR\2015-07-14\NS00DC017\06f2461c05ac9001.lpr');

	//UpDir('D:\temp\');
	//RecurDir('D:\Temp\');
	//
	//FindFilesRecur('R:\GitRepos\NS-000144-extract-events-by-id\TEST-TREE');
	//ProcessLprFile('R:\GitRepos\NS-000144-extract-events-by-id\ebc9619f390ca2f4.lpr');
end;



procedure ProgDone();
begin
	DatabaseClose();
end;


	
begin
	//gintLineCount := 0;

	ProgInit();
	//ProgTest();
	ProgRun();
	ProgDone();
	
	WriteLn;
	WriteLn('Processed ', gintCountEvent, ' event(s).');
end. 