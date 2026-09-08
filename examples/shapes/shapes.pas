library shapes;
{$Screen 80 40}

// Draw shapes with nothing but write/writeln — no canvas, no pixels.
// Classic textbook Pascal: nested loops print rows of characters.

procedure DrawTriangle(n: Integer);
var
  row, col: Integer;
begin
  writeln('Triangle (', n, ' rows):');
  for row := 1 to n do
  begin
    // leading spaces to center the triangle
    for col := 1 to (n - row) do
      write(' ');
    for col := 1 to (2 * row - 1) do
      write('*');
    writeln;
  end;
end;

procedure DrawTree(n: Integer);
var
  row, col, i: Integer;
begin
  writeln('Tree (', n, ' levels):');
  // foliage: stacked triangles
  for i := 1 to n do
    for row := 1 to i + 1 do
    begin
      for col := 1 to (n + 1 - row) do
        write(' ');
      for col := 1 to (2 * row - 1) do
        write('*');
      writeln;
    end;
  // trunk
  for row := 1 to 3 do
  begin
    for col := 1 to n do
      write(' ');
    writeln('*');
  end;
end;

procedure DrawBox(w, h: Integer);
var
  row, col: Integer;
begin
  writeln('Box (', w, ' x ', h, '):');
  for row := 1 to h do
  begin
    for col := 1 to w do
      // ternary as a write argument: pick the border character in place
      write(if (row = 1) or (row = h) or (col = 1) or (col = w) then '*' else ' ');
    writeln;
  end;
end;

begin
  DrawTriangle(6);
  writeln;
  DrawTree(4);
  writeln;
  DrawBox(12, 5);
  writeln;
  writeln('All shapes drawn with write/writeln only!');
end.
