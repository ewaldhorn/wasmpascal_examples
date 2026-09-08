unit sweepgame;

interface

uses
  sweepdefs,
  sweeprand;

var
  difficulty: Integer = 0;
  state: Integer = ST_UNDEFINED;
  start_time: Double = 0.0;
  last_time: Double = 0.0;
  cells: array[0..MAX_W * MAX_H - 1] of Integer;
  bombs: array[0..MAX_W * MAX_H - 1] of Boolean;
  nums: array[0..MAX_W * MAX_H - 1] of Byte;
  mouse_x: Integer = 0;
  mouse_y: Integer = 0;
  mouse_down: Boolean = false;
  mouse_down_btn: Integer = MB_NONE;
  best_times: array[0..2] of Integer;
  bx: Integer = 9;
  by: Integer = 9;
  nbombs: Integer = 10;
  rng_state: Cardinal = $2545F491;
  lbr0x: Integer; lbr0y: Integer; lbr0w: Integer; lbr0h: Integer;
  lbr1x: Integer; lbr1y: Integer; lbr1w: Integer; lbr1h: Integer;
  lbr2x: Integer; lbr2y: Integer; lbr2w: Integer; lbr2h: Integer;
  pressing_board: Boolean;
  face_pressed: Boolean;
  show_levels: Boolean;
  face_state: Integer;


procedure SyncLevel;

procedure ZeroGameState;

procedure SetDifficulty(d: Integer);

procedure StartGame(click_i, click_j: Integer);

procedure FloodFillOpen(click_i, click_j: Integer);

procedure CheckWin;

function FlagCount: Integer;

procedure GameUpdate;

function CellAt(x, y: Integer): Boolean;

function LevelPickHit(x, y: Integer): Boolean;

procedure HandleLeftClick(x, y: Integer);

procedure HandleRightClick(x, y: Integer);

function KeyIsDigit(buf: Integer; len: Integer; digit: Byte): Boolean;

function KeyIsR(buf: Integer; len: Integer): Boolean;

procedure HandleKeyDown(buf: Integer; len: Integer);

procedure HandleMouseMove(x, y: Integer);

procedure HandleMouseDown(x, y: Integer; button: Integer);

procedure HandleMouseUp(x, y: Integer);

procedure WindowSize(sx, sy: Integer);

procedure WindowOrigin;

procedure FieldRect;

procedure FaceRect;

function FaceHit(x, y: Integer): Boolean;

procedure FillLevelButtons;

implementation


procedure SyncLevel;
begin
  if difficulty = 1 then
  begin
    bx := 16; by := 16; nbombs := 40;
  end
  else if difficulty = 2 then
  begin
    bx := 30; by := 16; nbombs := 99;
  end
  else
  begin
    bx := 9; by := 9; nbombs := 10;
  end;
end;

procedure ZeroGameState;
var
  i: Integer;
begin
  state := ST_UNDEFINED;
  start_time := 0.0;
  last_time := 0.0;
  for i := 0 to MAX_W * MAX_H - 1 do
  begin
    cells[i] := CS_INITIAL;
    bombs[i] := false;
    nums[i] := 0;
  end;
end;

procedure SetDifficulty(d: Integer);
begin
  if (d < 0) or (d >= 3) then Exit;
  difficulty := d;
  SyncLevel;
  SaveDifficulty(d);
  ZeroGameState;
end;

procedure StartGame(click_i, click_j: Integer);
var
  k, attempts, i, j: Integer;
  n: Integer;
begin
  state := ST_PLAYING;
  start_time := dom_now / 1000.0;
  last_time := start_time;
  for i := 0 to MAX_W * MAX_H - 1 do
  begin
    cells[i] := CS_INITIAL;
    bombs[i] := false;
  end;
  for k := 0 to nbombs - 1 do
  begin
    for attempts := 0 to 99 do
    begin
      i := RngInt(bx);
      j := RngInt(by);
      if (not bombs[i * MAX_H + j]) and (not ((i = click_i) and (j = click_j))) then
      begin
        bombs[i * MAX_H + j] := true;
        Break;
      end;
    end;
  end;
  for i := 0 to bx - 1 do
    for j := 0 to by - 1 do
    begin
      n := 0;
      if (i > 0) and (j > 0) then
        if bombs[(i - 1) * MAX_H + (j - 1)] then n := n + 1;
      if j > 0 then
        if bombs[i * MAX_H + (j - 1)] then n := n + 1;
      if i > 0 then
        if bombs[(i - 1) * MAX_H + j] then n := n + 1;
      if j + 1 < by then
        if bombs[i * MAX_H + (j + 1)] then n := n + 1;
      if i + 1 < bx then
        if bombs[(i + 1) * MAX_H + j] then n := n + 1;
      if (i > 0) and (j + 1 < by) then
        if bombs[(i - 1) * MAX_H + (j + 1)] then n := n + 1;
      if (i + 1 < bx) and (j > 0) then
        if bombs[(i + 1) * MAX_H + (j - 1)] then n := n + 1;
      if (i + 1 < bx) and (j + 1 < by) then
        if bombs[(i + 1) * MAX_H + (j + 1)] then n := n + 1;
      nums[i * MAX_H + j] := Byte(n);
    end;
end;

procedure FloodFillOpen(click_i, click_j: Integer);
var
  i, j: Integer;
begin
  cells[click_i * MAX_H + click_j] := CS_OPENED;
  if nums[click_i * MAX_H + click_j] > 0 then Exit;
  for i := click_i - 1 to click_i + 1 do
    for j := click_j - 1 to click_j + 1 do
    begin
      if (i = click_i) and (j = click_j) then continue;
      if (i < 0) or (j < 0) then continue;
      if (i >= bx) or (j >= by) then continue;
      if cells[i * MAX_H + j] <> CS_OPENED then
        FloodFillOpen(i, j);
    end;
end;

procedure CheckWin;
var
  i, j: Integer;
  elapsed, best: Integer;
begin
  for i := 0 to bx - 1 do
    for j := 0 to by - 1 do
      if (cells[i * MAX_H + j] <> CS_OPENED) and (not bombs[i * MAX_H + j]) then Exit;
  for i := 0 to bx - 1 do
    for j := 0 to by - 1 do
      if bombs[i * MAX_H + j] then
        cells[i * MAX_H + j] := CS_FLAGGED;
  state := ST_WON;
  elapsed := Integer(last_time - start_time);
  best := best_times[difficulty];
  if (best = 0) or (elapsed < best) then
  begin
    best_times[difficulty] := elapsed;
    SaveBestTime(difficulty, elapsed);
  end;
end;

function FlagCount: Integer;
var
  i, count: Integer;
begin
  count := 0;
  for i := 0 to MAX_W * MAX_H - 1 do
    if cells[i] = CS_FLAGGED then count := count + 1;
  FlagCount := count;
end;

procedure GameUpdate;
begin
  if state = ST_PLAYING then
    last_time := dom_now / 1000.0;
end;

function CellAt(x, y: Integer): Boolean;
var
  fi, fj: Integer;
begin
  FieldRect;
  CellAt := false;
  if (x < field_x) or (y < field_y) then Exit;
  fi := (x - field_x) div CELL_SIZE;
  fj := (y - field_y) div CELL_SIZE;
  if (fi < 0) or (fj < 0) then Exit;
  if (fi >= bx) or (fj >= by) then Exit;
  cell_i := fi;
  cell_j := fj;
  CellAt := true;
end;

function LevelPickHit(x, y: Integer): Boolean;
begin
  FillLevelButtons;
  LevelPickHit := false;
  if (x >= lbr0x) and (x < lbr0x + lbr0w) and (y >= lbr0y) and (y < lbr0y + lbr0h) then
  begin
    SetDifficulty(0);
    LevelPickHit := true;
  end
  else if (x >= lbr1x) and (x < lbr1x + lbr1w) and (y >= lbr1y) and (y < lbr1y + lbr1h) then
  begin
    SetDifficulty(1);
    LevelPickHit := true;
  end
  else if (x >= lbr2x) and (x < lbr2x + lbr2w) and (y >= lbr2y) and (y < lbr2y + lbr2h) then
  begin
    SetDifficulty(2);
    LevelPickHit := true;
  end;
end;

procedure HandleLeftClick(x, y: Integer);
begin
  if FaceHit(x, y) then
  begin
    ZeroGameState;
    Exit;
  end;
  if state = ST_UNDEFINED then
    if LevelPickHit(x, y) then Exit;
  if (state = ST_WON) or (state = ST_LOST) then Exit;
  if not CellAt(x, y) then Exit;
  if state = ST_UNDEFINED then
    StartGame(cell_i, cell_j);
  if cells[cell_i * MAX_H + cell_j] = CS_FLAGGED then Exit;
  if bombs[cell_i * MAX_H + cell_j] then
  begin
    cells[cell_i * MAX_H + cell_j] := CS_OPENED;
    state := ST_LOST;
    Exit;
  end;
  if nums[cell_i * MAX_H + cell_j] = 0 then
    FloodFillOpen(cell_i, cell_j)
  else
    cells[cell_i * MAX_H + cell_j] := CS_OPENED;
  CheckWin;
end;

procedure HandleRightClick(x, y: Integer);
var
  idx: Integer;
begin
  if (state = ST_WON) or (state = ST_LOST) then Exit;
  if not CellAt(x, y) then Exit;
  if state = ST_UNDEFINED then
    StartGame(cell_i, cell_j);
  idx := cell_i * MAX_H + cell_j;
  case cells[idx] of
    1: begin end;                                    // opened: ignored
    0: cells[idx] := 2;                              // initial -> flagged
    2: cells[idx] := 3;                              // flagged -> uncertain
    3: cells[idx] := 0;                              // uncertain -> initial
    else cells[idx] := 0;
  end;
end;

function KeyIsDigit(buf: Integer; len: Integer; digit: Byte): Boolean;
begin
  KeyIsDigit := (len = 1) and (PB(buf, 0) = 48 + digit);
end;

function KeyIsR(buf: Integer; len: Integer): Boolean;
begin
  KeyIsR := (len = 1) and ((PB(buf, 0) = 114) or (PB(buf, 0) = 82)); // r | R
end;

procedure HandleKeyDown(buf: Integer; len: Integer);
begin
  if state = ST_UNDEFINED then
  begin
    if KeyIsDigit(buf, len, 1) then SetDifficulty(0);
    if KeyIsDigit(buf, len, 2) then SetDifficulty(1);
    if KeyIsDigit(buf, len, 3) then SetDifficulty(2);
  end;
  if KeyIsR(buf, len) then ZeroGameState;
end;

procedure HandleMouseMove(x, y: Integer);
begin
  mouse_x := x;
  mouse_y := y;
end;

procedure HandleMouseDown(x, y: Integer; button: Integer);
begin
  mouse_x := x;
  mouse_y := y;
  mouse_down := true;
  mouse_down_btn := button;
end;

procedure HandleMouseUp(x, y: Integer);
begin
  mouse_x := x;
  mouse_y := y;
  mouse_down := false;
  mouse_down_btn := MB_NONE;
end;

procedure WindowSize(sx, sy: Integer);
begin
  win_w := sx * CELL_SIZE + 28;
  win_h := sy * CELL_SIZE + 74;
end;

procedure WindowOrigin;
begin
  WindowSize(bx, by);
  win_ox := (CANVAS_W - win_w) div 2;
  win_oy := (CANVAS_H - win_h) div 2;
end;

procedure FieldRect;
begin
  WindowOrigin;
  field_x := win_ox + 14;
  field_y := win_oy + 60;
  field_w := bx * CELL_SIZE;
  field_h := by * CELL_SIZE;
end;

procedure FaceRect;
begin
  WindowOrigin;
  WindowSize(bx, by);
  face_x := win_ox + (win_w - 32) div 2;
  face_y := win_oy + 14;
  face_w := 32;
  face_h := 32;
end;

function FaceHit(x, y: Integer): Boolean;
begin
  FaceRect;
  FaceHit := (x >= face_x) and (x < face_x + face_w) and (y >= face_y) and (y < face_y + face_h);
end;

procedure FillLevelButtons;
begin
  WindowOrigin;
  lbr0x := win_ox + 14; lbr0y := win_oy + 18; lbr0w := 24; lbr0h := 24;
  lbr1x := win_ox + 38; lbr1y := win_oy + 18; lbr1w := 24; lbr1h := 24;
  lbr2x := win_ox + 62; lbr2y := win_oy + 18; lbr2w := 24; lbr2h := 24;
end;

begin
end.
