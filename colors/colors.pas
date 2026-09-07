library colors;

// Colored text (TextColor/TextBackground) + a graphics canvas on the same
// page — the two output paths wasmpascal supports, side by side.
// Draws a gradient to the canvas and prints a color table to the console
// with write/writeln + field widths.

function  dom_get_element_by_id(id: string): Integer;
          external 'pascaldom_env' name 'dom_get_element_by_id';
function  dom_canvas_create(parent: Integer; w, h: Integer): Integer;
          external 'pascaldom_env' name 'dom_canvas_create';
function  dom_canvas_get_context(cv: Integer): Integer;
          external 'pascaldom_env' name 'dom_canvas_get_context';
procedure dom_canvas_render(cv, ctx, pp, pl, w, h: Integer);
          external 'pascaldom_env' name 'dom_canvas_render';

const
  W = 320;
  H = 200;

var
  pixels: array[0..W * H * 4 - 1] of Byte;
  cv_h: Integer = 0;
  ctx_h: Integer = 0;

// Fill the pixel buffer with a horizontal rainbow gradient.
procedure DrawGradient;
var
  x, y, idx: Integer;
  r, g, b: Byte;
begin
  for y := 0 to H - 1 do
  begin
    for x := 0 to W - 1 do
    begin
      r := Byte((x * 255) div W);
      g := Byte((y * 255) div H);
      b := Byte(255 - (x * 255) div W);
      idx := (y * W + x) * 4;
      pixels[idx + 0] := r;
      pixels[idx + 1] := g;
      pixels[idx + 2] := b;
      pixels[idx + 3] := 255;
    end;
  end;
end;

procedure pascaldom_main;
var
  app: Integer;
begin
  app := dom_get_element_by_id('stage');
  cv_h := dom_canvas_create(app, W, H);
  ctx_h := dom_canvas_get_context(cv_h);
  DrawGradient;
  dom_canvas_render(cv_h, ctx_h, Integer(@pixels), W * H * 4, W, H);
end;

exports
  pascaldom_main name 'pascaldom_main';

begin
  // Console output with colors — runs after the canvas is drawn.
  writeln('=== TextColor / TextBackground demo ===');
  writeln;
  TextColor(1);  write('red');
  TextColor(2);  write(' green');
  TextColor(3);  write(' yellow');
  TextColor(4);  write(' blue');
  TextColor(5);  write(' magenta');
  TextColor(6);  write(' cyan');
  TextColor(7);  write(' white');
  TextColor(15); writeln(' bright');
  TextColor(7);
  writeln;
  writeln('Field widths (right-aligned):');
  writeln(1:6);
  writeln(12:6);
  writeln(123:6);
  writeln(1234:6);
  writeln(12345:6);
  writeln;
  TextBackground(1);
  writeln('  red background  ');
  TextBackground(4);
  writeln('  blue background  ');
  TextBackground(0);
  TextColor(7);
  writeln;
  writeln('Canvas gradient above, colored text below.');
end.
