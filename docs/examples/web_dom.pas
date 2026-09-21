// web_dom.pas — the DOM, in Pascal, with the boilerplate gone.
//
// Compare this with pascaldom_probe.pas (51 lines to fill one canvas, with its
// imports hand-declared) or the raw-bridge programs the ABI docs used to lead
// with. What is NOT here is the point of the file:
//
//   - no `external` declarations for the pascaldom bridge — `uses WEB` brings
//     the whole 40-entry surface in, resolved from the compiler binary exactly
//     like `Crt` or `classes`, with no WEB.pas on disk;
//   - no `CB_*` callback-id constants and no `case id of` dispatcher — handlers
//     are registered BY NAME (`web.On`, `web.OnTick`) and the unit owns the
//     dispatch table;
//   - no `exports pascaldom_main` / `pascaldom_invoke_callback` /
//     `pascaldom_set_last_event` — `uses WEB` makes the program body the
//     pascaldom entry point and auto-exports the callback hooks when the
//     program defines them;
//   - no `cv_h` / `ctx_h` globals — the canvas and its context are `TWeb`
//     fields, and `MakeCanvas` / `RenderCanvas` carry the size.
//
// It reads a numeric property without hand-rolling a float parser
// (`GetPropertyF64`), reads pointer coordinates without the
// last-event/scratch-buffer dance (`EventClientX/Y`), and passes string
// EXPRESSIONS to the bridge, not just literals.
//
// THE RULES THIS FILE FOLLOWS (docs/porting_odin_to_pascal.md §2-3):
//   - Pascal folds case, so no global and function here share a name;
//   - everything else the guide once warned about is fixed: a handler may be
//     NESTED (a captured frame is retained — docs/features.md §10.36) and may
//     share a name with a `TWeb` method (§10.34 — that was never shadowing,
//     unit merging was dropping the method). This file keeps its handlers
//     top-level only because its state is globals; a handler that needs
//     captured state should live where that state is.

library web_dom;

uses WEB;

const
  W = 160;
  H = 100;
  PIXEL_COUNT = W * H * 4;
  BAND_STEP = 8;              // redraw the canvas every Nth frame

  STYLE_BASE = '.panel{font:14px sans-serif;padding:10px;color:#ddd;background:#222}';
  STYLE_TITLE = '.panel h1{font-size:16px;margin:0 0 8px;color:#8cf}';
  STYLE_CANVAS = '#stage canvas{border:1px solid #555;cursor:crosshair;image-rendering:pixelated}';
  STYLE_STATUS = '.status{font:12px monospace;color:#9c9;margin-top:8px}';

var
  web: TWeb;
  pixels: array[0..PIXEL_COUNT - 1] of Byte;
  canvasH: Integer;
  statusH: Integer;
  frames: Integer;
  clicks: Integer;
  tint: Integer;

// Paint a diagonal band that walks down the canvas as `tint` advances.
procedure FillPixels;
var
  i, x, y, band: Integer;
begin
  band := tint mod (H + 40) - 20;
  i := 0;
  for y := 0 to H - 1 do
  begin
    for x := 0 to W - 1 do
    begin
      pixels[i] := Byte(x * 255 div W);              // R: left to right
      pixels[i + 1] := Byte(y * 255 div H);          // G: top to bottom
      if (y > band) and (y < band + 12) then
        pixels[i + 2] := 255                         // the band itself
      else
        pixels[i + 2] := 48;
      pixels[i + 3] := 255;                          // opaque
      i := i + 4;
    end;
  end;
  web.RenderCanvas(Integer(@pixels), PIXEL_COUNT);
end;

procedure ShowStatus;
var
  text: String[255];
  n: String[16];
begin
  Str(clicks, n);
  text := 'clicks ' + n + '   frames ';
  Str(frames, n);
  text := text + n;
  web.SetInnerText(statusH, text);
end;

// A click marks the spot by tinting the band; the coordinates come from the
// event the host passed to pascaldom_set_last_event.
procedure HandleDown(id: Integer);
var
  cx, cy: Integer;
begin
  clicks := clicks + 1;
  cx := Trunc(web.EventClientX);
  cy := Trunc(web.EventClientY);
  tint := (cx + cy) mod 255;
  FillPixels;
  ShowStatus;
  web.StorageSetItem('web_dom.clicks', 'remembered');
end;

// Pointer motion reports its position without repainting: a numeric property
// read, which the bridge only exposes as a string.
procedure HandleMove(id: Integer);
begin
  frames := frames;                       // motion does not advance the clock
end;

// The animation loop: advance the band, repaint every Nth frame, and keep the
// status line honest.
procedure HandleTick(id: Integer);
begin
  frames := frames + 1;
  tint := tint + 1;
  if frames mod BAND_STEP = 0 then
  begin
    FillPixels;
    ShowStatus;
  end;
end;

var
  panel, title: Integer;
  seen: Integer;

begin
  web := TWeb.Create;
  // A string EXPRESSION, not a literal: the bridge marshals any string value
  // (the hand-written idiom this replaces needed StrAddr('lit') and literals
  // only).
  web.AddStyle(STYLE_BASE + STYLE_TITLE + STYLE_CANVAS + STYLE_STATUS);

  panel := web.CreateElement('div');
  web.SetClassName(panel, 'panel');
  title := web.CreateElement('h1');
  web.SetInnerText(title, 'web_dom — built entirely in Pascal');
  web.AppendChild(panel, title);
  web.AppendChild(web.GetElementById('stage'), panel);

  canvasH := web.MakeCanvas(panel, W, H);
  statusH := web.CreateElement('div');
  web.SetClassName(statusH, 'status');
  web.AppendChild(panel, statusH);

  // The host may hand the canvas a size of its own with a style, so ask for it
  // back rather than assuming: a numeric property, read as a string.
  seen := web.GetPropertyInt(canvasH, 'scrollWidth');
  if seen > 0 then
    web.SetInnerText(title, 'web_dom — ' + web.GetPropertyStr(canvasH, 'tagName'));

  // Handlers by name. No ids, no dispatcher, no exports clause.
  web.On(web.GetElementById('stage'), 'mousedown', HandleDown);
  web.On(canvasH, 'mousemove', HandleMove);
  web.OnTick(HandleTick);

  tint := 0;
  frames := 0;
  clicks := 0;
  FillPixels;
  ShowStatus;
  web.Log('web_dom: ' + web.GetPropertyStr(web.WindowHandle, 'name'));
end.
