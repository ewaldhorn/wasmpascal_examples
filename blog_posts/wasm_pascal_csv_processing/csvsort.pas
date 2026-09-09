library csvsort;

{ ------------------------------------------------------------------ }
{ csvsort.pas — CSV Parsing and Sorting in WebAssembly using Pascal  }
{                                                                    }
{ Accepts raw CSV bytes (Name,Age) deposited in inputBuffer by JS,   }
{ parses records into a TPerson array, sorts them by age ascending,  }
{ and generates a sorted CSV in outputBuffer ready for download.     }
{                                                                    }
{ Compile at https://wasmpascal.com/ -> Run -> Download .wasm        }
{ Save as csvsort.wasm alongside companion index.html.               }
{ ------------------------------------------------------------------ }

const
  MAX_INPUT = 65536;    { 64 KB buffer limit }
  MAX_RECORDS = 512;    { Up to 512 person records }

type
  TPerson = record
    name: String[64];
    age: Integer;
  end;

var
  inputBuffer: array[0..MAX_INPUT - 1] of Char;
  outputBuffer: array[0..MAX_INPUT - 1] of Char;
  outputLen: Integer;
  people: array[0..MAX_RECORDS - 1] of TPerson;
  peopleCount: Integer;

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
  if outputLen < MAX_INPUT then
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

{ Sort people array by age ascending using insertion sort }
procedure SortPeople;
var
  i, j: Integer;
  temp: TPerson;
begin
  for i := 1 to peopleCount - 1 do
  begin
    temp := people[i];
    j := i - 1;
    while (j >= 0) and (people[j].age > temp.age) do
    begin
      people[j + 1] := people[j];
      j := j - 1;
    end;
    people[j + 1] := temp;
  end;
end;

{ Main processing entry point: returns number of sorted records }
function ProcessCSV(inputLen: Integer): Integer;
var
  pos: Integer;
  ch: Char;
  curName: String[64];
  curAge: Integer;
  isFirstLine: Boolean;
  hasAge: Boolean;
  k: Integer;
begin
  peopleCount := 0;
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
    { Read name until comma, newline, or end of buffer }
    curName := '';
    while (pos < inputLen) and (inputBuffer[pos] <> ',') and (inputBuffer[pos] <> #10) and (inputBuffer[pos] <> #13) do
    begin
      ch := inputBuffer[pos];
      if not ((Length(curName) = 0) and ((ch = ' ') or (ch = '"'))) then
      begin
        if ch <> '"' then
          curName := curName + ch;
      end;
      pos := pos + 1;
    end;

    { Skip comma delimiter }
    if (pos < inputLen) and (inputBuffer[pos] = ',') then
      pos := pos + 1;

    { Read integer age digits until newline }
    curAge := 0;
    hasAge := False;
    while (pos < inputLen) and (inputBuffer[pos] <> #10) and (inputBuffer[pos] <> #13) do
    begin
      ch := inputBuffer[pos];
      if (ch >= '0') and (ch <= '9') then
      begin
        curAge := curAge * 10 + (Ord(ch) - Ord('0'));
        hasAge := True;
      end;
      pos := pos + 1;
    end;

    { Skip carriage return and line feed }
    while (pos < inputLen) and ((inputBuffer[pos] = #13) or (inputBuffer[pos] = #10)) do
      pos := pos + 1;

    { Skip header line if detected }
    if isFirstLine and ((curName = 'Name') or (curName = 'name') or (not hasAge)) then
    begin
      { header line skipped }
    end
    else if (Length(curName) > 0) and hasAge and (peopleCount < MAX_RECORDS) then
    begin
      people[peopleCount].name := curName;
      people[peopleCount].age := curAge;
      peopleCount := peopleCount + 1;
    end;

    isFirstLine := False;
  end;

  { Sort records by age ascending }
  if peopleCount > 1 then
    SortPeople;

  { Format CSV output into outputBuffer }
  AppendChar('N'); AppendChar('a'); AppendChar('m'); AppendChar('e');
  AppendChar(',');
  AppendChar('A'); AppendChar('g'); AppendChar('e');
  AppendChar(#10);

  for pos := 0 to peopleCount - 1 do
  begin
    curName := people[pos].name;
    for k := 1 to Length(curName) do
      AppendChar(curName[k]);
    AppendChar(',');
    AppendInt(people[pos].age);
    AppendChar(#10);
  end;

  ProcessCSV := peopleCount;
end;

exports
  GetInputBuffer name 'GetInputBuffer',
  GetOutputBuffer name 'GetOutputBuffer',
  GetOutputLength name 'GetOutputLength',
  GetMaxInputSize name 'GetMaxInputSize',
  ProcessCSV name 'ProcessCSV';

begin
end.
