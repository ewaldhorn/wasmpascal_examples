program enums;
// M1: enumerated + named subrange types — ordinals, case, for-loop counters,
// array bounds from enum/subrange types, and set membership.
type
  Color = (Red, Green, Blue);
  Index = 1..10;
  Neg = -3..3;
var
  c: Color;
  i: Index;
  n: Neg;
  arr: array[Color] of Integer;
  byidx: array[Index] of Integer;
  s: set of Color;
begin
  c := Blue;
  writeln(Ord(c));                 // 2
  case c of
    Red: writeln('red');
    Green: writeln('green');
    Blue: writeln('blue');
  end;
  for c := Red to Blue do
    arr[c] := Ord(c) * 10;
  writeln(arr[Green]);             // 10
  byidx[5] := 99;
  writeln(byidx[5]);               // 99
  i := 10;
  writeln(i);                      // 10
  n := -2;
  writeln(n);                      // -2
  s := [Red, Blue];
  if Blue in s then writeln('in') else writeln('out');
end.
