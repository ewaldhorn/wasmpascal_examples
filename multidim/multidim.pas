program multidim;
// M6: multi-dim array declarations — array[a..b, c..d] of T with a[i, j].
type
  Color = (Red, Green, Blue);
  Index = 1..3;
var
  grid: array[1..3, 1..4] of Integer;
  rgb: array[Color, Index] of Integer;
  cube: array[1..2, 1..2, 1..2] of Integer;
  i, j: Integer;
begin
  // nested loops fill the 2-dim array; a[i, j] and a[i][j] are equivalent
  for i := 1 to 3 do
    for j := 1 to 4 do
      grid[i, j] := i * 10 + j;
  writeln(grid[2, 3]);                 // 23
  writeln(grid[2][3]);                 // 23 (nested-index form)
  // enum + subrange bounds on the first two dims
  rgb[Green, 2] := 77;
  rgb[Blue, 3] := 88;
  writeln(rgb[Green, 2]);              // 77
  writeln(rgb[Blue][3]);               // 88
  // 3 dims
  cube[2, 1, 2] := 99;
  writeln(cube[2][1][2]);              // 99
  // SizeOf follows the nested layout
  writeln(SizeOf(grid));               // 48
  writeln(SizeOf(cube));               // 32 (2x2x2 Integers)
end.
