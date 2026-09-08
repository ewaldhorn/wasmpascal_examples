// game.pas — Pascaloids: Destroids ported to Pascal via wasmpascal.
// Batched Canvas2D through the Batchiness wire format; same host ABI as the
// Odin original (app_env + batch_env imports, batchiness_main / invoke /
// set_last_event exports; keyboard is self-wired via batch_add_event_listener).

// ---- Scalars and types ----
library pascaloids;

const
  TAU = 6.283185307179586;
  STAR_COUNT = 380;
  MAX_ASTEROIDS = 256;
  MAX_BULLETS = 6;
  MAX_PARTICLES = 700;
  MAX_DEBRIS = 160;
  MAX_SHOCKWAVES = 16;
  SHAPE_N = 12;

  SHIP_TURN = 3.6;
  SHIP_THRUST = 260.0;
  SHIP_FRICTION = 0.6;
  SHIP_MAX_SPEED = 420.0;
  SHIP_RADIUS = 11.0;

  BULLET_SPEED = 520.0;
  BULLET_LIFE = 1.15;
  FIRE_COOLDOWN = 0.16;

  INVULN_TIME = 2.5;
  RESPAWN_DELAY = 1.2;

  AST_R_LARGE = 46.0;
  AST_R_MED = 26.0;
  AST_R_SMALL = 14.0;

  SND_FIRE = 0;
  SND_BANG_LARGE = 1;
  SND_BANG_MED = 2;
  SND_BANG_SMALL = 3;
  SND_SHIP_DEATH = 4;
  SND_LEVEL = 5;
  SND_HYPER = 6;
  SND_THUD = 7;

  KEY_LEFT = 0;
  KEY_RIGHT = 1;
  KEY_THRUST = 2;
  KEY_FIRE = 3;
  KEY_START = 4;
  KEY_HYPER = 5;
  KEY_PAUSE = 6;
  KEY_COUNT = 7;

  CANVAS_W = 800;
  CANVAS_H = 600;
  CB_TICK = 0;
  CB_KEYDOWN = 1;
  CB_KEYUP = 2;

  // batch opcodes
  OP_SET_FILL = $01;
  OP_SET_STROKE = $02;
  OP_SET_LINE_WIDTH = $03;
  OP_SET_FONT = $04;
  OP_SET_TEXT_ALIGN = $05;
  OP_SET_TEXT_BASELINE = $06;
  OP_SET_GLOBAL_ALPHA = $07;
  OP_SET_LINE_CAP = $08;
  OP_FILL_RECT = $10;
  OP_STROKE_RECT = $11;
  OP_CLEAR_RECT = $12;
  OP_BEGIN_PATH = $20;
  OP_MOVE_TO = $21;
  OP_LINE_TO = $22;
  OP_CLOSE_PATH = $23;
  OP_ARC = $24;
  OP_ELLIPSE = $25;
  OP_RECT = $26;
  OP_FILL = $28;
  OP_STROKE = $29;
  OP_CLIP = $2A;
  OP_FILL_TEXT = $30;
  OP_STROKE_TEXT = $31;
  OP_BEZIER_CURVE_TO = $27;
  OP_SAVE = $40;
  OP_RESTORE = $41;
  OP_TRANSLATE = $42;
  OP_SCALE = $43;
  OP_ROTATE = $44;
  OP_SET_TRANSFORM = $45;
  OP_RESET_TRANSFORM = $46;
  OP_LINEAR_GRADIENT = $50;
  OP_RADIAL_GRADIENT = $51;
  OP_ADD_COLOR_STOP = $52;
  OP_USE_GRADIENT_FILL = $53;
  OP_USE_GRADIENT_STROKE = $54;
  OP_DRAW_SPRITE = $60;
  OP_DRAW_SPRITE_SCALED = $61;
  OP_DRAW_SPRITE_SUB = $62;
  OP_SET_SHADOW = $70;
  OP_CLEAR_SHADOW = $71;
  OP_SET_FILTER = $72;
  OP_CLEAR_FILTER = $73;
  OP_BAKE_BEGIN = $80;
  OP_BAKE_END = $81;

  CMD_CAPACITY = 262144;

type
  TStar = record
    sx, sy, brightness, twinkle: Single;
  end;

  TShip = record
    px, py, vx, vy, angle: Single;
    alive: Boolean;
    thrust: Boolean;
    invuln, respawn, cooldown: Single;
  end;

  TBullet = record
    px, py, vx, vy, life: Single;
    active: Boolean;
  end;

  TAsteroid = record
    px, py, vx, vy, angle, spin, radius: Single;
    size: Integer;
    shape: array[0..SHAPE_N - 1] of Single;
    active: Boolean;
  end;

  TParticle = record
    px, py, vx, vy, life, max_life: Single;
    active: Boolean;
  end;

  TDebris = record
    px, py, vx, vy, angle, spin, len, life, max_life: Single;
    active: Boolean;
  end;

  TShockwave = record
    px, py, radius, max_radius, life, max_life: Single;
    active: Boolean;
  end;

var
  stars: array[0..STAR_COUNT - 1] of TStar;
  ship: TShip;
  bullets: array[0..MAX_BULLETS - 1] of TBullet;
  asteroids: array[0..MAX_ASTEROIDS - 1] of TAsteroid;
  particles: array[0..MAX_PARTICLES - 1] of TParticle;
  debris: array[0..MAX_DEBRIS - 1] of TDebris;
  shockwaves: array[0..MAX_SHOCKWAVES - 1] of TShockwave;

  score: Integer;
  best_score: Integer;
  lives: Integer;
  level: Integer;
  game_over: Boolean;
  thrust_snd_on: Boolean;
  intro: Boolean;
  paused: Boolean;

  shake_mag: Single;
  shake_x: Single;
  shake_y: Single;
  hyper_cooldown: Single;
  thud_cooldown: Single;
  thrust_particle_timer: Single;

  rng_state: Cardinal;
  anim_time: Single;

  keys: array[0..KEY_COUNT - 1] of Boolean;
  just_pressed: array[0..KEY_COUNT - 1] of Boolean;

  fps_frames: Integer;
  fps_accum: Single;
  last_ms: Double;

  ctx: Integer;

  cmd: array[0..CMD_CAPACITY - 1] of Byte;
  cmd_len: Integer;

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

procedure aSetFps(f: Single); external 'app_env' name 'set_fps';
procedure aPlaySound(id: Integer); external 'app_env' name 'play_sound';
procedure aSetThrust(on: Integer); external 'app_env' name 'set_thrust';
function  aGetBest: Integer; external 'app_env' name 'get_best_score';
procedure aSetBest(s: Integer); external 'app_env' name 'set_best_score';

function  mSin(x: Double): Double; external 'odin_env' name 'sin';
function  mCos(x: Double): Double; external 'odin_env' name 'cos';
function  mPow(b, e: Double): Double; external 'odin_env' name 'pow';

// ---- RNG ----
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

// ---- Batch primitives (wire format from batch.odin) ----
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

// ---- Batch API (mirror batch.odin wrappers) ----
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

procedure bSetGlobalAlpha(a: Single);
begin
  PutU8(OP_SET_GLOBAL_ALPHA); PutF32(a);
end;

procedure bSetLineCap(p: Integer; n: Integer);
begin
  PutU8(OP_SET_LINE_CAP); PutLit(p, n);
end;

procedure bFillRect(x, y, w, h: Single);
begin
  PutU8(OP_FILL_RECT); PutF32(x); PutF32(y); PutF32(w); PutF32(h);
end;

procedure bSetShadow(p: Integer; n: Integer; blur: Single);
begin
  PutU8(OP_SET_SHADOW); PutLit(p, n); PutF32(blur);
end;

procedure bClearShadow;
begin
  PutU8(OP_CLEAR_SHADOW);
end;

procedure bBeginPath;
begin
  PutU8(OP_BEGIN_PATH);
end;

procedure bClosePath;
begin
  PutU8(OP_CLOSE_PATH);
end;

procedure bStroke;
begin
  PutU8(OP_STROKE);
end;

procedure bFill;
begin
  PutU8(OP_FILL);
end;

procedure bMoveTo(x, y: Single);
begin
  PutU8(OP_MOVE_TO); PutF32(x); PutF32(y);
end;

procedure bLineTo(x, y: Single);
begin
  PutU8(OP_LINE_TO); PutF32(x); PutF32(y);
end;

procedure bArc(x, y, r, a0, a1: Single);
begin
  PutU8(OP_ARC); PutF32(x); PutF32(y); PutF32(r); PutF32(a0); PutF32(a1); PutU8(0);
end;

procedure bSave;
begin
  PutU8(OP_SAVE);
end;

procedure bRestore;
begin
  PutU8(OP_RESTORE);
end;

procedure bTranslate(x, y: Single);
begin
  PutU8(OP_TRANSLATE); PutF32(x); PutF32(y);
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

// ---- Math / vector helpers (Vec2 flattened) ----
function Dist2(ax, ay, bx, by: Single): Single;
var
  dx, dy: Single;
begin
  dx := ax - bx;
  dy := ay - by;
  Dist2 := dx * dx + dy * dy;
end;

function Clamp01(v: Single): Single;
begin
  if v < 0 then Clamp01 := 0
  else if v > 1 then Clamp01 := 1
  else Clamp01 := v;
end;

function PowF32(ba, ex: Single): Single;
begin
  PowF32 := Single(mPow(Double(ba), Double(ex)));
end;

// ---- String helpers for HUD (no heap, fixed scratch) ----
var
  text_buf: array[0..63] of Byte;
  last_event: Integer = 0;
  tmp16: array[0..15] of Byte;

// write decimal of n (>=0) into text_buf starting at off; returns new offset
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

// Build "PREFIX<num>" into text_buf; returns length
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


// ---------------------------------------------------------------------------
// Setup / reset
// ---------------------------------------------------------------------------
procedure SpawnShip;
begin
  ship.px := CANVAS_W / 2.0;
  ship.py := CANVAS_H / 2.0;
  ship.vx := 0; ship.vy := 0;
  ship.angle := -TAU / 4.0;
  ship.alive := true;
  ship.thrust := false;
  ship.invuln := INVULN_TIME;
  ship.respawn := 0;
  ship.cooldown := 0;
end;

procedure DeactivateAll;
var
  i: Integer;
begin
  for i := 0 to MAX_BULLETS - 1 do bullets[i].active := false;
  for i := 0 to MAX_ASTEROIDS - 1 do asteroids[i].active := false;
  for i := 0 to MAX_PARTICLES - 1 do particles[i].active := false;
  for i := 0 to MAX_DEBRIS - 1 do debris[i].active := false;
  for i := 0 to MAX_SHOCKWAVES - 1 do shockwaves[i].active := false;
end;

procedure SpawnAsteroid(px, py: Single; size: Integer);
var
  i, k: Integer;
  spd, dir: Single;
begin
  for i := 0 to MAX_ASTEROIDS - 1 do
  begin
    if asteroids[i].active then continue;
    asteroids[i].active := true;
    asteroids[i].px := px;
    asteroids[i].py := py;
    asteroids[i].size := size;
    if size = 3 then asteroids[i].radius := AST_R_LARGE
    else if size = 2 then asteroids[i].radius := AST_R_MED
    else asteroids[i].radius := AST_R_SMALL;
    spd := RandRangeF32(24.0, 60.0) * (1.0 + Single(3 - size) * 0.35);
    dir := RandRangeF32(0.0, TAU);
    asteroids[i].vx := mCos(dir) * spd;
    asteroids[i].vy := mSin(dir) * spd;
    asteroids[i].angle := RandRangeF32(0.0, TAU);
    asteroids[i].spin := RandRangeF32(-1.6, 1.6);
    for k := 0 to SHAPE_N - 1 do
      asteroids[i].shape[k] := RandRangeF32(0.72, 1.08);
    exit;
  end;
end;

procedure NextLevel;
var
  count, i: Integer;
  px, py, r: Single;
begin
  level := level + 1;
  if level > 1 then aPlaySound(SND_LEVEL);
  count := 4 + level * 2;
  for i := 0 to count - 1 do
  begin
    if RandF32 < 0.5 then
    begin
      px := RandF32 * CANVAS_W;
      if RandF32 < 0.5 then py := 0.0 else py := CANVAS_H;
    end else begin
      if RandF32 < 0.5 then px := 0.0 else px := CANVAS_W;
      py := RandF32 * CANVAS_H;
    end;
    SpawnAsteroid(px, py, 3);
  end;
end;

procedure ResetGame;
var
  i: Integer;
begin
  score := 0;
  lives := 3;
  level := 0;
  game_over := false;
  DeactivateAll;
  shake_mag := 0; shake_x := 0; shake_y := 0;
  hyper_cooldown := 0; thud_cooldown := 0;
  thrust_particle_timer := 0;
  paused := false;
  SpawnShip;
  NextLevel;
end;

procedure InitGame;
var
  i: Integer;
  fx, fy: Single;
begin
  // seed the xorshift RNG (unseeded 0 stays 0 -> all randomness collapses)
  rng_state := $9E3779B9;
  for i := 0 to STAR_COUNT - 1 do
  begin
    stars[i].sx := RandF32 * CANVAS_W;
    stars[i].sy := RandF32 * CANVAS_H;
    stars[i].brightness := RandRangeF32(0.15, 0.9);
    stars[i].twinkle := RandRangeF32(0.0, TAU);
  end;
  intro := true;
  best_score := aGetBest;
  ResetGame;
end;

// ---------------------------------------------------------------------------
// Particles / debris / shockwaves / shake
// ---------------------------------------------------------------------------
procedure SpawnParticles(px, py: Single; n: Integer; spread: Single);
var
  i, made: Integer;
  dir, spd: Single;
begin
  made := 0;
  for i := 0 to MAX_PARTICLES - 1 do
  begin
    if made >= n then break;
    if particles[i].active then continue;
    particles[i].active := true;
    particles[i].px := px;
    particles[i].py := py;
    dir := RandRangeF32(0.0, TAU);
    spd := RandRangeF32(30.0, spread);
    particles[i].vx := mCos(dir) * spd;
    particles[i].vy := mSin(dir) * spd;
    particles[i].max_life := RandRangeF32(0.4, 1.0);
    particles[i].life := particles[i].max_life;
    made := made + 1;
  end;
end;

procedure SpawnDebris(px, py: Single; n: Integer; spread, size_scale: Single);
var
  i, made: Integer;
  dir, spd: Single;
begin
  made := 0;
  for i := 0 to MAX_DEBRIS - 1 do
  begin
    if made >= n then break;
    if debris[i].active then continue;
    debris[i].active := true;
    debris[i].px := px;
    debris[i].py := py;
    dir := RandRangeF32(0.0, TAU);
    spd := RandRangeF32(20.0, spread);
    debris[i].vx := mCos(dir) * spd;
    debris[i].vy := mSin(dir) * spd;
    debris[i].angle := RandRangeF32(0.0, TAU);
    debris[i].spin := RandRangeF32(-6.0, 6.0);
    debris[i].len := RandRangeF32(3.0, 7.0) * size_scale;
    debris[i].max_life := RandRangeF32(0.5, 1.1);
    debris[i].life := debris[i].max_life;
    made := made + 1;
  end;
end;

procedure SpawnShockwave(px, py, max_radius: Single);
var
  i: Integer;
begin
  for i := 0 to MAX_SHOCKWAVES - 1 do
  begin
    if shockwaves[i].active then continue;
    shockwaves[i].active := true;
    shockwaves[i].px := px;
    shockwaves[i].py := py;
    shockwaves[i].radius := 4;
    shockwaves[i].max_radius := max_radius;
    shockwaves[i].max_life := 0.4;
    shockwaves[i].life := 0.4;
    exit;
  end;
end;

procedure TriggerShake(amount: Single);
begin
  if amount > shake_mag then shake_mag := amount;
end;

// ---------------------------------------------------------------------------
// Ship / hyperspace
// ---------------------------------------------------------------------------
procedure FireBullet;
var
  i: Integer;
  dirx, diry: Single;
begin
  for i := 0 to MAX_BULLETS - 1 do
  begin
    if bullets[i].active then continue;
    bullets[i].active := true;
    dirx := mCos(ship.angle);
    diry := mSin(ship.angle);
    bullets[i].px := ship.px + dirx * SHIP_RADIUS;
    bullets[i].py := ship.py + diry * SHIP_RADIUS;
    bullets[i].vx := ship.vx + dirx * BULLET_SPEED;
    bullets[i].vy := ship.vy + diry * BULLET_SPEED;
    bullets[i].life := BULLET_LIFE;
    ship.vx := ship.vx - dirx * (BULLET_SPEED * 0.05);
    ship.vy := ship.vy - diry * (BULLET_SPEED * 0.05);
    aPlaySound(SND_FIRE);
    exit;
  end;
end;


// ---------------------------------------------------------------------------
// Asteroids scoring / splitting
// ---------------------------------------------------------------------------
procedure SplitAsteroid(i: Integer);
begin
  if asteroids[i].size = 3 then
  begin
    score := score + 20;
    aPlaySound(SND_BANG_LARGE);
    TriggerShake(7.0);
  end
  else if asteroids[i].size = 2 then
  begin
    score := score + 50;
    aPlaySound(SND_BANG_MED);
    TriggerShake(4.0);
  end
  else begin
    score := score + 100;
    aPlaySound(SND_BANG_SMALL);
    TriggerShake(2.0);
  end;
  SpawnParticles(asteroids[i].px, asteroids[i].py, asteroids[i].size * 6 + 6, asteroids[i].radius * 4.0);
  SpawnDebris(asteroids[i].px, asteroids[i].py, asteroids[i].size * 2 + 2, asteroids[i].radius * 3.0, Single(asteroids[i].size));
  SpawnShockwave(asteroids[i].px, asteroids[i].py, asteroids[i].radius * 1.8);
  if asteroids[i].size > 1 then
  begin
    SpawnAsteroid(asteroids[i].px, asteroids[i].py, asteroids[i].size - 1);
    SpawnAsteroid(asteroids[i].px, asteroids[i].py, asteroids[i].size - 1);
  end;
  asteroids[i].active := false;
end;

procedure KillShip;
begin
  aPlaySound(SND_SHIP_DEATH);
  SpawnParticles(ship.px, ship.py, 28, 260.0);
  SpawnDebris(ship.px, ship.py, 10, 300.0, 1.4);
  SpawnShockwave(ship.px, ship.py, 70.0);
  TriggerShake(14.0);
  ship.alive := false;
  lives := lives - 1;
  if lives <= 0 then
  begin
    game_over := true;
    if score > best_score then
    begin
      best_score := score;
      aSetBest(score);
    end;
  end else begin
    ship.respawn := RESPAWN_DELAY;
  end;
end;

// ---------------------------------------------------------------------------
// Collisions
// ---------------------------------------------------------------------------
procedure ResolveAsteroidPair(i, j: Integer);
var
  ddx, ddy, d2, min_dist, dist, nx, ny, m1, m2, total, overlap, relx, rely, vn, imp: Single;
begin
  ddx := asteroids[i].px - asteroids[j].px;
  ddy := asteroids[i].py - asteroids[j].py;
  d2 := ddx * ddx + ddy * ddy;
  min_dist := asteroids[i].radius + asteroids[j].radius;
  if (d2 >= min_dist * min_dist) or (d2 < 0.0001) then exit;
  dist := Sqrt(d2);
  nx := ddx / dist;
  ny := ddy / dist;
  m1 := asteroids[i].radius * asteroids[i].radius;
  m2 := asteroids[j].radius * asteroids[j].radius;
  total := m1 + m2;
  overlap := min_dist - dist;
  asteroids[i].px := asteroids[i].px + nx * (overlap * (m2 / total));
  asteroids[i].py := asteroids[i].py + ny * (overlap * (m2 / total));
  asteroids[j].px := asteroids[j].px - nx * (overlap * (m1 / total));
  asteroids[j].py := asteroids[j].py - ny * (overlap * (m1 / total));
  relx := asteroids[i].vx - asteroids[j].vx;
  rely := asteroids[i].vy - asteroids[j].vy;
  vn := relx * nx + rely * ny;
  if vn >= 0 then exit;
  imp := (2.0 * vn) / total;
  asteroids[i].vx := asteroids[i].vx - nx * (imp * m2);
  asteroids[i].vy := asteroids[i].vy - ny * (imp * m2);
  asteroids[j].vx := asteroids[j].vx + nx * (imp * m1);
  asteroids[j].vy := asteroids[j].vy + ny * (imp * m1);
  if thud_cooldown <= 0 then
  begin
    aPlaySound(SND_THUD);
    thud_cooldown := 0.12;
  end;
end;

procedure HandleCollisions;
var
  i, j: Integer;
  rr: Single;
begin
  // bullets vs asteroids
  for i := 0 to MAX_BULLETS - 1 do
  begin
    if not bullets[i].active then continue;
    for j := 0 to MAX_ASTEROIDS - 1 do
    begin
      if not asteroids[j].active then continue;
      if Dist2(bullets[i].px, bullets[i].py, asteroids[j].px, asteroids[j].py) <= asteroids[j].radius * asteroids[j].radius then
      begin
        bullets[i].active := false;
        SplitAsteroid(j);
        break;
      end;
    end;
  end;
  // asteroids vs ship
  if ship.alive and (ship.invuln <= 0) then
  begin
    for j := 0 to MAX_ASTEROIDS - 1 do
    begin
      if not asteroids[j].active then continue;
      rr := asteroids[j].radius + SHIP_RADIUS;
      if Dist2(ship.px, ship.py, asteroids[j].px, asteroids[j].py) <= rr * rr then
      begin
        KillShip;
        break;
      end;
    end;
  end;
  // asteroids vs asteroids
  for i := 0 to MAX_ASTEROIDS - 1 do
  begin
    if not asteroids[i].active then continue;
    for j := i + 1 to MAX_ASTEROIDS - 1 do
    begin
      if not asteroids[j].active then continue;
      ResolveAsteroidPair(i, j);
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Per-frame updates
// ---------------------------------------------------------------------------
procedure WrapXY(var px, py: Single);
begin
  if px < 0 then px := px + CANVAS_W;
  if px >= CANVAS_W then px := px - CANVAS_W;
  if py < 0 then py := py + CANVAS_H;
  if py >= CANVAS_H then py := py - CANVAS_H;
end;


// ---------------------------------------------------------------------------
// Ship update + hyperspace
// ---------------------------------------------------------------------------
procedure HyperspaceJump;
begin
  SpawnParticles(ship.px, ship.py, 14, 220.0);
  aPlaySound(SND_HYPER);
  if RandF32 < 0.14 then
  begin
    KillShip;
    exit;
  end;
  ship.px := RandRangeF32(40.0, CANVAS_W - 40.0);
  ship.py := RandRangeF32(40.0, CANVAS_H - 40.0);
  ship.vx := ship.vx * 0.2;
  ship.vy := ship.vy * 0.2;
  if ship.invuln < 0.4 then ship.invuln := 0.4;
  SpawnParticles(ship.px, ship.py, 14, 220.0);
end;

procedure UpdateShip(dt: Single; just_hyper: Boolean);
var
  drag, spd, backx, backy: Single;
begin
  if ship.respawn > 0 then
  begin
    ship.respawn := ship.respawn - dt;
    if ship.respawn <= 0 then SpawnShip;
    exit;
  end;
  if not ship.alive then exit;
  if ship.invuln > 0 then ship.invuln := ship.invuln - dt;
  if ship.cooldown > 0 then ship.cooldown := ship.cooldown - dt;
  if hyper_cooldown > 0 then hyper_cooldown := hyper_cooldown - dt;

  if just_hyper and (hyper_cooldown <= 0) then
  begin
    HyperspaceJump;
    hyper_cooldown := 0.5;
  end;
  if not ship.alive then exit;   // hyperspace malfunction may have killed us

  if keys[KEY_LEFT] then ship.angle := ship.angle - SHIP_TURN * dt;
  if keys[KEY_RIGHT] then ship.angle := ship.angle + SHIP_TURN * dt;

  ship.thrust := keys[KEY_THRUST];
  if ship.thrust then
  begin
    ship.vx := ship.vx + mCos(ship.angle) * SHIP_THRUST * dt;
    ship.vy := ship.vy + mSin(ship.angle) * SHIP_THRUST * dt;
    thrust_particle_timer := thrust_particle_timer - dt;
    if thrust_particle_timer <= 0 then
    begin
      backx := ship.px - mCos(ship.angle) * SHIP_RADIUS;
      backy := ship.py - mSin(ship.angle) * SHIP_RADIUS;
      SpawnParticles(backx, backy, 2, 40.0);
      thrust_particle_timer := 0.03;
    end;
  end;

  drag := PowF32(SHIP_FRICTION, dt);
  ship.vx := ship.vx * drag;
  ship.vy := ship.vy * drag;

  spd := Sqrt(ship.vx * ship.vx + ship.vy * ship.vy);
  if spd > SHIP_MAX_SPEED then
  begin
    ship.vx := ship.vx * (SHIP_MAX_SPEED / spd);
    ship.vy := ship.vy * (SHIP_MAX_SPEED / spd);
  end;

  ship.px := ship.px + ship.vx * dt;
  ship.py := ship.py + ship.vy * dt;
  WrapXY(ship.px, ship.py);

  if keys[KEY_FIRE] and (ship.cooldown <= 0) then
  begin
    FireBullet;
    ship.cooldown := FIRE_COOLDOWN;
  end;
end;

// ---------------------------------------------------------------------------
// Particles / bullets / asteroids / wave / shake updates
// ---------------------------------------------------------------------------
procedure UpdateBullets(dt: Single);
var
  i: Integer;
begin
  for i := 0 to MAX_BULLETS - 1 do
  begin
    if not bullets[i].active then continue;
    bullets[i].px := bullets[i].px + bullets[i].vx * dt;
    bullets[i].py := bullets[i].py + bullets[i].vy * dt;
    WrapXY(bullets[i].px, bullets[i].py);
    bullets[i].life := bullets[i].life - dt;
    if bullets[i].life <= 0 then bullets[i].active := false;
  end;
end;

procedure UpdateAsteroids(dt: Single);
var
  i: Integer;
begin
  for i := 0 to MAX_ASTEROIDS - 1 do
  begin
    if not asteroids[i].active then continue;
    asteroids[i].px := asteroids[i].px + asteroids[i].vx * dt;
    asteroids[i].py := asteroids[i].py + asteroids[i].vy * dt;
    asteroids[i].angle := asteroids[i].angle + asteroids[i].spin * dt;
    WrapXY(asteroids[i].px, asteroids[i].py);
  end;
end;

procedure UpdateParticles(dt: Single);
var
  i: Integer;
  decay: Single;
begin
  decay := PowF32(0.2, dt);
  for i := 0 to MAX_PARTICLES - 1 do
  begin
    if not particles[i].active then continue;
    particles[i].px := particles[i].px + particles[i].vx * dt;
    particles[i].py := particles[i].py + particles[i].vy * dt;
    particles[i].vx := particles[i].vx * decay;
    particles[i].vy := particles[i].vy * decay;
    particles[i].life := particles[i].life - dt;
    if particles[i].life <= 0 then particles[i].active := false;
  end;
end;

procedure UpdateDebris(dt: Single);
var
  i: Integer;
  decay: Single;
begin
  decay := PowF32(0.25, dt);
  for i := 0 to MAX_DEBRIS - 1 do
  begin
    if not debris[i].active then continue;
    debris[i].px := debris[i].px + debris[i].vx * dt;
    debris[i].py := debris[i].py + debris[i].vy * dt;
    debris[i].vx := debris[i].vx * decay;
    debris[i].vy := debris[i].vy * decay;
    debris[i].angle := debris[i].angle + debris[i].spin * dt;
    debris[i].life := debris[i].life - dt;
    if debris[i].life <= 0 then debris[i].active := false;
  end;
end;

procedure UpdateShockwaves(dt: Single);
var
  i: Integer;
  tpos: Single;
begin
  for i := 0 to MAX_SHOCKWAVES - 1 do
  begin
    if not shockwaves[i].active then continue;
    shockwaves[i].life := shockwaves[i].life - dt;
    if shockwaves[i].life <= 0 then
    begin
      shockwaves[i].active := false;
      continue;
    end;
    tpos := 1 - shockwaves[i].life / shockwaves[i].max_life;
    shockwaves[i].radius := shockwaves[i].max_radius * tpos;
  end;
end;

procedure UpdateShake(dt: Single);
begin
  if shake_mag > 0.05 then
  begin
    shake_x := RandRangeF32(-shake_mag, shake_mag);
    shake_y := RandRangeF32(-shake_mag, shake_mag);
    shake_mag := shake_mag * PowF32(0.02, dt);
  end else begin
    shake_mag := 0;
    shake_x := 0;
    shake_y := 0;
  end;
end;

procedure UpdateThrustSound;
begin
  if (ship.alive and ship.thrust and not game_over) <> thrust_snd_on then
  begin
    thrust_snd_on := (ship.alive and ship.thrust and not game_over);
    if thrust_snd_on then aSetThrust(1) else aSetThrust(0);
  end;
end;

function CountAsteroids: Integer;
var
  i, n: Integer;
begin
  n := 0;
  for i := 0 to MAX_ASTEROIDS - 1 do
    if asteroids[i].active then n := n + 1;
  CountAsteroids := n;
end;

// ---------------------------------------------------------------------------
// Main per-frame update
// ---------------------------------------------------------------------------
function ConsumePressed(code: Integer): Boolean;
begin
  if (code < KEY_COUNT) and just_pressed[code] then
  begin
    just_pressed[code] := false;
    ConsumePressed := true;
  end else begin
    ConsumePressed := false;
  end;
end;

procedure UpdateGame(dt: Single);
var
  just_start, just_fire, just_pause, just_hyper: Boolean;
begin
  just_start := ConsumePressed(KEY_START);
  just_fire := ConsumePressed(KEY_FIRE);
  just_pause := ConsumePressed(KEY_PAUSE);
  just_hyper := ConsumePressed(KEY_HYPER);

  if intro then
  begin
    if just_start or just_fire then intro := false;
    exit;
  end;

  if (not game_over) and just_pause then paused := not paused;
  if (not game_over) and paused then
  begin
    if thrust_snd_on then
    begin
      thrust_snd_on := false;
      aSetThrust(0);
    end;
    exit;
  end;

  if thud_cooldown > 0 then thud_cooldown := thud_cooldown - dt;

  if game_over then
  begin
    if just_start then ResetGame;
    UpdateParticles(dt);
    UpdateDebris(dt);
    UpdateShockwaves(dt);
    UpdateShake(dt);
    UpdateThrustSound;
    exit;
  end;

  UpdateShip(dt, just_hyper);
  UpdateBullets(dt);
  UpdateAsteroids(dt);
  UpdateParticles(dt);
  UpdateDebris(dt);
  UpdateShockwaves(dt);
  UpdateShake(dt);
  HandleCollisions;
  UpdateThrustSound;

  if CountAsteroids = 0 then NextLevel;
end;


// ---------------------------------------------------------------------------
// Drawing (mirror draw.odin, batched into cmd)
// ---------------------------------------------------------------------------
procedure DrawStars;
var
  i: Integer;
  tw, a, sz: Single;
begin
  for i := 0 to STAR_COUNT - 1 do
  begin
    tw := 0.55 + 0.45 * mSin(anim_time * 2.0 + stars[i].twinkle);
    a := stars[i].brightness * tw;
    bSetFill(StrAddr('#ffffff'), 7);
    bSetGlobalAlpha(a);
    if stars[i].brightness > 0.7 then sz := 2 else sz := 1;
    bFillRect(stars[i].sx, stars[i].sy, sz, sz);
  end;
  bSetGlobalAlpha(1.0);
end;

procedure DrawParticles;
var
  i: Integer;
  a: Single;
begin
  bSetShadow(StrAddr('#ffce7a'), 6, 4.0);
  bSetFill(StrAddr('#ffce7a'), 7);
  for i := 0 to MAX_PARTICLES - 1 do
  begin
    if not particles[i].active then continue;
    a := particles[i].life / particles[i].max_life;
    bSetGlobalAlpha(a);
    bFillRect(particles[i].px - 1, particles[i].py - 1, 2, 2);
  end;
  bSetGlobalAlpha(1.0);
  bClearShadow;
end;

procedure DrawDebris;
var
  i: Integer;
  a, c, s, hx, hy: Single;
begin
  bSetStroke(StrAddr('#e8c79a'), 7);
  bSetLineWidth(1.4);
  for i := 0 to MAX_DEBRIS - 1 do
  begin
    if not debris[i].active then continue;
    a := debris[i].life / debris[i].max_life;
    bSetGlobalAlpha(a);
    c := mCos(debris[i].angle);
    s := mSin(debris[i].angle);
    hx := c * debris[i].len * 0.5;
    hy := s * debris[i].len * 0.5;
    bBeginPath;
    bMoveTo(debris[i].px - hx, debris[i].py - hy);
    bLineTo(debris[i].px + hx, debris[i].py + hy);
    bStroke;
  end;
  bSetGlobalAlpha(1.0);
end;

procedure DrawShockwaves;
var
  i: Integer;
  a: Single;
begin
  bSetStroke(StrAddr('#8fd8ff'), 7);
  for i := 0 to MAX_SHOCKWAVES - 1 do
  begin
    if not shockwaves[i].active then continue;
    a := shockwaves[i].life / shockwaves[i].max_life;
    bSetGlobalAlpha(a * 0.8);
    bSetLineWidth(2.0 + 3.0 * (1 - a));
    bBeginPath;
    bArc(shockwaves[i].px, shockwaves[i].py, shockwaves[i].radius, 0.0, TAU);
    bStroke;
  end;
  bSetGlobalAlpha(1.0);
end;

procedure DrawAsteroids;
var
  i, k: Integer;
  ang, r, x, y: Single;
begin
  bSetStroke(StrAddr('#c9d4e6'), 7);
  bSetLineWidth(1.6);
  for i := 0 to MAX_ASTEROIDS - 1 do
  begin
    if not asteroids[i].active then continue;
    bBeginPath;
    for k := 0 to SHAPE_N - 1 do
    begin
      ang := asteroids[i].angle + TAU * Single(k) / Single(SHAPE_N);
      r := asteroids[i].radius * asteroids[i].shape[k];
      x := asteroids[i].px + mCos(ang) * r;
      y := asteroids[i].py + mSin(ang) * r;
      if k = 0 then bMoveTo(x, y) else bLineTo(x, y);
    end;
    bClosePath;
    bStroke;
  end;
end;

procedure DrawBullets;
var
  i: Integer;
  tx, ty: Single;
begin
  bSetShadow(StrAddr('#ffffff'), 7, 6.0);
  bSetStroke(StrAddr('#ffffff'), 7);
  bSetLineWidth(2.2);
  bSetLineCap(StrAddr('round'), 5);
  for i := 0 to MAX_BULLETS - 1 do
  begin
    if not bullets[i].active then continue;
    tx := bullets[i].px - bullets[i].vx * 0.02;
    ty := bullets[i].py - bullets[i].vy * 0.02;
    bBeginPath;
    bMoveTo(tx, ty);
    bLineTo(bullets[i].px, bullets[i].py);
    bStroke;
  end;
  bClearShadow;
end;

procedure DrawShipGlyph(x, y: Single);
begin
  bBeginPath;
  bMoveTo(x, y - 10);
  bLineTo(x - 7, y + 8);
  bLineTo(x + 7, y + 8);
  bClosePath;
  bStroke;
end;

procedure DrawShip;
var
  c, s: Single;
  nx, ny, tlx, tly, trx, try_: Single;
  flx, fly, frx, fry, tpx, tpy: Single;
  blink: Boolean;
begin
  blink := false;
  if (ship.invuln > 0) and (not intro) and (not paused) then
    if (Integer(ship.invuln * 12.0) mod 2) = 0 then blink := true;
  if blink then exit;

  c := mCos(ship.angle);
  s := mSin(ship.angle);
  nx := ship.px + (16.0 * c);
  ny := ship.py + (16.0 * s);
  tlx := ship.px + (-10.0 * c - (-9.0) * s);
  tly := ship.py + (-10.0 * s + (-9.0) * c);
  trx := ship.px + (-10.0 * c - 9.0 * s);
  try_ := ship.py + (-10.0 * s + 9.0 * c);

  bSetStroke(StrAddr('#e8f0ff'), 7);
  bSetLineWidth(2.0);
  bBeginPath;
  bMoveTo(nx, ny);
  bLineTo(tlx, tly);
  bLineTo(trx, try_);
  bClosePath;
  bStroke;

  if ship.thrust and (not paused) and (not intro) then
  begin
    if (Integer(anim_time * 30.0) mod 2) = 0 then
    begin
      flx := ship.px + (-10.0 * c - (-5.0) * s);
      fly := ship.py + (-10.0 * s + (-5.0) * c);
      frx := ship.px + (-10.0 * c - 5.0 * s);
      fry := ship.py + (-10.0 * s + 5.0 * c);
      tpx := ship.px + (-20.0 * c);
      tpy := ship.py + (-20.0 * s);
      bSetStroke(StrAddr('#ff9a3c'), 7);
      bBeginPath;
      bMoveTo(flx, fly);
      bLineTo(tpx, tpy);
      bLineTo(frx, fry);
      bStroke;
    end;
  end;
end;

procedure DrawHUD;
var
  i: Integer;
  x: Single;
  n: Integer;
begin
  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('20px monospace'), 14);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
  n := HUDText(StrAddr('SCORE '), 6, score);
  bFillText(Integer(@text_buf), n, 16, 14);

  bSetTextAlign(StrAddr('right'), 5);
  n := HUDText(StrAddr('WAVE '), 5, level);
  bFillText(Integer(@text_buf), n, CANVAS_W - 16, 14);

  bSetStroke(StrAddr('#e8f0ff'), 7);
  bSetLineWidth(2.0);
  for i := 0 to lives - 1 do
  begin
    x := Single(CANVAS_W) / 2.0 - Single(lives) * 12.0 + Single(i) * 24.0;
    DrawShipGlyph(x, 26.0);
  end;
end;

procedure DrawOverlay(alpha: Single; title: PByte; tlen, ty: Integer;
                      sub: PByte; slen, sy: Integer);
begin
  bSetFill(StrAddr('rgba(3,5,10,0.72)'), 17);
  bSetGlobalAlpha(alpha);
  bFillRect(0, 0, CANVAS_W, CANVAS_H);
  bSetGlobalAlpha(1.0);

  bSetFill(StrAddr('#ff5a4c'), 7);
  bSetFont(StrAddr('bold 64px monospace'), 19);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('middle'), 6);
  bFillText(title, tlen, CANVAS_W div 2, ty);

  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('24px monospace'), 14);
  bFillText(sub, slen, CANVAS_W div 2, sy);
end;

procedure DrawGameOver;
var
  n: Integer;
begin
  DrawOverlay(1.0, StrAddr('GAME OVER'), 9, CANVAS_H div 2 - 40,
              StrAddr('FINAL SCORE '), 12, CANVAS_H div 2 + 16);
  bSetFill(StrAddr('#ffce7a'), 7);
  bSetFont(StrAddr('18px monospace'), 14);
  n := HUDText(StrAddr('BEST SCORE '), 11, best_score);
  bFillText(Integer(@text_buf), n, CANVAS_W div 2, CANVAS_H div 2 + 46);
  bSetFill(StrAddr('#9fb2d0'), 7);
  bFillText(StrAddr('PRESS ENTER TO PLAY AGAIN'), 25, CANVAS_W div 2, CANVAS_H div 2 + 78);
end;

procedure DrawIntro;
begin
  bSetFill(StrAddr('rgba(3,5,10,0.78)'), 17);
  bFillRect(0, 0, CANVAS_W, CANVAS_H);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('middle'), 6);
  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('bold 40px monospace'), 19);
  bFillText(StrAddr('PASCALOIDS'), 10, CANVAS_W div 2, CANVAS_H div 2 - 84);
  bSetFill(StrAddr('#ffce7a'), 7);
  bSetFont(StrAddr('18px monospace'), 14);
  bFillText(StrAddr('BUILT FOR DESKTOP - KEYBOARD REQUIRED'), 37, CANVAS_W div 2, CANVAS_H div 2 - 36);
  bSetFill(StrAddr('#9fb2d0'), 7);
  bSetFont(StrAddr('16px monospace'), 14);
  bFillText(StrAddr('ARROWS TURN  UP THRUST  SPACE FIRE  SHIFT HYPER'), 47, CANVAS_W div 2, CANVAS_H div 2);
  bFillText(StrAddr('P PAUSE  ENTER RESTART'), 22, CANVAS_W div 2, CANVAS_H div 2 + 26);
  bSetFill(StrAddr('#7fe0a0'), 7);
  bSetFont(StrAddr('bold 20px monospace'), 19);
  bFillText(StrAddr('PRESS ENTER OR SPACE TO START'), 29, CANVAS_W div 2, CANVAS_H div 2 + 68);
end;

procedure DrawPaused;
begin
  bSetFill(StrAddr('rgba(3,5,10,0.6)'), 16);
  bFillRect(0, 0, CANVAS_W, CANVAS_H);
  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('bold 40px monospace'), 19);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('middle'), 6);
  bFillText(StrAddr('PAUSED'), 6, CANVAS_W div 2, CANVAS_H div 2 - 10);
  bSetFill(StrAddr('#9fb2d0'), 7);
  bSetFont(StrAddr('18px monospace'), 14);
  bFillText(StrAddr('PRESS P TO RESUME'), 17, CANVAS_W div 2, CANVAS_H div 2 + 26);
end;

procedure DrawGame;
begin
  anim_time := anim_time + 1.0 / 60.0;
  BufReset;

  bSetFill(StrAddr('#05070d'), 7);
  bFillRect(0, 0, CANVAS_W, CANVAS_H);

  bSave;
  bTranslate(shake_x, shake_y);

  DrawStars;
  DrawShockwaves;
  DrawParticles;
  DrawDebris;
  DrawAsteroids;
  DrawBullets;
  if ship.alive then DrawShip;

  bRestore;

  DrawHUD;

  if intro then DrawIntro
  else if paused then DrawPaused
  else if game_over then DrawGameOver;

  bBatchFlush(ctx, Integer(@cmd), cmd_len);
end;

// ---------------------------------------------------------------------------
// Bridge: exports
// ---------------------------------------------------------------------------
procedure PascaloidsMain;
var
  app, canvas, doc: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  canvas := bCanvasCreate(app, CANVAS_W, CANVAS_H);
  ctx := bGetContext(canvas);
  InitGame;
  // Self-wired keyboard on `document` (batch_add_event_listener, like pong):
  // reads evt.key from the current event, so the game owns its own keys.
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
      fps_accum := fps_accum + Single(1.0 / dt);
      fps_frames := fps_frames + 1;
      if fps_frames >= 24 then
      begin
        aSetFps(fps_accum / Single(fps_frames));
        fps_accum := 0;
        fps_frames := 0;
      end;
      UpdateGame(Single(dt));
      DrawGame;
    end;
  end
  else if id = CB_KEYDOWN then
    HandleKey(1)
  else if id = CB_KEYUP then
    HandleKey(0);
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

procedure SetKey(code, down: Integer);
begin
  if code < KEY_COUNT then
  begin
    keys[code] := (down <> 0);
    if down <> 0 then just_pressed[code] := true;
  end;
end;

// Self-wired keyboard: map evt.key to the game's key slots.
// evt.key is a NAMED string ('Enter', 'ArrowLeft', ' '), not a keyCode, so
// named keys must be matched by their full string (like pong.pas), not by
// the first byte: 'ArrowLeft'[0] = 'A' (65) would collide with the 'A' key,
// and 'Enter'[0] = 'E' (69) would never match 13.
procedure HandleKey(down: Integer);
var
  n: Integer;
  c0: Byte;
begin
  n := bGetPropStr(last_event, 'key', Integer(@text_buf), 16);
  if n <= 0 then exit;
  c0 := text_buf[0];
  // Named keys are multi-byte ('Enter'=5, 'ArrowLeft'=9, ...); single-char
  // keys are exactly 1 byte. Dispatch on length FIRST so a named key never
  // falls through to the single-char branches (all arrows start with 'A').
  if n = 1 then
  begin
    // single-char keys: a/A, d/D, w/W, h/H, p/P, Space
    if (c0 = 97) or (c0 = 65) then
      SetKey(KEY_LEFT, down)
    else if (c0 = 100) or (c0 = 68) then
      SetKey(KEY_RIGHT, down)
    else if (c0 = 119) or (c0 = 87) then
      SetKey(KEY_THRUST, down)
    else if c0 = 32 then
      SetKey(KEY_FIRE, down)
    else if (c0 = 104) or (c0 = 72) then
      SetKey(KEY_HYPER, down)
    else if (c0 = 112) or (c0 = 80) then
      SetKey(KEY_PAUSE, down);
  end
  // named keys: match the full string (n = byte count from bGetPropStr)
  else if n >= 5 then
  begin
    // 'Enter' (5 bytes)
    if (text_buf[0] = 69) and (text_buf[1] = 110) and (text_buf[2] = 116) and
       (text_buf[3] = 101) and (text_buf[4] = 114) then
      SetKey(KEY_START, down)
    // 'ArrowLeft' (9 bytes)
    else if (n >= 9) and (text_buf[0] = 65) and (text_buf[1] = 114) and
       (text_buf[2] = 114) and (text_buf[3] = 111) and (text_buf[4] = 119) and
       (text_buf[5] = 76) and (text_buf[6] = 101) and (text_buf[7] = 102) and
       (text_buf[8] = 116) then
      SetKey(KEY_LEFT, down)
    // 'ArrowRight' (10 bytes)
    else if (n >= 10) and (text_buf[0] = 65) and (text_buf[1] = 114) and
       (text_buf[2] = 114) and (text_buf[3] = 111) and (text_buf[4] = 119) and
       (text_buf[5] = 82) and (text_buf[6] = 105) and (text_buf[7] = 103) and
       (text_buf[8] = 104) and (text_buf[9] = 116) then
      SetKey(KEY_RIGHT, down)
    // 'ArrowUp' (7 bytes)
    else if (n >= 7) and (text_buf[0] = 65) and (text_buf[1] = 114) and
       (text_buf[2] = 114) and (text_buf[3] = 111) and (text_buf[4] = 119) and
       (text_buf[5] = 85) and (text_buf[6] = 112) then
      SetKey(KEY_THRUST, down);
  end;
end;

exports
  PascaloidsMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
