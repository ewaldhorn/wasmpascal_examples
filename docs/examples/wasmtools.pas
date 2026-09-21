{ ======================================================================
  WasmTools - a loving tribute to the menuing systems that made Turbo
  Pascal famous: stacked pull-down menus on a menu bar, hotkeys
  (F3 for Open, Esc to go back), a status line, ASCII drop shadows
  behind dialog boxes, a blinking "PRESS ENTER" banner, and a
  directory-tree browser. Like PC Tools, it doesn't really DO
  anything - the whole point is that it LOOKS cool.

  All of this is plain console ABI: an in-code character cell screen
  (virtual 80x25) rendered by GotoXY + write. Nothing needs the
  compiler extended. It is also a good tour of the string/console
  features: String[n] fixed buffers, Char arithmetic, GotoXY + write,
  TextColor/TextBackground color pairs, and ReadKey/KeyPressed for
  navigation.

  Controls:
    - The menu bar is at the top; press the HOTKEY letter of a menu
      (F D V T S C O M H Q) to drop it down.
    - Arrows move within a menu; Enter picks; Esc closes.
    - F3 opens the "Open..." dialog (the famous PC Tools key).
    - Alt keys are not forwarded by the host (they are browser
      shortcuts), so Quit is reachable via the Q menu.
    - 1..9 jump to a demo dialog (tree / system info / disk map).

  This is the classic TP7 visual vocabulary:
    - Window frames use the CP437 box-drawing characters (the output
      panel's fixed-width grid renders them).
    - A color pair is (fg + bg*16); 15+8*1 = bright white on blue,
      the classic Norton Commander / PC Tools look.
    - Menus highlight the selected row with reverse video.
  ====================================================================== }

program wasmtools;
{$Screen 80 25}
uses Crt;

const
  { Color pairs: fg + 16*bg, the TP7 way. }
  BarAttr    = 7 + 16*1;      { bright white text on blue }
  Highlight  = 0 + 16*15;     { black on bright white (highlight bar) }
  BannerAttr = 15 + 16*4;     { white on dark red (PRESS ENTER) }
  FrameAttr  = 15 + 16*1;     { bright white frame on blue }

  { Menu bar: 10 entries, 8 cells each, starting at column 2. }
  BarY      = 1;
  BarX0     = 2;
  BarWidth  = 8;
  MenuCount = 10;
  MenuRow   = 2;
  MenuWidth = 19;

  { Dialogue geometry (fit comfortably in 80x25). }
  TreeW = 44; TreeH = 17; TreeTop = 4; TreeLeft = 3;
  InfoW = 44; InfoH = 17; InfoTop = 4; InfoLeft = 22;

type
  TScreen = array[1..25] of array[1..80] of Char;

var
  ScreenBuf: TScreen;      { the visible 80x25 character screen }
  CurFg: Integer;          { current console foreground }
  CurBg: Integer;          { current console background }
  MenuTitles: array[1..MenuCount] of String[12];
  MenuItemCount: array[1..MenuCount] of Integer;
  Items: array[1..MenuCount, 1..5] of String[30];
  TreeLines: array[1..12] of String[20];
  MenuKeys: array[1..MenuCount] of Char;    { hotkey per menu }
  MenuCols: array[1..MenuCount] of Integer; { screen column of each menu }

{ ======================================================================
  Low-level screen API
  ====================================================================== }

{ Apply the current color state. }
procedure SetColors(fg, bg: Integer);
begin
  CurFg := fg;
  CurBg := bg;
  TextColor(fg);
  TextBackground(bg);
end;

{ Set a character at (x, y), 1-based, in the current color. }
procedure Put(x, y: Integer; ch: Char);
begin
  if (x >= 1) and (x <= 80) and (y >= 1) and (y <= 25) then
  begin
    ScreenBuf[y][x] := ch;
    GotoXY(x, y);
    write(ch);
  end;
end;

{ Write a string at (x, y) with the given colors; also updates the
  screen buffer so overlapping dialogs can repaint from it. }
procedure PutStr(x, y: Integer; s: String[80]; fg, bg: Integer);
var
  i: Integer;
begin
  TextBackground(bg);
  TextColor(fg);
  GotoXY(x, y);
  write(s);
  for i := 1 to Length(s) do
    if (x + i - 1 >= 1) and (x + i - 1 <= 80) then
      ScreenBuf[y][x + i - 1] := s[i];
  CurFg := fg;
  CurBg := bg;
end;

{ Fill a rectangle (x,y)-(x+w-1, y+h-1) with spaces of a color. }
procedure Fill(x, y, w, h: Integer; fg, bg: Integer);
var
  i, j: Integer;
begin
  TextBackground(bg);
  TextColor(fg);
  for i := 0 to h - 1 do
  begin
    GotoXY(x, y + i);
    for j := 0 to w - 1 do
    begin
      if (x + j >= 1) and (x + j <= 80) then
      begin
        write(' ');
        ScreenBuf[y + i][x + j] := ' ';
      end;
    end;
  end;
  CurFg := fg;
  CurBg := bg;
end;

{ Draw a window frame: a rectangle with the CP437 box characters. }
procedure Frame(x, y, w, h: Integer);
var
  i: Integer;
begin
  for i := x to x + w - 1 do
  begin
    Put(i, y, #196);               { ─ }
    Put(i, y + h - 1, #196);
  end;
  for i := y + 1 to y + h - 2 do
  begin
    Put(x, i, #179);               { │ }
    Put(x + w - 1, i, #179);
  end;
  Put(x, y, #218);                 { ┌ }
  Put(x + w - 1, y, #191);         { ┐ }
  Put(x, y + h - 1, #192);         { └ }
  Put(x + w - 1, y + h - 1, #217); { ┘ }
end;

{ Draw a window: shadow, box, inner fill, and a centered title. }
procedure Window(x, y, w, h: Integer; Title: String[40]; fg, bg: Integer);
var
  i, t: Integer;
begin
  { First the drop shadow one cell right and down. }
  Fill(x + 1, y + 1, w, h, 0, 8);
  { The window body. }
  Fill(x, y, w, h, fg, bg);
  Frame(x, y, w, h);
  { Title centered on the top border. }
  t := x + (w - Length(Title)) div 2;
  for i := 1 to Length(Title) do
  begin
    ScreenBuf[y][t + i - 1] := Title[i];
    GotoXY(t + i - 1, y);
    TextColor(15);
    TextBackground(bg);
    write(Title[i]);
  end;
end;

{ Blink the word ENTER on the last line, PC Tools style. }
procedure BlinkEnter;
var
  i: Integer;
begin
  for i := 0 to 3 do
  begin
    Fill(1, 25, 80, 1, 15, 4);
    PutStr(25, 25, 'PRESS ENTER', 15, 4);
    Delay(120);
    Fill(1, 25, 80, 1, 7, 1);
    Delay(120);
  end;
end;

{ Draw the status line at the bottom. }
procedure DrawStatus(s: String[80]);
begin
  Fill(1, 25, 80, 1, 7, 1);
  PutStr(1, 25, s, 7, 1);
end;

{ Display the small "hotkey" menu hint under a dialog. }
procedure DrawHint(s: String[40]);
var
  x, i: Integer;
begin
  { Clear row 24, then draw the hint right-aligned. }
  TextBackground(0);
  TextColor(7);
  GotoXY(1, 24);
  for i := 1 to 80 do
  begin
    write(' ');
    ScreenBuf[24][i] := ' ';
  end;
  x := 77 - Length(s);
  GotoXY(x, 24);
  write(s);
  for i := 1 to Length(s) do
    ScreenBuf[24][x + i - 1] := s[i];
end;

{ ======================================================================
  Menu data (built once at startup)
  ====================================================================== }

procedure BuildData;
begin
  MenuKeys[1] := 'F'; MenuKeys[2] := 'D'; MenuKeys[3] := 'V';
  MenuKeys[4] := 'T'; MenuKeys[5] := 'S'; MenuKeys[6] := 'C';
  MenuKeys[7] := 'O'; MenuKeys[8] := 'M'; MenuKeys[9] := 'H';
  MenuKeys[10] := 'Q';
  MenuCols[1] := 2;  MenuCols[2] := 10; MenuCols[3] := 18;
  MenuCols[4] := 26; MenuCols[5] := 34; MenuCols[6] := 42;
  MenuCols[7] := 50; MenuCols[8] := 58; MenuCols[9] := 66;
  MenuCols[10] := 74;

  MenuTitles[1] := 'File';   MenuTitles[2] := 'Disk';
  MenuTitles[3] := 'View';   MenuTitles[4] := 'Tools';
  MenuTitles[5] := 'Setup';  MenuTitles[6] := 'Config';
  MenuTitles[7] := 'Options'; MenuTitles[8] := 'Macros';
  MenuTitles[9] := 'Help';   MenuTitles[10] := 'Quit';

  { File }
  Items[1][1] := 'Open...'; Items[1][2] := 'New';
  Items[1][3] := 'Save As...'; Items[1][4] := 'Print';
  Items[1][5] := 'Exit';
  MenuItemCount[1] := 5;
  { Disk }
  Items[2][1] := 'Format'; Items[2][2] := 'Copy Disk';
  Items[2][3] := 'Directory'; Items[2][4] := 'Change Drive';
  MenuItemCount[2] := 4;
  { View }
  Items[3][1] := 'Tree'; Items[3][2] := 'Directory';
  Items[3][3] := 'Files'; Items[3][4] := 'File Info';
  Items[3][5] := 'Zoom';
  MenuItemCount[3] := 5;
  { Tools }
  Items[4][1] := 'Disk Map'; Items[4][2] := 'Memory Map';
  Items[4][3] := 'System Info'; Items[4][4] := 'File Map';
  MenuItemCount[4] := 4;
  { Setup }
  Items[5][1] := 'Mode'; Items[5][2] := 'Display';
  Items[5][3] := 'Screen Colors'; Items[5][4] := 'Password';
  MenuItemCount[5] := 4;
  { Config }
  Items[6][1] := 'Boot'; Items[6][2] := 'Config';
  Items[6][3] := 'Video';
  MenuItemCount[6] := 3;
  { Options }
  Items[7][1] := 'Output'; Items[7][2] := 'Desktop';
  Items[7][3] := 'Clipboard'; Items[7][4] := 'Save';
  MenuItemCount[7] := 4;
  { Macros }
  Items[8][1] := 'System Info'; Items[8][2] := 'Calculator';
  Items[8][3] := 'Calendar';
  MenuItemCount[8] := 3;
  { Help }
  Items[9][1] := 'About WasmTools'; Items[9][2] := 'How to Use';
  MenuItemCount[9] := 2;
  { Quit }
  Items[10][1] := 'Quit';
  Items[10][2] := 'Save & Quit';
  MenuItemCount[10] := 2;

  { Directory tree (PC Shell style). }
  TreeLines[1]  := 'C:\';
  TreeLines[2]  := '  DOS';
  TreeLines[3]  := '  WINDOWS';
  TreeLines[4]  := '    SYSTEM';
  TreeLines[5]  := '  PROGRA~1';
  TreeLines[6]  := '    SYSTEM32';
  TreeLines[7]  := '    TOOLBOX';
  TreeLines[8]  := '  TOOLS';
  TreeLines[9]  := '    PCTOOLS';
  TreeLines[10] := '  AUTOEXEC.BAT';
  TreeLines[11] := '  CONFIG.SYS';
  TreeLines[12] := '  README.TXT';
end;

{ ======================================================================
  Menu bar
  ====================================================================== }

{ Draw the whole menu bar. }
procedure DrawBar;
var
  i, j: Integer;
  s: String[12];
begin
  Fill(BarX0 - 1, BarY, 79, 1, 7, 1);
  for i := 1 to MenuCount do
  begin
    s := MenuTitles[i];   { exact label; the bar slot is wide }
    for j := 1 to BarWidth do
      if j <= Length(s) then
        Put(BarX0 + (i - 1) * BarWidth + j - 1, BarY, s[j])
      else
        Put(BarX0 + (i - 1) * BarWidth + j - 1, BarY, ' ');
  end;
  { Render the bar row once with color. }
  TextBackground(1);
  TextColor(7);
  GotoXY(1, BarY);
  for i := 1 to 80 do
  begin
    write(ScreenBuf[BarY][i]);
  end;
end;

{ Highlight one bar entry (menu open state). }
procedure BarHighlight(m: Integer; onoff: Boolean);
var
  fg, bg: Integer;
  j: Integer;
  s: String[12];
begin
  if onoff then
  begin
    fg := 0; bg := 15;
  end
  else
  begin
    fg := 7; bg := 1;
  end;
  s := MenuTitles[m];   { exact label, right-aligned width 8 }
  TextBackground(bg);
  TextColor(fg);
  GotoXY(MenuCols[m] - 1, BarY);
  for j := 1 to BarWidth do
    if j <= Length(s) then write(s[j]) else write(' ');
end;

{ ======================================================================
  Pull-down menus
  ====================================================================== }

{ Draw one item of a menu; `sel` = highlight. }
procedure DrawItem(m, i: Integer; sel: Boolean);
var
  fg, bg: Integer;
  x: Integer;
begin
  x := MenuCols[m] - 1;
  if sel then
  begin
    fg := 0; bg := 15;
  end
  else
  begin
    fg := 7; bg := 1;
  end;
  Fill(x, MenuRow + i - 1, MenuWidth, 1, fg, bg);
  if Length(Items[m][i]) > 0 then
    PutStr(x, MenuRow + i - 1, Items[m][i], fg, bg);
end;

{ Draw a whole menu. }
procedure DrawMenu(m: Integer);
var
  i: Integer;
begin
  for i := 1 to MenuItemCount[m] do DrawItem(m, i, false);
end;

{ Remove a menu (restore the background). }
procedure UndrawMenu(m: Integer);
begin
  Fill(MenuCols[m] - 1, MenuRow, MenuWidth, MenuItemCount[m], 7, 1);
end;

{ Run a menu with a moving highlight until dismissed. Returns the picked
  item index, or 0 for cancel. }
function RunMenu(m: Integer): Integer;
var
  cur, k: Integer;
  picked: Integer;
begin
  cur := 1;
  DrawMenu(m);
  DrawItem(m, cur, true);
  picked := 0;
  repeat
    k := ReadKey;
    if k = #0 then k := ReadKey;
    if (k = #72) and (cur > 1) then              { Up }
    begin
      DrawItem(m, cur, false);
      cur := cur - 1;
      DrawItem(m, cur, true);
    end
    else if (k = #80) and (cur < MenuItemCount[m]) then  { Down }
    begin
      DrawItem(m, cur, false);
      cur := cur + 1;
      DrawItem(m, cur, true);
    end
    else if (k = #75) or (k = #77) or (k = #27) then    { L/R/Esc = cancel }
      picked := -1
    else if k = #13 then                               { Enter }
      picked := cur;
  until picked <> 0;
  UndrawMenu(m);
  if picked = -1 then RunMenu := 0
  else RunMenu := picked;
end;

{ Open a menu from the bar; returns the picked item (0 = dismissed). }
function OpenMenu(m: Integer): Integer;
begin
  BarHighlight(m, true);
  OpenMenu := RunMenu(m);
  BarHighlight(m, false);
end;

{ ======================================================================
  Demo contents
  ====================================================================== }

procedure DrawTree;
var
  i: Integer;
begin
  Window(TreeLeft, TreeTop, TreeW, TreeH, ' C:\ Directory Tree ', FrameAttr, 1);
  for i := 1 to 12 do
    PutStr(TreeLeft + 6, TreeTop + i + 1, TreeLines[i], 7, 1);
  DrawHint('Q menu quits  Esc closes');
end;

procedure DrawInfo;
begin
  Window(InfoLeft, InfoTop, InfoW, InfoH, ' System Information ', FrameAttr, 1);
  PutStr(InfoLeft + 6, InfoTop + 3, 'WasmTools 1.0  (c) 2026', 15, 1);
  PutStr(InfoLeft + 6, InfoTop + 5, 'CPU:      Wasm 32-bit (browser)', 7, 1);
  PutStr(InfoLeft + 6, InfoTop + 6, 'Memory:   640K', 7, 1);
  PutStr(InfoLeft + 6, InfoTop + 7, 'DOS:      7.20', 7, 1);
  PutStr(InfoLeft + 6, InfoTop + 8, 'IDE:      Wasmpascal 0.4.0', 7, 1);
  PutStr(InfoLeft + 6, InfoTop + 10, 'Press any key...', 11, 1);
end;

procedure DrawDiskMap;
var
  i, j: Integer;
  ch: Char;
begin
  Window(16, 4, 44, 15, ' Disk Map ', FrameAttr, 1);
  for i := 0 to 4 do
    for j := 0 to 7 do
    begin
      if (i = 0) or ((i * 7 + j) mod 3 = 0) then ch := '#'
      else ch := '.';
      Put(20 + j * 3, 7 + i * 2, ch);
      GotoXY(20 + j * 3, 7 + i * 2);
      TextColor(11);
      write(ch);
    end;
  PutStr(20, 16, 'Bad sectors on track 0', 12, 1);
  DrawHint('Disk sectors, PCTools style');
end;

procedure DrawOpenDialog;
begin
  Window(22, 6, 36, 12, ' Open ', FrameAttr, 1);
  PutStr(26, 9, 'Open File Name:', 15, 1);
  PutStr(26, 10, '*.PAS', 11, 1);
  PutStr(26, 13, 'F3  was the PC Tools open key', 7, 1);
end;

procedure DrawAbout;
begin
  Window(22, 8, 36, 9, ' About WasmTools ', FrameAttr, 1);
  PutStr(26, 10, 'WasmTools 1.0 - a tribute', 15, 1);
  PutStr(26, 12, 'to the PC Tools menu system.', 7, 1);
  DrawHint('Q menu quits');
end;

{ ======================================================================
  Main loop
  ====================================================================== }

var
  k: Char;
  m, i, picked: Integer;
  done: Boolean;
begin
  ClrScr;
  { Clear the virtual screen buffer. }
  for m := 1 to 25 do
    for i := 1 to 80 do ScreenBuf[m][i] := ' ';
  BuildData;
  DrawBar;
  DrawStatus(' WasmTools 1.0 - PC Tools tribute     F3 opens');
  done := false;
  repeat
    k := ReadKey;
    if k = #0 then k := ReadKey;

    { Number keys open the demo dialogs. }
    if (k >= '1') and (k <= '5') then
    begin
      case k of
        '1': DrawTree;
        '2': DrawInfo;
        '3': DrawDiskMap;
        '4': DrawOpenDialog;
        '5': DrawAbout;
      end;
      BlinkEnter;
      DrawBar;
      DrawStatus(' WasmTools 1.0 - PC Tools tribute     F3 opens');
    end;

    { F3 (scan 61) opens the dialog. }
    if k = #61 then
    begin
      DrawOpenDialog;
      BlinkEnter;
      DrawBar;
      DrawStatus(' WasmTools 1.0 - PC Tools tribute     F3 opens');
    end;

    { Menu hotkeys open the corresponding pull-down. }
    if (k >= 'a') and (k <= 'z') then k := Chr(Ord(k) - 32);
    for m := 1 to MenuCount do
      if k = MenuKeys[m] then
      begin
        picked := OpenMenu(m);
        if picked > 0 then
        begin
          case m of
            1: if picked = 1 then DrawOpenDialog
               else if picked = 5 then done := true;
            2: if picked = 3 then DrawTree;
            3: if picked = 4 then DrawInfo;
            4: if picked = 3 then DrawDiskMap;
            10: done := true;
          end;
          if not done then
          begin
            BlinkEnter;
            DrawBar;
            DrawStatus(' WasmTools 1.0 - PC Tools tribute     F3 opens');
          end;
        end;
      end;
  until done;
end.