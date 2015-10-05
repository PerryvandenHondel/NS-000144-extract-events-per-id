//
//	Extract Events by ID from LPR export files. (EEBI)
//
//	R:\GitRepos\NS-000144-extract-events-by-id\NS00DC012\08db66346664a0b5.lpr					
//
//	PROCEDURES AND FUNCTIONS
//		function ExtractUniqueIdFromPath(p: string): string;
//		function FixLine(strLine: AnsiString): AnsiString;
//		function ReadSettingKey(section: string; key: string): string;
//		procedure ProcessLine(const e: integer; uid: string; lineNumber: integer; l: AnsiString);
//		procedure ProcessLprFile(const e: string; const p: string);
//		procedure ProgDone();
//		procedure ProgInit();
//		procedure ProgRun();
//		procedure ProgUsage();
//


program ExtracEventsById;


{$MODE OBJFPC} // Do not forget this ever
{$M+}
{$H+}


uses
	DateUtils,
	Dos,
	Process,
	SysUtils,
	StrUtils,
	UTextFile,
	UTextSeparated,
	USupportLibrary;

	
const
	STEP_MOD = 			257;
	CONF_NAME = 		'eebi.conf';


var
	csv: CTextFile;

	

function ReadSettingKey(section: string; key: string): string;
//
//	Read a Key from a section from a config (.conf) file.
//
//	[Section]
//	Key1=10
//	Key2=Something
//
//	Usage:
//		WriteLn(ReadSettingKey('Section', 'Key2'));  > returns 'Something'
//		When not found, returns a empty string.
//		
//	Needs updates for checking, validating data.
//
var
	r: Ansistring;					// Return value of this function
	sectionName: string;
	inSection: boolean;
	l: Ansistring;					// Line buffer
	p: string;					// Path of the config file
	conf: CTextFile;			// Class Text File 
begin
	p := GetProgramFolder() + '\' + CONF_NAME;
	conf := CTextFile.Create(p);
	conf.OpenFileRead();

	r := '';
	sectionName := '['+ section + ']';
	inSection := false;
	repeat
		l := conf.ReadFromFile();
		//WriteLn(inSection, #9, l);
		
		if Pos(sectionName, l) > 0 then
		begin
			//WriteLn('FOUND SECTION: ', sectionName);
			inSection := true;
		end;
		
		if inSection = true then
		
		begin
			if (Pos(key, l) > 0) then
			begin
				//WriteLn('Found key ', key, ' found in section ', sectionName);
				r := RightStr(l, Length(l) - Length(key + '='));
				//WriteLn(r);
				Break; // break the loop
			end; // of if 
		end; // of if inSection
		
	until conf.GetEof();
	conf.CloseFile();
	ReadSettingKey := r;
	WriteLn('ReadSettingKey(): ', r, 'LEN=', Length(r));
end; // of function ReadSettingKey



function FixLine(strLine: AnsiString): AnsiString;
//
//	Fix the lines values
//	
//	From:	|some|value||for|nothing
//	To:		|some|value|-|for|nothing
//	
//	Removes the double || and replaces it with |-| 
//
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
			// Replaces the double pipe (||) to pipe-dash-pipe (|-|)
			strLine := StringReplace(strLine, '||', '|-|', [rfReplaceAll]);
	until blnFixed = true;
	
	// Finally replace all the pipe symbol for a tab.
	// NO NEED TO CHANGE THE PIPE TO A TAB, Pipe Separated Values.
	//strLine := StringReplace(strLine, '|', TAB, [rfReplaceAll]);
	
	//WriteLn('FixLine returns:');
	//Writeln(strLine);
	FixLine := strLine;
end;
	

function ExtractUniqueIdFromPath(p: string): string;
//
//	Returns the Unique DI from the path (last 8 chars of the file name)
//
//	p = \\10.4.222.20\TESTLPR\2015-10-02\NS00DC011\NS00DC011-Sec-20151002064535-h5e0AycC.lpr 
//
//	Returns: h5e0AycC
//
var
	//x: integer;
	a: TStringArray;
begin
	SetLength(a, 0);
	a := SplitString(p, '-');
	//for x := 0 to high(a) do
	//begin
	//	WriteLn(x:2, ': ', a[x]);
	//end; // of for
	ExtractUniqueIdFromPath := LeftStr(a[5], Length(a[5]) - 4);
	SetLength(a, 0);
end; // of function ExtractUniqueIdFromPath


procedure ProcessLine(uid: string; lineNumber: integer; l: AnsiString);
//
//	Write a line to the output file
//
//	e:				Event ID
//	uid:			Unique ID of the source file.
//	lineNumber:		The line number in the source file.
//	l:				String containing the log line data
//
begin
	//WriteLn('ProcessLine():');
	l := FixLine(l);
	csv.WriteToFile(uid + '|' + IntToStr(lineNumber) + '|' + l);
end; // of procedure ProcessLine


procedure ProcessLprFile(const e: string; const p: string);
var
	lpr: CTextFile;
	strLine: AnsiString;
	intCurrentLine: integer;
	uid: string;
	header: Ansistring;
	foundEvents: integer;
begin
	WriteLn('Extracting all ', e, ' events from file: ', p, ', please wait...');
	
	foundEvents := 0;
	
	csv := CTextFile.Create(e + '.csv');
	csv.OpenFileWrite();

	if csv.AppendingToFile() = false then
	begin
		// Write the header because the file is new and does not have a header line yet.
		//WriteLn(' >> Appending data to file: ', );
	
		// Read the header string from the .conf file.
		header := ReadSettingKey(e, 'Header');
		WriteLn('header after ReadSettingKey length: ', Length(header));
		if Length(header) = 0 then
		begin
			WriteLn('*** Missing the header for event ', e, ' in the config file ', CONF_NAME , ' ***');
			Exit;
		end; // of if
		// Write the lheader to the file
		WriteLn('Writing header to ', e, '.csv:');
		WriteLn(header);
		csv.WriteToFile(header);
	end; // of if

	uid := ExtractUniqueIdFromPath(p);

	lpr := CTextFile.Create(p);
	lpr.OpenFileRead();
	repeat
		strLine := lpr.ReadFromFile();
		intCurrentLine := lpr.GetCurrentLine();
		//WriteLn(intCurrentLine:6, ': ', strLine);
		WriteMod(intCurrentLine, STEP_MOD, 'lines');
		
		if Pos('|'  + e + '|', strLine) > 0 then
		begin
			// The Event ID is found in the line
			//WriteLn('>>> Event ID: ', e, ' is found in the line');
			ProcessLine(uid, intCurrentLine, strLine);
			Inc(foundEvents);
		end;
		
	until lpr.GetEof();
	
	lpr.CloseFile();
	
	WriteLn('Input file contained ', intCurrentLine, ' lines, extracted ', foundEvents, ' events.');
	
	
	csv.CloseFile();
end; // of procedure ProcessLprFile


procedure ProgUsage();
begin
	WriteLn('Usage:');
	WriteLn('  ' + ParamStr(0) + ' <event-id> <full path to file>');
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
end; // of procedure ProgInit


procedure ProgRun();
begin
	if ParamCount <> 2 then
		ProgUsage()
	else
		// ParamStr(1): Event ID
		// ParamStr(2): Path to LPR file
		ProcessLprFile(ParamStr(1), ParamStr(2));
end; // of procedure ProgRun

{
procedure ProgTest();
var	
	p: string;
	e: integer;
begin
	e := 4776; // Event ID.
	
	p := '\\10.4.222.20\TESTLPR\2015-10-02\NS00DC011\NS00DC011-Sec-20151002064535-h5e0AycC.lpr'; // Path of LPR file.
	p := '\\10.4.222.20\TESTLPR\2015-10-02\NS00DC011\NS00DC011-Sec-20151002075035-tMrBYCL0.lpr'; // Path of LPR file.
	//WriteLn(ExtractUniqueIdFromPath(p));
	//ProcessLprFile(e, p);
end;
}

procedure ProgDone();
begin
end; // of procedure ProgTest
	
	
begin
	ProgInit();
	// ProgTest();
	ProgRun();
	ProgDone();
end.  // of program ExtracEventsById