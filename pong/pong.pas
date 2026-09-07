// pong.pas — a complete game of Pong, ported to Pascal via wasmpascal.
// Batchiness ABI (batchiness_main / batchiness_invoke_callback /
// batchiness_set_last_event), same host wiring as pascaloids.pas. Left paddle
// is you (W/S or the up/down arrows); right paddle is a simple tracking AI.
// Space serves. First to 7 wins,
// then Space plays again. Every wall and paddle hit is a live oscillator blip.
//
// All game state lives in one TState record; the batch command buffer is rebuilt
// every frame and flushed with a single batch_cmd_flush call.

library pong;

const
  TAU = 6.283185307179586;

  W = 800;
  H = 480;
  PW = 14;
  PH = 92;
  BR = 9;
  PSPEED = 380.0;
  AISPEED = 300.0;
  BSPEED = 340.0;
  WIN = 7;

  CB_TICK = 0;
  CB_KEYDOWN = 1;
  CB_KEYUP = 2;

  KEY_UP = 2;    // ArrowUp / W
  KEY_DOWN = 1;  // ArrowDown / S
  KEY_SPACE = 3; // Space

  // batch opcodes (wire format from batch.odin / batchiness.js)
  OP_SET_FILL = $01;
  OP_SET_FONT = $04;
  OP_SET_TEXT_ALIGN = $05;
  OP_SET_TEXT_BASELINE = $06;
  OP_FILL_RECT = $10;
  OP_BEGIN_PATH = $20;
  OP_MOVE_TO = $21;
  OP_LINE_TO = $22;
  OP_CLOSE_PATH = $23;
  OP_ARC = $24;
  OP_FILL = $28;
  OP_FILL_TEXT = $30;

  CMD_CAPACITY = 32768;

  SND_PADDLE = 0; // fire blip
  SND_WALL = 7;   // thud
  SND_SCORE = 4;  // ship death boom

type
  TState = record
    bx, by, bvx, bvy: Single;
    ly, ry: Single;
    ls, rs: Integer;
    playing: Boolean;
    over: Boolean;
  end;

var
  g: TState;

  keys: array[0..3] of Boolean;
  just_pressed: array[0..3] of Boolean;

  last_event: Integer = 0;

  rng_state: Cardinal;

  last_ms: Double;

  ctx: Integer;

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

procedure aPlaySound(id: Integer); external 'app_env' name 'play_sound';

// ---- RNG (xorshift, same as pascaloids) ----
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

function RandRangeF32(lo, hi: Single): Single;
begin
  RandRangeF32 := lo + (hi - lo) * RandF32;
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

// ---- Batch API (subset pascaloids uses) ----
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

procedure bClosePath;
begin
  PutU8(OP_CLOSE_PATH);
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

// ---- String helpers for HUD (no heap, fixed scratch) ----
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

function HUDText(prefix: PByte; plen, num: Integer): Integer;
var
  i, o: Integer;
begin
  o := 0;
  for i := 0 to plen - 1 do
  begin
    if o < 64 then text_buf[o] := prefix[i];
    o := o + 1;
  end;
  o := WriteInt(o, num);
  HUDText := o;
end;

// ---- Game logic ----
function ClampF(v, lo, hi: Single): Single;
begin
  if v < lo then ClampF := lo
  else if v > hi then ClampF := hi
  else ClampF := v;
end;

procedure Serve(dir: Integer);
begin
  g.bx := W / 2.0;
  g.by := H / 2.0;
  g.bvx := Single(dir) * BSPEED;
  g.bvy := RandRangeF32(-160.0, 160.0);
  g.playing := true;
end;

// Reflect the ball off a paddle whose top is at py, adding "english": where
// the ball strikes the paddle sets the outgoing vertical angle. Speeds the
// ball up a touch per hit to keep rallies from dragging.
procedure BouncePaddle(py: Single; dir: Integer);
var
  centre, offset: Single;
begin
  g.bvx := Single(dir) * Abs(g.bvx) * 1.04;
  centre := py + PH / 2.0;
  offset := (g.by - centre) / (PH / 2.0);
  g.bvy := offset * 300.0;
  aPlaySound(SND_PADDLE);
end;

procedure UpdateAI(dt: Single);
var
  target: Single;
begin
  target := g.by - PH / 2.0;
  if g.ry + 4.0 < target then g.ry := g.ry + AISPEED * dt;
  if g.ry - 4.0 > target then g.ry := g.ry - AISPEED * dt;
  g.ry := ClampF(g.ry, 0.0, H - PH);
end;

procedure UpdatePlayer(dt: Single);
begin
  if keys[KEY_UP] then g.ly := g.ly - PSPEED * dt;
  if keys[KEY_DOWN] then g.ly := g.ly + PSPEED * dt;
  g.ly := ClampF(g.ly, 0.0, H - PH);
end;

procedure ScorePoint(who: Integer);
begin
  if who = 0 then g.ls := g.ls + 1;
  if who = 1 then g.rs := g.rs + 1;
  aPlaySound(SND_SCORE);
  g.playing := false;
  if (g.ls >= WIN) or (g.rs >= WIN) then g.over := true;
end;

procedure UpdateBall(dt: Single);
begin
  g.bx := g.bx + g.bvx * dt;
  g.by := g.by + g.bvy * dt;

  // Top and bottom walls.
  if (g.by - BR < 0.0) and (g.bvy < 0.0) then
  begin
    g.bvy := -g.bvy;
    aPlaySound(SND_WALL);
  end;
  if (g.by + BR > H) and (g.bvy > 0.0) then
  begin
    g.bvy := -g.bvy;
    aPlaySound(SND_WALL);
  end;

  // Left paddle: ball moving left, within the paddle's x band and vertical extent.
  if (g.bvx < 0.0) and (g.bx - BR < PW + 18.0) and (g.bx - BR > 8.0) then
  begin
    if (g.by > g.ly) and (g.by < g.ly + PH) then BouncePaddle(g.ly, 1);
  end;

  // Right paddle.
  if (g.bvx > 0.0) and (g.bx + BR > W - PW - 18.0) and (g.bx + BR < W - 8.0) then
  begin
    if (g.by > g.ry) and (g.by < g.ry + PH) then BouncePaddle(g.ry, -1);
  end;

  // Off an end: award the point.
  if g.bx < -BR then ScorePoint(1);
  if g.bx > W + BR then ScorePoint(0);
end;

procedure UpdateGame(dt: Single);
var
  dir: Integer;
begin
  UpdatePlayer(dt);

  if not g.playing then
  begin
    if just_pressed[KEY_SPACE] then
    begin
      just_pressed[KEY_SPACE] := false;
      if g.over then
      begin
        g.playing := false; g.over := false;
        g.ls := 0; g.rs := 0;
        g.ly := 194.0; g.ry := 194.0;
      end;
      dir := 1;
      if RandF32 < 0.5 then dir := -1;
      Serve(dir);
    end;
    Exit;
  end;

  UpdateAI(dt);
  UpdateBall(dt);
end;

// ---- Drawing ----
procedure DrawNet;
var
  y: Integer;
begin
  bSetFill(StrAddr('#1b2436'), 7);
  y := 6;
  while y < H do
  begin
    bFillRect(W / 2.0 - 2.0, Single(y), 4.0, 18.0);
    y := y + 30;
  end;
end;

procedure DrawGame;
var
  n: Integer;
begin
  BufReset;

  bSetFill(StrAddr('#10101d'), 7);
  bFillRect(0, 0, W, H);

  DrawNet;

  // Paddles.
  bSetFill(StrAddr('#4ecdc4'), 7);
  bFillRect(8.0, g.ly, PW, PH);
  bSetFill(StrAddr('#ff6b6b'), 7);
  bFillRect(W - PW - 8.0, g.ry, PW, PH);

  // Ball.
  bSetFill(StrAddr('#ffe66d'), 7);
  bBeginPath;
  bArc(g.bx, g.by, BR, 0.0, TAU);
  bFill;

  // Scores.
  bSetFill(StrAddr('#cdd7ea'), 7);
  bSetFont(StrAddr('48px monospace'), 14);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('top'), 3);
  n := WriteInt(0, g.ls);
  bFillText(Integer(@text_buf), n, W div 2 - 90, 60);
  n := WriteInt(0, g.rs);
  bFillText(Integer(@text_buf), n, W div 2 + 60, 60);

  // Prompts.
  if g.over then
  begin
    bSetFill(StrAddr('#7fe0a0'), 7);
    bSetFont(StrAddr('40px monospace'), 14);
    if g.rs > g.ls then
      bFillText(StrAddr('RIGHT WINS'), 10, W div 2, H div 2 - 20)
    else
      bFillText(StrAddr('LEFT WINS'), 9, W div 2, H div 2 - 20);
    bSetFill(StrAddr('#7f8ba6'), 7);
    bSetFont(StrAddr('26px monospace'), 14);
    bFillText(StrAddr('SPACE to play again'), StrLen('SPACE to play again'), W div 2, H div 2 + 30);
  end;
  if (not g.playing) and (not g.over) then
  begin
    bSetFill(StrAddr('#7f8ba6'), 7);
    bSetFont(StrAddr('24px monospace'), 14);
    bFillText(StrAddr('W / S to move, SPACE to serve'), StrLen('W / S to move, SPACE to serve'), W div 2, H div 2 + 40);
  end;

  bBatchFlush(ctx, Integer(@cmd), cmd_len);
end;

// ---- Bridge: exports ----
// Self-wired keyboard: keydown/keyup events on `document` are read via
// batch_get_property_str('key'), so the game owns its own keys (no host
// key mapping). This is the reference pattern for batchiness games.
procedure HandleKey(down: Integer);
var
  n: Integer;
  c0: Byte;
begin
  n := bGetPropStr(last_event, 'key', Integer(@text_buf), 16);
  if n > 0 then
  begin
    c0 := text_buf[0];
    // w / W
    if (c0 = 119) or (c0 = 87) then
    begin
      keys[KEY_UP] := (down <> 0);
      if down <> 0 then just_pressed[KEY_UP] := true;
    end
    // s / S
    else if (c0 = 115) or (c0 = 83) then
    begin
      keys[KEY_DOWN] := (down <> 0);
      if down <> 0 then just_pressed[KEY_DOWN] := true;
    end
    // space
    else if c0 = 32 then
    begin
      keys[KEY_SPACE] := (down <> 0);
      if down <> 0 then just_pressed[KEY_SPACE] := true;
    end;
    // Arrow keys are multi-char ('ArrowUp' etc.); handle them by prefix.
    if n >= 6 then
    begin
      if (text_buf[0] = 65) and (text_buf[1] = 114) and (text_buf[2] = 114) and
         (text_buf[3] = 111) and (text_buf[4] = 119) and (text_buf[5] = 85) then
      begin keys[KEY_UP] := (down <> 0); if down <> 0 then just_pressed[KEY_UP] := true; end; // ArrowUp
      if (text_buf[0] = 65) and (text_buf[1] = 114) and (text_buf[2] = 114) and
         (text_buf[3] = 111) and (text_buf[4] = 119) and (text_buf[5] = 68) then
      begin keys[KEY_DOWN] := (down <> 0); if down <> 0 then just_pressed[KEY_DOWN] := true; end; // ArrowDown
    end;
  end;
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

procedure PongMain;
var
  app, canvas, doc: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  canvas := bCanvasCreate(app, W, H);
  ctx := bGetContext(canvas);

  // seed the xorshift RNG from the clock (µs fraction, not whole ms: the ms value is ~constant in a freshly booted host, giving near-identical boards)
  rng_state := Cardinal((bNow - Trunc(bNow)) * 1000000.0) xor $9E3779B9;
  if rng_state = 0 then rng_state := 1;

  g.playing := false; g.over := false;
  g.ls := 0; g.rs := 0;
  g.ly := 194.0; g.ry := 194.0;
  g.bx := W / 2.0; g.by := H / 2.0;
  g.bvx := 0.0; g.bvy := 0.0;

  // Self-wired keyboard on `document` (the batchiness games' key pattern).
  doc := bGetGlobal('document');
  bAddListener(doc, 'keydown', CB_KEYDOWN);
  bAddListener(doc, 'keyup', CB_KEYUP);

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
    HandleKey(0);
end;

exports
  PongMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
