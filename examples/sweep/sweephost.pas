unit sweephost;

{$mode fpc}

// The host layer, migrated to `uses WEB` (DOMPLAN.md D1/D2/D3) on 2026-09-14.
//
// What this file used to be: 15 `external 'odindom_env'` declarations in
// sweepdefs.pas, four handle globals (`doc_h`/`cv_h`/`ctx_h`/`win_h`), a
// `last_event` global fed by an exported `odindom_set_last_event`, eight
// `CB_*` callback-id constants and a 60-line `case id of` dispatcher exported
// as `odindom_invoke_callback`.
//
// What it is now: the embedded `WEB` unit declares the same bridge under the
// same `dom_*` names (so call sites below are unchanged), owns the two callback
// entry points, assigns the ids, and keeps the dispatch table. The handles live
// on the `TWeb` instance (`Doc`, `Cv`, `Ctx`, the canvas size, the cached
// `defaultView`), and handlers are registered BY NAME:
//
//     web.On(web.Doc, 'click', OnClick);
//     web.OnTick(OnTick);
//
// The ids are therefore no longer this program's business — see `_test.js`,
// which reads them back out of `dom_add_event_listener` / the animation loop
// instead of assuming CB_* constants.

interface

uses
  sweepdefs,
  sweepgame,
  sweepscreen,
  sweepstore;

var
  web: TWeb;
  rect_left: Double = 0.0;
  rect_top: Double = 0.0;
  rect_scale_x: Double = 1.0;
  rect_scale_y: Double = 1.0;
  rect_settle: Integer = 30;


procedure RefreshCanvasRect;

procedure CanvasCoords;

procedure Tick;

procedure SweepMain;  // the program body calls it; becomes pascaldom_main

implementation


procedure RefreshCanvasRect;
var
  rect: Integer;
begin
  rect := web.CallMethodRet(web.CanvasHandle, 'getBoundingClientRect');
  rect_left := web.GetPropertyF64(rect, 'left');
  rect_top := web.GetPropertyF64(rect, 'top');
  rect_scale_x := Double(CANVAS_W) / web.GetPropertyF64(rect, 'width');
  rect_scale_y := Double(CANVAS_H) / web.GetPropertyF64(rect, 'height');
end;

procedure CanvasCoords;
var
  cx, cy: Double;
begin
  cx := web.GetPropertyF64(web.LastEvent, 'clientX');
  cy := web.GetPropertyF64(web.LastEvent, 'clientY');
  cw_x := Integer((cx - rect_left) * rect_scale_x);
  cw_y := Integer((cy - rect_top) * rect_scale_y);
end;

procedure Tick;
begin
  if rect_settle > 0 then
  begin
    rect_settle := rect_settle - 1;
    RefreshCanvasRect;
  end;
  GameUpdate;
  DrawFrame;
  web.RenderCanvas(Integer(@pixels), PIXEL_COUNT);
end;

// ---- handlers -------------------------------------------------------------
// Each takes the callback id the WEB unit assigned and ignores it: the id is
// the unit's bookkeeping, and the event itself arrives via `web.LastEvent`.

procedure OnClick(id: Integer);
begin
  CanvasCoords;
  HandleLeftClick(cw_x, cw_y);
end;

procedure OnContextMenu(id: Integer);
begin
  dom_call_method0(web.LastEvent, 'preventDefault');
  CanvasCoords;
  HandleRightClick(cw_x, cw_y);
end;

procedure OnMouseMove(id: Integer);
begin
  CanvasCoords;
  HandleMouseMove(cw_x, cw_y);
end;

procedure OnMouseDown(id: Integer);
var
  button: Integer;
begin
  CanvasCoords;
  button := web.GetPropertyInt(web.LastEvent, 'button');
  if button = 2 then button := MB_RIGHT else button := MB_LEFT;
  HandleMouseDown(cw_x, cw_y, button);
end;

procedure OnMouseUp(id: Integer);
begin
  CanvasCoords;
  HandleMouseUp(cw_x, cw_y);
end;

procedure OnKeyDown(id: Integer);
var
  n: Integer;
begin
  n := dom_get_property_str(web.LastEvent, 'key', Integer(@scratch), 80);
  HandleKeyDown(Integer(@scratch), n);
end;

procedure OnTickCb(id: Integer);
begin
  Tick;
end;

procedure OnResize(id: Integer);
begin
  RefreshCanvasRect;
end;

procedure SweepMain;
var
  app, ver: Integer;
begin
  web := TWeb.Create;                       // wraps `document`

  // The container depends on the host, and this source is shipped to TWO: the
  // game's own page mounts at #app, and the browser IDE runs its examples under
  // #stage (webpascal/examples/sweep.pas is a symlink to this file). A page with
  // neither gets the document — a canvas on <body> beats a nil parent, because
  // dom_canvas_create does `jsValues[parent].appendChild(canvas)` and handle 0
  // is the bridge's RESERVED event slot, so passing it throws.
  app := web.GetElementById('app');
  if app = 0 then app := web.GetElementById('stage');
  if app = 0 then app := web.Doc;
  web.MakeCanvas(app, CANVAS_W, CANVAS_H);  // creates it and remembers cv/ctx/size

  // game init
  rng_state := (Cardinal(web.NowMs) xor $5A5A5A5A) or 1;
  difficulty := LoadDifficulty;
  SyncLevel;
  LoadBestTimes;
  ZeroGameState;

  RefreshCanvasRect;

  ver := web.GetElementById('version');
  if ver <> 0 then web.SetInnerText(ver, '1.0.0');

  web.On(web.Doc, 'click', OnClick);
  web.On(web.Doc, 'contextmenu', OnContextMenu);
  web.On(web.Doc, 'mousemove', OnMouseMove);
  web.On(web.Doc, 'mousedown', OnMouseDown);
  web.On(web.Doc, 'mouseup', OnMouseUp);
  web.On(web.Doc, 'keydown', OnKeyDown);

  web.On(web.WindowHandle, 'resize', OnResize);
  web.On(web.WindowHandle, 'orientationchange', OnResize);

  web.OnTick(OnTickCb);
end;

begin
end.
