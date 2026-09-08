library pascaldom_probe;

// A minimal pascaldom-ABI program: creates a canvas, fills it with a solid color
// once, and exports pascaldom_main so the host boots it via PascalDom.instantiate.
// Exercises the pascaldom_env imports (canvas create/context/render) end to end.

function  dom_get_global(nm: string): Integer; external 'pascaldom_env' name 'dom_get_global';
function  dom_get_element_by_id(id: string): Integer; external 'pascaldom_env' name 'dom_get_element_by_id';
function  dom_canvas_create(parent: Integer; w, h: Integer): Integer;
          external 'pascaldom_env' name 'dom_canvas_create';
function  dom_canvas_get_context(cv: Integer): Integer;
          external 'pascaldom_env' name 'dom_canvas_get_context';
procedure dom_canvas_render(cv, ctx, pp, pl, w, h: Integer);
          external 'pascaldom_env' name 'dom_canvas_render';

const
  W = 320;
  H = 200;
  PIXEL_COUNT = W * H * 4;

var
  pixels: array[0..PIXEL_COUNT - 1] of Byte;
  cv_h: Integer = 0;
  ctx_h: Integer = 0;

procedure FillPixels;
var
  i: Integer;
begin
  for i := 0 to PIXEL_COUNT - 1 do
  begin
    pixels[i] := 255;
  end;
end;

procedure pascaldom_main;
var
  app: Integer;
begin
  app := dom_get_element_by_id('stage');
  cv_h := dom_canvas_create(app, W, H);
  ctx_h := dom_canvas_get_context(cv_h);
  FillPixels;
  dom_canvas_render(cv_h, ctx_h, Integer(@pixels), PIXEL_COUNT, W, H);
end;

exports
  pascaldom_main name 'pascaldom_main';

begin
end.
