{
	
	Extract Events by ID from LPR export files.

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


	
const
	TAB = 				#9;



var
	gintLineCount: integer;
	gtfTsv: TextFile;
	gstrEventId: string;
	
procedure WriteHeader(strFnameEvent: string);
var
	f: TextFile;
	h: AnsiString;
begin
	
	if not FileExists(strFnameEvent) then
	begin
		AssignFile(f, strFnameEvent);
		{I+}
		try 
			ReWrite(f);
			h := 'DcServer';
			h := h + TAB + 'DateTime';
			h := h + TAB + 'EventId';
			h := h + TAB + 'EventStatus';
			h := h + TAB + 'Unknown1';
			h := h + TAB + 'Unknown2';
			h := h + TAB + 'Unknown3';
			h := h + TAB + 'Unknown4';
			h := h + TAB + 'SecurityId';
			h := h + TAB + 'SamAccountName';
			h := h + TAB + 'Domain';
			h := h + TAB + 'LogonFailureCode';
			h := h + TAB + 'Unknown5';
			h := h + TAB + 'SubLogonFailureCode';
			h := h + TAB + 'LogonType';
			h := h + TAB + 'LogonProcess';
			h := h + TAB + 'Protocol';
			h := h + TAB + 'WorkstationName';
			h := h + TAB + 'Unknown6';
			h := h + TAB + 'Unknown7';
			h := h + TAB + 'Unknown8';
			h := h + TAB + 'Unknown9';
			h := h + TAB + 'Unknown10';
			h := h + TAB + 'SourceNetworkAddress';
			h := h + TAB + 'SourcePort';
		
			WriteLn(f, h);
			
			CloseFile(f);
		except
			on E: EInOutError do
				WriteLn('File ', strFnameEvent, ' handeling error occurred, Details: ', E.ClassName, '/', E.Message);
		end;
	end;
end;
	
	
  procedure SafeCopy(fromFile, toFile : string);
  type bufferType = array [1..65535] of char;
  type bufferTypePtr = ^bufferType;  { Use the heap }
  var bufferPtr : bufferTypePtr;     { for the buffer }
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
    writeln ('Copied ', fromFile, ' to ', toFile,
             ' ', FileSize(f2), ' bytes');
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
	strLine := StringReplace(strLine, '|', TAB, [rfReplaceAll]);
	
	//WriteLn('FixLine returns:');
	//Writeln(strLine);
	FixLine := strLine;
end;
	
	
	
procedure WriteEventLine(strDcName: string; strLine: AnsiString);
var
	strBuffer: AnsiString;
begin
	// Replace all pipes for a tab.
	strBuffer := FixLine(strLine);
	
	// Add the prefix the DC name.
	strBuffer := strDcName + #9 + strBuffer;
	
	//Writeln('WriteEventLine(): ', strBuffer);
	WriteLn(gtfTsv, strBuffer);
	Inc(gintLineCount);
	//Write('--Line: ', gintLineCount);
end;



procedure ProcessLprFile(strDcName: string; strPathLpr: string; strPathEvents: string; strEventId: string);
var
	f: TextFile;
	strLine: AnsiString;
	arrLine: TStringArray;
begin
	WriteLn('ProcessLprFile():'); 
	WriteLn('Extracting only events with id ', strEventId); 
	WriteLn('                          from ', strPathLpr);
	WriteLn('                     of system ', strDcName);
	WriteLn('                     into file ', strPathEvents);
	
	AssignFile(f, strPathLpr);
	{I+}
	try 
		Reset(f);
		repeat
			ReadLn(f, strLine);
			//WriteLn(strLine);
			
			SetLength(arrLine, 0);
			arrLine := SplitString(strLine, '|');
			if arrLine[1] = strEventId then
				// Only export the events with id strEventId.
				WriteEventLine(strDcName, strLine);
		until Eof(f);
		CloseFile(f);
	except
		on E: EInOutError do
			WriteLn('ProcessLprFile(): file ', strPathLpr, ' handling error occurred, Details: ', E.ClassName, '/', E.Message);
	end;
end;




procedure ProgTest();
begin
	//UpDir('D:\temp\');
	//RecurDir('D:\Temp\');
end;


procedure ProgRun();
var
	strPathLpr: string;
	arrPath: TStringArray;
	strDcName: string;
	
	strPathTsv: string;
	//strPathHdr: string;
begin
	//gblnWriteHeader := false;
	if (ParamCount <> 2) then
	begin
		WriteLn('ERROR: Not the correct number of parameters supplied!');
		WriteLn('Example: CONVERT.EXE <pathtolpr> <eventid>');
		Halt(0);
	end
	else
	begin
		strPathLpr := ParamStr(1);
		gstrEventId := ParamStr(2);
		gintLineCount := 0;
		
		SetLength(arrPath, 0);
		arrPath := SplitString(strPathLpr, '\');
		strDcName := arrPath[Length(arrPath) - 2];
		//WriteLn(strPathLpr);
		//WriteLn(strDcName);
		//WriteLn(strEventId);
		
		
		strPathTsv := GetProgramFolder() + '\events-' + gstrEventId + '.tsv';
		//strPathHdr := GetProgramFolder() + '\header-' + gstrEventId + '.tsv';
		
		//WriteLn(strPathTsv);
		//WriteLn(strPathHdr);
		{
		if gblnWriteHeader = true then 
		begin
		
			if not FileExists(strPathHdr) then
			begin
				WriteLn('ERROR: Header file for event id ', strEventId, ' not found!');
				Exit;
			end;
		
			if not FileExists(strPathTsv) then
			begin
				// The file does not exists. copy the header to the tsv
				SafeCopy(strPathHdr , strPathTsv); // Copies the header file (.HDR) to the Tab Separated Values (.TSV) file.
			end;
		end;
		}
		
		AssignFile(gtfTsv, strPathTsv);
		{I+}
		if FileExists(strPathTsv) = true then
			Append(gtfTsv) // File already exists, open for appending new text.
		else
			ReWrite(gtfTsv); // Open file to write, create when needed.
		
		ProcessLprFile(strDcName, strPathLpr, strPathTsv, gstrEventId);
		
		CloseFile(gtfTsv);
	end;
end;

	
	
begin
	gintLineCount := 0;

	//ProgTest();
	ProgRun();
	
	WriteLn('Found ', gintLineCount, ' events with id ', gstrEventId);
end. 