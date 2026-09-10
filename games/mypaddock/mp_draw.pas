unit mp_draw;

{ Pixel primitives on the frame buffer, bake-target primitives on the bg
  buffer, and the 5x7 bitmap font. Port of the drawing half of renderer.odin
  + font.odin. Mirrors sweepdraw.pas conventions (SetActive + PutPixel). }

interface

uses
  mp_defs;

procedure SetActive(r, g, b, a: Integer);

procedure PutPixel(x, y: Integer);

procedure FillRect(x, y, w, h: Integer);

procedure CFillRect(x, y, w, h, r, g, b: Integer);

procedure FillCircle(cx, cy, radius: Integer);

procedure CFillCircle(cx, cy, rad, r, g, b: Integer);

procedure RectOutline(x, y, w, h: Integer);

procedure CRectOutline(x, y, w, h, r, g, b: Integer);

procedure CRectThick(x, y, w, h, t, r, g, b: Integer);

function IntToBuf(v: Integer): Integer;

procedure DrawDigits(x, y, n: Integer; r, g, b: Integer);

procedure DrawLabelInt(x, y, pa, pl, v: Integer; r, g, b: Integer);

procedure CircleOutline(cx, cy, radius: Integer);

procedure DitherCircle(cx, cy, radius: Integer);

procedure DimScreen;

procedure BgPutPixel(x, y: Integer);

procedure BgFillRect(x, y, w, h: Integer);

procedure BgFillCircle(cx, cy, radius: Integer);

function FontByte(ch, row: Integer): Byte;

{ Text takes (addr, len) Integer pairs (StrAddr/StrLen pattern): indexing a
  by-value string param is unsupported by the compiler (emits base 0). }

procedure DrawText(x, y, addr, len: Integer; r, g, b: Integer);

procedure DrawTextLarge(x, y, addr, len: Integer; r, g, b: Integer);

function TextWidth(len: Integer): Integer;

function TextWidthLarge(len: Integer): Integer;

implementation

uses
  mp_rand;

procedure SetActive(r, g, b, a: Integer);
begin
  act_r := Byte(r);
  act_g := Byte(g);
  act_b := Byte(b);
  act_a := Byte(a);
end;

procedure PutPixel(x, y: Integer);
var
  off: Integer;
begin
  if (x < 0) or (x >= CANVAS_W) or (y < 0) or (y >= CANVAS_H) then Exit;
  off := (y * CANVAS_W + x) * 4;
  pixels[off + 0] := act_r;
  pixels[off + 1] := act_g;
  pixels[off + 2] := act_b;
  pixels[off + 3] := act_a;
end;

procedure FillRect(x, y, w, h: Integer);
var
  i, j: Integer;
begin
  if (w <= 0) or (h <= 0) then Exit;
  for j := 0 to h - 1 do
    for i := 0 to w - 1 do
      PutPixel(x + i, y + j);
end;

procedure CFillRect(x, y, w, h, r, g, b: Integer);
begin
  SetActive(r, g, b, 255);
  FillRect(x, y, w, h);
end;

procedure FillCircle(cx, cy, radius: Integer);
var
  dy, chord, r2, dx: Integer;
begin
  if radius <= 0 then Exit;
  r2 := radius * radius;
  for dy := -radius to radius do
  begin
    chord := Trunc(mSqrt(Double(r2 - dy * dy)));
    for dx := -chord to chord do
      PutPixel(cx + dx, cy + dy);
  end;
end;

procedure CFillCircle(cx, cy, rad, r, g, b: Integer);
begin
  SetActive(r, g, b, 255);
  FillCircle(cx, cy, rad);
end;

procedure BgPutPixel(x, y: Integer);
var
  off: Integer;
begin
  if (x < 0) or (x >= bg_w) or (y < 0) or (y >= bg_h) then Exit;
  off := (y * bg_w + x) * 4;
  bg[off + 0] := act_r;
  bg[off + 1] := act_g;
  bg[off + 2] := act_b;
  bg[off + 3] := act_a;
end;

procedure BgFillRect(x, y, w, h: Integer);
var
  i, j: Integer;
begin
  if (w <= 0) or (h <= 0) then Exit;
  for j := 0 to h - 1 do
    for i := 0 to w - 1 do
      BgPutPixel(x + i, y + j);
end;

procedure BgFillCircle(cx, cy, radius: Integer);
var
  dy, chord, r2, dx: Integer;
begin
  if radius <= 0 then Exit;
  r2 := radius * radius;
  for dy := -radius to radius do
  begin
    chord := Trunc(mSqrt(Double(r2 - dy * dy)));
    for dx := -chord to chord do
      BgPutPixel(cx + dx, cy + dy);
  end;
end;

{ 5x7 font, chars 32..95, 7 rows each, bit 4 = leftmost. Flat table:
  index = (ch - 32) * 7 + row. Chars 92 and 94 are all zero (unused).
  Transcribed from font.odin's font5x7. }
const
  FONT: array[0..447] of Byte = (
    0, 0, 0, 0, 0, 0, 0,
    4, 4, 4, 4, 4, 0, 4,
    10, 10, 0, 0, 0, 0, 0,
    10, 10, 31, 10, 31, 10, 10,
    4, 15, 20, 14, 5, 30, 4,
    17, 9, 4, 14, 4, 18, 17,
    12, 18, 20, 8, 21, 18, 13,
    4, 4, 0, 0, 0, 0, 0,
    2, 4, 8, 8, 8, 4, 2,
    8, 4, 2, 2, 2, 4, 8,
    0, 10, 14, 4, 14, 10, 0,
    0, 4, 4, 31, 4, 4, 0,
    0, 0, 0, 0, 6, 4, 8,
    0, 0, 0, 31, 0, 0, 0,
    0, 0, 0, 0, 0, 6, 6,
    1, 2, 2, 4, 8, 8, 16,
    14, 17, 19, 21, 25, 17, 14,
    4, 12, 4, 4, 4, 4, 14,
    14, 17, 1, 6, 8, 16, 31,
    14, 17, 1, 6, 1, 17, 14,
    3, 5, 9, 17, 31, 1, 1,
    31, 16, 30, 1, 1, 17, 14,
    14, 16, 16, 30, 17, 17, 14,
    31, 1, 2, 4, 8, 8, 8,
    14, 17, 17, 14, 17, 17, 14,
    14, 17, 17, 15, 1, 17, 14,
    0, 12, 12, 0, 12, 12, 0,
    0, 12, 12, 0, 12, 8, 4,
    2, 4, 8, 16, 8, 4, 2,
    0, 0, 31, 0, 31, 0, 0,
    8, 4, 2, 1, 2, 4, 8,
    14, 17, 1, 6, 4, 0, 4,
    14, 17, 1, 13, 21, 21, 14,
    14, 17, 17, 31, 17, 17, 17,
    30, 17, 17, 30, 17, 17, 30,
    14, 17, 16, 16, 16, 17, 14,
    30, 17, 17, 17, 17, 17, 30,
    31, 16, 16, 30, 16, 16, 31,
    31, 16, 16, 30, 16, 16, 16,
    14, 17, 16, 19, 17, 17, 14,
    17, 17, 17, 31, 17, 17, 17,
    14, 4, 4, 4, 4, 4, 14,
    7, 1, 1, 1, 17, 17, 14,
    17, 18, 20, 24, 20, 18, 17,
    16, 16, 16, 16, 16, 16, 31,
    17, 27, 21, 17, 17, 17, 17,
    17, 25, 21, 19, 17, 17, 17,
    14, 17, 17, 17, 17, 17, 14,
    30, 17, 17, 30, 16, 16, 16,
    14, 17, 17, 17, 21, 18, 13,
    30, 17, 17, 30, 20, 18, 17,
    14, 17, 16, 14, 1, 17, 14,
    31, 4, 4, 4, 4, 4, 4,
    17, 17, 17, 17, 17, 17, 14,
    17, 17, 17, 17, 17, 10, 4,
    17, 17, 17, 21, 21, 27, 17,
    17, 17, 10, 4, 10, 17, 17,
    17, 17, 10, 4, 4, 4, 4,
    31, 1, 2, 4, 8, 16, 31,
    14, 8, 8, 8, 8, 8, 14,
    0, 0, 0, 0, 0, 0, 0,
    14, 2, 2, 2, 2, 2, 14,
    0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 31
  );

function FontByte(ch, row: Integer): Byte;
begin
  FontByte := FONT[(ch - 32) * 7 + row];
end;

procedure DrawGlyph(cx, y, ch, scale: Integer);
var
  row, col, bits: Integer;
begin
  for row := 0 to 6 do
  begin
    bits := FontByte(ch, row);
    for col := 0 to 4 do
      if ((bits shr (4 - col)) and 1) = 1 then
        FillRect(cx + col * scale, y + row * scale, scale, scale);
  end;
end;

function UpperByte(v: Byte): Integer;
begin
  if (v >= 97) and (v <= 122) then UpperByte := v - 32
  else UpperByte := v;
end;

procedure DrawText(x, y, addr, len: Integer; r, g, b: Integer);
var
  i, ch, cx: Integer;
begin
  SetActive(r, g, b, 255);
  cx := x;
  for i := 0 to len - 1 do
  begin
    ch := UpperByte(BufByte(addr, i));
    if (ch >= 32) and (ch <= 95) then
      DrawGlyph(cx, y, ch, 2);
    cx := cx + 12;
  end;
end;

procedure DrawTextLarge(x, y, addr, len: Integer; r, g, b: Integer);
var
  i, ch, cx: Integer;
begin
  SetActive(r, g, b, 255);
  cx := x;
  for i := 0 to len - 1 do
  begin
    ch := UpperByte(BufByte(addr, i));
    if (ch >= 32) and (ch <= 95) then
      DrawGlyph(cx, y, ch, 4);
    cx := cx + 24;
  end;
end;

function TextWidth(len: Integer): Integer;
begin
  TextWidth := len * 12;
end;

function TextWidthLarge(len: Integer): Integer;
begin
  TextWidthLarge := len * 24;
end;

procedure RectOutline(x, y, w, h: Integer);
begin
  if (w <= 0) or (h <= 0) then Exit;
  FillRect(x, y, w, 1);
  FillRect(x, y + h - 1, w, 1);
  FillRect(x, y, 1, h);
  FillRect(x + w - 1, y, 1, h);
end;

procedure CRectOutline(x, y, w, h, r, g, b: Integer);
begin
  SetActive(r, g, b, 255);
  RectOutline(x, y, w, h);
end;

procedure CRectThick(x, y, w, h, t, r, g, b: Integer);
var
  tt: Integer;
begin
  SetActive(r, g, b, 255);
  for tt := 0 to t - 1 do
  begin
    if (w - tt * 2 <= 0) or (h - tt * 2 <= 0) then Break;
    RectOutline(x + tt, y + tt, w - tt * 2, h - tt * 2);
  end;
end;

function IntToBuf(v: Integer): Integer;
var
  x, d, i, j, t, neg: Integer;
begin
  x := v; neg := 0;
  if x < 0 then begin neg := 1; x := -x; end;
  d := 0;
  if x = 0 then begin numbuf[0] := 48; d := 1; end
  else
    while x > 0 do
    begin
      numbuf[d] := Byte(48 + (x mod 10));
      x := x div 10;
      d := d + 1;
    end;
  i := 0; j := d - 1;
  while i < j do
  begin
    t := numbuf[i]; numbuf[i] := numbuf[j]; numbuf[j] := Byte(t);
    i := i + 1; j := j - 1;
  end;
  if neg = 1 then
  begin
    i := d;
    while i > 0 do begin numbuf[i] := numbuf[i - 1]; i := i - 1; end;
    numbuf[0] := 45;
    d := d + 1;
  end;
  IntToBuf := d;
end;

procedure DrawDigits(x, y, n: Integer; r, g, b: Integer);
var
  i: Integer;
begin
  SetActive(r, g, b, 255);
  for i := 0 to n - 1 do
    DrawGlyph(x + i * 12, y, numbuf[i], 2);
end;

procedure DrawLabelInt(x, y, pa, pl, v: Integer; r, g, b: Integer);
var
  n: Integer;
begin
  DrawText(x, y, pa, pl, r, g, b);
  n := IntToBuf(v);
  DrawDigits(x + pl * 12, y, n, r, g, b);
end;

procedure CircleOutline(cx, cy, radius: Integer);
var
  x, y, err: Integer;
begin
  if radius <= 0 then Exit;
  x := radius;
  y := 0;
  err := 1 - radius;
  while x >= y do
  begin
    PutPixel(cx + x, cy + y);
    PutPixel(cx - x, cy + y);
    PutPixel(cx + x, cy - y);
    PutPixel(cx - x, cy - y);
    PutPixel(cx + y, cy + x);
    PutPixel(cx - y, cy + x);
    PutPixel(cx + y, cy - x);
    PutPixel(cx - y, cy - x);
    y := y + 1;
    if err <= 0 then
      err := err + 2 * y + 1
    else
    begin
      x := x - 1;
      err := err + 2 * (y - x) + 1;
    end;
  end;
end;

{ DitherCircle draws a 50% checkerboard disc — stands in for Odin's
  translucent shadow circles, which a raw RGBA buffer cannot blend. }
procedure DitherCircle(cx, cy, radius: Integer);
var
  dy, chord, r2, dx: Integer;
begin
  if radius <= 0 then Exit;
  SetActive(0, 0, 0, 255);
  r2 := radius * radius;
  for dy := -radius to radius do
  begin
    chord := Trunc(mSqrt(Double(r2 - dy * dy)));
    for dx := -chord to chord do
      if ((cx + dx + cy + dy) mod 2) = 0 then
        PutPixel(cx + dx, cy + dy);
  end;
end;

procedure DimScreen;
var
  x, y: Integer;
begin
  SetActive(0, 0, 0, 255);
  for y := 0 to CANVAS_H - 1 do
    for x := 0 to CANVAS_W - 1 do
      if ((x + y) mod 2) = 0 then
        PutPixel(x, y);
end;

begin
end.
