unit mp_host;

{ DOM/canvas bootstrap + event loop. Port of main.odin, structured on
  sweephost.pas. Canvas id 'stage' and 'version' element match the sweep
  convention the IDE host already serves. }

interface

uses
  mp_defs,
  mp_rand,
  mp_game,
  mp_env;

var
  cv_h: Integer = 0;
  ctx_h: Integer = 0;
  doc_h: Integer = 0;
  last_event: Integer = 0;
  last_time: Double = 0.0;
  rect_left: Double = 0.0;
  rect_top: Double = 0.0;
  rect_scale_x: Double = 1.0;
  rect_scale_y: Double = 1.0;
  rect_settle: Integer = 30;

procedure RefreshCanvasRect;

procedure CanvasCoords;

procedure Tick;

procedure MpMain;

procedure SetLastEvent(h: Integer);

procedure InvokeCallback(id: Integer);

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
var
  now, dt: Double;
begin
  now := dom_now;
  dt := (now - last_time) / 1000.0;
  if dt > 0.1 then dt := 0.1;
  last_time := now;
  if rect_settle > 0 then
  begin
    rect_settle := rect_settle - 1;
    RefreshCanvasRect;
  end;
  GameUpdate(dt);
  DrawFrame;
  dom_canvas_render(cv_h, ctx_h, Integer(@pixels), PIXEL_COUNT, CANVAS_W, CANVAS_H);
end;

procedure MpMain;
var
  app, ver: Integer;
  seed: Cardinal;
  nowms: Double;
begin
  doc_h := dom_get_global('document');
  app := dom_get_element_by_id('stage');
  cv_h := dom_canvas_create(app, CANVAS_W, CANVAS_H);
  ctx_h := dom_canvas_get_context(cv_h);

  nowms := mp_date_now();
  seed := (Cardinal(Trunc(nowms / 1000.0)) xor $5A5A5A5A) or 1;
  GameInit(seed, nowms);
  RefreshCanvasRect;

  ver := dom_get_element_by_id('version');
  { Literal, not a const: StrAddr-style builtins take literals only. }
  if ver <> 0 then dom_set_inner_text(ver, '1.0.7');

  dom_add_event_listener(doc_h, 'mousedown', CB_MOUSEDOWN);
  dom_add_event_listener(doc_h, 'mousemove', CB_MOUSEMOVE);
  dom_add_event_listener(doc_h, 'mouseup', CB_MOUSEUP);
  dom_add_event_listener(doc_h, 'keydown', CB_KEYDOWN);

  dom_start_animation_loop(CB_TICK);
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

procedure InvokeCallback(id: Integer);
var
  n: Integer;
begin
  case id of
    CB_MOUSEDOWN:
      begin
        CanvasCoords;
        HandlePointerDown(cw_x, cw_y);
      end;
    CB_MOUSEMOVE:
      begin
        CanvasCoords;
        HandlePointerMove(cw_x, cw_y);
      end;
    CB_MOUSEUP:
      begin
        CanvasCoords;
        HandlePointerUp(cw_x, cw_y);
      end;
    CB_KEYDOWN:
      begin
        n := dom_get_property_str(last_event, 'key', Integer(@scratch), 80);
        HandleKeyDown(Integer(@scratch), n);
      end;
    CB_TICK:
      Tick;
    CB_RESIZE:
      RefreshCanvasRect;
    else begin end;
  end;
end;

begin
end.
