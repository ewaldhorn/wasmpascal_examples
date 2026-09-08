// xonix.pas — Xonix on the batchiness canvas ABI.
//
// Faithful port of odinix (skidmark/languages/odin/wasm/games/odinix), a
// direct port of the classic Xonix. The capture rule is the important one:
// the board floods from the ENEMIES — every sea cell reachable by any enemy
// is safe, and only sea no enemy can reach becomes land. An enclosed ball
// therefore keeps its own pocket open; the fill can never cover a ball.
//
// Rules: 40x25 cells, a 2-cell land frame, open sea inside. The marker moves
// cell by cell (arrows, 80ms/step, no reversing); on sea it leaves a trail,
// on land the trail closes and the enemy-free region it cut off is claimed.
// Touching the trail or a ball costs a life (3 lives, +1 every 5 levels).
// Claim 75% of the field to level up (more balls per level, max 10).

library xonix;

const
  COLS = 40;
  ROWS = 25;
  CELL = 30;
  HUD_H = 44;
  W = 1200;          // COLS * CELL
  H = 750;           // ROWS * CELL
  CANVAS_H = 794;    // H + HUD_H

  G_SEA = 0;
  G_LAND = 1;
  G_TRAIL = 2;

  ST_START = 0;
  ST_PLAYING = 1;
  ST_OVER = 2;
  ST_LEVELUP = 3;

  MOVE_MS = 80.0;        // player ms per cell step
  ENEMY_SPEED = 100.0;   // enemy pixels per second (per axis)
  MAX_ENEMIES = 10;
  TARGET_PCT = 75;

  CB_TICK = 0;
  CB_KEYDOWN = 1;
  CB_KEYUP = 2;

  // batch opcodes (wire format from batch.odin / batchiness.js)
  OP_SET_FILL = $01;
  OP_SET_FONT = $04;
  OP_FILL_RECT = $10;
  OP_BEGIN_PATH = $20;
  OP_ARC = $24;
  OP_FILL = $28;
  OP_FILL_TEXT = $30;
  OP_SET_SHADOW = $70;
  OP_CLEAR_SHADOW = $71;

  CMD_CAPACITY = 32768;
  TEXT_CAP = 128;

  // colors (odinix palette)
  COL_LAND = '#00ffcc';
  COL_TRAIL = '#ff00ff';
  COL_ENEMY = '#ff0055';
  COL_PLAYER = '#ffffff';

type
  TEnemy = record
    pixel_x, pixel_y: Double;
    vel_x, vel_y: Double;
    size: Double;
    active: Boolean;
  end;

var
  grid: array[0..COLS - 1, 0..ROWS - 1] of Byte;
  safe_set: array[0..COLS - 1, 0..ROWS - 1] of Byte;
  enemies: array[0..MAX_ENEMIES - 1] of TEnemy;
  enemy_count: Integer;

  px, py, pdx, pdy: Integer;
  move_timer: Double;

  score, level, lives: Integer;
  status: Integer;
  level_up_timer: Double;

  pending_dx, pending_dy: Integer;
  has_pending: Boolean;
  start_requested: Boolean;

  rng_state: Cardinal;
  last_ms: Double;
  ctx: Integer;
  last_event: Integer;

  cmd: array[0..CMD_CAPACITY - 1] of Byte;
  cmd_len: Integer;
  text_buf: array[0..TEXT_CAP - 1] of Byte;
  tmp16: array[0..15] of Byte;
  fill_stack: array[0..COLS * ROWS - 1] of Integer;

// ---- External imports ----
procedure bBatchFlush(c, buf, len: Integer); external 'batch_env' name 'batch_cmd_flush';
function  bNow: Double; external 'batch_env' name 'batch_now';
function  bCanvasCreate(parent, w, h: Integer): Integer; external 'batch_env' name 'batch_canvas_create';
function  bGetElement(p: Integer; n: Integer): Integer; external 'batch_env' name 'batch_get_element_by_id';
function  bGetGlobal(nm: string): Integer; external 'batch_env' name 'batch_get_global';
function  bGetContext(canvas: Integer): Integer; external 'batch_env' name 'batch_canvas_get_context';
procedure bStartLoop(cbId: Integer); external 'batch_env' name 'batch_start_animation_loop';
procedure bAddListener(elem: Integer; ev: string; cb: Integer); external 'batch_env' name 'batch_add_event_listener';
function  bGetPropStr(h: Integer; k: string; buf: Integer; maxlen: Integer): Integer;
          external 'batch_env' name 'batch_get_property_str';

// ---- RNG (xorshift32, same as odinix) ----
function NextRand: Cardinal;
begin
  rng_state := rng_state xor (rng_state shl 13);
  rng_state := rng_state xor (rng_state shr 17);
  rng_state := rng_state xor (rng_state shl 5);
  NextRand := rng_state;
end;

function RandInt(n: Integer): Integer;
begin
  if n <= 0 then begin RandInt := 0; Exit; end;
  RandInt := Integer(NextRand mod Cardinal(n));
end;

// [1-pct, 1+pct] bounce multiplier
function Jitter(pct: Double): Double;
begin
  Jitter := 1.0 - pct + (Double(NextRand mod 10001) / 10000.0) * 2.0 * pct;
end;

// ---- Batch wire writers ----
procedure BufReset;
begin
  cmd_len := 0;
end;

procedure PutU8(v: Integer);
begin
  if cmd_len + 1 > CMD_CAPACITY then Exit;
  cmd[cmd_len] := Byte(v);
  cmd_len := cmd_len + 1;
end;

procedure PutU16(v: Integer);
begin
  if cmd_len + 2 > CMD_CAPACITY then Exit;
  cmd[cmd_len] := Byte(v and $FF);
  cmd[cmd_len + 1] := Byte((v shr 8) and $FF);
  cmd_len := cmd_len + 2;
end;

procedure PutF32(v: Single);
var
  bits: Cardinal;
begin
  bits := F32Bits(v);
  if cmd_len + 4 > CMD_CAPACITY then Exit;
  cmd[cmd_len] := Byte(bits and $FF);
  cmd[cmd_len + 1] := Byte((bits shr 8) and $FF);
  cmd[cmd_len + 2] := Byte((bits shr 16) and $FF);
  cmd[cmd_len + 3] := Byte((bits shr 24) and $FF);
  cmd_len := cmd_len + 4;
end;

procedure PutLit(p: Integer; n: Integer);
var
  i: Integer;
begin
  if cmd_len + 2 + n > CMD_CAPACITY then Exit;
  PutU16(n);
  for i := 0 to n - 1 do
  begin
    cmd[cmd_len] := PByte(p)[i];
    cmd_len := cmd_len + 1;
  end;
end;

procedure bSetFill(p: Integer; n: Integer);
begin
  PutU8(OP_SET_FILL); PutLit(p, n);
end;

procedure bSetShadow(p: Integer; n: Integer; blur: Single);
begin
  PutU8(OP_SET_SHADOW); PutLit(p, n); PutF32(blur);
end;

procedure bClearShadow;
begin
  PutU8(OP_CLEAR_SHADOW);
end;

procedure bSetFont(p: Integer; n: Integer);
begin
  PutU8(OP_SET_FONT); PutLit(p, n);
end;

procedure bFillRect(x, y, w, h: Single);
begin
  PutU8(OP_FILL_RECT); PutF32(x); PutF32(y); PutF32(w); PutF32(h);
end;

procedure bBeginPath;
begin
  PutU8(OP_BEGIN_PATH);
end;

procedure bArc(x, y, r, a0, a1: Single);
begin
  PutU8(OP_ARC); PutF32(x); PutF32(y); PutF32(r); PutF32(a0); PutF32(a1); PutU8(0);
end;

procedure bFill;
begin
  PutU8(OP_FILL);
end;

procedure bFillText(ptr: Integer; tlen, x, y: Integer);
var
  i: Integer;
begin
  PutU8(OP_FILL_TEXT);
  if cmd_len + 2 + tlen > CMD_CAPACITY then Exit;
  PutU16(tlen);
  for i := 0 to tlen - 1 do
  begin
    cmd[cmd_len] := PByte(ptr)[i];
    cmd_len := cmd_len + 1;
  end;
  PutF32(Single(x));
  PutF32(Single(y));
end;

// ---- Text builders (fixed scratch buffer) ----
procedure AppendChar(var off: Integer; c: Byte);
begin
  if off < TEXT_CAP then text_buf[off] := c;
  off := off + 1;
end;

procedure AppendInt(var off: Integer; n: Integer);
var
  d, x, c, i: Integer;
begin
  x := n;
  d := 0;
  if x = 0 then
  begin
    tmp16[0] := 48;
    d := 1;
  end else begin
    while x > 0 do
    begin
      tmp16[d] := Byte(48 + (x mod 10));
      x := x div 10;
      d := d + 1;
    end;
  end;
  for i := 0 to d - 1 do
  begin
    if off + i < TEXT_CAP then text_buf[off + i] := tmp16[d - 1 - i];
  end;
  off := off + d;
end;

procedure AppendStr(var off: Integer; s: String);
var
  i: Integer;
begin
  for i := 0 to Length(s) - 1 do
  begin
    if off + i < TEXT_CAP then text_buf[off + i] := PByte(StrAddr(s))[i];
  end;
  off := off + Length(s);
end;

// ---- Grid ----
procedure GridReset;
var
  x, y: Integer;
begin
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do
      if (x < 2) or (x >= COLS - 2) or (y < 2) or (y >= ROWS - 2) then
        grid[x, y] := G_LAND
      else
        grid[x, y] := G_SEA;
end;

function GetCell(x, y: Integer): Byte;
begin
  if (x < 0) or (x >= COLS) or (y < 0) or (y >= ROWS) then begin GetCell := G_LAND; Exit; end;
  GetCell := grid[x, y];
end;

procedure ClearTrail;
var
  x, y: Integer;
begin
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do
      if grid[x, y] = G_TRAIL then grid[x, y] := G_SEA;
end;

// ---- Capture: flood from every enemy; only enemy-unreachable sea fills ----
procedure FloodEnemy(ei: Integer);
var
  sx, sy, sp, x, y: Integer;
begin
  if not enemies[ei].active then Exit;
  sx := Trunc((enemies[ei].pixel_x + enemies[ei].size / 2.0) / CELL);
  sy := Trunc((enemies[ei].pixel_y + enemies[ei].size / 2.0) / CELL);
  if (sx < 0) or (sx >= COLS) or (sy < 0) or (sy >= ROWS) then Exit;
  if (grid[sx, sy] <> G_SEA) or (safe_set[sx, sy] <> 0) then Exit;
  sp := 0;
  safe_set[sx, sy] := 1;
  fill_stack[sp] := sy * 256 + sx;
  sp := sp + 1;
  while sp > 0 do
  begin
    sp := sp - 1;
    y := fill_stack[sp] div 256;
    x := fill_stack[sp] mod 256;
    if (x > 0) and (grid[x - 1, y] = G_SEA) and (safe_set[x - 1, y] = 0) then
    begin
      safe_set[x - 1, y] := 1;
      fill_stack[sp] := y * 256 + (x - 1);
      sp := sp + 1;
    end;
    if (x < COLS - 1) and (grid[x + 1, y] = G_SEA) and (safe_set[x + 1, y] = 0) then
    begin
      safe_set[x + 1, y] := 1;
      fill_stack[sp] := y * 256 + (x + 1);
      sp := sp + 1;
    end;
    if (y > 0) and (grid[x, y - 1] = G_SEA) and (safe_set[x, y - 1] = 0) then
    begin
      safe_set[x, y - 1] := 1;
      fill_stack[sp] := (y - 1) * 256 + x;
      sp := sp + 1;
    end;
    if (y < ROWS - 1) and (grid[x, y + 1] = G_SEA) and (safe_set[x, y + 1] = 0) then
    begin
      safe_set[x, y + 1] := 1;
      fill_stack[sp] := (y + 1) * 256 + x;
      sp := sp + 1;
    end;
  end;
end;

function PercentCaptured: Double;
var
  x, y, n: Integer;
begin
  n := 0;
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do
      if grid[x, y] = G_LAND then n := n + 1;
  PercentCaptured := Double(n) * 100.0 / Double(COLS * ROWS);
end;

procedure AddScore(points: Integer);
begin
  score := score + points;
  if PercentCaptured >= TARGET_PCT then
  begin
    status := ST_LEVELUP;
    level_up_timer := 1000.0;
  end;
end;

// BFS from the enemy's cell to the nearest sea; teleport it there and flip
// its velocity. Called after captures (and every update, cheap no-op when
// the enemy is already on sea).
procedure EnsureInSea(ei: Integer);
var
  cs, cx, cy: Double;
  gx, gy, head, tail, x, y: Integer;
  found: Boolean;
begin
  if not enemies[ei].active then Exit;
  cs := CELL;
  if GetCell(Trunc(enemies[ei].pixel_x / cs), Trunc(enemies[ei].pixel_y / cs)) <> G_LAND then Exit;
  if GetCell(Trunc((enemies[ei].pixel_x + enemies[ei].size) / cs), Trunc(enemies[ei].pixel_y / cs)) <> G_LAND then Exit;
  if GetCell(Trunc(enemies[ei].pixel_x / cs), Trunc((enemies[ei].pixel_y + enemies[ei].size) / cs)) <> G_LAND then Exit;
  if GetCell(Trunc((enemies[ei].pixel_x + enemies[ei].size) / cs), Trunc((enemies[ei].pixel_y + enemies[ei].size) / cs)) <> G_LAND then Exit;

  cx := enemies[ei].pixel_x + enemies[ei].size / 2.0;
  cy := enemies[ei].pixel_y + enemies[ei].size / 2.0;
  gx := Trunc(cx / cs);
  gy := Trunc(cy / cs);

  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do safe_set[x, y] := 0;
  head := 0;
  tail := 0;
  found := false;
  if (gx >= 0) and (gx < COLS) and (gy >= 0) and (gy < ROWS) then
  begin
    safe_set[gx, gy] := 1;
    fill_stack[tail] := gy * 256 + gx;
    tail := tail + 1;
  end;
  while (head < tail) and (not found) do
  begin
    y := fill_stack[head] div 256;
    x := fill_stack[head] mod 256;
    head := head + 1;
    if grid[x, y] = G_SEA then
    begin
      enemies[ei].pixel_x := Double(x) * cs + (cs - enemies[ei].size) / 2.0;
      enemies[ei].pixel_y := Double(y) * cs + (cs - enemies[ei].size) / 2.0;
      enemies[ei].vel_x := -enemies[ei].vel_x;
      enemies[ei].vel_y := -enemies[ei].vel_y;
      found := true;
    end
    else begin
      if (x > 0) and (safe_set[x - 1, y] = 0) then
      begin
        safe_set[x - 1, y] := 1;
        fill_stack[tail] := y * 256 + (x - 1);
        tail := tail + 1;
      end;
      if (x < COLS - 1) and (safe_set[x + 1, y] = 0) then
      begin
        safe_set[x + 1, y] := 1;
        fill_stack[tail] := y * 256 + (x + 1);
        tail := tail + 1;
      end;
      if (y > 0) and (safe_set[x, y - 1] = 0) then
      begin
        safe_set[x, y - 1] := 1;
        fill_stack[tail] := (y - 1) * 256 + x;
        tail := tail + 1;
      end;
      if (y < ROWS - 1) and (safe_set[x, y + 1] = 0) then
      begin
        safe_set[x, y + 1] := 1;
        fill_stack[tail] := (y + 1) * 256 + x;
        tail := tail + 1;
      end;
    end;
  end;
end;

procedure CheckCapture;
var
  x, y, i, captured: Integer;
begin
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do safe_set[x, y] := 0;

  for i := 0 to enemy_count - 1 do FloodEnemy(i);

  captured := 0;
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do
    begin
      if grid[x, y] = G_TRAIL then grid[x, y] := G_LAND
      else if (grid[x, y] = G_SEA) and (safe_set[x, y] = 0) then
      begin
        grid[x, y] := G_LAND;
        captured := captured + 1;
      end;
    end;

  if captured > 0 then AddScore(captured * 10);

  for i := 0 to enemy_count - 1 do EnsureInSea(i);
end;

// ---- Player ----
procedure PlayerReset;
begin
  px := COLS div 2;
  py := 0;
  pdx := 0;
  pdy := 0;
  move_timer := 0.0;
end;

procedure SetDir(dx, dy: Integer);
begin
  // No reversing (exactly), like odinix.
  if (pdx = -dx) and (pdy = -dy) and ((pdx <> 0) or (pdy <> 0)) then Exit;
  pdx := dx;
  pdy := dy;
end;

procedure PlayerDied;
begin
  if (lives <= 0) or (status <> ST_PLAYING) then Exit;
  lives := lives - 1;
  if lives <= 0 then
    status := ST_OVER
  else begin
    PlayerReset;
    ClearTrail;
  end;
end;

// Returns 0 = nothing, 1 = died, 2 = captured.
function PlayerUpdate(dt_ms: Double): Integer;
var
  nx, ny, next_cell, prev_cell: Integer;
begin
  PlayerUpdate := 0;
  if (pdx = 0) and (pdy = 0) then Exit;
  move_timer := move_timer + dt_ms;
  if move_timer < MOVE_MS then Exit;
  move_timer := 0.0;

  nx := px + pdx;
  ny := py + pdy;

  if (nx >= 0) and (nx < COLS) and (ny >= 0) and (ny < ROWS) then
  begin
    next_cell := grid[nx, ny];
    prev_cell := grid[px, py];

    if next_cell = G_TRAIL then
    begin
      PlayerDied;
      PlayerUpdate := 1;
      Exit;
    end;

    px := nx;
    py := ny;

    if next_cell = G_SEA then
      grid[px, py] := G_TRAIL
    else if next_cell = G_LAND then
    begin
      // Returned to land from the trail -> capture.
      if prev_cell = G_TRAIL then
      begin
        CheckCapture;
        PlayerUpdate := 2;
      end;
    end;
  end else begin
    // Hit the screen edge: stop.
    pdx := 0;
    pdy := 0;
  end;
end;

// ---- Enemies ----
function IsValidSpawn(x, y: Integer): Boolean;
var
  dx, dy: Double;
begin
  IsValidSpawn := false;
  if GetCell(x, y) <> G_SEA then Exit;
  dx := Double(x - px);
  dy := Double(y - py);
  if Sqrt(dx * dx + dy * dy) < 8.0 then Exit;
  if (GetCell(x + 1, y) = G_SEA) or (GetCell(x - 1, y) = G_SEA) or
     (GetCell(x, y + 1) = G_SEA) or (GetCell(x, y - 1) = G_SEA) then
    IsValidSpawn := true;
end;

procedure EnemyReset(ei, gx, gy: Integer);
begin
  enemies[ei].pixel_x := Double(gx * CELL);
  enemies[ei].pixel_y := Double(gy * CELL);
  enemies[ei].vel_x := ENEMY_SPEED;
  enemies[ei].vel_y := ENEMY_SPEED;
  enemies[ei].size := CELL - 8;
  enemies[ei].active := true;
end;

procedure StartLevel;
var
  i, ex, ey, tries, sx, sy, x, y: Integer;
  found: Boolean;
begin
  status := ST_PLAYING;
  GridReset;
  PlayerReset;

  enemy_count := level;
  if enemy_count > MAX_ENEMIES then enemy_count := MAX_ENEMIES;

  for i := 0 to enemy_count - 1 do
  begin
    ex := 0;
    ey := 0;
    found := false;
    tries := 0;
    while (not found) and (tries < 200) do
    begin
      ex := RandInt(COLS - 4) + 2;
      ey := RandInt(ROWS - 4) + 2;
      tries := tries + 1;
      if IsValidSpawn(ex, ey) then found := true;
    end;

    // Fallback: scan the grid from a random offset.
    if not found then
    begin
      sx := RandInt(COLS);
      sy := RandInt(ROWS);
      for y := 0 to ROWS - 1 do
      begin
        for x := 0 to COLS - 1 do
        begin
          ex := (sx + x) mod COLS;
          ey := (sy + y) mod ROWS;
          if IsValidSpawn(ex, ey) then
          begin
            found := true;
            break;
          end;
        end;
        if found then break;
      end;
    end;

    if not found then
    begin
      ex := COLS div 2;
      ey := ROWS div 2;
    end;

    EnemyReset(i, ex, ey);
  end;
end;

procedure StartGame;
begin
  score := 0;
  level := 1;
  lives := 3;
  StartLevel;
end;

// 4-corner land collision for an enemy box at (bx, by). Out-of-bounds
// corners are ignored (the canvas wall clamps handle the edges).
function EnemyCollides(ei: Integer; bx, by: Double): Boolean;
var
  sz, x0, y0: Double;
  gx, gy: Integer;
begin
  EnemyCollides := false;
  sz := enemies[ei].size;
  x0 := bx / CELL;
  y0 := by / CELL;
  gx := Trunc(x0);
  gy := Trunc(y0);
  if (gx >= 0) and (gx < COLS) and (gy >= 0) and (gy < ROWS) then
    if grid[gx, gy] = G_LAND then begin EnemyCollides := true; Exit; end;
  gx := Trunc((bx + sz) / CELL);
  if (gx >= 0) and (gx < COLS) and (gy >= 0) and (gy < ROWS) then
    if grid[gx, gy] = G_LAND then begin EnemyCollides := true; Exit; end;
  gx := Trunc(x0);
  gy := Trunc((by + sz) / CELL);
  if (gx >= 0) and (gx < COLS) and (gy >= 0) and (gy < ROWS) then
    if grid[gx, gy] = G_LAND then begin EnemyCollides := true; Exit; end;
  gx := Trunc((bx + sz) / CELL);
  gy := Trunc((by + sz) / CELL);
  if (gx >= 0) and (gx < COLS) and (gy >= 0) and (gy < ROWS) then
    if grid[gx, gy] = G_LAND then EnemyCollides := true;
end;

procedure EnemyUpdate(ei: Integer; dt_ms: Double);
var
  dt, cs, next_x, next_y, tmp: Double;
  cx, cy, gx, gy, i: Integer;
  dx, dy, dist, ox, oy, edx, edy, edist, nx2, ny2, relx, rely, dot: Double;
begin
  if not enemies[ei].active then Exit;
  dt := dt_ms / 1000.0;
  cs := CELL;

  EnsureInSea(ei);

  // Move X.
  next_x := enemies[ei].pixel_x + enemies[ei].vel_x * dt;
  if EnemyCollides(ei, next_x, enemies[ei].pixel_y) then
  begin
    if enemies[ei].vel_x > 0 then
      enemies[ei].pixel_x := Double(Trunc((next_x + enemies[ei].size) / cs)) * cs - enemies[ei].size - 0.1
    else
      enemies[ei].pixel_x := Double(Trunc(next_x / cs) + 1) * cs + 0.1;
    enemies[ei].vel_x := -enemies[ei].vel_x * Jitter(0.07);
  end else
    enemies[ei].pixel_x := next_x;

  // Move Y.
  next_y := enemies[ei].pixel_y + enemies[ei].vel_y * dt;
  if EnemyCollides(ei, enemies[ei].pixel_x, next_y) then
  begin
    if enemies[ei].vel_y > 0 then
      enemies[ei].pixel_y := Double(Trunc((next_y + enemies[ei].size) / cs)) * cs - enemies[ei].size - 0.1
    else
      enemies[ei].pixel_y := Double(Trunc(next_y / cs) + 1) * cs + 0.1;
    enemies[ei].vel_y := -enemies[ei].vel_y * Jitter(0.07);
  end else
    enemies[ei].pixel_y := next_y;

  // Canvas wall clamps.
  if enemies[ei].pixel_x <= 0 then
  begin
    enemies[ei].pixel_x := 0;
    enemies[ei].vel_x := Abs(enemies[ei].vel_x) * Jitter(0.07);
  end;
  if enemies[ei].pixel_x + enemies[ei].size >= W then
  begin
    enemies[ei].pixel_x := W - enemies[ei].size;
    enemies[ei].vel_x := -Abs(enemies[ei].vel_x) * Jitter(0.07);
  end;
  if enemies[ei].pixel_y <= 0 then
  begin
    enemies[ei].pixel_y := 0;
    enemies[ei].vel_y := Abs(enemies[ei].vel_y) * Jitter(0.07);
  end;
  if enemies[ei].pixel_y + enemies[ei].size >= H then
  begin
    enemies[ei].pixel_y := H - enemies[ei].size;
    enemies[ei].vel_y := -Abs(enemies[ei].vel_y) * Jitter(0.07);
  end;

  // Trail impact: the enemy's center on the trail kills the player.
  cx := Trunc((enemies[ei].pixel_x + enemies[ei].size / 2.0) / cs);
  cy := Trunc((enemies[ei].pixel_y + enemies[ei].size / 2.0) / cs);
  if (cx >= 0) and (cx < COLS) and (cy >= 0) and (cy < ROWS) then
    if grid[cx, cy] = G_TRAIL then
    begin
      PlayerDied;
      Exit;
    end;

  // Player collision.
  dx := enemies[ei].pixel_x + enemies[ei].size / 2.0 - (Double(px) * cs + cs / 2.0);
  dy := enemies[ei].pixel_y + enemies[ei].size / 2.0 - (Double(py) * cs + cs / 2.0);
  dist := Sqrt(dx * dx + dy * dy);
  if dist < (enemies[ei].size / 2.0 + cs / 2.0) then
  begin
    PlayerDied;
    Exit;
  end;

  // Enemy-enemy collisions: swap velocities when approaching.
  for i := ei + 1 to enemy_count - 1 do
  begin
    if not enemies[i].active then continue;
    ox := enemies[i].pixel_x + enemies[i].size / 2.0;
    oy := enemies[i].pixel_y + enemies[i].size / 2.0;
    edx := enemies[ei].pixel_x + enemies[ei].size / 2.0 - ox;
    edy := enemies[ei].pixel_y + enemies[ei].size / 2.0 - oy;
    edist := Sqrt(edx * edx + edy * edy);
    if edist < enemies[ei].size then
    begin
      // Collision normal (a ternary, as in odinix: short-circuits the
      // divide so a zero distance never divides).
      nx2 := (if edist = 0 then 1.0 else edx / edist);
      ny2 := (if edist = 0 then 0.0 else edy / edist);
      relx := enemies[ei].vel_x - enemies[i].vel_x;
      rely := enemies[ei].vel_y - enemies[i].vel_y;
      dot := relx * nx2 + rely * ny2;
      if dot < 0 then
      begin
        tmp := enemies[ei].vel_x;
        enemies[ei].vel_x := enemies[i].vel_x;
        enemies[i].vel_x := tmp;
        tmp := enemies[ei].vel_y;
        enemies[ei].vel_y := enemies[i].vel_y;
        enemies[i].vel_y := tmp;
      end;
    end;
  end;
end;

// ---- Drawing ----
procedure DrawHUD;
var
  o: Integer;
  pct: Double;
  ip, fp: Integer;
begin
  bSetFill(StrAddr('#cdd7ea'), 7);
  bSetFont(StrAddr('20px monospace'), 14);

  o := 0;
  AppendStr(o, 'SCORE ');
  AppendInt(o, score);
  AppendStr(o, '    LV ');
  AppendInt(o, level);
  AppendStr(o, '    AREA ');
  pct := PercentCaptured;
  ip := Trunc(pct);
  fp := Trunc((pct - Double(ip)) * 10.0);
  if fp < 0 then fp := -fp;
  AppendInt(o, ip);
  AppendChar(o, 46); // '.'
  AppendChar(o, Byte(48 + fp));
  AppendChar(o, 37); // '%'
  AppendStr(o, '    LIVES ');
  AppendInt(o, lives);
  bFillText(Integer(@text_buf), o, 10, 14);

  // Status line over the gameplay area: LIGHT bold text on a SOLID dark
  // panel, so it reads over the bright teal frame and over dark sea alike
  // (a dark shadow gives the text a 1px lift).
  o := 0;
  if status = ST_START then
    AppendStr(o, 'XONIX — PRESS SPACE TO START')
  else if status = ST_OVER then
    AppendStr(o, 'GAME OVER — PRESS SPACE TO RESTART')
  else if status = ST_LEVELUP then
    AppendStr(o, 'LEVEL UP!');
  if o > 0 then
  begin
    bSetFill(StrAddr('rgba(5,5,16,0.85)'), 17);
    bFillRect(Single(W div 2 - o * 7 - 12), 38, Single(o * 14 + 24), 30);
    bSetFill(StrAddr('#eaf6ff'), 7);
    bSetFont(StrAddr('bold 22px monospace'), 20);
    bSetShadow(StrAddr('rgba(0,0,0,0.8)'), 15, 1.0);
    bFillText(Integer(@text_buf), o, W div 2 - o * 7, 58);
    bClearShadow;
  end;
end;

procedure Draw;
var
  x, y, i: Integer;
begin
  BufReset;

  // Background.
  bSetFill(StrAddr('#050510'), 7);
  bFillRect(0, 0, W, CANVAS_H);

  // Land + trail cells.
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do
    begin
      if grid[x, y] = G_LAND then
      begin
        bSetFill(StrAddr(COL_LAND), 7);
        bFillRect(Single(x * CELL), Single(HUD_H + y * CELL), CELL, CELL);
      end
      else if grid[x, y] = G_TRAIL then
      begin
        bSetFill(StrAddr(COL_TRAIL), 7);
        bFillRect(Single(x * CELL), Single(HUD_H + y * CELL), CELL, CELL);
      end;
    end;

  // No grid lines — they read as harsh cell separators; the sea is plain.

  // Player.
  bSetFill(StrAddr(COL_PLAYER), 7);
  bFillRect(Single(px * CELL), Single(HUD_H + py * CELL), CELL, CELL);

  // Enemies.
  for i := 0 to enemy_count - 1 do
    if enemies[i].active then
    begin
      bSetFill(StrAddr(COL_ENEMY), 7);
      bBeginPath;
      bArc(Single(enemies[i].pixel_x + enemies[i].size / 2.0),
           Single(HUD_H + enemies[i].pixel_y + enemies[i].size / 2.0),
           Single(enemies[i].size / 2.0), 0.0, 6.283185307179586);
      bFill;
    end;

  DrawHUD;

  bBatchFlush(ctx, Integer(@cmd), cmd_len);
end;

// ---- Bridge: exports ----
procedure HandleKey(down: Integer);
var
  n: Integer;
begin
  if down = 0 then Exit;
  n := bGetPropStr(last_event, 'key', Integer(@text_buf), 16);
  if n <= 0 then Exit;

  if status = ST_PLAYING then
  begin
    // Arrow keys (multi-char 'ArrowX').
    if n >= 6 then
      if (text_buf[0] = 65) and (text_buf[1] = 114) and (text_buf[2] = 114) and
         (text_buf[3] = 111) and (text_buf[4] = 119) then
      begin
        if text_buf[5] = 85 then begin pending_dx := 0; pending_dy := -1; has_pending := true; end;
        if text_buf[5] = 68 then begin pending_dx := 0; pending_dy := 1; has_pending := true; end;
        if text_buf[5] = 76 then begin pending_dx := -1; pending_dy := 0; has_pending := true; end;
        if text_buf[5] = 82 then begin pending_dx := 1; pending_dy := 0; has_pending := true; end;
      end;
  end
  else if (status = ST_START) or (status = ST_OVER) then
  begin
    // Space (single char 32) or Enter starts / restarts.
    if text_buf[0] = 32 then start_requested := true
    else if (text_buf[0] = 69) and (text_buf[1] = 110) and (text_buf[2] = 116) and
            (text_buf[3] = 101) and (text_buf[4] = 114) then start_requested := true;
  end;
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

procedure XonixMain;
var
  app, canvas, doc: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  canvas := bCanvasCreate(app, W, CANVAS_H);
  ctx := bGetContext(canvas);

  rng_state := Cardinal((bNow - Trunc(bNow)) * 1000000.0) xor $9E3779B9;
  if rng_state = 0 then rng_state := 1;

  status := ST_START;
  GridReset;
  PlayerReset;
  enemy_count := 0;
  last_event := 0;
  has_pending := false;
  start_requested := false;

  doc := bGetGlobal('document');
  bAddListener(doc, 'keydown', CB_KEYDOWN);
  bAddListener(doc, 'keyup', CB_KEYUP);

  last_ms := bNow;
  bStartLoop(CB_TICK);
end;

procedure Tick(dt_ms: Double);
var
  i, res: Integer;
begin
  if has_pending then
  begin
    SetDir(pending_dx, pending_dy);
    has_pending := false;
  end;
  if start_requested then
  begin
    StartGame;
    start_requested := false;
  end;

  if status = ST_LEVELUP then
  begin
    level_up_timer := level_up_timer - dt_ms;
    if level_up_timer <= 0 then
    begin
      level := level + 1;
      if level mod 5 = 0 then lives := lives + 1;
      StartLevel;
    end;
  end
  else if status = ST_PLAYING then
  begin
    res := PlayerUpdate(dt_ms);
    if res = 1 then Exit; // died: no enemy updates this frame
    for i := 0 to enemy_count - 1 do EnemyUpdate(i, dt_ms);
  end;

  Draw;
end;

procedure InvokeCallback(id: Integer);
var
  now_ms, dt_raw, dt_ms: Double;
begin
  if id = CB_TICK then
  begin
    now_ms := bNow;
    dt_raw := (now_ms - last_ms) / 1000.0;
    last_ms := now_ms;
    if dt_raw > 0.05 then dt_raw := 0.05;
    dt_ms := dt_raw * 1000.0;
    Tick(dt_ms);
  end
  else if id = CB_KEYDOWN then
    HandleKey(1)
  else if id = CB_KEYUP then
    HandleKey(0);
end;

exports
  XonixMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
