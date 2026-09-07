// runner.pas — Skoll-inspired infinite runner, ported to Pascal via wasmpascal.
// Batchiness ABI (batchiness_main / batchiness_invoke_callback / batchiness_set_last_event),
// same host wiring as pong.pas / breakout_graphics.pas / pascaloids.pas. A wolf
// dashes across an endlessly-scrolling norse landscape, jumping gaps, crates and
// spikes and snatching runes. Speed ramps with distance; parallax hills and a
// day-to-night sky sell the endless world. All visuals are canvas primitives,
// all SFX are the host Web Audio synth — zero assets, zero npm deps.
//
// Controls: Space / W / ArrowUp to jump (hold for a touch higher), R or Space
// to restart after a crash. Tap / click also jumps.
//
// State lives in a handful of fixed pools — no per-frame allocation, one
// batch flush per frame. The world is a sliding window of 16 platform slabs;
// when the leftmost slab scrolls off, it is recycled to the right with fresh
// procedural content (width, height, gap, crate/spike, rune).
//
// Ported from the Skoll design in Odint Know That (nofuss.co.za) — the Odin+
// raylib original uses Camera2D + procedural terrain + particles + screen shake;
// this port keeps the same invariants with batchiness' batched Canvas2D wire
// format.

library runner;

const
  TAU = 6.283185307179586;

  W = 800;
  H = 480;

  // world
  GROUND_Y = 380.0;
  PLAYER_X = 110.0;
  PLAYER_W = 22.0;
  PLAYER_H = 26.0;

  GRAVITY = 1900.0;
  JUMP_VY = -560.0;
  HOLD_GRAVITY_SCALE = 0.58; // when holding jump and rising, gravity is softer

  SPEED0 = 210.0;
  SPEED_MAX = 520.0;
  COYOTE_TIME = 0.09; // s — forgive a late jump after leaving a ledge

  MAX_PLAT = 16;
  MAX_OBS  = 16;
  MAX_RUNE = 16;
  MAX_PART = 64;

  CB_TICK = 0;
  CB_KEYDOWN = 1;
  CB_KEYUP   = 2;
  CB_PTRDOWN = 3;
  CB_PTRUP   = 4;

  KEY_JUMP = 0; // Space / W / ArrowUp

  // batch opcodes (wire format from batch.odin / batchiness.js)
  OP_SET_FILL = $01;
  OP_SET_STROKE = $02;
  OP_SET_LINE_WIDTH = $03;
  OP_SET_FONT = $04;
  OP_SET_TEXT_ALIGN = $05;
  OP_SET_TEXT_BASELINE = $06;
  OP_SET_GLOBAL_ALPHA = $07;
  OP_FILL_RECT = $10;
  OP_BEGIN_PATH = $20;
  OP_MOVE_TO = $21;
  OP_LINE_TO = $22;
  OP_CLOSE_PATH = $23;
  OP_ARC = $24;
  OP_FILL = $28;
  OP_STROKE = $29;
  OP_FILL_TEXT = $30;

  CMD_CAPACITY = 32768;

  SND_JUMP = 0;
  SND_COIN = 5;
  SND_HIT  = 4;
  SND_BUMP = 7;

type
  TPlat = record
    x, y, w: Single;
  end;
  TObs = record
    x, y, w, h: Single;
    alive: Boolean;
    kind: Integer; // 0 crate, 1 spikes
  end;
  TRune = record
    x, y: Single;
    alive: Boolean;
    taken: Boolean;
    phase: Single;
  end;
  TPart = record
    x, y, vx, vy, life: Single;
    kind: Integer; // 0 dust, 1 spark
  end;

var
  // player
  py, vy: Single;
  onGround: Boolean;
  coyote: Single;
  runPhase: Single;
  score, bestScore, distScore: Integer;
  scroll, speed: Single;
  state: Integer; // 0 title, 1 playing, 2 dead
  deadTimer: Single;
  shake: Single;
  flash: Single;

  // world pools
  plats: array[0..MAX_PLAT - 1] of TPlat;
  platCount: Integer;
  obs: array[0..MAX_OBS - 1] of TObs;
  runes: array[0..MAX_RUNE - 1] of TRune;
  parts: array[0..MAX_PART - 1] of TPart;
  partCount: Integer;

  keys: array[0..0] of Boolean;
  just_pressed: array[0..0] of Boolean;

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
function  aGetBest: Integer; external 'app_env' name 'get_best_score';
procedure aSetBest(s: Integer); external 'app_env' name 'set_best_score';
procedure aSetFps(f: Single); external 'app_env' name 'set_fps';

function  mSin(x: Double): Double; external 'odin_env' name 'sin';
function  mCos(x: Double): Double; external 'odin_env' name 'cos';

// ---- RNG (xorshift) ----
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

function RandRangeI(lo, hi: Integer): Integer;
begin
  RandRangeI := lo + Integer(Trunc(RandF32 * Single(hi - lo + 1)));
  if RandRangeI > hi then RandRangeI := hi;
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

// ---- Batch API ----
procedure bSetFill(p: Integer; n: Integer);
begin
  PutU8(OP_SET_FILL); PutLit(p, n);
end;

procedure bSetStroke(p: Integer; n: Integer);
begin
  PutU8(OP_SET_STROKE); PutLit(p, n);
end;

procedure bSetLineWidth(w: Single);
begin
  PutU8(OP_SET_LINE_WIDTH); PutF32(w);
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

procedure bSetAlpha(a: Single);
begin
  PutU8(OP_SET_GLOBAL_ALPHA); PutF32(a);
end;

procedure bFillRect(x, y, w, h: Single);
begin
  PutU8(OP_FILL_RECT); PutF32(x); PutF32(y); PutF32(w); PutF32(h);
end;

procedure bBeginPath;
begin
  PutU8(OP_BEGIN_PATH);
end;

procedure bMoveTo(x, y: Single);
begin
  PutU8(OP_MOVE_TO); PutF32(x); PutF32(y);
end;

procedure bLineTo(x, y: Single);
begin
  PutU8(OP_LINE_TO); PutF32(x); PutF32(y);
end;

procedure bClosePath;
begin
  PutU8(OP_CLOSE_PATH);
end;

procedure bFill;
begin
  PutU8(OP_FILL);
end;

procedure bStroke;
begin
  PutU8(OP_STROKE);
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

// ---- String helpers ----
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

// ---- Particles ----
procedure SpawnDust(x, y: Single; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
  begin
    if partCount >= MAX_PART then Exit;
    parts[partCount].x := x + RandRangeF32(-4.0, 4.0);
    parts[partCount].y := y + RandRangeF32(-2.0, 2.0);
    parts[partCount].vx := RandRangeF32(-70.0, 70.0);
    parts[partCount].vy := RandRangeF32(-180.0, -60.0);
    parts[partCount].life := RandRangeF32(0.22, 0.42);
    parts[partCount].kind := 0;
    partCount := partCount + 1;
  end;
end;

procedure SpawnSparks(x, y: Single; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
  begin
    if partCount >= MAX_PART then Exit;
    parts[partCount].x := x;
    parts[partCount].y := y;
    parts[partCount].vx := RandRangeF32(-160.0, 160.0);
    parts[partCount].vy := RandRangeF32(-260.0, -40.0);
    parts[partCount].life := RandRangeF32(0.28, 0.55);
    parts[partCount].kind := 1;
    partCount := partCount + 1;
  end;
end;

procedure UpdateParts(dt: Single);
var
  i: Integer;
begin
  i := 0;
  while i < partCount do
  begin
    parts[i].vy := parts[i].vy + 900.0 * dt;
    parts[i].x := parts[i].x + parts[i].vx * dt;
    parts[i].y := parts[i].y + parts[i].vy * dt;
    parts[i].life := parts[i].life - dt;
    if parts[i].life <= 0.0 then
    begin
      partCount := partCount - 1;
      if i <> partCount then parts[i] := parts[partCount];
    end else
      i := i + 1;
  end;
end;

// ---- World generation ----
function TailX: Single;
begin
  if platCount = 0 then TailX := 0.0
  else TailX := plats[platCount - 1].x + plats[platCount - 1].w;
end;

procedure PlaceObsOnPlat(px, py, pw: Single);
var
  i, slot: Integer;
  ow, oh: Single;
  ox: Single;
  kind: Integer;
begin
  // 35% of platforms get an obstacle
  if RandF32 > 0.35 then Exit;
  // find a free slot
  slot := -1;
  for i := 0 to MAX_OBS - 1 do
    if not obs[i].alive then begin slot := i; Break; end;
  if slot < 0 then Exit;
  // choose kind: 70% crate (walk-over must jump), 30% spikes (low)
  if RandF32 < 0.3 then kind := 1 else kind := 0;
  if kind = 0 then begin ow := 22.0; oh := 22.0; end
  else begin ow := 28.0; oh := 14.0; end;
  ox := px + pw * RandRangeF32(0.35, 0.72) - ow / 2.0;
  // avoid placing at the very edge where it is unfair
  if ox < px + 18.0 then ox := px + 18.0;
  obs[slot].x := ox;
  obs[slot].y := py - oh;
  obs[slot].w := ow;
  obs[slot].h := oh;
  obs[slot].kind := kind;
  obs[slot].alive := true;
end;

procedure PlaceRuneOnPlat(px, py, pw: Single);
var
  i, slot: Integer;
  rx, ry: Single;
begin
  if RandF32 > 0.52 then Exit;
  slot := -1;
  for i := 0 to MAX_RUNE - 1 do
    if not runes[i].alive then begin slot := i; Break; end;
  if slot < 0 then Exit;
  rx := px + pw * RandRangeF32(0.18, 0.82);
  ry := py - RandRangeF32(38.0, 68.0);
  // keep rune above spikes/crates — nudge up if it would overlap an obs on same plat
  runes[slot].x := rx;
  runes[slot].y := ry;
  runes[slot].alive := true;
  runes[slot].taken := false;
  runes[slot].phase := RandF32 * TAU;
end;

procedure GenOnePlat(atX: Single);
var
  w, y, gap: Single;
  idx: Integer;
begin
  // width 140..300, gap 44..150 ramped with distance so jumps get spicier
  w := RandRangeF32(140.0, 290.0);
  gap := RandRangeF32(44.0 + scroll * 0.018, 132.0 + scroll * 0.016);
  if scroll < 600.0 then gap := gap * 0.72; // gentle opening
  if atX < 700.0 then begin w := 260.0; gap := 0.0; end; // safe runway

  // height: drift with clamped variation — higher = harder to reach, so keep
  // most platforms near ground and only occasionally pop up
  if RandF32 < 0.18 then
    y := GROUND_Y - RandRangeF32(42.0, 88.0)
  else if RandF32 < 0.35 then
    y := GROUND_Y - RandRangeF32(10.0, 32.0)
  else
    y := GROUND_Y;

  if y < 260.0 then y := 260.0;
  if y > GROUND_Y then y := GROUND_Y;

  // find free plat slot at tail (we maintain dense 0..platCount-1)
  if platCount < MAX_PLAT then idx := platCount
  else idx := MAX_PLAT - 1; // caller shifts before calling when full

  plats[idx].x := atX + gap;
  plats[idx].y := y;
  plats[idx].w := w;
  if platCount < MAX_PLAT then platCount := platCount + 1;

  // maybe put stuff on it
  PlaceObsOnPlat(plats[idx].x, plats[idx].y, plats[idx].w);
  PlaceRuneOnPlat(plats[idx].x, plats[idx].y, plats[idx].w);
end;

procedure RecyclePlats;
var
  i: Integer;
  nx: Single;
begin
  // shift while leftmost is well behind the camera
  while (platCount > 0) and (plats[0].x + plats[0].w < scroll - 180.0) do
  begin
    nx := TailX;
    for i := 0 to platCount - 2 do plats[i] := plats[i + 1];
    platCount := platCount - 1;
    GenOnePlat(nx);
  end;
  // cull obstacles/runes that fell behind
  for i := 0 to MAX_OBS - 1 do
    if obs[i].alive and (obs[i].x + obs[i].w < scroll - 220.0) then obs[i].alive := false;
  for i := 0 to MAX_RUNE - 1 do
    if runes[i].alive and (runes[i].x < scroll - 240.0) then runes[i].alive := false;
end;

procedure InitWorld;
var
  i: Integer;
  x: Single;
begin
  platCount := 0;
  partCount := 0;
  for i := 0 to MAX_OBS - 1 do obs[i].alive := false;
  for i := 0 to MAX_RUNE - 1 do runes[i].alive := false;
  x := -80.0;
  // runway of 3 predictable slabs so the player can find their feet
  for i := 0 to 5 do
  begin
    GenOnePlat(x);
    x := TailX;
  end;
  // fill the rest
  while platCount < MAX_PLAT do
  begin
    GenOnePlat(TailX);
  end;
end;

procedure ResetGame;
begin
  scroll := 0.0;
  speed := SPEED0;
  py := GROUND_Y - PLAYER_H;
  vy := 0.0;
  onGround := true;
  coyote := 0.0;
  runPhase := 0.0;
  score := 0;
  distScore := 0;
  deadTimer := 0.0;
  shake := 0.0;
  flash := 0.0;
  state := 0; // title until first jump
  InitWorld;
  // snap player to first plat
  py := plats[0].y - PLAYER_H;
end;

// ---- Collision helpers ----
function AABB(ax, ay, aw, ah, bx, by, bw, bh: Single): Boolean;
begin
  AABB := (ax + aw > bx) and (ax < bx + bw) and (ay + ah > by) and (ay < by + bh);
end;

// ---- Game logic ----
procedure Die;
begin
  if state = 2 then Exit;
  state := 2;
  deadTimer := 0.0;
  shake := 10.0;
  flash := 0.9;
  aPlaySound(SND_HIT);
  SpawnSparks(PLAYER_X + PLAYER_W / 2.0, py + PLAYER_H / 2.0, 18);
  if score > bestScore then
  begin
    bestScore := score;
    aSetBest(score);
  end;
end;

procedure UpdateGame(dt: Single);
var
  i: Integer;
  prevBottom, nextBottom: Single;
  wantJump: Boolean;
  platScreenX: Single;
  landed: Boolean;
begin
  // global fx tick
  if shake > 0.0 then shake := shake - dt * 28.0;
  if shake < 0.0 then shake := 0.0;
  if flash > 0.0 then flash := flash - dt * 2.8;
  if flash < 0.0 then flash := 0.0;

  // title bob
  if state = 0 then
  begin
    runPhase := runPhase + dt * 3.0;
    // first jump starts the run
    if just_pressed[KEY_JUMP] then
    begin
      state := 1;
      just_pressed[KEY_JUMP] := false;
      vy := JUMP_VY;
      onGround := false;
      coyote := 0.0;
      aPlaySound(SND_JUMP);
      SpawnDust(PLAYER_X + PLAYER_W / 2.0, py + PLAYER_H, 6);
    end;
    UpdateParts(dt);
    Exit;
  end;

  if state = 2 then
  begin
    deadTimer := deadTimer + dt;
    // allow restart after a short lockout
    if (deadTimer > 0.35) and just_pressed[KEY_JUMP] then
    begin
      just_pressed[KEY_JUMP] := false;
      ResetGame;
      state := 1;
      vy := JUMP_VY;
      onGround := false;
      aPlaySound(SND_JUMP);
    end;
    // keep drifting a touch then freeze
    scroll := scroll + speed * dt * 0.18;
    UpdateParts(dt);
    Exit;
  end;

  // --- playing ---
  // speed ramp
  speed := SPEED0 + scroll * 0.038;
  if speed > SPEED_MAX then speed := SPEED_MAX;
  scroll := scroll + speed * dt;
  distScore := Trunc(scroll * 0.1);
  aSetFps(speed);

  // jump input (coyote + early press would be a nice follow-up)
  wantJump := just_pressed[KEY_JUMP];
  if wantJump and (onGround or (coyote > 0.0)) then
  begin
    vy := JUMP_VY;
    onGround := false;
    coyote := 0.0;
    just_pressed[KEY_JUMP] := false;
    wantJump := false;
    aPlaySound(SND_JUMP);
    SpawnDust(PLAYER_X + PLAYER_W / 2.0, py + PLAYER_H, 7);
  end;
  // consume stale press after we used it
  if wantJump and (not onGround) and (coyote <= 0.0) then
  begin
    // keep it for a few frames? simpler: clear
    // (player can just press again)
  end;

  prevBottom := py + PLAYER_H;
  // gravity with hold-to-jump-higher
  if keys[KEY_JUMP] and (vy < 0.0) then
    vy := vy + GRAVITY * HOLD_GRAVITY_SCALE * dt
  else
    vy := vy + GRAVITY * dt;
  py := py + vy * dt;
  nextBottom := py + PLAYER_H;

  // platform landings — top-only, like Skoll ch.4
  landed := false;
  for i := 0 to platCount - 1 do
  begin
    platScreenX := plats[i].x - scroll;
    if (PLAYER_X + PLAYER_W > platScreenX) and (PLAYER_X < platScreenX + plats[i].w) then
    begin
      // landing: was above the ledge, now at or below, and falling
      if (vy >= 0.0) and (prevBottom <= plats[i].y + 6.0) and (nextBottom >= plats[i].y) then
      begin
        py := plats[i].y - PLAYER_H;
        vy := 0.0;
        landed := true;
        // small landing puff when hitting from a real fall
        if not onGround then SpawnDust(PLAYER_X + PLAYER_W / 2.0, py + PLAYER_H, 4);
        Break;
      end;
    end;
  end;

  if landed then
  begin
    onGround := true;
    coyote := COYOTE_TIME;
    runPhase := runPhase + dt * (9.0 + speed * 0.012);
  end else begin
    onGround := false;
    if coyote > 0.0 then coyote := coyote - dt;
  end;

  // recycle world
  RecyclePlats;

  // rune pickups
  for i := 0 to MAX_RUNE - 1 do
  begin
    if not runes[i].alive or runes[i].taken then Continue;
    runes[i].phase := runes[i].phase + dt * 4.5;
    // rune screen pos
    if AABB(PLAYER_X - 2.0, py - 2.0, PLAYER_W + 4.0, PLAYER_H + 4.0,
            runes[i].x - scroll - 7.0, runes[i].y - 7.0, 14.0, 14.0) then
    begin
      runes[i].taken := true;
      runes[i].alive := false;
      score := score + 7;
      aPlaySound(SND_COIN);
      SpawnSparks(runes[i].x - scroll, runes[i].y, 8);
    end;
  end;

  // crate / spike hits — AABB, forgiving by 2px
  for i := 0 to MAX_OBS - 1 do
  begin
    if not obs[i].alive then Continue;
    if AABB(PLAYER_X + 3.0, py + 4.0, PLAYER_W - 6.0, PLAYER_H - 6.0,
            obs[i].x - scroll, obs[i].y, obs[i].w, obs[i].h) then
    begin
      Die;
      Break;
    end;
  end;

  // fall into a gap
  if py > H + 40.0 then Die;

  // update runes shimmer in place already; update particles
  UpdateParts(dt);
end;

// ---- Drawing ----
procedure DrawSky;
var
  i: Integer;
  t: Single;
  sunX, sunY: Single;
begin
  // night-to-dawn gradient bands
  bSetFill(StrAddr('#060d1e'), 7);
  bFillRect(0, 0, W, 110);
  bSetFill(StrAddr('#0d1b33'), 7);
  bFillRect(0, 110, W, 90);
  bSetFill(StrAddr('#152a4a'), 7);
  bFillRect(0, 200, W, 80);
  bSetFill(StrAddr('#1e3a5e'), 7);
  bFillRect(0, 280, W, 70);
  // horizon glow
  bSetFill(StrAddr('#2a4a6b'), 7);
  bFillRect(0, 350, W, 16);

  // moon / sun drift with distance (Skoll ch.8 day-night)
  t := scroll * 0.00055;
  sunX := 620.0 + Single(mCos(t)) * 44.0;
  sunY := 72.0 + Single(mSin(t * 0.7)) * 10.0;
  bSetFill(StrAddr('#ffe9a8'), 7);
  bBeginPath; bArc(sunX, sunY, 18.0, 0.0, TAU); bFill;
  bSetFill(StrAddr('#ffefc6'), 7);
  bBeginPath; bArc(sunX - 3.0, sunY - 2.0, 6.0, 0.0, TAU); bFill;

  // stars — parallax 0
  bSetFill(StrAddr('#c8d7ee'), 7);
  for i := 0 to 27 do
  begin
    bBeginPath;
    bArc(23.0 + Single(i * 29 mod 760) + Single(mSin(scroll * 0.0003 + Double(i))) * 6.0,
         18.0 + Single((i * 37) mod 92), 1.1, 0.0, TAU); bFill;
  end;
end;

procedure DrawHills;
var
  i: Integer;
  sx, peak: Single;
  base: Single;
begin
  // far range — parallax 0.18, dark
  bSetFill(StrAddr('#0f2747'), 7);
  base := 338.0;
  bBeginPath;
  bMoveTo(-40.0, base);
  for i := -2 to 6 do
  begin
    sx := Single(i) * 220.0 - Single(Trunc(scroll * 0.18) mod 220);
    peak := Single(38 + (i * 53 mod 26));
    bLineTo(sx + 110.0, base - peak);
  end;
  bLineTo(W + 40.0, base);
  bLineTo(W + 40.0, H);
  bLineTo(-40.0, H);
  bClosePath; bFill;

  // near range — parallax 0.42, mid
  bSetFill(StrAddr('#14365e'), 7);
  base := 354.0;
  bBeginPath;
  bMoveTo(-40.0, base);
  for i := -3 to 7 do
  begin
    sx := Single(i) * 180.0 - Single(Trunc(scroll * 0.42) mod 180);
    peak := Single(22 + (i * 71 mod 18));
    bLineTo(sx + 90.0, base - peak);
  end;
  bLineTo(W + 40.0, base);
  bLineTo(W + 40.0, H);
  bLineTo(-40.0, H);
  bClosePath; bFill;
end;

procedure DrawPlats;
var
  i: Integer;
  sx, sy, sw: Single;
begin
  for i := 0 to platCount - 1 do
  begin
    sx := plats[i].x - scroll;
    sy := plats[i].y;
    sw := plats[i].w;
    if (sx + sw < -40.0) or (sx > W + 40.0) then Continue;
    // slab body
    bSetFill(StrAddr('#2b241e'), 7);
    bFillRect(sx, sy, sw, H - sy);
    // top rock
    bSetFill(StrAddr('#3d342a'), 7);
    bFillRect(sx, sy, sw, 10.0);
    // grass
    bSetFill(StrAddr('#3a7a3a'), 7);
    bFillRect(sx, sy - 4.0, sw, 6.0);
    // grass highlight
    bSetFill(StrAddr('#4e9a4e'), 7);
    bFillRect(sx, sy - 4.0, sw, 2.0);
    // edge shade
    bSetFill(StrAddr('#1e1814'), 7);
    bFillRect(sx, sy + 10.0, sw, 2.0);
  end;
end;

procedure DrawObs;
var
  i: Integer;
  sx, sy: Single;
begin
  for i := 0 to MAX_OBS - 1 do
  begin
    if not obs[i].alive then Continue;
    sx := obs[i].x - scroll;
    if (sx + obs[i].w < -20.0) or (sx > W + 20.0) then Continue;
    sy := obs[i].y;
    if obs[i].kind = 0 then
    begin
      // crate
      bSetFill(StrAddr('#8b4a2b'), 7);
      bFillRect(sx, sy, obs[i].w, obs[i].h);
      bSetFill(StrAddr('#6e3a22'), 7);
      bFillRect(sx, sy + 5.0, obs[i].w, 2.0);
      bFillRect(sx, sy + 12.0, obs[i].w, 2.0);
      bSetFill(StrAddr('#a85a33'), 7);
      bFillRect(sx, sy, obs[i].w, 2.0);
      bSetStroke(StrAddr('#1a120e'), 7); bSetLineWidth(1.0);
      bBeginPath; bMoveTo(sx, sy); bLineTo(sx + obs[i].w, sy); bLineTo(sx + obs[i].w, sy + obs[i].h); bLineTo(sx, sy + obs[i].h); bClosePath; bStroke;
    end else begin
      // spikes — three triangles on a base
      bSetFill(StrAddr('#3a1a14'), 7);
      bFillRect(sx, sy + 8.0, obs[i].w, 6.0);
      bSetFill(StrAddr('#c0392b'), 7);
      bBeginPath;
      bMoveTo(sx + 2.0, sy + 8.0); bLineTo(sx + 7.0, sy); bLineTo(sx + 12.0, sy + 8.0); bClosePath; bFill;
      bBeginPath;
      bMoveTo(sx + 10.0, sy + 8.0); bLineTo(sx + 15.0, sy - 2.0); bLineTo(sx + 20.0, sy + 8.0); bClosePath; bFill;
      bBeginPath;
      bMoveTo(sx + 18.0, sy + 8.0); bLineTo(sx + 23.0, sy + 1.0); bLineTo(sx + 26.0, sy + 8.0); bClosePath; bFill;
    end;
  end;
end;

procedure DrawRunes;
var
  i: Integer;
  sx, sy, bob: Single;
begin
  for i := 0 to MAX_RUNE - 1 do
  begin
    if not runes[i].alive or runes[i].taken then Continue;
    sx := runes[i].x - scroll;
    if (sx < -16.0) or (sx > W + 16.0) then Continue;
    bob := Single(mSin(runes[i].phase)) * 3.5;
    sy := runes[i].y + bob;
    // glow
    bSetFill(StrAddr('#ffef8a'), 7);
    bBeginPath; bArc(sx, sy, 9.0, 0.0, TAU); bFill;
    // rune body
    bSetFill(StrAddr('#ffcc33'), 7);
    bBeginPath; bArc(sx, sy, 6.5, 0.0, TAU); bFill;
    // inner
    bSetFill(StrAddr('#fff7cc'), 7);
    bBeginPath; bArc(sx - 1.0, sy - 1.5, 2.2, 0.0, TAU); bFill;
    // rune glyph (tiny triangle)
    bSetFill(StrAddr('#8a5a00'), 7);
    bBeginPath; bMoveTo(sx, sy - 3.0); bLineTo(sx + 2.5, sy + 2.0); bLineTo(sx - 2.5, sy + 2.0); bClosePath; bFill;
  end;
end;

procedure DrawPlayer;
var
  x, y: Single;
  legA, legB: Single;
  bob: Single;
  hx: Integer;
begin
  x := PLAYER_X;
  y := py;
  if shake > 0.0 then
  begin
    x := x + Single(mSin(scroll * 0.12)) * shake * 0.18;
    y := y + Single(mCos(scroll * 0.09)) * shake * 0.12;
  end;
  bob := 0.0;
  if onGround then bob := Single(mSin(runPhase * 1.4)) * 1.2;

  // shadow under feet — subtle, not an opaque black disc
  if onGround then
  begin
    bSetAlpha(0.22);
    bSetFill(StrAddr('#0a0f1a'), 7);
    bBeginPath; bArc(x + 11.0, y + PLAYER_H + 2.5, 9.0, 0.0, TAU); bFill;
    bSetAlpha(1.0);
  end;

  // tail
  bSetFill(StrAddr('#1b1e28'), 7);
  bFillRect(x - 1.0, y + 10.0 + bob, 5.0, 5.0);
  bSetFill(StrAddr('#252836'), 7);
  bFillRect(x + 1.0, y + 8.0 + bob, 3.0, 3.0);

  // back legs / front legs — two-tone run cycle
  legA := Single(mSin(runPhase)) * 4.2;
  legB := Single(mSin(runPhase + 3.14)) * 4.2;
  if not onGround then begin legA := -2.0; legB := 2.0; end;

  // legs are short rects under the body
  bSetFill(StrAddr('#1a1c26'), 7);
  bFillRect(x + 5.0 + legA * 0.28, y + 18.0 + bob, 3.0, 7.0); // back
  bFillRect(x + 13.0 + legB * 0.28, y + 18.0 + bob, 3.0, 7.0); // front

  // body
  bSetFill(StrAddr('#2f3342'), 7);
  bFillRect(x + 2.0, y + 8.0 + bob, 16.0, 11.0);
  bSetFill(StrAddr('#3a3f52'), 7);
  bFillRect(x + 2.0, y + 8.0 + bob, 16.0, 3.0);

  // chest fluff
  bSetFill(StrAddr('#e6e2d6'), 7);
  bFillRect(x + 14.0, y + 11.0 + bob, 4.0, 6.0);

  // head
  bSetFill(StrAddr('#3a3f52'), 7);
  bFillRect(x + 12.0, y + 2.0 + bob, 11.0, 11.0);
  // snout
  bSetFill(StrAddr('#c9c5b8'), 7);
  bFillRect(x + 20.0, y + 7.0 + bob, 6.0, 5.0);
  bSetFill(StrAddr('#1a1c26'), 7);
  bFillRect(x + 24.0, y + 8.0 + bob, 2.0, 2.0); // nose
  // ears
  bSetFill(StrAddr('#2f3342'), 7);
  bBeginPath; bMoveTo(x + 14.0, y + 2.0 + bob); bLineTo(x + 16.0, y - 1.0 + bob); bLineTo(x + 18.0, y + 2.0 + bob); bClosePath; bFill;
  bBeginPath; bMoveTo(x + 18.0, y + 2.0 + bob); bLineTo(x + 20.0, y - 1.0 + bob); bLineTo(x + 22.0, y + 2.0 + bob); bClosePath; bFill;
  // ears inner
  bSetFill(StrAddr('#e6a0a0'), 7);
  bFillRect(x + 15.0, y + 1.0 + bob, 2.0, 2.0);
  bFillRect(x + 19.0, y + 1.0 + bob, 2.0, 2.0);
  // eye
  bSetFill(StrAddr('#ffe066'), 7);
  bBeginPath; bArc(x + 18.0, y + 6.0 + bob, 2.4, 0.0, TAU); bFill;
  bSetFill(StrAddr('#1a1c26'), 7);
  bBeginPath; bArc(x + 19.0, y + 6.0 + bob, 1.1, 0.0, TAU); bFill;
  // eye shine
  bSetFill(StrAddr('#ffffff'), 7);
  bBeginPath; bArc(x + 18.6, y + 5.3 + bob, 0.7, 0.0, TAU); bFill;

  // hurt flash
  if flash > 0.12 then
  begin
    hx := Trunc(flash * 140.0);
    if hx > 90 then hx := 90;
    bSetFill(StrAddr('#ff3b3b'), 7);
    bFillRect(x + 2.0, y + 8.0 + bob, 16.0, 11.0);
  end;
end;

procedure DrawParts;
var
  i: Integer;
  r, a: Single;
begin
  for i := 0 to partCount - 1 do
  begin
    if parts[i].kind = 0 then
    begin
      a := parts[i].life / 0.42;
      if a > 1.0 then a := 1.0;
      if a < 0.0 then a := 0.0;
      if a > 0.5 then bSetFill(StrAddr('#8a9bb5'), 7) else bSetFill(StrAddr('#5a6a8a'), 7);
      r := 1.6 + a * 2.0;
      bBeginPath; bArc(parts[i].x - scroll + PLAYER_X - 110.0 + 11.0, parts[i].y, r, 0.0, TAU); bFill;
      // dust is in screen space offset above — we stored world x, so convert
      // simpler: parts store screen-relative already for dust; keep as is
    end else begin
      a := parts[i].life / 0.55;
      bSetFill(StrAddr('#ffe066'), 7);
      r := 1.2 + a * 3.0;
      bBeginPath; bArc(parts[i].x, parts[i].y, r, 0.0, TAU); bFill;
    end;
  end;
end;

procedure DrawHUD;
var
  n, o: Integer;
begin
  // top bar
  bSetFill(StrAddr('#0a0f1a'), 7);
  bFillRect(0, 0, W, 26);

  bSetFill(StrAddr('#e6edf7'), 7);
  bSetFont(StrAddr('13px monospace'), 14);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
  n := WriteInt(0, score + distScore);
  bFillText(Integer(@text_buf), n, 10, 8);
  bSetFill(StrAddr('#7f8ba6'), 7);
  bSetFont(StrAddr('11px monospace'), 14);
  bFillText(StrAddr('SCORE'), 5, 52, 8);

  bSetFill(StrAddr('#e6edf7'), 7);
  bSetFont(StrAddr('13px monospace'), 14);
  bSetTextAlign(StrAddr('center'), 6);
  n := WriteInt(0, distScore);
  bFillText(Integer(@text_buf), n, W div 2, 8);
  bSetFill(StrAddr('#7f8ba6'), 7);
  bSetFont(StrAddr('11px monospace'), 14);
  bFillText(StrAddr('M'), 1, W div 2 + 24, 8);

  bSetFill(StrAddr('#e6edf7'), 7);
  bSetFont(StrAddr('13px monospace'), 14);
  bSetTextAlign(StrAddr('right'), 5);
  n := WriteInt(0, bestScore);
  bFillText(Integer(@text_buf), n, W - 10, 8);
  bSetFill(StrAddr('#7f8ba6'), 7);
  bSetFont(StrAddr('11px monospace'), 14);
  bFillText(StrAddr('BEST'), 4, W - 42, 8);

  // speed tick
  bSetFill(StrAddr('#1e2a44'), 7);
  bFillRect(W div 2 - 60, 20, 120, 3);
  bSetFill(StrAddr('#4ecdc4'), 7);
  bFillRect(W div 2 - 60, 20, (speed - SPEED0) / (SPEED_MAX - SPEED0) * 120.0, 3);
end;

procedure DrawTitle;
begin
  bSetFill(StrAddr('#0a0f1a'), 7);
  bFillRect(W div 2 - 210, 86, 420, 96);
  bSetFill(StrAddr('#1a2a44'), 7);
  bFillRect(W div 2 - 210, 86, 420, 3);

  bSetFill(StrAddr('#e6edf7'), 7);
  bSetFont(StrAddr('42px monospace'), 14);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('top'), 3);
  bFillText(StrAddr('RUNNER'), 6, W div 2, 96);

  bSetFill(StrAddr('#4ecdc4'), 7);
  bSetFont(StrAddr('12px monospace'), 14);
  bFillText(StrAddr('SKOLL-INSPIRED  ENDLESS  TERRAIN'), StrLen('SKOLL-INSPIRED  ENDLESS  TERRAIN'), W div 2, 138);

  bSetFill(StrAddr('#7f8ba6'), 7);
  bSetFont(StrAddr('12px monospace'), 14);
  bFillText(StrAddr('SPACE / W / UP  to jump  -  hold for higher'), StrLen('SPACE / W / UP  to jump  -  hold for higher'), W div 2, 158);

  // pulsing prompt
  if Trunc(runPhase * 2.0) mod 2 = 0 then
  begin
    bSetFill(StrAddr('#ffe066'), 7);
    bSetFont(StrAddr('14px monospace'), 14);
    bFillText(StrAddr('PRESS JUMP TO RUN'), StrLen('PRESS JUMP TO RUN'), W div 2, 194);
  end;
end;

procedure DrawDead;
var
  n: Integer;
begin
  bSetFill(StrAddr('#1a0f14'), 7);
  bFillRect(W div 2 - 220, 72, 440, 124);
  bSetFill(StrAddr('#ff3b3b'), 7);
  bFillRect(W div 2 - 220, 72, 440, 3);

  bSetFill(StrAddr('#ff6b6b'), 7);
  bSetFont(StrAddr('34px monospace'), 14);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('top'), 3);
  if py > H then
    bFillText(StrAddr('FELL INTO THE VOID'), StrLen('FELL INTO THE VOID'), W div 2, 84)
  else
    bFillText(StrAddr('CRASHED'), 7, W div 2, 84);

  bSetFill(StrAddr('#e6edf7'), 7);
  bSetFont(StrAddr('16px monospace'), 14);
  n := WriteInt(0, score + distScore);
  bFillText(Integer(@text_buf), n, W div 2 - 60, 128);
  bSetFill(StrAddr('#7f8ba6'), 7);
  bSetFont(StrAddr('12px monospace'), 14);
  bFillText(StrAddr('SCORE'), 5, W div 2 - 18, 128);
  bSetFill(StrAddr('#e6edf7'), 7);
  bSetFont(StrAddr('13px monospace'), 14);
  bSetTextAlign(StrAddr('left'), 4);
  n := WriteInt(0, bestScore);
  bFillText(Integer(@text_buf), n, W div 2 + 36, 128);
  bSetFill(StrAddr('#7f8ba6'), 7);
  bSetFont(StrAddr('12px monospace'), 14);
  bFillText(StrAddr('BEST'), 4, W div 2 + 62, 128);

  if deadTimer > 0.35 then
  begin
    if Trunc(deadTimer * 3.0) mod 2 = 0 then bSetFill(StrAddr('#ffe066'), 7) else bSetFill(StrAddr('#7f8ba6'), 7);
    bSetFont(StrAddr('13px monospace'), 14);
    bSetTextAlign(StrAddr('center'), 6);
    bFillText(StrAddr('SPACE TO RUN AGAIN'), StrLen('SPACE TO RUN AGAIN'), W div 2, 166);
  end;
end;

procedure DrawGame;
var
  i: Integer;
begin
  BufReset;

  DrawSky;
  DrawHills;
  DrawPlats;
  DrawObs;
  DrawRunes;
  DrawPlayer;

  // particles are in world/screen mix — draw them in screen space
  // (our SpawnSparks already stored screen x, SpawnDust stored near player)
  // For simplicity we stored everything roughly screen-relative except platforms;
  // keep parts as screen-space to avoid double-subtracting scroll.
  for i := 0 to partCount - 1 do
  begin
    if parts[i].kind = 0 then
    begin
      // dust drifts with the world a touch
      bSetFill(StrAddr('#7a8aa6'), 7);
      bBeginPath; bArc(parts[i].x, parts[i].y, 1.8 + parts[i].life * 2.4, 0.0, TAU); bFill;
    end else begin
      bSetFill(StrAddr('#ffe066'), 7);
      bBeginPath; bArc(parts[i].x, parts[i].y, 1.4 + parts[i].life * 3.0, 0.0, TAU); bFill;
    end;
  end;

  DrawHUD;

  if state = 0 then DrawTitle
  else if state = 2 then DrawDead;

  // hurt vignette
  if flash > 0.05 then
  begin
    bSetFill(StrAddr('#ff1a1a'), 7);
    // top/bottom flash bars (cheap vignette)
    bFillRect(0, 0, W, 4.0 + flash * 10.0);
    bFillRect(0, H - 4.0 - flash * 10.0, W, 4.0 + flash * 10.0);
  end;

  // controls hint in play
  if (state = 1) and (distScore < 40) then
  begin
    bSetFill(StrAddr('#0a0f1a'), 7);
    bFillRect(W div 2 - 150, H - 28, 300, 16);
    bSetFill(StrAddr('#7f8ba6'), 7);
    bSetFont(StrAddr('11px monospace'), 14);
    bSetTextAlign(StrAddr('center'), 6);
    bFillText(StrAddr('JUMP gaps and crates  -  grab runes'), StrLen('JUMP gaps and crates  -  grab runes'), W div 2, H - 18);
  end;

  bBatchFlush(ctx, Integer(@cmd), cmd_len);
end;

// ---- Bridge: input + exports ----
procedure HandleKey(down: Integer);
var
  n: Integer;
begin
  n := bGetPropStr(last_event, 'key', Integer(@text_buf), 16);
  if n <= 0 then Exit;

  // space (1 char ' ')
  if n = 1 then
  begin
    if text_buf[0] = 32 then
    begin
      keys[KEY_JUMP] := (down <> 0);
      if down <> 0 then just_pressed[KEY_JUMP] := true;
    end
    else if (text_buf[0] = 119) or (text_buf[0] = 87) then
    begin
      keys[KEY_JUMP] := (down <> 0);
      if down <> 0 then just_pressed[KEY_JUMP] := true;
    end
    else if (text_buf[0] = 114) or (text_buf[0] = 82) then
    begin
      // R to restart when dead
      if (down <> 0) and (state = 2) and (deadTimer > 0.35) then
      begin
        just_pressed[KEY_JUMP] := true;
      end;
    end;
  end;

  // named keys — dispatch by length first (AGENTS gotcha)
  if n >= 5 then
  begin
    // ArrowUp (7 chars) — Single-char keys are length 1, named keys are >=5
    if (n = 7) and (text_buf[0]=65) and (text_buf[1]=114) and (text_buf[2]=114) and (text_buf[3]=111) and (text_buf[4]=119) and (text_buf[5]=85) and (text_buf[6]=112) then
    begin
      keys[KEY_JUMP] := (down <> 0);
      if down <> 0 then just_pressed[KEY_JUMP] := true;
    end;
  end;
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

procedure RunnerMain;
var
  app, canvas, doc: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  canvas := bCanvasCreate(app, W, H);
  ctx := bGetContext(canvas);

  rng_state := Cardinal((bNow - Trunc(bNow)) * 1000000.0) xor $9E3779B9;
  if rng_state = 0 then rng_state := 1;
  bestScore := aGetBest;

  ResetGame;
  last_ms := bNow;

  doc := bGetGlobal('document');
  bAddListener(doc, 'keydown', CB_KEYDOWN);
  bAddListener(doc, 'keyup', CB_KEYUP);
  // pointer / touch jump — attached to the stage element and document for coverage
  bAddListener(canvas, 'pointerdown', CB_PTRDOWN);
  bAddListener(canvas, 'pointerup', CB_PTRUP);
  bAddListener(doc, 'pointerdown', CB_PTRDOWN);
  bAddListener(doc, 'pointerup', CB_PTRUP);

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
  else if id = CB_KEYDOWN then HandleKey(1)
  else if id = CB_KEYUP then HandleKey(0)
  else if id = CB_PTRDOWN then
  begin
    keys[KEY_JUMP] := true;
    just_pressed[KEY_JUMP] := true;
  end
  else if id = CB_PTRUP then
  begin
    keys[KEY_JUMP] := false;
  end;
end;

exports
  RunnerMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
