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

procedure BgPutPixel(x, y: Integer);

procedure BgFillRect(x, y, w, h: Integer);

procedure BgFillCircle(cx, cy, radius: Integer);

function FontByte(ch, row: Integer): Byte;

procedure DrawText(x, y: Integer; s: string; r, g, b: Integer);

procedure DrawTextLarge(x, y: Integer; s: string; r, g, b: Integer);

function TextWidth(s: string): Integer;

function TextWidthLarge(s: string): Integer;

implementation

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

procedure DrawText(x, y: Integer; s: string; r, g, b: Integer);
var
  i, ch, row, col, bits, cx: Integer;
begin
  SetActive(r, g, b, 255);
  cx := x;
  for i := 1 to Length(s) do
  begin
    ch := Ord(UpCase(s[i]));
    if (ch >= 32) and (ch <= 95) then
    begin
      for row := 0 to 6 do
      begin
        bits := FontByte(ch, row);
        for col := 0 to 4 do
          if ((bits shr (4 - col)) and 1) = 1 then
            FillRect(cx + col * 2, y + row * 2, 2, 2);
      end;
    end;
    cx := cx + 12;
  end;
end;

procedure DrawTextLarge(x, y: Integer; s: string; r, g, b: Integer);
var
  i, ch, row, col, bits, cx: Integer;
begin
  SetActive(r, g, b, 255);
  cx := x;
  for i := 1 to Length(s) do
  begin
    ch := Ord(UpCase(s[i]));
    if (ch >= 32) and (ch <= 95) then
    begin
      for row := 0 to 6 do
      begin
        bits := FontByte(ch, row);
        for col := 0 to 4 do
          if ((bits shr (4 - col)) and 1) = 1 then
            FillRect(cx + col * 4, y + row * 4, 4, 4);
      end;
    end;
    cx := cx + 24;
  end;
end;

function TextWidth(s: string): Integer;
begin
  TextWidth := Length(s) * 12;
end;

function TextWidthLarge(s: string): Integer;
begin
  TextWidthLarge := Length(s) * 24;
end;

begin
end.
