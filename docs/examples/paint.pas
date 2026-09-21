// paint.pas — PAINT: a small paint program whose entire interface is built
// from the DOM, in Pascal.
//
// This example covers the *other* half of the pascaldom ABI. The games
// (sweep, classic_dots, …) own one canvas and drive an animation loop; this
// program builds a real page instead — a styled panel, a toolbar of buttons,
// colour swatches and a live status line — with web.CreateElement /
// web.AppendChild / web.SetClassName / web.SetStyle, styles it with an injected
// stylesheet (web.AddStyle, so hover and selection states stay in CSS where
// they belong), and wires every control BY NAME (web.On(...), the handler is a
// procedure). Nothing on the page comes from index.html except the #stage
// element it mounts into; the markup, the styling and the behaviour all
// originate here. `uses WEB` means this file declares no imports, picks no
// callback ids and owns no dispatcher — see the bridge section below.
//
// Painting is the retained-framebuffer approach the ABI is built around: an
// RGBA buffer the host blits with putImageData. A stroke stamps a disc along
// the segment between two pointer samples (spacing scales with the brush, so
// a thin brush leaves no gaps and a thick one does not stamp itself to death).
// Undo is a ring of three snapshots; the canvas repaints only when something
// changed, so an idle paint program costs nothing.
//
// Written against the host contract in docs/porting_odin_to_pascal.md.
// (Three entries this list used to carry are gone: `Break` inside an `if` and
//  indexing a by-value `string` param were compiler defects, now fixed — and
//  the StrAddr/StrLen rule stopped applying when this file moved to `uses WEB`,
//  because `web.EventKey` hands back a real Pascal string.)
//
// ABI: pascaldom — `uses WEB` makes the BODY of this library pascaldom_main,
// and the web unit owns pascaldom_invoke_callback / pascaldom_set_last_event
// and the dispatch table behind them (the same three exports sweep.pas has).

{$M 32M}
library paint;

uses
  WEB;

const
  CANVAS_W = 640;
  CANVAS_H = 480;
  PIXEL_COUNT = CANVAS_W * CANVAS_H * 4;

  // Undo ring: three full framebuffer snapshots. Each is ~1.2 MB, and the
  // static globals of this module (buffer + ring + scratch) must sit below the
  // heap, so three is what fits comfortably in the default 16 MiB memory — the
  // {$M 32M} above makes the headroom explicit rather than accidental.
  UNDO_SLOTS = 3;

  PAL_SLOTS = 10;
  SIZE_SLOTS = 4;

  TOOL_BRUSH = 0;
  TOOL_ERASER = 1;

  // No callback ids here: `web.On(...)` HANDS ONE BACK. The repeating button
  // groups keep those returned ids in swatch_cb / size_cb and match on the id
  // the handler receives, which is what the parameter is for — the program
  // never invents a number the unit also uses.

  // Brush radii, in canvas pixels. Buttons are labelled with these.
  // (Named SIZE_R* rather than anything shorter: identifiers are
  // case-insensitive, so a const `N` and a local `n` are the same name —
  // and a silent collision with a const is a constant where a value
  // was meant, which shows up only as invalid wasm.)
  SIZE_R0 = 2;
  SIZE_R1 = 4;
  SIZE_R2 = 9;
  SIZE_R3 = 18;

  // Single-character key codes. Named constants, because a one-character
  // string literal is a Char in this dialect and StrAddr/StrLen miscompile on
  // it — so key matching never spells one.
  CH_1 = 49;
  CH_4 = 52;
  CH_LBRACKET = 91;
  CH_RBRACKET = 93;

// ---------------------------------------------------------------------------
// The bridge: `uses WEB`, no declarations of its own
// ---------------------------------------------------------------------------
// The unit declares the whole pascaldom bridge and gives it a `TWeb` facade —
// elements, classes, styles, the injected stylesheet, the canvas, the generic
// method/property calls, events. Nothing here names an import: the module
// imports exactly the bridge entries the unit's live code reaches.

var
  // --- framebuffer and undo ring ---
  pixels: array[0..PIXEL_COUNT - 1] of Byte;
  undo_buf: array[0..UNDO_SLOTS * PIXEL_COUNT - 1] of Byte;
  undo_head: Integer = 0;            // next slot to write
  undo_count: Integer = 0;           // slots currently valid

  // --- DOM handles ---
  stage_h: Integer = 0;
  root_h: Integer = 0;
  status_h: Integer = 0;
  cv_h: Integer = 0;                 // = web.CanvasHandle, kept for the hot path
  ctx_h: Integer = 0;
  web: TWeb;
  swatch_h: array[0..PAL_SLOTS - 1] of Integer;
  size_h: array[0..SIZE_SLOTS - 1] of Integer;
  tool_h: array[0..1] of Integer;
  swatch_cb: array[0..PAL_SLOTS - 1] of Integer;
  size_cb: array[0..SIZE_SLOTS - 1] of Integer;

  // --- brush state ---
  tool: Integer = TOOL_BRUSH;
  brush: Integer = SIZE_R1;          // radius, canvas pixels
  size_idx: Integer = 1;
  pal_idx: Integer = 7;
  pal_r, pal_g, pal_b: array[0..PAL_SLOTS - 1] of Byte;
  pen_r, pen_g, pen_b: Byte;
  drawing: Boolean = false;
  last_x: Integer = 0;
  last_y: Integer = 0;
  ptr_x: Integer = 0;
  ptr_y: Integer = 0;
  stroke_len: Integer = 0;           // Chebyshev length of the last stroke

  // --- canvas box → client coordinates ---
  rect_left: Double = 0.0;
  rect_top: Double = 0.0;
  rect_scale_x: Double = 1.0;
  rect_scale_y: Double = 1.0;

  // --- text ---
  num_str: string;
  status_text: string;

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------
// There is no byte-compare and no float parser here any more. Both existed
// because a property read came back as RAW BYTES in a caller-owned buffer,
// which is exactly what the unit's getters take off your hands:
// web.GetPropertyF64 / GetPropertyInt parse with the compiler's own `Val` (and
// take the value's leading numeric run, docs/features.md §10.49), and a boolean
// reads as the string the DOM has always given for it — `= 'true'`.

// ---------------------------------------------------------------------------
// The framebuffer
// ---------------------------------------------------------------------------

procedure Render;
begin
  // MakeCanvas remembered the canvas, its context and its size; RenderCanvas
  // blits the framebuffer through them (it used to be a six-argument call with
  // three of the arguments being globals this file carried by hand).
  web.RenderCanvas(Integer(@pixels), PIXEL_COUNT);
end;

// Clipped single pixel. Bounds are checked here and nowhere else, so the brush
// and stroke code can be written as if the canvas were infinite.
procedure Plot(x, y: Integer);
var
  i: Integer;
begin
  if (x >= 0) and (x < CANVAS_W) and (y >= 0) and (y < CANVAS_H) then
  begin
    i := (y * CANVAS_W + x) * 4;
    pixels[i] := pen_r;
    pixels[i + 1] := pen_g;
    pixels[i + 2] := pen_b;
    pixels[i + 3] := 255;
  end;
end;

// A filled disc: the brush's footprint.
procedure Stamp(cx, cy: Integer);
var
  dx, dy, r2: Integer;
begin
  r2 := brush * brush;
  dy := -brush;
  while dy <= brush do
  begin
    dx := -brush;
    while dx <= brush do
    begin
      if dx * dx + dy * dy <= r2 then Plot(cx + dx, cy + dy);
      dx := dx + 1;
    end;
    dy := dy + 1;
  end;
end;

// Stamp along the segment (x0,y0)-(x1,y1). Spacing scales with the brush so a
// 2 px brush is continuous and an 18 px one stamps 10 px apart instead of
// repainting its whole footprint 300 times.
procedure Stroke(x0, y0, x1, y1: Integer);
var
  dx, dy, steps, step_px, d: Integer;
begin
  dx := x1 - x0;
  dy := y1 - y0;
  steps := Abs(dx);
  if Abs(dy) > steps then steps := Abs(dy);
  step_px := 1 + brush div 2;
  d := step_px;
  while d < steps do
  begin
    Stamp(x0 + (dx * d) div steps, y0 + (dy * d) div steps);
    d := d + step_px;
  end;
  Stamp(x1, y1);                     // the endpoint always lands exactly
end;

// ---------------------------------------------------------------------------
// Undo (a ring of whole-buffer snapshots) and clearing
// ---------------------------------------------------------------------------

procedure PushUndo;
begin
  Move(@pixels, @undo_buf[undo_head * PIXEL_COUNT], PIXEL_COUNT);
  undo_head := (undo_head + 1) mod UNDO_SLOTS;
  if undo_count < UNDO_SLOTS then undo_count := undo_count + 1;
end;

function PopUndo: Boolean;
begin
  if undo_count = 0 then
  begin
    PopUndo := false;
  end
  else
  begin
    undo_head := (undo_head + UNDO_SLOTS - 1) mod UNDO_SLOTS;
    undo_count := undo_count - 1;
    Move(@undo_buf[undo_head * PIXEL_COUNT], @pixels, PIXEL_COUNT);
    PopUndo := true;
  end;
end;

procedure UndoStroke;
begin
  if PopUndo then
  begin
    stroke_len := 0;
    Render;
    UpdateStatus;
  end;
end;

procedure ClearCanvas;
begin
  PushUndo;
  FillChar(@pixels, PIXEL_COUNT, 255);   // opaque white, every channel
  stroke_len := 0;
  Render;
  UpdateStatus;
end;

// ---------------------------------------------------------------------------
// State → DOM. The two directions the whole program is made of.
// ---------------------------------------------------------------------------

procedure SyncPen;
begin
  if tool = TOOL_ERASER then
  begin
    pen_r := 255; pen_g := 255; pen_b := 255;
  end
  else
  begin
    pen_r := pal_r[pal_idx];
    pen_g := pal_g[pal_idx];
    pen_b := pal_b[pal_idx];
  end;
end;

procedure UpdateStatus;
begin
  Str(brush, num_str);
  if tool = TOOL_ERASER then status_text := 'Eraser'
  else status_text := 'Brush';
  status_text := status_text + ' ' + num_str + ' px';
  if stroke_len > 0 then
  begin
    Str(stroke_len, num_str);
    status_text := status_text + '   ·   last stroke ' + num_str + ' px';
  end
  else
  begin
    status_text := status_text + '   ·   drag on the canvas to paint';
  end;
  web.SetInnerText(status_h, status_text);
end;

procedure SelectTool(t: Integer);
var
  i: Integer;
begin
  tool := t;
  SyncPen;
  for i := 0 to 1 do
  begin
    if i = t then web.ClassListAdd(tool_h[i], 'on')
    else web.ClassListRemove(tool_h[i], 'on');
  end;
  UpdateStatus;
end;

procedure SelectSwatch(i: Integer);
var
  k: Integer;
begin
  pal_idx := i;
  SyncPen;
  for k := 0 to PAL_SLOTS - 1 do
  begin
    if k = i then web.ClassListAdd(swatch_h[k], 'on')
    else web.ClassListRemove(swatch_h[k], 'on');
  end;
  UpdateStatus;
end;

procedure SelectSize(i: Integer);
var
  k: Integer;
begin
  if i < 0 then i := 0;
  if i > SIZE_SLOTS - 1 then i := SIZE_SLOTS - 1;
  size_idx := i;
  case i of
    0: brush := SIZE_R0;
    1: brush := SIZE_R1;
    2: brush := SIZE_R2;
    3: brush := SIZE_R3;
    else brush := SIZE_R1;
  end;
  for k := 0 to SIZE_SLOTS - 1 do
  begin
    if k = i then web.ClassListAdd(size_h[k], 'on')
    else web.ClassListRemove(size_h[k], 'on');
  end;
  UpdateStatus;
end;

// ---------------------------------------------------------------------------
// Pointer input
// ---------------------------------------------------------------------------

// The host's stylesheet stretches `#stage canvas` to the panel width, so the
// canvas is almost never displayed at 1:1 — every pointer sample is mapped
// back through the bounding rect. Refreshed on pointerdown and on resize
// rather than every frame: it is a forced layout, and the rect only moves when
// the layout does.
procedure RefreshCanvasRect;
var
  rect: Integer;
  dw, dh: Double;
begin
  if cv_h = 0 then exit;
  rect := web.CallMethodRet(cv_h, 'getBoundingClientRect');
  rect_left := web.GetPropertyF64(rect, 'left');
  rect_top := web.GetPropertyF64(rect, 'top');
  dw := web.GetPropertyF64(rect, 'width');
  dh := web.GetPropertyF64(rect, 'height');
  web.ReleaseHandle(rect);           // the bridge hands out a handle per call
  if dw > 0.5 then rect_scale_x := Double(CANVAS_W) / dw;
  if dh > 0.5 then rect_scale_y := Double(CANVAS_H) / dh;
end;

procedure ReadPointer;
var
  cx, cy: Integer;
begin
  // EventClientX/Y are the same two property reads with the parse folded in.
  cx := Trunc((web.EventClientX - rect_left) * rect_scale_x);
  cy := Trunc((web.EventClientY - rect_top) * rect_scale_y);
  if cx < 0 then cx := 0;
  if cx > CANVAS_W - 1 then cx := CANVAS_W - 1;
  if cy < 0 then cy := 0;
  if cy > CANVAS_H - 1 then cy := CANVAS_H - 1;
  ptr_x := cx;
  ptr_y := cy;
end;

procedure BeginStroke;
begin
  web.CallMethod0(web.LastEvent, 'preventDefault');   // no text selection drag
  RefreshCanvasRect;
  ReadPointer;
  PushUndo;
  drawing := true;
  stroke_len := 0;
  last_x := ptr_x;
  last_y := ptr_y;
  Stamp(ptr_x, ptr_y);
  Render;
end;

procedure ExtendStroke;
var
  ddx, ddy: Integer;
begin
  if not drawing then exit;
  ReadPointer;
  if (ptr_x = last_x) and (ptr_y = last_y) then exit;
  Stroke(last_x, last_y, ptr_x, ptr_y);
  ddx := Abs(ptr_x - last_x);
  ddy := Abs(ptr_y - last_y);
  if ddx > ddy then stroke_len := stroke_len + ddx
  else stroke_len := stroke_len + ddy;
  last_x := ptr_x;
  last_y := ptr_y;
  Render;
end;

procedure FinishStroke;
begin
  if drawing then
  begin
    drawing := false;
    UpdateStatus;
  end;
end;

// ---------------------------------------------------------------------------
// Keyboard
// ---------------------------------------------------------------------------

// Modifier state, read straight off the event. Named keys ('ArrowLeft') and
// single characters both arrive as `key`, so only 1-byte keys are shortcuts.
// Modifier state, read straight off the event PASSED IN rather than the
// `last_event` global: the bridge keeps one shared slot for "the current
// event", so a handler that acts before reading (and an action that could ever
// dispatch another event) would read the wrong one.
function EventFlagIsTrue(ev: Integer; key: string): Boolean;
begin
  // The DOM stringifies a boolean property, so this is a string compare — NOT
  // GetPropertyInt, which takes the leading numeric run and would read
  // 'true' as 0 (a held key would then repeat the shortcut it was meant to
  // suppress).
  EventFlagIsTrue := web.GetPropertyStr(ev, key) = 'true';
end;

procedure HandleKey;
var
  ev, k: Integer;
  key: String[255];
  uk: Char;
begin
  ev := web.LastEvent;                 // capture before anything can re-dispatch
  key := web.GetPropertyStr(ev, 'key');
  if Length(key) <> 1 then exit;
  k := Ord(key[1]);
  if EventFlagIsTrue(ev, 'ctrlKey') or EventFlagIsTrue(ev, 'metaKey') then exit;
  // A held key repeats keydown; acting on those would run the shortcut dozens
  // of times a second (holding 'u' would drain the whole undo ring, holding
  // '[' would run the brush to the end of its range). One press, one action.
  if EventFlagIsTrue(ev, 'repeat') then exit;
  uk := UpCase(Chr(k));
  if uk = 'B' then SelectTool(TOOL_BRUSH)
  else if uk = 'E' then SelectTool(TOOL_ERASER)
  else if uk = 'U' then UndoStroke
  else if uk = 'C' then ClearCanvas
  else if k = CH_LBRACKET then SelectSize(size_idx - 1)
  else if k = CH_RBRACKET then SelectSize(size_idx + 1)
  else if (k >= CH_1) and (k <= CH_4) then SelectSize(k - CH_1)
  else exit;
  web.CallMethod0(ev, 'preventDefault');
end;

// ---------------------------------------------------------------------------
// Event handlers — registered BY NAME (DOMPLAN.md D3)
// ---------------------------------------------------------------------------
// The WEB unit assigns the callback ids and owns the dispatch table, so this
// file owns neither: each handler below is a procedure, `web.On` hands back the
// id it assigned, and the two repeating button groups match on the id the
// handler RECEIVES (swatch_cb / size_cb) instead of on an id the program
// invented. Every handler captures web.LastEvent — the event the unit stored
// before it called us — rather than reading it again after acting.

procedure OnPointerDown(id: Integer);
begin BeginStroke; end;

procedure OnPointerMove(id: Integer);
begin ExtendStroke; end;

// pointerup, pointercancel and pointerleave all end a stroke.
procedure OnPointerUp(id: Integer);
begin FinishStroke; end;

procedure OnKeyDown(id: Integer);
begin HandleKey; end;

procedure OnResize(id: Integer);
begin RefreshCanvasRect; end;

procedure OnBrush(id: Integer);
begin SelectTool(TOOL_BRUSH); end;

procedure OnEraser(id: Integer);
begin SelectTool(TOOL_ERASER); end;

procedure OnClear(id: Integer);
begin ClearCanvas; end;

procedure OnUndo(id: Integer);
begin UndoStroke; end;

procedure OnSwatch(id: Integer);
var i: Integer;
begin
  for i := 0 to PAL_SLOTS - 1 do
    if swatch_cb[i] = id then SelectSwatch(i);
end;

procedure OnSize(id: Integer);
var i: Integer;
begin
  for i := 0 to SIZE_SLOTS - 1 do
    if size_cb[i] = id then SelectSize(i);
end;

// ---------------------------------------------------------------------------
// Building the interface
// ---------------------------------------------------------------------------

// The stylesheet, in three sheets — layout, buttons, swatches. Style is set
// inline only where it has to beat the host's `#stage` rules (the canvas);
// everything with a :hover or a selected state belongs here, in CSS.
//
// Each sheet is ONE string literal rather than a `+` chain, which reads better
// for a stylesheet and is the shape this file has always used. (The old
// reason — this compiler clamped a concatenated string to 255 bytes, TP7's
// String capacity, so a 1.2 KB stylesheet was silently truncated to its first
// rule — has not been true since docs/features.md §10.41: a `+` chain is
// unbounded now. Only a `String[n]` DESTINATION still truncates.)
procedure InjectStyles;
begin
  web.AddStyle(
    '.pp-root{display:flex;flex-direction:column;gap:10px;width:100%;max-width:664px;align-self:center;box-sizing:border-box;padding:12px;background:#0a0e17;border:1px solid #1b2436;border-radius:12px;color:#cdd7ea;font:13px/1.45 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}.pp-head{display:flex;align-items:baseline;justify-content:space-between;gap:12px}.pp-title{font-size:12px;font-weight:700;letter-spacing:.18em;color:#4ecdc4}.pp-status{font-size:12px;color:#8fa1c0;text-align:right;white-space:nowrap}.pp-row{display:flex;flex-wrap:wrap;align-items:center;gap:6px}.pp-sep{width:1px;height:20px;margin:0 5px;background:#1b2436}');
  web.AddStyle(
    '.pp-btn{font:inherit;padding:5px 11px;color:#cdd7ea;background:#131a28;border:1px solid #24304a;border-radius:7px;cursor:pointer}.pp-btn:hover{background:#1a2437;border-color:#38507e}.pp-btn:focus-visible{outline:2px solid #4ecdc4;outline-offset:1px}.pp-btn.on{background:#4ecdc4;border-color:#4ecdc4;color:#04121a;font-weight:700}');
  web.AddStyle(
    '.pp-sw{width:26px;height:26px;padding:0;box-sizing:border-box;border:2px solid #24304a;border-radius:50%;cursor:pointer;transition:transform .08s ease}.pp-sw:hover{transform:scale(1.14)}.pp-sw.on{border-color:#4ecdc4;box-shadow:0 0 0 2px rgba(78,205,196,.35)}');
end;

// Returns the handle; the CALLER registers its handler, because the handler is
// a procedure now rather than an integer.
function MakeButton(parent: Integer; caption: string; tip: string): Integer;
var
  b: Integer;
begin
  b := web.CreateElement('button');
  web.SetClassName(b, 'pp-btn');
  web.SetInnerText(b, caption);
  web.SetPropertyStr(b, 'type', 'button');     // never a form submit button
  web.SetPropertyStr(b, 'title', tip);
  web.AppendChild(parent, b);
  MakeButton := b;
end;

procedure AddSeparator(parent: Integer);
var
  sp: Integer;
begin
  sp := web.CreateElement('span');
  web.SetClassName(sp, 'pp-sep');
  web.AppendChild(parent, sp);
end;

// One swatch button plus its colour in both forms the program needs: the hex
// string is a CSS background, the three bytes are what Plot writes.
procedure AddSwatch(parent: Integer; idx: Integer; hex: string; r, g, b: Byte);
var
  sw: Integer;
begin
  sw := web.CreateElement('button');
  web.SetClassName(sw, 'pp-sw');
  web.SetStyle(sw, 'background', hex);
  web.SetPropertyStr(sw, 'type', 'button');
  web.SetPropertyStr(sw, 'title', hex);
  web.AppendChild(parent, sw);
  swatch_h[idx] := sw;
  pal_r[idx] := r;
  pal_g[idx] := g;
  pal_b[idx] := b;
end;

procedure BuildUI;
var
  head, title, row, pal, b, i: Integer;
begin
  InjectStyles;

  root_h := web.CreateElement('div');
  web.SetClassName(root_h, 'pp-root');
  web.AppendChild(stage_h, root_h);

  head := web.CreateElement('div');
  web.SetClassName(head, 'pp-head');
  web.AppendChild(root_h, head);
  title := web.CreateElement('span');
  web.SetClassName(title, 'pp-title');
  web.SetInnerText(title, 'PASCAL PAINT');
  web.AppendChild(head, title);
  status_h := web.CreateElement('span');
  web.SetClassName(status_h, 'pp-status');
  web.AppendChild(head, status_h);

  row := web.CreateElement('div');
  web.SetClassName(row, 'pp-row');
  web.AppendChild(root_h, row);
  tool_h[0] := MakeButton(row, 'Brush', 'Paint with the selected colour (B)');
  web.On(tool_h[0], 'click', OnBrush);
  tool_h[1] := MakeButton(row, 'Eraser', 'Paint with white (E)');
  web.On(tool_h[1], 'click', OnEraser);
  AddSeparator(row);
  size_h[0] := MakeButton(row, '2', 'Brush radius 2 px (1)');
  size_h[1] := MakeButton(row, '4', 'Brush radius 4 px (2)');
  size_h[2] := MakeButton(row, '9', 'Brush radius 9 px (3)');
  size_h[3] := MakeButton(row, '18', 'Brush radius 18 px (4)');
  for i := 0 to SIZE_SLOTS - 1 do
    size_cb[i] := web.On(size_h[i], 'click', OnSize);
  AddSeparator(row);
  b := MakeButton(row, 'Undo', 'Undo the last stroke (U)');
  web.On(b, 'click', OnUndo);
  b := MakeButton(row, 'Clear', 'Erase the whole canvas (C)');
  web.On(b, 'click', OnClear);

  pal := web.CreateElement('div');
  web.SetClassName(pal, 'pp-row');
  web.AppendChild(root_h, pal);
  AddSwatch(pal, 0, '#111318', 17, 19, 24);
  AddSwatch(pal, 1, '#64748b', 100, 116, 139);
  AddSwatch(pal, 2, '#ef4444', 239, 68, 68);
  AddSwatch(pal, 3, '#f97316', 249, 115, 22);
  AddSwatch(pal, 4, '#facc15', 250, 204, 21);
  AddSwatch(pal, 5, '#22c55e', 34, 197, 94);
  AddSwatch(pal, 6, '#14b8a6', 20, 184, 166);
  AddSwatch(pal, 7, '#3b82f6', 59, 130, 246);
  AddSwatch(pal, 8, '#8b5cf6', 139, 92, 246);
  AddSwatch(pal, 9, '#ffffff', 255, 255, 255);
  for i := 0 to PAL_SLOTS - 1 do
    swatch_cb[i] := web.On(swatch_h[i], 'click', OnSwatch);
end;

procedure BuildCanvas;
begin
  // One call replaces create + get-context + remembering all three.
  web.MakeCanvas(root_h, CANVAS_W, CANVAS_H);
  cv_h := web.CanvasHandle;          // kept in a local: Render runs per frame
  ctx_h := web.ContextHandle;
  // Inline, because the host's `#stage canvas` rule would otherwise stretch it
  // (id selectors outrank anything this stylesheet can say).
  web.SetStyle(cv_h, 'width', '100%');
  web.SetStyle(cv_h, 'max-width', '640px');
  web.SetStyle(cv_h, 'height', 'auto');
  web.SetStyle(cv_h, 'display', 'block');
  web.SetStyle(cv_h, 'margin', '0 auto');
  web.SetStyle(cv_h, 'background', '#ffffff');
  web.SetStyle(cv_h, 'border', '1px solid #24304a');
  web.SetStyle(cv_h, 'border-radius', '8px');
  web.SetStyle(cv_h, 'cursor', 'crosshair');
  web.SetStyle(cv_h, 'touch-action', 'none');
  web.SetStyle(cv_h, 'box-shadow', '0 6px 18px rgba(0,0,0,.45)');

  web.On(cv_h, 'pointerdown', OnPointerDown);
  web.On(cv_h, 'pointermove', OnPointerMove);
  web.On(cv_h, 'pointerup', OnPointerUp);
  web.On(cv_h, 'pointercancel', OnPointerUp);
  web.On(cv_h, 'pointerleave', OnPointerUp);

  web.On(web.Doc, 'keydown', OnKeyDown);
  web.On(web.WindowHandle, 'resize', OnResize);
end;

// ---------------------------------------------------------------------------
// The body IS pascaldom_main (the pascaldom ABI)
// ---------------------------------------------------------------------------
// No wrapper procedure, no `exports` clause, no dispatcher: the host calls the
// body once after instantiate, and the unit's dispatch table routes each event
// to the handler registered above.
begin
  web := TWeb.Create;                // wraps `document`
  // The mount point is the HOST's business and this source ships to more than
  // one: the IDE runs its examples under #stage, a standalone page often has
  // neither id, and handle 0 is the bridge's RESERVED event slot rather than
  // "no parent" (dom_canvas_create would throw on it). Ask, then fall back.
  stage_h := web.GetElementById('stage');
  if stage_h = 0 then stage_h := web.GetElementById('app');
  if stage_h = 0 then stage_h := web.Doc;

  BuildUI;
  BuildCanvas;

  FillChar(@pixels, PIXEL_COUNT, 255);
  RefreshCanvasRect;
  SelectSwatch(pal_idx);
  SelectSize(size_idx);
  SelectTool(tool);
  Render;
end.
