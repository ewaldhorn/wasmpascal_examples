library namesort;

{$M 128M} { 128 MB linear memory (2,048 pages) for large buffer allocation }

{ ------------------------------------------------------------------ }
{ namesort.pas — High-Performance Large CSV Sorter in WebAssembly    }
{                                                                    }
{ Ingests large CSV files (such as 10 MB names.csv with 300k+ rows). }
{ Uses 12-byte zero-copy index records instead of string copying.    }
{ Employs in-place Quicksort O(N log N) for rapid sorting.           }
{                                                                    }
{ Compile at https://wasmpascal.com/ -> Run -> Download .wasm        }
{ Save as namesort.wasm alongside companion index.html.              }
{ ------------------------------------------------------------------ }

const
  MAX_INPUT   = 16777216; { 16 MB input buffer }
  MAX_OUTPUT  = 16777216; { 16 MB output buffer }
  MAX_RECORDS = 500000;   { Up to 500,000 index records }

type
  TIndexRecord = record
    nameOffset: Integer; { byte offset in inputBuffer }
    nameLen:    Integer; { length of the name slice  }
    age:        Integer; { parsed integer age        }
  end;

var
  inputBuffer:  array[0..MAX_INPUT - 1] of Char;
  outputBuffer: array[0..MAX_OUTPUT - 1] of Char;
  outputLen:    Integer;
  records:      array[0..MAX_RECORDS - 1] of TIndexRecord;
  recordCount:  Integer;

function GetInputBuffer: Integer;
begin
  GetInputBuffer := Integer(@inputBuffer[0]);
end;

function GetOutputBuffer: Integer;
begin
  GetOutputBuffer := Integer(@outputBuffer[0]);
end;

function GetOutputLength: Integer;
begin
  GetOutputLength := outputLen;
end;

function GetMaxInputSize: Integer;
begin
  GetMaxInputSize := MAX_INPUT;
end;

procedure AppendChar(c: Char);
begin
  if outputLen < MAX_OUTPUT then
  begin
    outputBuffer[outputLen] := c;
    outputLen := outputLen + 1;
  end;
end;

procedure AppendInt(n: Integer);
var
  temp: array[0..15] of Char;
  digits: Integer;
  val: Integer;
  d: Integer;
begin
  if n = 0 then
  begin
    AppendChar('0');
    Exit;
  end;

  if n < 0 then
  begin
    AppendChar('-');
    val := -n;
  end
  else
    val := n;

  digits := 0;
  while val > 0 do
  begin
    d := val mod 10;
    temp[digits] := Chr(Ord('0') + d);
    digits := digits + 1;
    val := val div 10;
  end;

  while digits > 0 do
  begin
    digits := digits - 1;
    AppendChar(temp[digits]);
  end;
end;

procedure QuickSort(left, right: Integer);
var
  i, j, pivot: Integer;
  temp: TIndexRecord;
begin
  i := left;
  j := right;
  pivot := records[(left + right) div 2].age;
  repeat
    while records[i].age < pivot do i := i + 1;
    while records[j].age > pivot do j := j - 1;
    if i <= j then
    begin
      temp := records[i];
      records[i] := records[j];
      records[j] := temp;
      i := i + 1;
      j := j - 1;
    end;
  until i > j;
  if left < j then QuickSort(left, j);
  if i < right then QuickSort(i, right);
end;

function ProcessCSV(inputLen: Integer): Integer;
var
  pos: Integer;
  nameStart: Integer;
  nameLength: Integer;
  curAge: Integer;
  isFirstLine: Boolean;
  hasAge: Boolean;
  r, k: Integer;
begin
  recordCount := 0;
  outputLen := 0;

  if (inputLen <= 0) or (inputLen > MAX_INPUT) then
  begin
    ProcessCSV := 0;
    Exit;
  end;

  pos := 0;
  isFirstLine := True;

  while pos < inputLen do
  begin
    { Skip blank characters or newline remnants }
    while (pos < inputLen) and ((inputBuffer[pos] = ' ') or (inputBuffer[pos] = #13) or (inputBuffer[pos] = #10)) do
      pos := pos + 1;

    if pos >= inputLen then Break;

    nameStart := pos;

    { Scan Name field until comma, newline, or carriage return }
    while (pos < inputLen) and (inputBuffer[pos] <> ',') and (inputBuffer[pos] <> #10) and (inputBuffer[pos] <> #13) do
      pos := pos + 1;

    nameLength := pos - nameStart;

    { Strip surrounding quotes if present }
    if (nameLength >= 2) and (inputBuffer[nameStart] = '"') and (inputBuffer[nameStart + nameLength - 1] = '"') then
    begin
      nameStart := nameStart + 1;
      nameLength := nameLength - 2;
    end;

    { Skip comma delimiter }
    if (pos < inputLen) and (inputBuffer[pos] = ',') then
      pos := pos + 1;

    { Skip trailing spaces after comma }
    while (pos < inputLen) and (inputBuffer[pos] = ' ') do
      pos := pos + 1;

    { Parse Age digits }
    curAge := 0;
    hasAge := False;
    while (pos < inputLen) and (inputBuffer[pos] >= '0') and (inputBuffer[pos] <= '9') do
    begin
      curAge := curAge * 10 + (Ord(inputBuffer[pos]) - Ord('0'));
      hasAge := True;
      pos := pos + 1;
    end;

    { Skip rest of line until next line }
    while (pos < inputLen) and (inputBuffer[pos] <> #10) and (inputBuffer[pos] <> #13) do
      pos := pos + 1;
    while (pos < inputLen) and ((inputBuffer[pos] = #10) or (inputBuffer[pos] = #13)) do
      pos := pos + 1;

    { Skip header line if detected }
    if isFirstLine and ((not hasAge) or (nameLength = 4)) then
    begin
      if (inputBuffer[nameStart] in ['N', 'n']) and
         (inputBuffer[nameStart+1] in ['A', 'a']) and
         (inputBuffer[nameStart+2] in ['M', 'm']) and
         (inputBuffer[nameStart+3] in ['E', 'e']) then
      begin
        isFirstLine := False;
        Continue;
      end;
    end;
    isFirstLine := False;

    if (nameLength > 0) and hasAge and (recordCount < MAX_RECORDS) then
    begin
      records[recordCount].nameOffset := nameStart;
      records[recordCount].nameLen    := nameLength;
      records[recordCount].age        := curAge;
      recordCount := recordCount + 1;
    end;
  end;

  { Sort index table in-place }
  if recordCount > 1 then
    QuickSort(0, recordCount - 1);

  { Construct sorted CSV output }
  AppendChar('N'); AppendChar('a'); AppendChar('m'); AppendChar('e');
  AppendChar(',');
  AppendChar('A'); AppendChar('g'); AppendChar('e');
  AppendChar(#10);

  for r := 0 to recordCount - 1 do
  begin
    nameStart := records[r].nameOffset;
    nameLength := records[r].nameLen;
    for k := 0 to nameLength - 1 do
      AppendChar(inputBuffer[nameStart + k]);
    AppendChar(',');
    AppendInt(records[r].age);
    AppendChar(#10);
  end;

  ProcessCSV := recordCount;
end;

exports
  GetInputBuffer  name 'GetInputBuffer',
  GetOutputBuffer name 'GetOutputBuffer',
  GetOutputLength name 'GetOutputLength',
  GetMaxInputSize name 'GetMaxInputSize',
  ProcessCSV      name 'ProcessCSV';

begin
end.
