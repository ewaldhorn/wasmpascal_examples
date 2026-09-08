// transforms.pas — a showcase for the Canvas2D transform stack, ported to
// Pascal via wasmpascal. Batchiness ABI. Every shape is drawn in its own
// *local* coordinate space, centred on the origin, and then positioned, spun
// and pulsed purely with transforms (save / translate / rotate / scale in the
// batch wire format). Not one vertex is rotated by hand.
//
// Three groups run at once, each nesting transforms differently:
//   1. a central gear: one polygon, spun in place.
//   2. an orbit ring: squares carried around the centre by a
//      rotate-then-translate-out chain, each also spinning about its own
//      centre, so two rotations compose.
//   3. a pulse row: triangles along the bottom, each scaled by a sine wave.
//
// Ported from muspel engine/games/shapes/main.mus. The polygon point arrays
// are built exactly once in the start section and reused every frame (no
// per-frame allocation — the same rule sparks and pascaloids follow).

library transforms;

const
  TAU = 6.283185307179586;

  W = 800;
  H = 800;

  GEAR_OUTER_N = 8;
  GEAR_INNER_N = 8;
  TRI_N = 3;
  POLY_TOTAL = (GEAR_OUTER_N + GEAR_INNER_N + TRI_N) * 2;
  POLY_GEAR_OUTER = 0;
  POLY_GEAR_INNER = GEAR_OUTER_N * 2;
  POLY_TRI = (GEAR_OUTER_N + GEAR_INNER_N) * 2;

  CB_TICK = 0;
  CB_KEYDOWN = 2;
  CB_KEYUP = 3;

  KEY_SPACE = 3;

  // batch opcodes (wire format from batch.odin / batchiness.js)
  OP_SET_FILL = $01;
  OP_SET_STROKE = $02;
  OP_SET_LINE_WIDTH = $03;
  OP_SET_FONT = $04;
  OP_SET_TEXT_ALIGN = $05;
  OP_SET_TEXT_BASELINE = $06;
  OP_FILL_RECT = $10;
  OP_BEGIN_PATH = $20;
  OP_MOVE_TO = $21;
  OP_LINE_TO = $22;
  OP_CLOSE_PATH = $23;
  OP_FILL = $28;
  OP_STROKE = $29;
  OP_FILL_TEXT = $30;
  OP_SAVE = $40;
  OP_RESTORE = $41;
  OP_TRANSLATE = $42;
  OP_SCALE = $43;
  OP_ROTATE = $44;

  CMD_CAPACITY = 32768;

var
  t: Single;

  paused: Boolean;
  px: Single;
  py: Single;

  // Flat [x0, y0, x1, y1, ...] polygon data, built once in the start section.
  // Three polygons share this buffer at fixed offsets (POLY_*).
  poly: array[0..POLY_TOTAL - 1] of Single;

  keys: array[0..3] of Boolean;
  just_pressed: array[0..3] of Boolean;

  last_event: Integer = 0;

  last_ms: Double;

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
function  bGetGlobal(nm: string): Integer; external 'batch_env' name 'batch_get_global';
function  bGetContext(canvas: Integer): Integer; external 'batch_env' name 'batch_canvas_get_context';
procedure bStartLoop(cbId: Integer); external 'batch_env' name 'batch_start_animation_loop';
procedure bAddListener(elem: Integer; ev: string; cb: Integer); external 'batch_env' name 'batch_add_event_listener';
function  bGetPropStr(h: Integer; k: string; buf: Integer; maxlen: Integer): Integer;
          external 'batch_env' name 'batch_get_property_str';
function  bCallMethodRet(h: Integer; nm: string): Integer; external 'batch_env' name 'batch_call_method_ret';

function  mSin(x: Double): Double; external 'odin_env' name 'sin';
function  mCos(x: Double): Double; external 'odin_env' name 'cos';
function  mSqrt(x: Double): Double; external 'odin_env' name 'sqrt';

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

procedure bStroke;
begin
  PutU8(OP_STROKE);
end;

procedure bMoveTo(x, y: Single);
begin
  PutU8(OP_MOVE_TO); PutF32(x); PutF32(y);
end;

procedure bLineTo(x, y: Single);
begin
  PutU8(OP_LINE_TO); PutF32(x); PutF32(y);
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

procedure bRotate(a: Single);
begin
  PutU8(OP_ROTATE); PutF32(a);
end;

procedure bScale(s: Single);
begin
  PutU8(OP_SCALE); PutF32(s); PutF32(s);
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

// ---- Geometry ----
// Build a regular `sides`-gon of radius `r` centred on the origin into the
// shared poly buffer at offset `base`. Called once in the start section.
procedure BuildPoly(base, sides: Integer; r: Single);
var
  i: Integer;
  a: Single;
begin
  for i := 0 to sides - 1 do
  begin
    a := TAU / Single(sides) * Single(i);
    poly[base + i * 2] := Single(mCos(a)) * r;
    poly[base + i * 2 + 1] := Single(mSin(a)) * r;
  end;
end;

// Set the fill colour from the demo palette (index 0..7).
procedure SetPaletteColor(i: Integer);
begin
  case i of
    0: bSetFill(StrAddr('#ff6b6b'), 7);
    1: bSetFill(StrAddr('#4ecdc4'), 7);
    2: bSetFill(StrAddr('#ffe66d'), 7);
    3: bSetFill(StrAddr('#95e1d3'), 7);
    4: bSetFill(StrAddr('#a29bfe'), 7);
    5: bSetFill(StrAddr('#f7a072'), 7);
    6: bSetFill(StrAddr('#70a1d7'), 7);
    7: bSetFill(StrAddr('#ff9ff3'), 7);
    else bSetFill(StrAddr('#ffffff'), 7);
  end;
end;

// Draw a polygon (n vertices at offset `base` in the poly buffer), positioned
// by translate and spun by rotate. Allocates nothing per frame.
procedure DrawPoly(base, n: Integer; cx, cy, spin: Single; color: Integer);
var
  i: Integer;
begin
  bSave;
  bTranslate(cx, cy);
  bRotate(spin);
  SetPaletteColor(color);
  bBeginPath;
  bMoveTo(poly[base], poly[base + 1]);
  for i := 1 to n - 1 do
    bLineTo(poly[base + i * 2], poly[base + i * 2 + 1]);
  bClosePath;
  bFill;
  bRestore;
end;

// ---- Drawing ----
procedure DrawGear(cx, cy: Single; spin: Single);
begin
  // outer polygon, then the inner polygon punched out in the background colour.
  DrawPoly(POLY_GEAR_OUTER, GEAR_OUTER_N, cx, cy, spin, 1);
  DrawPoly(POLY_GEAR_INNER, GEAR_INNER_N, cx, cy, spin, 0);
end;

procedure DrawOrbitRing(cx, cy: Single);
var
  i: Integer;
  angle: Single;
begin
  for i := 0 to 7 do
  begin
    angle := TAU / 8.0 * Single(i) + t * 0.4;
    bSave;
    bTranslate(cx, cy);
    bRotate(angle);
    bTranslate(220.0, 0.0);
    bRotate(t * 2.0);
    SetPaletteColor(i);
    bFillRect(-34.0, -34.0, 68.0, 68.0);
    bRestore;
  end;
end;

procedure DrawPulseRow;
var
  i: Integer;
  x: Single;
  pulse: Single;
begin
  for i := 0 to 8 do
  begin
    x := 80.0 + Single(i) * 80.0;
    pulse := 1.0 + Single(mSin(t * 3.0 + Single(i) * 0.6)) * 0.5;
    bSave;
    bTranslate(x, H - 90.0);
    bRotate(0.0 - TAU / 4.0);
    bScale(pulse);
    SetPaletteColor(i);
    bBeginPath;
    bMoveTo(poly[POLY_TRI], poly[POLY_TRI + 1]);
    bLineTo(poly[POLY_TRI + 2], poly[POLY_TRI + 3]);
    bLineTo(poly[POLY_TRI + 4], poly[POLY_TRI + 5]);
    bClosePath;
    bFill;
    bRestore;
  end;
end;

procedure DrawGame;
var
  cx, cy: Single;
  n, dist: Integer;
begin
  BufReset;

  bSetFill(StrAddr('#05070d'), 7);
  bFillRect(0, 0, W, H);

  cx := W / 2.0;
  cy := H / 2.0;

  // 1. central gear, spinning slowly.
  DrawGear(cx, cy, t * 0.6);

  // 2. orbit ring of eight squares.
  DrawOrbitRing(cx, cy);

  // 3. pulse row of triangles along the bottom.
  DrawPulseRow;

  // Pointer crosshair.
  bSetStroke(StrAddr('#7a8699'), 7);
  bSetLineWidth(1.0);
  bBeginPath;
  bMoveTo(px - 10.0, py);
  bLineTo(px + 10.0, py);
  bMoveTo(px, py - 10.0);
  bLineTo(px, py + 10.0);
  bStroke;

  // Pointer's distance from the centre, formatted as HUD text.
  dist := Trunc(mSqrt(Double((px - cx) * (px - cx) + (py - cy) * (py - cy))));
  bSetFill(StrAddr('#7a8699'), 7);
  bSetFont(StrAddr('16px monospace'), 14);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
  n := WriteInt(0, dist);
  bFillText(Integer(@text_buf), n, Trunc(px) + 14, Trunc(py) - 8);

  bSetFill(StrAddr('#7a8699'), 7);
  bSetFont(StrAddr('20px monospace'), 14);
  bFillText(StrAddr('transform stack: translate / rotate / scale'), StrLen('transform stack: translate / rotate / scale'), 20, 40);
  if paused then
  begin
    bSetFill(StrAddr('#ffe66d'), 7);
    bFillText(StrAddr('paused (Space) - move the pointer'), StrLen('paused (Space) - move the pointer'), 20, 66);
  end
  else
    bFillText(StrAddr('Space to pause, move the pointer'), StrLen('Space to pause, move the pointer'), 20, 66);

  bBatchFlush(ctx, Integer(@cmd), cmd_len);
end;

// ---- Bridge: exports ----
procedure TransformsMain;
var
  app, canvas, doc: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  canvas := bCanvasCreate(app, W, H);
  canvas_h := canvas;
  ctx := bGetContext(canvas);

  // Build the polygon geometry once.
  BuildPoly(POLY_GEAR_OUTER, GEAR_OUTER_N, 120.0);
  BuildPoly(POLY_GEAR_INNER, GEAR_INNER_N, 70.0);
  BuildPoly(POLY_TRI, TRI_N, 30.0);

  t := 0.0;
  paused := false;
  px := 400.0;
  py := 400.0;

  RefreshCanvasRect;

  // Track the pointer via mousemove (self-wired, like sweep's pascaldom ABI).
  bAddListener(app, 'mousemove', 1);

  // Self-wired keyboard on `document` (the batchiness games' key pattern).
  doc := bGetGlobal('document');
  bAddListener(doc, 'keydown', CB_KEYDOWN);
  bAddListener(doc, 'keyup', CB_KEYUP);

  last_ms := bNow;
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
      if not paused then t := t + Single(dt);
      DrawGame;
    end;
  end
  else if id = 1 then
  begin
    // mousemove: read clientX/clientY from the current event and convert to
    // canvas coordinates (the canvas is scaled/offset inside the stage).
    n := bGetPropStr(last_event, 'clientX', Integer(@text_buf), 40);
    px := Single((ParseF64(Integer(@text_buf), n) - rect_left) * rect_scale_x);
    n := bGetPropStr(last_event, 'clientY', Integer(@text_buf), 40);
    py := Single((ParseF64(Integer(@text_buf), n) - rect_top) * rect_scale_y);
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

// Self-wired keyboard (batch_add_event_listener on `document`, like pong):
// reads evt.key from the current event and toggles pause on Space.
procedure HandleKey(down: Integer);
var
  n: Integer;
  c0: Byte;
begin
  n := bGetPropStr(last_event, 'key', Integer(@text_buf), 16);
  if n > 0 then
  begin
    c0 := text_buf[0];
    if c0 = 32 then // ' '
    begin
      if (down <> 0) and (not just_pressed[KEY_SPACE]) then
      begin
        just_pressed[KEY_SPACE] := true;
        paused := not paused;
      end;
      if down = 0 then just_pressed[KEY_SPACE] := false;
    end;
  end;
end;

exports
  TransformsMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
