// floaty_car.pas — Floaty Car ported to Pascal via wasmpascal.
//
// A top-down endless driver: steer the car left/right to stay on a winding
// road that scrolls faster the longer you survive. You can boost for bonus
// points, but you can never slow down. Off the road means a crash.
//
// Ported from https://github.com/ewaldhorn/floaty_car (a Floaty-engine JS
// gamelet: 16x16 grid of 8px blocks on a 128x128 field). This port scales the
// field up to 32x24 board of 25px (800x600), adds Web Audio SFX with a mute
// toggle, and pointer/tap steering for touch and mouse.
//
// Batchiness ABI (batchiness_main / batchiness_invoke_callback /
// batchiness_set_last_event), same host wiring as pong.pas / runner.pas.
// Controls: A/D or arrows steer, W/Up boosts (+45 pts), P pauses,
// R/Space restarts after a crash, M toggles sound. Tapping/clicking the left
// or right half of the field steers; tapping the sound button toggles mute.
//
// All state lives in globals; the board is a 32x24 grid of cell shades
// scrolled down one row per step (no per-frame allocation, one batch flush
// per frame).

library floaty_car;

const
  // ---- Field & board geometry (COLS*BLOCK = W, ROWS*BLOCK = H) ----
  W = 800;
  H = 600;
  COLS = 32;
  ROWS = 24;
  BLOCK = 25;
  PLAYER_ROW = 23; // the car's row, the bottom row of the board

  // ---- Board cell shades ----
  // board[y, x] holds one of these. The generator rolls a random grass shade
  // (CELL_PLAIN..CELL_SHADE) and carves the road out as CELL_ROAD; the shade
  // number tells DrawCells which extra detail to paint, if any.
  CELL_ROAD   = 0; // asphalt
  CELL_PLAIN  = 1; // plain grass, no extra detail
  CELL_DOUBLE = 2; // two dark speckles
  CELL_SPARK  = 3; // one light speckle
  CELL_SPECK  = 4; // one dark speckle
  CELL_SHADE  = 5; // a whole darker grass patch

  // ---- Road generation ----
  ROAD_W0 = 12;    // starting road width, in cells
  ROAD_W_MIN = 6;
  ROAD_W_MAX = 12;
  ROAD_P0 = 10;    // starting left edge of the road

  // ---- Scoring ----
  BOOST_SCORE = 45;    // points per boost tap (boosting also speeds the ramp)
  MILESTONE_EVERY = 250; // every N points a chime plays

  // ---- Host callbacks (batchiness_invoke_callback id) ----
  CB_TICK = 0;
  CB_KEYDOWN = 1;
  CB_KEYUP = 2;
  CB_PTRDOWN = 3;

  // ---- Actions (indices into keys[] / just_pressed[]) ----
  KEY_LEFT = 0;
  KEY_RIGHT = 1;
  KEY_BOOST = 2;
  KEY_PAUSE = 3;
  KEY_RESTART = 4;
  KEY_MUTE = 5;

  // ---- Palette (each colour is named once and reused) ----
  COL_GRASS      = '#37a05f'; // base grass
  COL_GRASS_DARK = '#2f8f52'; // CELL_SHADE patches
  COL_ROAD       = '#20242e'; // asphalt
  COL_SPECK_DARK = '#1f6b3d'; // CELL_DOUBLE / CELL_SPECK dots
  COL_SPECK_LIGHT = '#7ce8a4'; // CELL_SPARK dot
  COL_PANEL      = '#10101d'; // hint bar, overlay boxes, sound button
  COL_TEXT       = '#ffffff'; // main HUD text
  COL_TEXT_SOFT  = '#cdd7ea'; // secondary HUD text (best score)
  COL_TEXT_DIM   = '#7f8ba6'; // hints and panel borders
  COL_SOUND_ON   = '#7fe0a0'; // "sound on" label
  COL_SOUND_OFF  = '#ff6b6b'; // "muted" label
  COL_CAR        = '#ffe66d'; // car body
  COL_CAR_GLASS  = '#20242e'; // windscreen (same hex as the road)
  COL_CRASH      = '#ff5252'; // wreck, crash headline, crash panel border
  COL_BURST      = '#ff9f1c'; // impact burst behind the wreck

  // ---- Fonts ----
  FONT_SMALL = '14px monospace'; // hint bar, best, sound button
  FONT_MED = '20px monospace';   // score readouts, crash score
  FONT_TITLE = '40px monospace'; // crash / pause headline
  FONT_SUB = '16px monospace';   // overlay instructions

  // ---- UI strings ----
  HINT_BAR = 'A/D or arrows steer - W boost - P pause - M sound - tap sides to steer';
  TXT_SCORE = 'Score:';
  TXT_BEST = 'Best:';
  TXT_SCORE_SMALL = 'score';
  TXT_CRASHED = 'CRASHED!';
  TXT_PAUSED = 'PAUSED';
  TXT_MUTED = 'muted (M)';
  TXT_SOUND_ON = 'sound on (M)';
  TXT_RESTART_HINT = 'R / SPACE / tap to restart';
  TXT_RESUME_HINT = 'P / tap to resume';

  // ---- HUD layout ----
  HUD_H = 28;        // top hint bar height
  HINT_Y = 7;        // hint text top inside the bar
  READOUT_X = 10;    // left edge of the Score:/Best: labels
  SCORE_Y = 38;      // Score: line
  SCORE_VALUE_X = 90; // score number start
  BEST_Y = 64;       // Best: line
  BEST_VALUE_X = 62; // best number start

  // sound button (this rect is also the mute hit-test in ConsumeTap)
  MUTE_X0 = 620;
  MUTE_X1 = 790;
  MUTE_Y0 = 34;
  MUTE_Y1 = 70;
  MUTE_TEXT_Y = 45;

  // crash overlay: a box centred on the field
  CRASH_HALF_W = 190;
  CRASH_Y = 200;
  CRASH_H = 130;
  CRASH_TITLE_Y = 212;
  CRASH_SCORE_Y = 262;
  CRASH_HINT_Y = 296;

  // pause overlay
  PAUSE_HALF_W = 150;
  PAUSE_Y = 220;
  PAUSE_H = 90;
  PAUSE_TITLE_Y = 232;
  PAUSE_HINT_Y = 280;

  // ---- Batch opcodes (wire format from batch.odin / batchiness.js) ----
  OP_SET_FILL = $01;
  OP_SET_STROKE = $02;
  OP_SET_FONT = $04;
  OP_SET_TEXT_ALIGN = $05;
  OP_SET_TEXT_BASELINE = $06;
  OP_FILL_RECT = $10;
  OP_STROKE_RECT = $11;
  OP_FILL_TEXT = $30;

  CMD_CAPACITY = 32768; // batch command buffer, in bytes

  // ---- Sound slots (app_env.play_sound, shared with pong/pascaloids) ----
  SND_MOVE = 0;    // short blip
  SND_CRASH = 4;   // death boom
  SND_RESTART = 5; // wave-clear chime (restarts + score milestones)
  SND_UNMUTE = 6;  // hyperspace blip (mute-toggle confirm)
  SND_BOOST = 9;   // launch sweep

var
  // board[y, x]: one CELL_* shade per cell
  board: array[0..ROWS - 1, 0..COLS - 1] of Byte;

  // run state
  roadWidth, roadPos: Integer;
  playerPos: Integer;
  score, best: Integer;
  hasCrashed: Boolean;
  paused: Boolean;
  muted: Boolean;
  acc: Double; // seconds accrued toward the next scroll step

  // input state: keys[] holds held keys, just_pressed[] is edge-triggered and
  // cleared every frame by ClearPressed
  keys: array[0..KEY_MUTE] of Boolean;
  just_pressed: array[0..KEY_MUTE] of Boolean;

  tapPending: Boolean; // a tap arrived this frame (coords in canvas pixels)
  tap_x, tap_y: Single;

  // batchiness host scaffolding (same names as the other batch games)
  last_event: Integer = 0;
  rng_state: Cardinal;
  last_ms: Double;
  ctx: Integer;      // batch canvas 2D context handle
  canvas_h: Integer = 0;
  rect_left: Double = 0.0; // canvas rect on the page, used to map taps
  rect_top: Double = 0.0;
  rect_scale_x: Double = 1.0;
  rect_scale_y: Double = 1.0;

  // scratch buffers (no heap in examples)
  cmd: array[0..CMD_CAPACITY - 1] of Byte;
  cmd_len: Integer;
  text_buf: array[0..63] of Byte;
  tmp16: array[0..15] of Byte;

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
function  bCallMethodRet(h: Integer; nm: string): Integer; external 'batch_env' name 'batch_call_method_ret';

procedure aPlaySound(id: Integer); external 'app_env' name 'play_sound';

// ---- RNG (xorshift, same as pong/runner) ----
function NextRand: Cardinal;
begin
  rng_state := rng_state xor (rng_state shl 13);
  rng_state := rng_state xor (rng_state shr 17);
  rng_state := rng_state xor (rng_state shl 5);
  NextRand := rng_state;
end;

function RandF32: Single;
begin
  RandF32 := Single(NextRand and $FFFFFF) / 16777216.0;
end;

function RandRangeI(lo, hi: Integer): Integer;
begin
  RandRangeI := lo + Integer(Trunc(RandF32 * Single(hi - lo + 1)));
  if RandRangeI > hi then RandRangeI := hi;
end;

// ---- Batch wire writers (same subset pong/growable use) ----
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

procedure bSetStroke(p: Integer; n: Integer);
begin
  PutU8(OP_SET_STROKE); PutLit(p, n);
end;

procedure bSetFont(p: Integer; n: Integer);
begin
  PutU8(OP_SET_FONT); PutLit(p, n);
end;

procedure bSetTextAlign(p: Integer; n: Integer);
begin
  PutU8(OP_SET_TEXT_ALIGN); PutLit(p, n);
end;

procedure bSetTextBaseline(p: Integer; n: Integer);
begin
  PutU8(OP_SET_TEXT_BASELINE); PutLit(p, n);
end;

procedure bFillRect(x, y, w, h: Single);
begin
  PutU8(OP_FILL_RECT); PutF32(x); PutF32(y); PutF32(w); PutF32(h);
end;

procedure bStrokeRect(x, y, w, h: Single);
begin
  PutU8(OP_STROKE_RECT); PutF32(x); PutF32(y); PutF32(w); PutF32(h);
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

// ---- Scratch-string helpers (no heap, fixed scratch) ----
// WriteInt formats n (right-justified) into text_buf at off and returns the
// new end offset; digits are staged in tmp16 first so they can be reversed.
function WriteInt(off, n: Integer): Integer;
var
  d, x, c: Integer;
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
  for c := 0 to d - 1 do
  begin
    if off + c < 64 then text_buf[off + c] := tmp16[d - 1 - c];
  end;
  WriteInt := off + d;
end;

// ---- Canvas mapping (property reads share the text_buf scratch, so each
// value is parsed out immediately after it is fetched) ----
function PB(buf: Integer; i: Integer): Byte;
begin
  PB := PByte(buf)[i];
end;

function ParseF64(buf: Integer; blen: Integer): Double;
var
  i, s: Integer;
  ip, frac, scale: Double;
begin
  ip := 0.0; frac := 0.0; scale := 0.1; s := 1; i := 0;
  if blen > 0 then
  begin
    if PB(buf, 0) = 45 then begin s := -1; i := 1; end
    else if PB(buf, 0) = 43 then i := 1;
    while (i < blen) and (PB(buf, i) <> 46) do
    begin
      ip := ip * 10.0 + Double(PB(buf, i) - 48);
      i := i + 1;
    end;
    if (i < blen) and (PB(buf, i) = 46) then
    begin
      i := i + 1;
      while i < blen do
      begin
        frac := frac + Double(PB(buf, i) - 48) * scale;
        scale := scale * 0.1;
        i := i + 1;
      end;
    end;
  end;
  ParseF64 := (ip + frac) * Double(s);
end;

// Read the canvas's bounding rect so clientX/clientY map to canvas pixels
// (the canvas is scaled in the stage). Same as growable.pas.
procedure RefreshCanvasRect;
var
  rect: Integer;
  n: Integer;
begin
  rect := bCallMethodRet(canvas_h, 'getBoundingClientRect');
  n := bGetPropStr(rect, 'left', Integer(@text_buf), 40);
  rect_left := ParseF64(Integer(@text_buf), n);
  n := bGetPropStr(rect, 'top', Integer(@text_buf), 40);
  rect_top := ParseF64(Integer(@text_buf), n);
  n := bGetPropStr(rect, 'width', Integer(@text_buf), 40);
  rect_scale_x := Double(W) / ParseF64(Integer(@text_buf), n);
  n := bGetPropStr(rect, 'height', Integer(@text_buf), 40);
  rect_scale_y := Double(H) / ParseF64(Integer(@text_buf), n);
end;

// ---- Game logic ----

// Random grass shade for a fresh board cell: the dice rolls any grass shade
// (CELL_PLAIN..CELL_SHADE, i.e. never CELL_ROAD).
function GrassShade: Byte;
begin
  GrassShade := Byte(RandRangeI(CELL_PLAIN, CELL_SHADE));
end;

// Play a host sound, unless the player muted the game.
procedure PlaySound(id: Integer);
begin
  if not muted then aPlaySound(id);
end;

procedure ToggleMute;
begin
  muted := not muted;
  // confirm the way back on only
  if not muted then PlaySound(SND_UNMUTE);
end;

// Reset the run: score zeroed, a straight road down the middle, the board
// seeded with grass. Called at boot and on every restart (a restart chime
// plays unless this is the boot, when score is still 0).
procedure NewGame;
var
  x, y: Integer;
begin
  if score > 0 then PlaySound(SND_RESTART);
  roadWidth := ROAD_W0;
  roadPos := ROAD_P0;
  playerPos := COLS div 2;
  score := 0;
  hasCrashed := false;
  paused := false;
  acc := 0.0;
  // seed random grass, then carve the road through the starting span
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do
      board[y, x] := GrassShade;
  for y := 0 to ROWS - 1 do
    for x := roadPos to roadPos + roadWidth - 1 do
      board[y, x] := CELL_ROAD;
end;

procedure Crash;
begin
  if hasCrashed then Exit;
  hasCrashed := true;
  if score > best then best := score;
  PlaySound(SND_CRASH);
end;

// The car sits on the bottom row: driving over anything but road is a crash.
procedure CheckCrash;
begin
  if hasCrashed then Exit;
  if board[PLAYER_ROW, playerPos] <> CELL_ROAD then Crash;
end;

// One scroll step: check, score, roll a fresh top row, shift everything down
// one row. Mirrors the original's update(): the crash is checked both before
// and after the shift.
procedure ScrollStep;
var
  x, y: Integer;
begin
  CheckCrash;
  if hasCrashed then Exit;

  score := score + 1;
  if (score mod MILESTONE_EVERY) = 0 then PlaySound(SND_RESTART);

  // fresh top row: random grass...
  for x := 0 to COLS - 1 do
    board[0, x] := GrassShade;

  // ...then the road wanders (same dice as the original: 50/50 width/pos)
  if RandF32 < 0.5 then
  begin
    if roadWidth < ROAD_W_MAX then roadWidth := roadWidth + 1
    else if roadWidth > ROAD_W_MIN then roadWidth := roadWidth - 1;
  end;
  if RandF32 < 0.5 then
  begin
    if (RandF32 < 0.5) and (roadPos > 0) then roadPos := roadPos - 1
    else if roadPos < COLS - roadWidth then roadPos := roadPos + 1;
  end;

  // carve the road out of the fresh row
  for x := roadPos to roadPos + roadWidth - 1 do
    board[0, x] := CELL_ROAD;

  // shift every row down one; the bottom row scrolls off the field
  for y := ROWS - 2 downto 0 do
    for x := 0 to COLS - 1 do
      board[y + 1, x] := board[y, x];

  CheckCrash;
end;

// Steer one column, clamped to the field edges. Stepping onto grass crashes;
// a successful step onto road plays a blip.
procedure MovePlayer(dir: Integer);
var
  np: Integer;
begin
  if hasCrashed or paused then Exit;
  np := playerPos + dir;
  if np < 0 then np := 0;
  if np > COLS - 1 then np := COLS - 1;
  if np = playerPos then Exit;
  playerPos := np;
  if board[PLAYER_ROW, playerPos] <> CELL_ROAD then Crash
  else PlaySound(SND_MOVE);
end;

// A boost buys BOOST_SCORE points (and, via the score, a faster scroll).
procedure Boost;
begin
  if hasCrashed or paused then Exit;
  score := score + BOOST_SCORE;
  PlaySound(SND_BOOST);
end;

// Seconds per scroll step. The original counts update() calls against
// max(2, ceil(20 - score/45)) at ~60 ticks/s; this is the same ramp in
// seconds.
function StepInterval: Double;
var
  target: Integer;
begin
  target := 20 - score div BOOST_SCORE;
  if target < 2 then target := 2;
  StepInterval := Double(target) / 60.0;
end;

// Drop the per-frame edge flags (called once at the end of every UpdateGame).
procedure ClearPressed;
var
  i: Integer;
begin
  for i := 0 to KEY_MUTE do
    just_pressed[i] := false;
  tapPending := false;
end;

// Decide what a pending tap means. Runs each tick before UpdateGame: a tap on
// the sound button mutes; a tap anywhere else while crashed/paused stays
// pending so UpdateGame restarts/resumes; a tap on the field steers.
procedure ConsumeTap;
begin
  if not tapPending then Exit;
  if (tap_x >= MUTE_X0) and (tap_x <= MUTE_X1) and
     (tap_y >= MUTE_Y0) and (tap_y <= MUTE_Y1) then
  begin
    just_pressed[KEY_MUTE] := true;
    tapPending := false;
  end
  else if hasCrashed or paused then
  begin
    // leave the tap pending: UpdateGame consumes it as restart / resume
  end
  else if tap_x < W / 2 then
  begin
    just_pressed[KEY_LEFT] := true;
    tapPending := false;
  end else begin
    just_pressed[KEY_RIGHT] := true;
    tapPending := false;
  end;
end;

// Crash screen: R / Space / a tap starts a new run.
procedure UpdateCrashed;
begin
  if just_pressed[KEY_RESTART] or tapPending then NewGame;
end;

// Pause screen: any control wakes the run back up (the original unpauses on
// steer keys too).
procedure UpdatePaused;
begin
  if just_pressed[KEY_PAUSE] or just_pressed[KEY_LEFT] or
     just_pressed[KEY_RIGHT] or just_pressed[KEY_RESTART] or tapPending then
    paused := false;
end;

// Playing: steer, boost, pause, and scroll on the accrued time.
procedure UpdateRunning(dt: Single);
var
  iv: Double;
begin
  if just_pressed[KEY_PAUSE] then
  begin
    paused := true;
    Exit;
  end;

  if just_pressed[KEY_LEFT] then MovePlayer(-1);
  if just_pressed[KEY_RIGHT] then MovePlayer(1);
  if just_pressed[KEY_BOOST] then Boost;

  acc := acc + Double(dt);
  iv := StepInterval;
  while acc >= iv do
  begin
    acc := acc - iv;
    ScrollStep;
    if hasCrashed then Break;
  end;
end;

procedure UpdateGame(dt: Single);
begin
  // mute works on every screen
  if just_pressed[KEY_MUTE] then ToggleMute;

  if hasCrashed then UpdateCrashed
  else if paused then UpdatePaused
  else UpdateRunning(dt);

  ClearPressed;
end;

// ---- Drawing ----
// A whole board cell at (x, y): one BLOCK-sized rect at its grid position.
procedure CellRect(x, y: Integer);
begin
  bFillRect(Single(x * BLOCK), Single(y * BLOCK), BLOCK, BLOCK);
end;

// Paint every cell whose shade is `want` in `color`, one fill colour per
// pass. Per-cell bSetFill used to overflow the 32 KB command buffer and
// silently drop the HUD/overlays, so each pass sets its colour exactly once
// and then draws every matching cell.
procedure PaintCells(want: Integer; color: string);
var
  x, y: Integer;
begin
  bSetFill(StrAddr(color), StrLen(color));
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do
      if board[y, x] = want then CellRect(x, y);
end;

// Dark speckle dots (CELL_DOUBLE cells get two, CELL_SPECK cells one).
procedure DrawDarkSpeckles;
var
  x, y: Integer;
  v: Integer;
  px, py: Single;
begin
  bSetFill(StrAddr(COL_SPECK_DARK), StrLen(COL_SPECK_DARK));
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do
    begin
      v := board[y, x];
      if (v = CELL_DOUBLE) or (v = CELL_SPECK) then
      begin
        px := Single(x * BLOCK);
        py := Single(y * BLOCK);
        if v = CELL_DOUBLE then
        begin
          bFillRect(px + 5.0, py + 5.0, 3.0, 3.0);
          bFillRect(px + 15.0, py + 14.0, 3.0, 3.0);
        end else
          bFillRect(px + 11.0, py + 16.0, 3.0, 3.0);
      end;
    end;
end;

// One light speckle dot on CELL_SPARK cells, like the original's pset detail.
procedure DrawLightSpeckles;
var
  x, y: Integer;
  px, py: Single;
begin
  bSetFill(StrAddr(COL_SPECK_LIGHT), StrLen(COL_SPECK_LIGHT));
  for y := 0 to ROWS - 1 do
    for x := 0 to COLS - 1 do
      if board[y, x] = CELL_SPARK then
      begin
        px := Single(x * BLOCK);
        py := Single(y * BLOCK);
        bFillRect(px + 11.0, py + 6.0, 3.0, 3.0);
      end;
end;

// The whole board, painted shade by shade over a single grass base fill.
procedure DrawCells;
begin
  bSetFill(StrAddr(COL_GRASS), StrLen(COL_GRASS));
  bFillRect(0, 0, W, H);

  PaintCells(CELL_SHADE, COL_GRASS_DARK);
  PaintCells(CELL_ROAD, COL_ROAD);
  DrawDarkSpeckles;
  DrawLightSpeckles;
end;

// ---- Text & panel helpers ----
// Each text helper sets the full text state (align, baseline, font, colour)
// so a call never depends on which text was drawn before it.
procedure CenterText(x, y: Integer; s, font, color: string);
begin
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('top'), 3);
  bSetFont(StrAddr(font), StrLen(font));
  bSetFill(StrAddr(color), StrLen(color));
  bFillText(StrAddr(s), StrLen(s), x, y);
end;

// Left-aligned variant of CenterText.
procedure LeftText(x, y: Integer; s, font, color: string);
begin
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
  bSetFont(StrAddr(font), StrLen(font));
  bSetFill(StrAddr(color), StrLen(color));
  bFillText(StrAddr(s), StrLen(s), x, y);
end;

// A centred number, formatted into text_buf by WriteInt.
procedure CenterNumber(x, y, num: Integer; font, color: string);
var
  n: Integer;
begin
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('top'), 3);
  bSetFont(StrAddr(font), StrLen(font));
  bSetFill(StrAddr(color), StrLen(color));
  n := WriteInt(0, num);
  bFillText(Integer(@text_buf), n, x, y);
end;

// Left-aligned variant of CenterNumber.
procedure LeftNumber(x, y, num: Integer; font, color: string);
var
  n: Integer;
begin
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
  bSetFont(StrAddr(font), StrLen(font));
  bSetFill(StrAddr(color), StrLen(color));
  n := WriteInt(0, num);
  bFillText(Integer(@text_buf), n, x, y);
end;

// A dark panel with a coloured border (overlay boxes, the sound button).
procedure Panel(x, y, w, h: Integer; border: string);
begin
  bSetFill(StrAddr(COL_PANEL), StrLen(COL_PANEL));
  bFillRect(Single(x), Single(y), Single(w), Single(h));
  bSetStroke(StrAddr(border), StrLen(border));
  bStrokeRect(Single(x), Single(y), Single(w), Single(h));
end;

procedure DrawCar;
var
  px, py: Single;
begin
  px := Single(playerPos * BLOCK);
  py := Single(PLAYER_ROW * BLOCK);
  if hasCrashed then
  begin
    // impact burst around the wreck, then the wreck itself
    bSetFill(StrAddr(COL_BURST), StrLen(COL_BURST));
    bFillRect(px - 4.0, py - 4.0, BLOCK + 8.0, BLOCK + 8.0);
    bSetFill(StrAddr(COL_CRASH), StrLen(COL_CRASH));
    bFillRect(px + 2.0, py + 2.0, BLOCK - 4.0, BLOCK - 4.0);
  end else begin
    // body, with the windscreen inset near the top
    bSetFill(StrAddr(COL_CAR), StrLen(COL_CAR));
    bFillRect(px + 2.0, py + 1.0, BLOCK - 4.0, BLOCK - 2.0);
    bSetFill(StrAddr(COL_CAR_GLASS), StrLen(COL_CAR_GLASS));
    bFillRect(px + 6.0, py + 5.0, BLOCK - 12.0, 7.0);
  end;
end;

procedure DrawHUD;
var
  mute_cx: Integer;
begin
  // controls hint on a dark bar across the top
  bSetFill(StrAddr(COL_PANEL), StrLen(COL_PANEL));
  bFillRect(0, 0, W, HUD_H);
  CenterText(W div 2, HINT_Y, HINT_BAR, FONT_SMALL, COL_TEXT);

  // score / best readouts
  LeftText(READOUT_X, SCORE_Y, TXT_SCORE, FONT_MED, COL_TEXT);
  LeftNumber(SCORE_VALUE_X, SCORE_Y, score, FONT_MED, COL_TEXT);
  LeftText(READOUT_X, BEST_Y, TXT_BEST, FONT_SMALL, COL_TEXT_SOFT);
  LeftNumber(BEST_VALUE_X, BEST_Y, best, FONT_SMALL, COL_TEXT_SOFT);

  // sound button (the mute hit-test in ConsumeTap matches this rect)
  Panel(MUTE_X0, MUTE_Y0, MUTE_X1 - MUTE_X0, MUTE_Y1 - MUTE_Y0, COL_TEXT_DIM);
  mute_cx := (MUTE_X0 + MUTE_X1) div 2;
  if muted then
    CenterText(mute_cx, MUTE_TEXT_Y, TXT_MUTED, FONT_SMALL, COL_SOUND_OFF)
  else
    CenterText(mute_cx, MUTE_TEXT_Y, TXT_SOUND_ON, FONT_SMALL, COL_SOUND_ON);
end;

procedure DrawOverlay;
begin
  if hasCrashed then
  begin
    Panel(W div 2 - CRASH_HALF_W, CRASH_Y, CRASH_HALF_W * 2, CRASH_H, COL_CRASH);
    CenterText(W div 2, CRASH_TITLE_Y, TXT_CRASHED, FONT_TITLE, COL_CRASH);
    CenterText(W div 2 - 60, CRASH_SCORE_Y, TXT_SCORE_SMALL, FONT_MED, COL_TEXT);
    CenterNumber(W div 2 + 10, CRASH_SCORE_Y, score, FONT_MED, COL_TEXT);
    CenterText(W div 2, CRASH_HINT_Y, TXT_RESTART_HINT, FONT_SUB, COL_TEXT_DIM);
  end;
  if paused then
  begin
    Panel(W div 2 - PAUSE_HALF_W, PAUSE_Y, PAUSE_HALF_W * 2, PAUSE_H, COL_TEXT_DIM);
    CenterText(W div 2, PAUSE_TITLE_Y, TXT_PAUSED, FONT_TITLE, COL_TEXT);
    CenterText(W div 2, PAUSE_HINT_Y, TXT_RESUME_HINT, FONT_SUB, COL_TEXT_DIM);
  end;
end;

procedure DrawGame;
begin
  BufReset;
  DrawCells;
  DrawCar;
  DrawHUD;
  DrawOverlay;
  bBatchFlush(ctx, Integer(@cmd), cmd_len);
end;

// ---- Bridge: exports ----
// Self-wired keyboard on `document` (the batchiness games' key pattern, see
// pong.pas) plus a single pointerdown listener on the stage element: one
// listener means one callback per tap, so discrete steering can't double-fire
// the way canvas+document double-wiring would.
procedure MarkKey(k: Integer; down: Integer);
begin
  keys[k] := (down <> 0);
  if down <> 0 then just_pressed[k] := true;
end;

// Dispatch a keydown/keyup event. evt.key is a *named* string ('Enter',
// 'ArrowLeft', ' '), not a key code: dispatch on length first — the arrows
// start with 'A', which would otherwise collide with plain A in the
// single-char chain (right arrow steered left-then-right: net zero).
procedure HandleKey(down: Integer);
var
  n: Integer;
  c0: Byte;
begin
  n := bGetPropStr(last_event, 'key', Integer(@text_buf), 16);
  if n <= 0 then Exit;
  if n = 1 then
  begin
    // single-character keys arrive in the typed case, so accept both
    // (ASCII codes below map to the same action)
    c0 := text_buf[0];
    case c0 of
       97, 65: MarkKey(KEY_LEFT, down);    // 'a' / 'A'
      100, 68: MarkKey(KEY_RIGHT, down);   // 'd' / 'D'
      119, 87: MarkKey(KEY_BOOST, down);   // 'w' / 'W'
      112, 80: MarkKey(KEY_PAUSE, down);   // 'p' / 'P'
      114, 82: MarkKey(KEY_RESTART, down); // 'r' / 'R'
      109, 77: MarkKey(KEY_MUTE, down);    // 'm' / 'M'
         32: MarkKey(KEY_RESTART, down);   // space
    end;
  end
  // arrow keys: match the 'Arrow' prefix, then bind on the 6th character
  // ('ArrowLeft' / 'ArrowRight' / 'ArrowUp')
  else if n >= 6 then
  begin
    if (text_buf[0] = 65) and (text_buf[1] = 114) and (text_buf[2] = 114) and
       (text_buf[3] = 111) and (text_buf[4] = 119) then
      case text_buf[5] of
        76: MarkKey(KEY_LEFT, down);  // 'L'
        82: MarkKey(KEY_RIGHT, down); // 'R'
        85: MarkKey(KEY_BOOST, down); // 'U'
      end;
  end;
end;

procedure HandleTap;
var
  n: Integer;
begin
  // map the tap into canvas pixels (parse X before fetching Y: both reads
  // share the scratch buffer, so each value is parsed out immediately)
  RefreshCanvasRect;
  n := bGetPropStr(last_event, 'clientX', Integer(@text_buf), 40);
  tap_x := Single((ParseF64(Integer(@text_buf), n) - rect_left) * rect_scale_x);
  n := bGetPropStr(last_event, 'clientY', Integer(@text_buf), 40);
  tap_y := Single((ParseF64(Integer(@text_buf), n) - rect_top) * rect_scale_y);
  tapPending := true;
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

procedure FloatyCarMain;
var
  app, canvas, doc: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  canvas := bCanvasCreate(app, W, H);
  canvas_h := canvas;
  ctx := bGetContext(canvas);

  // seed the xorshift RNG from the clock fraction (whole ms is ~constant in
  // a freshly booted host, giving near-identical roads)
  rng_state := Cardinal((bNow - Trunc(bNow)) * 1000000.0) xor $9E3779B9;
  if rng_state = 0 then rng_state := 1;

  muted := false;
  best := 0;
  tapPending := false;
  NewGame;

  RefreshCanvasRect;

  doc := bGetGlobal('document');
  bAddListener(doc, 'keydown', CB_KEYDOWN);
  bAddListener(doc, 'keyup', CB_KEYUP);
  // pointerdown covers mouse click and touch tap alike
  bAddListener(app, 'pointerdown', CB_PTRDOWN);

  last_ms := bNow;
  bStartLoop(CB_TICK);
end;

procedure InvokeCallback(id: Integer);
var
  now_ms, dt: Double;
begin
  if id = CB_TICK then
  begin
    now_ms := bNow;
    dt := (now_ms - last_ms) / 1000.0;
    last_ms := now_ms;
    if dt > 0.0 then
    begin
      if dt > 0.05 then dt := 0.05;
      // the sound button is positional: resolve taps here, in canvas pixels,
      // so UpdateGame only ever sees whole steering/restart taps
      ConsumeTap;
      UpdateGame(Single(dt));
      DrawGame;
    end;
  end
  else if id = CB_KEYDOWN then
    HandleKey(1)
  else if id = CB_KEYUP then
    HandleKey(0)
  else if id = CB_PTRDOWN then
    HandleTap;
end;

exports
  FloatyCarMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
