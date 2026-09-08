// sparks.pas — a particle fountain whose live particle count rises and falls
// freely, ported to Pascal via wasmpascal. Batchiness ABI. Move the mouse to
// aim; the fountain always erupts from the bottom centre toward the pointer.
//
// Ported from muspel engine/games/sparks/main.mus. The Muspel original uses
// growable lists (list/append/pop/remove) to shuffle pooled particle structs
// between a `free` and a `live` list. Pascal has no growable-list builtin, so
// this port expresses the same fixed-pool-with-a-free-list pattern the Muspel
// comment describes: a static array of particles, a `liveCount`, and a free
// stack (indices of retired particles). Spawning pops an index off the free
// stack, reinitialises that particle in place, and appends it to the live
// region; retiring does the reverse. Nothing is allocated per frame.

library sparks;

const
  TAU = 6.283185307179586;

  W = 720;
  H = 560;
  GRAV = 520.0;
  MAX = 750;

  CB_TICK = 0;

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

  CMD_CAPACITY = 32768;

type
  TParticle = record
    x, y, vx, vy, life, hue: Single;
  end;

var
  // Fixed pool: particles[0..liveCount-1] are live; freeStack holds indices
  // of retired particles ready for reuse.
  particles: array[0..MAX - 1] of TParticle;
  freeStack: array[0..MAX - 1] of Integer;
  freeCount: Integer;
  liveCount: Integer;

  mouse_x: Single;
  mouse_y: Single;

  last_event: Integer = 0;

  last_ms: Double;

  rng_state: Cardinal;

  canvas_h: Integer = 0;
  rect_left: Double = 0.0;
  rect_top: Double = 0.0;
  rect_scale_x: Double = 1.0;
  rect_scale_y: Double = 1.0;

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
function  bGetContext(canvas: Integer): Integer; external 'batch_env' name 'batch_canvas_get_context';
procedure bStartLoop(cbId: Integer); external 'batch_env' name 'batch_start_animation_loop';
procedure bAddListener(elem: Integer; ev: string; cb: Integer); external 'batch_env' name 'batch_add_event_listener';
function  bGetPropStr(h: Integer; k: string; buf: Integer; maxlen: Integer): Integer;
          external 'batch_env' name 'batch_get_property_str';
function  bCallMethodRet(h: Integer; nm: string): Integer; external 'batch_env' name 'batch_call_method_ret';

function  mSin(x: Double): Double; external 'odin_env' name 'sin';
function  mCos(x: Double): Double; external 'odin_env' name 'cos';
function  mAtan2(y, x: Double): Double; external 'odin_env' name 'atan2';

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

// ---- Batch API ----
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

// ---- String helpers for HUD ----
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

// Read the canvas's bounding rect and compute the viewport→canvas scale so
// clientX/clientY map to canvas pixels (the canvas is scaled in the stage).
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

// ---- Particle pool ----
// The live region is dense: particles[0..liveCount-1]. The free stack holds
// indices of retired particles (always >= liveCount). Spawning pops a free
// index, reinitialises that particle in place, then moves it into the live
// region (copying into the boundary slot if needed). Retiring swap-removes
// the particle and pushes its old slot back onto the free stack. Nothing is
// allocated per frame.
procedure SpawnOne(tx, ty: Single);
var
  idx, slot: Integer;
  base_x, base_y: Single;
  ang, spd: Single;
begin
  if freeCount <= 0 then Exit;
  if liveCount >= MAX then Exit;
  base_x := W / 2.0;
  base_y := H - 140.0;
  ang := mAtan2(Double(ty - base_y), Double(tx - base_x)) + RandRangeF32(-0.35, 0.35);
  spd := RandRangeF32(240.0, 470.0);

  idx := freeStack[freeCount - 1];
  freeCount := freeCount - 1;

  particles[idx].x := base_x;
  particles[idx].y := base_y;
  particles[idx].vx := Single(mCos(ang)) * spd;
  particles[idx].vy := Single(mSin(ang)) * spd;
  particles[idx].life := RandRangeF32(0.5, 1.1);
  particles[idx].hue := RandF32;

  // move the fresh particle into the live region (slot = liveCount).
  slot := liveCount;
  liveCount := liveCount + 1;
  if slot <> idx then
  begin
    particles[slot].x := particles[idx].x;
    particles[slot].y := particles[idx].y;
    particles[slot].vx := particles[idx].vx;
    particles[slot].vy := particles[idx].vy;
    particles[slot].life := particles[idx].life;
    particles[slot].hue := particles[idx].hue;
  end;
end;

procedure Retire(i: Integer);
var
  last: Integer;
begin
  // swap-remove: move the last live particle into slot i, shrink the live
  // region, and push the freed slot back onto the free stack.
  last := liveCount - 1;
  if i <> last then
  begin
    particles[i].x := particles[last].x;
    particles[i].y := particles[last].y;
    particles[i].vx := particles[last].vx;
    particles[i].vy := particles[last].vy;
    particles[i].life := particles[last].life;
    particles[i].hue := particles[last].hue;
  end;
  liveCount := liveCount - 1;
  if freeCount < MAX then
  begin
    freeStack[freeCount] := last;
    freeCount := freeCount + 1;
  end;
end;

// ---- Update ----
procedure UpdateGame(dt: Single);
var
  tx, ty: Single;
  s, i: Integer;
  dead: Boolean;
begin
  tx := mouse_x;
  ty := mouse_y;
  if (tx <= 0.0) and (ty <= 0.0) then
  begin
    tx := W / 2.0;
    ty := 80.0;
  end;

  for s := 0 to 4 do
    SpawnOne(tx, ty);

  // Integrate every live particle; retire the dead ones. Iterate by index
  // because we swap-remove as we go (do not advance i on a retire).
  i := 0;
  while i < liveCount do
  begin
    particles[i].vy := particles[i].vy + GRAV * dt;
    particles[i].x := particles[i].x + particles[i].vx * dt;
    particles[i].y := particles[i].y + particles[i].vy * dt;
    particles[i].life := particles[i].life - dt;

    dead := (particles[i].life <= 0.0) or (particles[i].y > H + 20.0);
    if dead then
      Retire(i)
    else
      i := i + 1;
  end;
end;

// ---- Drawing ----
procedure DrawGame;
var
  i, idx: Integer;
  r: Single;
begin
  BufReset;

  bSetFill(StrAddr('#05070d'), 7);
  bFillRect(0, 0, W, H);

  for i := 0 to liveCount - 1 do
  begin
    idx := Trunc(particles[i].hue * 7.0) mod 7;
    case idx of
      0: bSetFill(StrAddr('#ff6b6b'), 7);
      1: bSetFill(StrAddr('#ffa46b'), 7);
      2: bSetFill(StrAddr('#ffe66d'), 7);
      3: bSetFill(StrAddr('#7be495'), 7);
      4: bSetFill(StrAddr('#4ecdc4'), 7);
      5: bSetFill(StrAddr('#6b9bff'), 7);
      else bSetFill(StrAddr('#c39bff'), 7);
    end;
    r := 2.0 + particles[i].life * 2.2;
    bBeginPath;
    bArc(particles[i].x, particles[i].y, r, 0.0, TAU);
    bFill;
  end;

  bSetFill(StrAddr('#7f8ba6'), 7);
  bSetFont(StrAddr('22px monospace'), 14);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
  bFillText(Integer(@text_buf), WriteInt(0, liveCount), 16, 28);
  bSetFont(StrAddr('16px monospace'), 14);
  bFillText(StrAddr('live particles (move the mouse to aim)'), StrLen('live particles (move the mouse to aim)'), 54, 28);

  bBatchFlush(ctx, Integer(@cmd), cmd_len);
end;

// ---- Bridge: exports ----
procedure SparksMain;
var
  app, canvas, i: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  canvas := bCanvasCreate(app, W, H);
  canvas_h := canvas;
  ctx := bGetContext(canvas);

  // seed the xorshift RNG from the clock (µs fraction, not whole ms: the ms value is ~constant in a freshly booted host, giving near-identical fountains)
  rng_state := Cardinal((bNow - Trunc(bNow)) * 1000000.0) xor $9E3779B9;
  if rng_state = 0 then rng_state := 1;

  // initialise the pool: every particle is free.
  liveCount := 0;
  freeCount := MAX;
  for i := 0 to MAX - 1 do
    freeStack[i] := i;

  mouse_x := 0.0;
  mouse_y := 0.0;

  RefreshCanvasRect;

  last_ms := bNow;

  // Track the pointer via mousemove (self-wired, like sweep's pascaldom ABI).
  bAddListener(app, 'mousemove', 1);

  bStartLoop(CB_TICK);
end;

procedure InvokeCallback(id: Integer);
var
  n: Integer;
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
  else if id = 1 then
  begin
    // mousemove: read clientX/clientY from the current event and convert to
    // canvas coordinates (the canvas is scaled/offset inside the stage).
    n := bGetPropStr(last_event, 'clientX', Integer(@text_buf), 40);
    mouse_x := Single((ParseF64(Integer(@text_buf), n) - rect_left) * rect_scale_x);
    n := bGetPropStr(last_event, 'clientY', Integer(@text_buf), 40);
    mouse_y := Single((ParseF64(Integer(@text_buf), n) - rect_top) * rect_scale_y);
  end;
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

exports
  SparksMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
