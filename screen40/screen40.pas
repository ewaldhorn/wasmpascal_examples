library screen40;
{$Screen 40 10}

// A non-standard text screen: {$Screen 40 10} makes the console a 40x10
// character grid instead of the default 80x25. GotoXY and ClrScr address the
// whole 40x10 area; output wraps and scrolls within it.

procedure Demo;
var
  i: Integer;
begin
  ClrScr;
  // Draw a diagonal of X's across the 10 rows.
  for i := 1 to 10 do
  begin
    GotoXY(i, i);
    write('X');
  end;
  // A status line on the last row (fits within 40 columns).
  GotoXY(1, 10);
  write('40x10 screen active');
end;

begin
  Demo;
end.
