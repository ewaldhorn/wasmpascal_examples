library colors;

// Colored text (TextColor/TextBackground) + a graphics canvas on the same
// page — the two output paths wasmpascal supports, side by side.
// Draws a gradient to the canvas and prints a color table to the console
// with write/writeln + field widths.
//
// The two paths come from two different places, which is the point of the
// example: the canvas goes through the WEB unit's bridge (`uses WEB`), the
// console text through `wasmpascal_env` — and BOTH run from the one body,
// which under this ABI IS pascaldom_main. Migrated 2026-09-14: four
// hand-declared `external`s and a separate pascaldom_main procedure + exports
// clause became `uses WEB` and a body (the same shape sweep/paint/musicbox
// have).

uses
  WEB;

const
  W = 320;
  H = 200;

var
  web: TWeb;
  app: Integer;
  pixels: array[0..W * H * 4 - 1] of Byte;

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

begin
  web := TWeb.Create;
  // The mount point is the HOST's business: the IDE runs examples under
  // #stage, a standalone page may have neither id, and handle 0 is the
  // bridge's reserved event slot rather than "no parent".
  app := web.GetElementById('stage');
  if app = 0 then app := web.GetElementById('app');
  if app = 0 then app := web.Doc;
  web.MakeCanvas(app, W, H);
  DrawGradient;
  web.RenderCanvas(Integer(@pixels), W * H * 4);

  // Console output with colors — the other output path, and it works from the
  // same body: the console sink is `wasmpascal_env`, not the canvas bridge.
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
