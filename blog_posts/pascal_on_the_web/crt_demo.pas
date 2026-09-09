program crt_demo;
uses Crt;
var
  i: Integer;
begin
  ClrScr;
  for i := 0 to 15 do
  begin
    TextColor(i);
    TextBackground(Black);
    writeln('Palette index ', i);
  end;
  TextColor(White);
  TextBackground(Black);
  writeln('Back to normal.');
end.
