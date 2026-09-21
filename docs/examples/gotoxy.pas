library gotoxy;

// GotoXY(x, y) and ClrScr — Console text-screen positioning. The host
// renders an 80x25 character grid in the output panel: GotoXY moves the
// cursor, write/writeln draw at the cursor, and ClrScr clears the screen.

procedure Demo;
var
  i: Integer;
begin
  ClrScr;
  // Draw a box border with GotoXY + write.
  for i := 1 to 40 do
  begin
    GotoXY(i, 1);  write('#');
    GotoXY(i, 10); write('#');
  end;
  for i := 2 to 9 do
  begin
    GotoXY(1, i);  write('#');
    GotoXY(40, i); write('#');
  end;
  gotoxy(1, 20);
  writeln('Press any key');
  readln;
  gotoxy(1, 20);
  write('                  ');
  // Text inside the box, positioned with GotoXY.
  GotoXY(5, 3);  TextColor(1);  write('Hello from');
  GotoXY(5, 4);  TextColor(2);  write('GotoXY!');
  GotoXY(5, 6);  TextColor(7);  write('Turbo Pascal style');
  GotoXY(5, 8);  write('80 x 25 grid');
  // Home the cursor and finish.
  GotoXY(1, 12);
  TextColor(7);
  writeln('Done.');
end;

begin
  Demo;
end.
