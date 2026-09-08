library enhanced_colours;

// Two colour demos.
// 1) 10 lines of '#' characters, each a red ramp that zigzags: 0..60, then
//    60..0, then 0..60, 60..0, and so on.
// 2) 20 lines of "Hello from WasmPascal!" in bright white on a blue
//    background that starts subtle and gets brighter and fades again.
// TextColorRGB / BackgroundRGB take runtime r,g,b components, so the ramps
// are just arithmetic on the loop counter.

{$Screen 80 40}

// ----------------------------------------------------------------------------
procedure printMessage(line: Integer);
begin
  TextColorRGB(255, 255, 255);
  BackgroundRGB(0, 0, line * 25);
  writeln('          Hello from WasmPascal!          ');
end;

// ----------------------------------------------------------------------------
procedure ShowOffColours;
var
  line, i: Integer;
begin
  writeln('WasmPascal supports a few more colours than usual...');
  writeln;

  for line := 1 to 10 do
    begin
      if (line mod 2) = 1 then
        for i := 0 to 60 do
          begin
            TextColorRGB(i * 4, 0, 0);
            Write('#');
          end
      else
        for i := 60 downto 0 do
          begin
            TextColorRGB(i * 4, 0, 0);
            Write('#');
          end;
      writeln;
    end;
  TextColor(7);
  writeln;

  for line := 1 to 10 do
    begin
      printMessage(line);
    end;
  for line := 10 downto 1 do
    begin
      printMessage(line);
    end;
    
  TextColor(7);
  TextBackground(0);
  writeln;
end;

// ============================================================================
begin
  ShowOffColours;
end.

