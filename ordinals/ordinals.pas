program ordinals;
// M2: Ord/Chr/Pred/Succ/Odd/Halt — ordinal and character builtins.
var
  c: Char;
  i: Integer;
begin
  c := 'B';
  writeln(Ord(c));                 // 66 (ASCII)
  writeln(Chr(65));                // A
  writeln(Pred('B'));              // A (pred of a char)
  writeln(Succ('B'));              // C
  writeln(Pred(5));                // 4
  writeln(Succ(5));                // 6
  for i := 1 to 10 do
    if Odd(i) then write(i, ' ');
  writeln;                         // 1 3 5 7 9
  if Succ(Pred(7)) = 7 then writeln('roundtrip');
  Halt;
  writeln('never printed');
end.
