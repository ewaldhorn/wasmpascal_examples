// breakout_graphics.pas — the canvas twin of breakout.pas.
//
// Same game as the console version (5 rows of colored blocks, a ball, and a
// paddle; clear all 90 blocks to win, 3 lives, R restarts), but rendered on
// a canvas instead of the 80x25 text screen. Batchiness ABI (batchiness_main
// / batchiness_invoke_callback / batchiness_set_last_event), same host
// wiring as pong.pas: the game self-wires its keyboard on `document` via
// batch_add_event_listener, reads evt.key with batch_get_property_str, and
// rebuilds the batch command buffer every frame, flushed with one
// batch_cmd_flush. Web Audio SFX via app_env.play_sound.
//
// Key handling gotcha (documented in AGENTS.md): evt.key is a NAMED string.
// 'ArrowLeft'[0] is 'A' (65), which collides with the 'a'/'A' key — so the
// named-key branch MUST run before the single-char branch (dispatch on
// string length first: named keys are >= 6 bytes, single-char keys are 1).
//
// Ball physics mirror the console game: bounces off walls and the paddle
// (the bounce angle follows where the ball hits the paddle), blocks are
// destroyed on contact, and the ball falls past the paddle to lose a life.
// The paddle is moved every frame by held keys; the ball travels at a fixed
// speed. No strings, no heap — a boolean block grid plus scalar state.

library breakout_graphics;

const
  TAU = 6.283185307179586;

  W = 800;
  H = 480;

  PaddleW = 120;
  PaddleH = 16;
  PaddleY = 432;      // bottom wall; the ball falls past this to lose a life
  PaddleMin = 6;
  PaddleMax = 674;    // W - 6 - PaddleW

  BR = 9;             // ball radius
  PSPEED = 440.0;     // paddle speed, px/s
  BSPEED = 150.0;     // ball speed, px/s (halved from 300: the ball felt too fast)
  MAXVX = 220.0;      // max horizontal ball speed after paddle hits (was 440)

  BlockRows = 5;
  BlocksPerRow = 18;
  BlockLeft = 6;      // 18 x 40px + 17 x 4px gaps = 788px, centered in 800
  BlockW = 40;
  BlockGap = 4;
  BlockTop = 60;
  BlockH = 18;
  RowGap = 8;         // rows at y = 60, 86, 112, 138, 164

  CB_TICK = 0;
  CB_KEYDOWN = 1;
  CB_KEYUP = 2;
  CB_POINTERDOWN = 3;

  KEY_LEFT = 0;
  KEY_RIGHT = 1;

  // batch opcodes (wire format from batch.odin / batchiness.js)
  OP_SET_FILL = $01;
  OP_SET_FONT = $04;
  OP_SET_TEXT_ALIGN = $05;
  OP_SET_TEXT_BASELINE = $06;
  OP_FILL_RECT = $10;
  OP_BEGIN_PATH = $20;
  OP_ARC = $24;
  OP_FILL = $28;
  OP_FILL_TEXT = $30;

  CMD_CAPACITY = 16384;

  // app_env.play_sound ids (app.js playSfx): 0=fire blip, 4=death boom,
  // 5=wave clear, 7=asteroid thud.
  SND_BLOCK = 0;
  SND_PADDLE = 0;
  SND_WALL = 7;
  SND_MISS = 4;
  SND_WIN = 5;

type
  TState = record
    paddleX: Single;
    bx, by, bvx, bvy: Single;
    score, lives, blocksLeft, state: Integer; // state: 0=play 1=win 2=lost
  end;

var
  g: TState;
  blocks: array[1..BlockRows] of array[1..BlocksPerRow] of Boolean;

  keys: array[0..1] of Boolean;

  // Touch target: the x (canvas px) the paddle glides toward after a tap.
  // -1 = no active tap (paddle is keyboard-driven). A tap sets it to the
  // tapped x; the paddle glides toward it at PSPEED until centered, then the
  // target clears so the paddle stops (no drift).
  touch_x: Single = -1.0;

  last_event: Integer = 0;

  rng_state: Cardinal;

  last_ms: Double;

  ctx: Integer;

  canvas_h: Integer = 0;
  rect_left: Double = 0.0;
  rect_top: Double = 0.0;
  rect_scale_x: Double = 1.0;
  rect_scale_y: Double = 1.0;

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

// ---- RNG (xorshift, same as pong.pas / pascaloids.pas) ----
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

// ---- Batch API (same subset pong.pas uses) ----
procedure bSetFill(p: Integer; n: Integer);
begin
  PutU8(OP_SET_FILL); PutLit(p, n);
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

procedure bBeginPath;
begin
  PutU8(OP_BEGIN_PATH);
end;

procedure bFill;
begin
  PutU8(OP_FILL);
end;

procedure bArc(x, y, r, a0, a1: Single);
begin
  PutU8(OP_ARC); PutF32(x); PutF32(y); PutF32(r); PutF32(a0); PutF32(a1); PutU8(0);
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

// ---- Number-to-text for the HUD (no heap, fixed scratch) ----
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
    if PB(buf, 0) = 45 then begin s := -1; i := 1; end   // '-'
    else if PB(buf, 0) = 43 then i := 1;                  // '+'
    while (i < blen) and (PB(buf, i) <> 46) do            // '.'
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

function AppendLit(o, p, n: Integer): Integer;
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    if o + i < 64 then text_buf[o + i] := PByte(p)[i];
  AppendLit := o + n;
end;

// ---- Geometry helpers ----
function FMin(a, b: Single): Single;
begin
  if a < b then FMin := a else FMin := b;
end;

function FMax(a, b: Single): Single;
begin
  if a > b then FMax := a else FMax := b;
end;

function ClampF(v, lo, hi: Single): Single;
begin
  if v < lo then ClampF := lo
  else if v > hi then ClampF := hi
  else ClampF := v;
end;

// Convert a pointer event's clientX to canvas pixels. The canvas is
// scaled/offset inside the stage, so the viewport coords must be mapped
// through the canvas's bounding rect (the growable/transforms pattern).
function PointerX: Single;
var
  n: Integer;
begin
  n := bGetPropStr(last_event, 'clientX', Integer(@text_buf), 40);
  PointerX := Single((ParseF64(Integer(@text_buf), n) - rect_left) * rect_scale_x);
end;

// Block rect for (row r, col c), 1-based.
function BlockX(c: Integer): Single;
begin
  BlockX := Single(BlockLeft + (c - 1) * (BlockW + BlockGap));
end;

function BlockY(r: Integer): Single;
begin
  BlockY := Single(BlockTop + (r - 1) * (BlockH + RowGap));
end;

// Classic breakout row colors (console RowColor's canvas equivalents).
procedure SetRowColor(r: Integer);
begin
  case r of
    1: bSetFill(StrAddr('#ff6b6b'), 7);
    2: bSetFill(StrAddr('#ff9f43'), 7);
    3: bSetFill(StrAddr('#ffe66d'), 7);
    4: bSetFill(StrAddr('#6bff88'), 7);
    5: bSetFill(StrAddr('#4ecdc4'), 7);
  end;
end;

// Read the canvas's bounding rect and compute the viewport→canvas scale so
// clientX/clientY (and pointer taps) map to canvas pixels (the canvas is
// scaled/offset inside the stage — the growable/transforms pattern).
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
// Serve from the middle of the paddle in a random horizontal direction.
procedure Serve;
var
  dir: Integer;
begin
  if RandF32 < 0.5 then dir := -1 else dir := 1;
  g.bvx := Single(dir) * BSPEED;
  g.bvy := -BSPEED;
  g.bx := g.paddleX + PaddleW / 2.0;
  g.by := Single(PaddleY - BR - 2);
end;

// Fresh game: reset state, fill the block grid, center the paddle, serve.
procedure NewGame;
var
  r, c: Integer;
begin
  g.state := 0;
  g.score := 0;
  g.lives := 3;
  g.blocksLeft := BlockRows * BlocksPerRow;
  for r := 1 to BlockRows do
    for c := 1 to BlocksPerRow do blocks[r][c] := true;
  g.paddleX := Single((W - PaddleW) div 2);
  touch_x := -1.0; // a stale tap must not resume gliding after a restart
  Serve;
end;

// The ball got past the paddle: lose a life and re-serve, or game over.
procedure MissBall;
begin
  g.lives := g.lives - 1;
  if g.lives <= 0 then g.state := 2
  else Serve;
  aPlaySound(SND_MISS);
end;

// Advance the ball, bounce off walls/blocks/paddle, handle a miss. Block
// collisions destroy every overlapped block and bounce on the axis of least
// penetration (a corner hit reverses both).
procedure UpdateBall(dt: Single);
var
  r, c: Integer;
  ox, oy: Single;
  hit: Boolean;
  offset: Single;
begin
  g.bx := g.bx + g.bvx * dt;
  g.by := g.by + g.bvy * dt;

  // Walls.
  if (g.bx - BR < 0.0) and (g.bvx < 0.0) then begin g.bvx := -g.bvx; aPlaySound(SND_WALL); end;
  if (g.bx + BR > W) and (g.bvx > 0.0) then begin g.bvx := -g.bvx; aPlaySound(SND_WALL); end;
  if (g.by - BR < 0.0) and (g.bvy < 0.0) then begin g.bvy := -g.bvy; aPlaySound(SND_WALL); end;

  // Blocks: destroy every overlapped block; the first hit decides the axis.
  hit := false;
  for r := 1 to BlockRows do
    for c := 1 to BlocksPerRow do
      if blocks[r][c] then
        if (g.bx + BR >= BlockX(c)) and (g.bx - BR <= BlockX(c) + BlockW) and
           (g.by + BR >= BlockY(r)) and (g.by - BR <= BlockY(r) + BlockH) then
        begin
          blocks[r][c] := false;
          g.blocksLeft := g.blocksLeft - 1;
          g.score := g.score + 1;
          aPlaySound(SND_BLOCK);
          if g.blocksLeft = 0 then g.state := 1;
          if not hit then
          begin
            hit := true;
            ox := FMin(g.bx + BR, BlockX(c) + BlockW) - FMax(g.bx - BR, BlockX(c));
            oy := FMin(g.by + BR, BlockY(r) + BlockH) - FMax(g.by - BR, BlockY(r));
            if ox < oy then g.bvx := -g.bvx
            else if oy < ox then g.bvy := -g.bvy
            else begin g.bvx := -g.bvx; g.bvy := -g.bvy; end;
          end;
        end;

  // Miss first (safety net: ball fully below the playfield).
  if g.by - BR > H then
  begin
    MissBall;
    Exit;
  end;

  // Paddle: the bottom wall. A hit bounces and steers by where it landed.
  // The bounce only fires for a FALLING ball (bvy > 0): the serve starts
  // just above the paddle, so without this gate a rising ball would
  // re-trigger the bounce every frame and crawl sideways along the paddle
  // top instead of flying up.
  if (g.bvy > 0.0) and (g.by + BR >= PaddleY) then
  begin
    if (g.bx >= g.paddleX - BR) and (g.bx <= g.paddleX + PaddleW + BR) then
    begin
      g.by := Single(PaddleY - BR); // stay above the paddle
      g.bvy := -BSPEED;
      offset := (g.bx - (g.paddleX + PaddleW / 2.0)) / (PaddleW / 2.0);
      g.bvx := offset * MAXVX;
      if g.bvx > MAXVX then g.bvx := MAXVX;
      if g.bvx < -MAXVX then g.bvx := -MAXVX;
      if (g.bvx < 40.0) and (g.bvx > -40.0) then
      begin
        if g.bvx < 0.0 then g.bvx := -40.0 else g.bvx := 40.0;
      end;
      aPlaySound(SND_PADDLE);
    end
    else
    begin
      MissBall; // fell beside the paddle
      Exit;
    end;
  end;
end;

// One frame: move the paddle by held keys, or glide it toward the touch
// target at the same PSPEED. A tap sets touch_x to the tapped x; the paddle
// centers on it, then touch_x clears so the paddle stops (no drift). The
// glide snaps to the target when a step would cross it, so the paddle always
// lands exactly centered on the tap (no overshoot, no oscillation). Holding a
// key cancels the tap target (keyboard takes over); a tap outside the
// paddle's reachable range is clamped at set time, so the glide always
// terminates.
procedure UpdateGame(dt: Single);
var
  center: Single;
begin
  if g.state <> 0 then Exit; // win/lose: paddle frozen until R
  if keys[KEY_LEFT] or keys[KEY_RIGHT] then touch_x := -1.0;
  if keys[KEY_LEFT] then g.paddleX := g.paddleX - PSPEED * dt;
  if keys[KEY_RIGHT] then g.paddleX := g.paddleX + PSPEED * dt;
  if touch_x >= 0.0 then
  begin
    center := g.paddleX + PaddleW / 2.0;
    if center < touch_x then
    begin
      g.paddleX := g.paddleX + PSPEED * dt;
      if g.paddleX + PaddleW / 2.0 >= touch_x then
      begin
        g.paddleX := touch_x - PaddleW / 2.0;
        touch_x := -1.0;
      end;
    end
    else if center > touch_x then
    begin
      g.paddleX := g.paddleX - PSPEED * dt;
      if g.paddleX + PaddleW / 2.0 <= touch_x then
      begin
        g.paddleX := touch_x - PaddleW / 2.0;
        touch_x := -1.0;
      end;
    end
    else touch_x := -1.0;
  end;
  g.paddleX := ClampF(g.paddleX, PaddleMin, PaddleMax);
  UpdateBall(dt);
end;

// ---- Drawing ----
procedure DrawGame;
var
  r, c, o: Integer;
begin
  BufReset;

  bSetFill(StrAddr('#10101d'), 7);
  bFillRect(0, 0, W, H);

  // Blocks.
  for r := 1 to BlockRows do
  begin
    SetRowColor(r);
    for c := 1 to BlocksPerRow do
      if blocks[r][c] then bFillRect(BlockX(c), BlockY(r), BlockW, BlockH);
  end;

  // Paddle.
  bSetFill(StrAddr('#eaf6ff'), 7);
  bFillRect(g.paddleX, Single(PaddleY), PaddleW, PaddleH);

  // Ball.
  if g.state = 0 then
  begin
    bSetFill(StrAddr('#ffe66d'), 7);
    bBeginPath;
    bArc(g.bx, g.by, BR, 0.0, TAU);
    bFill;
  end;

  // HUD (top-left): Score / Lives.
  bSetFill(StrAddr('#cdd7ea'), 7);
  bSetFont(StrAddr('20px monospace'), 14);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
  o := AppendLit(0, StrAddr('Score: '), 7);
  o := WriteInt(o, g.score);
  o := AppendLit(o, StrAddr('   Lives: '), 11);
  o := WriteInt(o, g.lives);
  bFillText(Integer(@text_buf), o, 16, 14);

  // End banners.
  if g.state <> 0 then
  begin
    bSetTextAlign(StrAddr('center'), 6);
    bSetFont(StrAddr('40px monospace'), 14);
    if g.state = 1 then
    begin
      bSetFill(StrAddr('#7fe0a0'), 7);
      bFillText(StrAddr('YOU WIN!'), 8, W div 2, H div 2 - 20);
    end
    else
    begin
      bSetFill(StrAddr('#ff6b6b'), 7);
      bFillText(StrAddr('GAME OVER'), 9, W div 2, H div 2 - 20);
    end;
    bSetFill(StrAddr('#7f8ba6'), 7);
    bSetFont(StrAddr('26px monospace'), 14);
    bFillText(StrAddr('PRESS R TO PLAY AGAIN'), StrLen('PRESS R TO PLAY AGAIN'), W div 2, H div 2 + 30);
  end;

  bBatchFlush(ctx, Integer(@cmd), cmd_len);
end;

// ---- Bridge: exports ----
// Self-wired keyboard on `document`. Dispatch on string LENGTH first: named
// keys ('ArrowLeft' etc.) are >= 6 bytes and start with 'A' (65), which
// collides with the 'a'/'A' key — the single-char branch must never run
// before the named-key branch.
procedure HandleKey(down: Integer);
var
  n: Integer;
  c0: Byte;
begin
  n := bGetPropStr(last_event, 'key', Integer(@text_buf), 16);
  if n > 0 then
  begin
    if n >= 6 then
    begin
      // 'ArrowLeft'  = A r r o w L e f t
      if (text_buf[0] = 65) and (text_buf[1] = 114) and (text_buf[2] = 114) and
         (text_buf[3] = 111) and (text_buf[4] = 119) and (text_buf[5] = 76) then
        keys[KEY_LEFT] := (down <> 0);
      // 'ArrowRight' = A r r o w R i g h t
      if (text_buf[0] = 65) and (text_buf[1] = 114) and (text_buf[2] = 114) and
         (text_buf[3] = 111) and (text_buf[4] = 119) and (text_buf[5] = 82) then
        keys[KEY_RIGHT] := (down <> 0);
    end
    else if n = 1 then
    begin
      c0 := text_buf[0];
      if (c0 = 97) or (c0 = 65) then keys[KEY_LEFT] := (down <> 0)      // a / A
      else if (c0 = 100) or (c0 = 68) then keys[KEY_RIGHT] := (down <> 0) // d / D
      else if (c0 = 114) or (c0 = 82) then                               // r / R
      begin
        if (down <> 0) and (g.state <> 0) then NewGame;
      end;
    end;
  end;
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

procedure BreakoutMain;
var
  app, canvas, doc: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  canvas := bCanvasCreate(app, W, H);
  canvas_h := canvas;
  ctx := bGetContext(canvas);

  // Canvas bounding rect → viewport scale, so pointer taps map to canvas px.
  RefreshCanvasRect;

  // Seed the xorshift RNG from the clock (µs fraction — the ms value is
  // ~constant in a freshly booted host, giving near-identical serves).
  rng_state := Cardinal((bNow - Trunc(bNow)) * 1000000.0) xor $9E3779B9;
  if rng_state = 0 then rng_state := 1;

  NewGame;

  // Self-wired keyboard on `document` (the batchiness games' key pattern).
  doc := bGetGlobal('document');
  bAddListener(doc, 'keydown', CB_KEYDOWN);
  bAddListener(doc, 'keyup', CB_KEYUP);

  // Touch: a tap anywhere on the canvas glides the paddle toward that x.
  bAddListener(canvas, 'pointerdown', CB_POINTERDOWN);

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
      UpdateGame(Single(dt));
      DrawGame;
    end;
  end
  else if id = CB_KEYDOWN then
    HandleKey(1)
  else if id = CB_KEYUP then
    HandleKey(0)
  else if id = CB_POINTERDOWN then
  begin
    // Tap: glide the paddle to center on the tapped x (canvas pixels).
    // Clamp to the reachable center range so the glide always terminates
    // (a tap near the wall would otherwise pin the paddle and never clear).
    touch_x := ClampF(PointerX, Single(PaddleMin + PaddleW div 2),
                              Single(PaddleMax + PaddleW div 2));
  end;
end;

exports
  BreakoutMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
