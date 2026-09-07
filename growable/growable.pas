// growable.pas — hold the mouse to spawn dots that drift up and fade out.
//
// Pascal has no growable-list builtin, so this performs swap-remove pattern
// with a fixed pool: a static array of particles plus a live count. Spawning
// appends a dot while the mouse is held; updating swap-removes the dead ones
// (the item swapped into the slot still needs visiting, so the index is not
// advanced on a remove — exactly the sparks game's pattern).

library growable;

const
  TAU = 6.283185307179586;

  W = 640;
  H = 440;
  MAX = 400;

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

  CMD_CAPACITY = 16384;

type
  TParticle = record
    x, y, vy, life: Single;
  end;

var
  ps: array[0..MAX - 1] of TParticle;
  count: Integer;

  mouseDown: Boolean;
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

// ---- Update ----
procedure UpdateGame(dt: Single);
var
  i: Integer;
  dead: Boolean;
begin
  // Spawn while the mouse is held (and there is still room).
  if mouseDown and (count < MAX) then
  begin
    ps[count].x := mouse_x;
    ps[count].y := mouse_y;
    ps[count].vy := RandRangeF32(-120.0, -60.0);
    ps[count].life := 1.0;
    count := count + 1;
  end;

  // Update, then swap-remove the dead ones. Don't advance i on a remove: the
  // item swapped into slot i still needs visiting (the sparks pattern).
  i := 0;
  while i < count do
  begin
    ps[i].y := ps[i].y + ps[i].vy * dt;
    ps[i].life := ps[i].life - dt * 0.6;
    dead := ps[i].life <= 0.0;
    if dead then
    begin
      count := count - 1;
      if i <> count then
      begin
        ps[i].x := ps[count].x;
        ps[i].y := ps[count].y;
        ps[i].vy := ps[count].vy;
        ps[i].life := ps[count].life;
      end;
    end
    else
      i := i + 1;
  end;
end;

// ---- Drawing ----
procedure DrawGame;
var
  i: Integer;
  r: Single;
begin
  BufReset;

  bSetFill(StrAddr('#05070d'), 7);
  bFillRect(0, 0, W, H);

  for i := 0 to count - 1 do
  begin
    bSetFill(StrAddr('#ffe66d'), 7);
    r := 2.0 + ps[i].life * 4.0;
    bBeginPath;
    bArc(ps[i].x, ps[i].y, r, 0.0, TAU);
    bFill;
  end;

  bSetFill(StrAddr('#7f8ba6'), 7);
  bSetFont(StrAddr('18px monospace'), 14);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
  bFillText(Integer(@text_buf), WriteInt(0, count), 16, 28);
  bSetFont(StrAddr('14px monospace'), 14);
  bFillText(StrAddr('hold the mouse to spawn'), StrLen('hold the mouse to spawn'), 16, 50);

  bBatchFlush(ctx, Integer(@cmd), cmd_len);
end;

// ---- Bridge: exports ----
procedure GrowableMain;
var
  app, canvas, i: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  canvas := bCanvasCreate(app, W, H);
  canvas_h := canvas;
  ctx := bGetContext(canvas);

  // seed the xorshift RNG from the clock (µs fraction, not whole ms: the ms value is
  // ~constant in a freshly booted host, giving near-identical patterns)
  rng_state := Cardinal((bNow - Trunc(bNow)) * 1000000.0) xor $9E3779B9;
  if rng_state = 0 then rng_state := 1;

  count := 0;
  mouseDown := false;
  mouse_x := 0.0;
  mouse_y := 0.0;

  RefreshCanvasRect;

  last_ms := bNow;

  // Track the pointer + mouse button (self-wired, like sweep's pascaldom ABI).
  bAddListener(app, 'mousemove', 1);
  bAddListener(app, 'mousedown', 2);
  bAddListener(app, 'mouseup', 3);

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
  else
  begin
    case id of
      1:
        begin
          n := bGetPropStr(last_event, 'clientX', Integer(@text_buf), 40);
          mouse_x := Single((ParseF64(Integer(@text_buf), n) - rect_left) * rect_scale_x);
          n := bGetPropStr(last_event, 'clientY', Integer(@text_buf), 40);
          mouse_y := Single((ParseF64(Integer(@text_buf), n) - rect_top) * rect_scale_y);
        end;
      2:
        begin
          // mousedown: also capture the position (a click without a preceding
          // mousemove would otherwise spawn at the stale (0,0) and be invisible).
          n := bGetPropStr(last_event, 'clientX', Integer(@text_buf), 40);
          mouse_x := Single((ParseF64(Integer(@text_buf), n) - rect_left) * rect_scale_x);
          n := bGetPropStr(last_event, 'clientY', Integer(@text_buf), 40);
          mouse_y := Single((ParseF64(Integer(@text_buf), n) - rect_top) * rect_scale_y);
          mouseDown := true;
        end;
      3: mouseDown := false;
      else begin end;
    end;
  end;
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

exports
  GrowableMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
