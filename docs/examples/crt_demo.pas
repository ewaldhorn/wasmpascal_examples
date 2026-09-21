// crt_demo.pas — the built-in Crt unit: `uses Crt` brings the 16 TP7
// colour constants (Black..White) into scope. ClrScr/TextColor/
// TextBackground/GotoXY/Delay/ReadKey/UpCase/KeyPressed are compiler
// builtins, so the unit only needs to supply the constant names.
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
