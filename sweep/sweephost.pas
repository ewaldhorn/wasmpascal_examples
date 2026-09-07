unit sweephost;

interface

uses
  sweepdefs,
  sweepgame,
  sweepscreen,
  sweepstore;

var
  cv_h: Integer = 0;
  ctx_h: Integer = 0;
  doc_h: Integer = 0;
  win_h: Integer = 0;
  last_event: Integer = 0;
  rect_left: Double = 0.0;
  rect_top: Double = 0.0;
  rect_scale_x: Double = 1.0;
  rect_scale_y: Double = 1.0;
  rect_settle: Integer = 30;


procedure RefreshCanvasRect;

procedure CanvasCoords;

procedure Tick;

procedure SweepMain;  // exported as pascaldom_main

procedure SetLastEvent(h: Integer);  // exported as pascaldom_set_last_event

procedure InvokeCallback(id: Integer);  // exported as pascaldom_invoke_callback

implementation


procedure RefreshCanvasRect;
var
  rect: Integer;
  n: Integer;
begin
  rect := dom_call_method_ret(cv_h, 'getBoundingClientRect');
  n := dom_get_property_str(rect, 'left', Integer(@scratch), 80);
  rect_left := ParseF64(Integer(@scratch), n);
  n := dom_get_property_str(rect, 'top', Integer(@scratch), 80);
  rect_top := ParseF64(Integer(@scratch), n);
  n := dom_get_property_str(rect, 'width', Integer(@scratch), 80);
  rect_scale_x := Double(CANVAS_W) / ParseF64(Integer(@scratch), n);
  n := dom_get_property_str(rect, 'height', Integer(@scratch), 80);
  rect_scale_y := Double(CANVAS_H) / ParseF64(Integer(@scratch), n);
end;

procedure CanvasCoords;
var
  n: Integer;
  cx, cy: Double;
begin
  n := dom_get_property_str(last_event, 'clientX', Integer(@scratch), 80);
  cx := ParseF64(Integer(@scratch), n);
  n := dom_get_property_str(last_event, 'clientY', Integer(@scratch), 80);
  cy := ParseF64(Integer(@scratch), n);
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
  dom_canvas_render(cv_h, ctx_h, Integer(@pixels), PIXEL_COUNT, CANVAS_W, CANVAS_H);
end;

procedure SweepMain;  // exported as pascaldom_main
var
  app, ver: Integer;
begin
  doc_h := dom_get_global('document');
  app := dom_get_element_by_id('stage');
  cv_h := dom_canvas_create(app, CANVAS_W, CANVAS_H);
  ctx_h := dom_canvas_get_context(cv_h);

  // game init
  rng_state := (Cardinal((dom_now - Trunc(dom_now)) * 1000000.0) xor $5A5A5A5A) or 1;
  difficulty := LoadDifficulty;
  SyncLevel;
  LoadBestTimes;
  ZeroGameState;

  RefreshCanvasRect;

  ver := dom_get_element_by_id('version');
  if ver <> 0 then dom_set_inner_text(ver, '1.0.0');

  dom_add_event_listener(doc_h, 'click', CB_CLICK);
  dom_add_event_listener(doc_h, 'contextmenu', CB_CONTEXTMENU);
  dom_add_event_listener(doc_h, 'mousemove', CB_MOUSEMOVE);
  dom_add_event_listener(doc_h, 'mousedown', CB_MOUSEDOWN);
  dom_add_event_listener(doc_h, 'mouseup', CB_MOUSEUP);
  dom_add_event_listener(doc_h, 'keydown', CB_KEYDOWN);

  win_h := dom_get_property(doc_h, 'defaultView');
  dom_add_event_listener(win_h, 'resize', CB_RESIZE);
  dom_add_event_listener(win_h, 'orientationchange', CB_RESIZE);

  dom_start_animation_loop(CB_TICK);
end;

procedure SetLastEvent(h: Integer);  // exported as pascaldom_set_last_event
begin
  last_event := h;
end;

procedure InvokeCallback(id: Integer);  // exported as pascaldom_invoke_callback
var
  n: Integer;
  button: Integer;
begin
  case id of
    CB_CLICK:
      begin
        CanvasCoords;
        HandleLeftClick(cw_x, cw_y);
      end;
    CB_CONTEXTMENU:
      begin
        dom_call_method0(last_event, 'preventDefault');
        CanvasCoords;
        HandleRightClick(cw_x, cw_y);
      end;
    CB_MOUSEMOVE:
      begin
        CanvasCoords;
        HandleMouseMove(cw_x, cw_y);
      end;
    CB_MOUSEDOWN:
      begin
        CanvasCoords;
        n := dom_get_property_str(last_event, 'button', Integer(@scratch), 80);
        button := ParseInt(Integer(@scratch), n);
        if button = 2 then button := MB_RIGHT else button := MB_LEFT;
        HandleMouseDown(cw_x, cw_y, button);
      end;
    CB_MOUSEUP:
      begin
        CanvasCoords;
        HandleMouseUp(cw_x, cw_y);
      end;
    CB_TICK:
      Tick;
    CB_RESIZE:
      RefreshCanvasRect;
    CB_KEYDOWN:
      begin
        n := dom_get_property_str(last_event, 'key', Integer(@scratch), 80);
        HandleKeyDown(Integer(@scratch), n);
      end;
    else begin end;
  end;
end;

begin
end.
