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
	USupportLibrary;



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



var
	//gintLineCount: integer;
	//gtfTsv: TextFile;
	//gstrEventId: string;
	arrEventFile: AEventFile;
	//gblnAppend: boolean;



procedure SafeCopy(fromFile, toFile : string);
type 
	bufferType = array [1..65535] of char;
	bufferTypePtr = ^bufferType;  { Use the heap }
var 
	bufferPtr : bufferTypePtr;     { for the buffer }
	f1, f2 : file;
	bufferSize, readCount, writeCount : word;
	fmSave : byte;              { To store the filemode }
begin
	bufferSize := SizeOf(bufferType);
	//if MaxAvail < bufferSize then exit;  { Assure there is enough memory }
	New (bufferPtr);              { Create the buffer }
	fmSave := FileMode;           { Store the filemode }
	FileMode := 0;                { To read also read-only files }
	Assign (f1, fromFile);
	{$I-} Reset (f1, 1); {$I+}    { Note the record size 1, important! }
	if IOResult <> 0 then exit;   { Does the file exist? }
	Assign (f2, toFile);
	{$I-} Reset (f2, 1); {$I+}    { Don't copy on an existing file }
	if IOResult = 0 then begin close (f2); exit; end;
	{$I-} Rewrite (f2, 1); {$I+}  { Open the target }
	if IOResult <> 0 then exit;
	repeat                        { Do the copying }
		BlockRead (f1, bufferPtr^, bufferSize, readCount);
		{$I-} BlockWrite (f2, bufferPtr^, readCount, writeCount); {$I+}
		if IOResult <> 0 then begin close (f1); exit; end;
		until (readCount = 0) or (writeCount <> readCount);
		writeln ('Copied ', fromFile, ' to ', toFile,' ', FileSize(f2), ' bytes');
	close (f1); close (f2);
	FileMode := fmSave;           { Restore the original filemode }
	Dispose (bufferPtr);          { Release the buffer from the heap }
end;  (* safecopy *)



function FixLine(strLine: AnsiString): AnsiString;
{
	Fix the lines values
	
	|some|value||for|nothing
	
	|some|value|-|for|nothing
	
	Removes the double || 
}
var
	p: integer;
	blnFixed: boolean;
begin
	blnFixed := false;
	p := 0;

	//WriteLn('FixLine():');
	//WriteLn(strLine);
	//Writeln('p=', p);
	repeat
		// Get a position of the || in the string.
		p := Pos('||', strLine);
		
		// If you can't find them continue.
		if p = 0 then
			blnFixed := true
		else
			strLine := StringReplace(strLine, '||', '|-|', [rfReplaceAll]);
	until blnFixed = true;
	
	// Finally replace all the pipe symbol for a tab.
	// NO NEED TO CHANGE THE PIPE TO A TAB, Pipe Separated Values.
	//strLine := StringReplace(strLine, '|', TAB, [rfReplaceAll]);
	
	//WriteLn('FixLine returns:');
	//Writeln(strLine);
	FixLine := strLine;
end;
	
	
function OccurrencesOfChar(const S: string; const C: char): integer;
var
	i: Integer;
begin
	result := 0;
	for i := 1 to Length(S) do
		if S[i] = C then
			inc(result);
end;

//WriteEventLine(intEventPos, strFileLpr, intLineCount, strDcName, strLine);
procedure WriteEventLine(intPosEvent: integer; strFileLpr: string; intLineNumber: integer; strDcName: string; strLine: AnsiString);
var
	strBuffer: AnsiString;
	intHeaderCount: integer;
	intFoundColumns: integer;
begin
	// Replace all pipes for a tab.
	strBuffer := FixLine(strLine);
	
	// Add the prefix the DC name.
	//strBuffer := strDcName + #9 + strBuffer;
	// Build a new buffer with source file, line number, DC name and the original buffer.
	strBuffer := strFileLpr + SEP + IntToStr(intLineNumber) + SEP + strDcName + SEP + strBuffer;
	
	//Writeln('WriteEventLine(): ', strBuffer);
	// Get the number of columns from the header record.
	intHeaderCount := arrEventFile[intPosEvent].HeaderCount;
	
	// Determine the number of columns in the line buffer. Add one of columns
	// Finding 4 separators means 5 colums with information: c1|c2|c3|c4|c5
	intFoundColumns := OccurrencesOfChar(strBuffer, SEP) + 1; 
	
	if intHeaderCount = intFoundColumns then
	begin
		WriteLn(arrEventFile[intPosEvent].FilePointer, strBuffer);
		//Inc(gintLineCount);
		Inc(arrEventFile[intPosEvent].count);
		//Write('--Line: ', gintLineCount);
	end;
	{else
		WriteLn('*** BAD LINE DETECTED: ', strBuffer);}
end;



function IsEventFound(intEventId: integer): integer;
var
	i: integer;
	m: integer;
	r: integer;
begin
	r := -1;
	
	// Get the number of items in the array.
	m := Length(arrEventFile);
	//WriteLn('IsEventFound(): m=', m);
	if m = 0 then
	begin
		// array does not contain items.
		//WriteLn('The array is empty!');
		r := -1;
	end
	else
	begin
		for i := 0 to m do
		begin
			//WriteLn('IsEventFound():', i, #9, arrEventFile[i].EventId, #9, arrEventFile[i].Path);
			if arrEventFile[i].EventId = intEventId then
			begin
				//WriteLn('FOUND IT ON POS ', i);
				r := i;
			end;
		end;
	end;
	IsEventFound := r;
end;



procedure AddEventHeader(intEventId: integer; strHeader: AnsiString);
var
	intFound: integer;
	arrHeader: TStringArray;
	i: integer;
begin
	intFound := IsEventFound(intEventId);
	WriteLn('AddEventHeader(): ', intEventId, '-', strHeader);
	
	SetLength(arrHeader, 0);
	arrHeader := SplitString(strHeader, #9);
	WriteLn('AddEventHeader(): number of columns=', Length(arrHeader));
	for i := 0 to High(arrHeader) do
	begin
		WriteLn(intEventId, ': ', i, ' = ', arrHeader[i]);
	end;
	
	arrEventFile[intFound].Header := strHeader;
end;


procedure AddEventHeaderFromFile(intEventId: integer);
var
	f: TextFile;
	strFileName: string;
	strLine: string;
	arrLine: TStringArray;
	i: integer;
	strHeader: AnsiString;
	intFound: integer;
begin
	WriteLn('AddEventHeaderFromFile(): ', intEventId);
	strFileName := 'eebi-header.conf';
	i := 0;
	strHeader := '';
	
	AssignFile(f, strFileName);
	{I+}
	try 
		Reset(f);
		repeat
			ReadLn(f, strLine);
			//WriteLn(strLine, ' pos=', i);
			SetLength(arrLine, 0);
			arrLine := SplitString(strLine, TAB);
			if StrToInt(arrLine[0]) = intEventId then
			begin
				//WriteLn('** Only the lines that start with ', intEventId);
				// The first part of the line is an event number.
				strHeader := strHeader + arrLine[1] + SEP;
				Inc(i);
			end;
		until Eof(f);
		CloseFile(f);
		
		intFound := IsEventFound(intEventId);
		
		WriteLn('ADD TO arrEventFile');
		// Remove the last pipe char.
		strHeader := LeftStr(strHeader, Length(strHeader) - 1);
		// Update the header record with the header and the number of header items.
		
		arrEventFile[intFound].Header := strHeader;
		arrEventFile[intFound].HeaderCount := i;
		//WriteLn('intFound=', intFound);
		//WriteLn('strHeader=', strHeader);
		WriteLn('Number of header items = ', i, ' (i)');
	except
		on E: EInOutError do
			WriteLn('ProcessLprFile(): file ', strFileName, ' handling error occurred, Details: ', E.ClassName, '/', E.Message);
	end;
end;



procedure AddEventFile(intEventId: integer);
var
	i: integer;
	strPath: string;
begin
	if IsEventFound(intEventId) = -1 then
	begin
		WriteLn('Found a new event id: ', intEventId);
		
		//WriteLn('LENGTH arrEventFile=', Length(arrEventFile)); // Init: 0
		//WriteLn('  HIGH arrEventFile=', High(arrEventFile));   // Init: -1
		
		i := Length(arrEventFile);
		SetLength(arrEventFile, i + 1);
		arrEventFile[i].EventId := intEventId;
		arrEventFile[i].count := 0;
		strPath := GetProgramFolder() + '\events-' + IntToStr(intEventId) + '.psv';
		arrEventFile[i].Path := strPath;
		
		AddEventHeaderFromFile(intEventId);
		
		{
		if intEventId = 4625 then
		begin
			AddEventHeaderFromFile(4625);
		end;
		
		if intEventId = 4770 then
		begin
			AddEventHeaderFromFile(4770);
		end;
		}
		{if intEventId = 4770 then
			AddEventHeader(4770, 'LprFile	LineNumber	DC	DateTime	EventId	EventStatus	AccountName	AccountDomain	ServiceName	ServiceId	TicketOptions	TicketEncryptionType	ClientAddress	ClientPort');
		}
		AssignFile(arrEventFile[i].FilePointer, strPath);
		{I+}	
		try 
			if FileExists(strPath) = true then
			begin
				// Append to existing file.
				Append(arrEventFile[i].FilePointer);
			end
			else
			begin
				// Create a new file.
				WriteLn('New output file ', strPath, ' is created');
				ReWrite(arrEventFile[i].FilePointer);
				// Write the header, only when there is a header line in the Event record.
				//WriteLn('len header=', Length(arrEventFile[i].Header));
				if Length(arrEventFile[i].Header) > 0 then
				begin
					// When there is a header found, write it to the file.
					WriteLn('Write a header line to event file: ', strPath);
					WriteLn(arrEventFile[i].FilePointer, arrEventFile[i].Header);
				end;
			end;
		except
			on E: EInOutError do
				WriteLn('ProcessLprFile(): file ', strPath, ' handling error occurred, Details: ', E.ClassName, '/', E.Message);
		end;
	end;
end;




procedure ProcessLprFile(strPathLpr: string);
var
	arrPath: TStringArray;
	arrLine: TStringArray;
	strLine: AnsiString;
	strDcName: string;
	//strEventId: string;
	intEventId: integer;
	//strPathTsv: string;
	intLineCount: integer;
	f: TextFile;
	intEventPos: integer;
	strFileLpr: string;
begin
	WriteLn('ProcessLprFile():');
	WriteLn('  strPathLpr: ', strPathLpr);
	
	SetLength(arrPath, 0);
	arrPath := SplitString(strPathLpr, '\');
	strDcName := arrPath[Length(arrPath) - 2];
	WriteLn('   strDcName: ', strDcName);
	
	strFileLpr := ExtractFileName(strPathLpr);
	strFileLpr := StringReplace(strFileLpr, '.lpr', '', [rfReplaceAll, rfIgnoreCase]);
	
	
	//strEventId := '4625';
	
	//strPathTsv := GetProgramFolder() + '\events-' + strEventId + '.tsv';
	//WriteLn('  strPathTsv: ', strPathTsv);
	
	//AssignFile(gtfTsv, strPathTsv);
	//ReWrite(gtfTsv); // Open file to write, create when needed.
		
	intLineCount := 0;
	AssignFile(f, strPathLpr);
	{I+}
	try 
		Reset(f);
		repeat
			Inc(intLineCount);
			ReadLn(f, strLine);
			//WriteLn(strLine);
			if intLineCount <> 1 then
			begin
				// Skip the header line!
				SetLength(arrLine, 0);
				arrLine := SplitString(strLine, '|');
				// Get the event id for the line.
				//strEventId := arrLine[1];
				intEventId := StrToInt(arrLine[1]);
				{if intEventId = 4625 then
				begin}
					AddEventFile(intEventId); // Add the event to the event array when it does not exist yet.
					//WriteLn(strFileLpr, #9, intLineCount);
					
					intEventPos := IsEventFound(intEventId);
					//WriteLn('--' + strPathLpr);
					WriteEventLine(intEventPos, strFileLpr, intLineCount, strDcName, strLine);
				//end;
				SetLength(arrLine, 0);
			end;
		until Eof(f);
		CloseFile(f);
	except
		on E: EInOutError do
			WriteLn('ProcessLprFile(): file ', strPathLpr, ' handling error occurred, Details: ', E.ClassName, '/', E.Message);
	end;	//ProcessLprFile(strDcName, strPathLpr, strPathTsv, gstrEventId);
		
	//CloseFile(gtfTsv);
end; // 



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
				WriteLn('Dir:    ', sr.Name);
				strFolderChild := strFolderStart + '\' + sr.Name;
				//WriteLn('strFolderChild=', strFolderChild);
				FindFilesRecur(strFolderChild);
			end
			else
			begin
				strPathFoundFile := strFolderStart + '\' + sr.Name;
				//WriteLn('strPathFoundFile:   ', strPathFoundFile);
				ProcessLprFile(strPathFoundFile);
			end;
		end;
		intValid := FindNext(sr);
	end; // of while.
end;



procedure ShowEventFile(strWhen: string);
var	
	i: integer;
	m: integer;
begin
	WriteLn('-----------------------------------');
	WriteLn('EVENTFILERECORDS: ', strWhen);
	
	m := High(arrEventFile);
	//WriteLn('items in array: ', m + 1);
	
	if m < 0 then
		WriteLn('No items in array arrEventFile!')
	else
	begin
		for i := 0 to m do
		begin
			WriteLn(i, ':', #9, arrEventFile[i].EventId, #9, arrEventFile[i].Path, #9, arrEventFile[i].count);
		end;
	end;
end;



procedure CloseAllFiles();
var
	i: integer;
begin
	for i := 0 to High(arrEventFile) do
	begin
		WriteLn('Closing file: ', arrEventFile[i].Path);
		CloseFile(arrEventFile[i].FilePointer);
	end;
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
end;



procedure ProgRun();
begin
	if ParamCount <> 1 then
		ProgUsage()
	else
		ProcessLprFile(ParamStr(1));
end;



procedure ProgTest();
begin
	//UpDir('D:\temp\');
	//RecurDir('D:\Temp\');
	//
	//ProcessLprFile('R:\GitRepos\NS-000144-extract-events-by-id\ebc9619f390ca2f4.lpr');
	
	WriteLn(FixLine('2015-07-05 14:54:17|4932|8|CN=NTDS Settings,CN=NS00DC012,CN=Servers,CN=Lelystad-01,CN=Sites,CN=Configuration,DC=fr,DC=ns,DC=nl|CN=NTDS Settings,CN=NS00DC055,CN=Servers,CN=Lelystad-01,CN=Sites,CN=Configuration,DC=fr,DC=ns,DC=nl|CN=Configuration,DC=fr,DC=ns,DC=nl|85|2070012|12111826'));

	
//	ShowEventFile('After!');
{	
	//WriteLn(DoesEventIdExists('4655'));
	//AddEventFile('4625');
	//AddEventFile('4625');
	//AddEventFile('4625');
	//ShowEventFile('Before!');
	//AddEventFile(4625);
	AddEventFile(4720);
	AddEventFile(5000);
	AddEventFile(5000);
	AddEventFile(5010);
	AddEventFile(5000);
	AddEventFile(4720);
	AddEventFile(4722);
	AddEventFile(4723);
	AddEventFile(4724);
	AddEventFile(4725);
	AddEventFile(4726);
	
	
	//WriteLn(IsEventFound('4625'));
	//AddEventFile('4625');
	//WriteLn(DoesEventIdExists('4625'));
	
	CloseAllFiles();
}	
end;


procedure ProgDone();
begin
end;


	
	
begin
	//gintLineCount := 0;

	ProgInit();
	//ProgTest();
	ProgRun();
	ProgDone();
	
	//WriteLn('Found ', gintLineCount, ' events with id ', strEventId);
end. 