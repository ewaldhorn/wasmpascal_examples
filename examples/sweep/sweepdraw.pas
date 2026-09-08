unit sweepdraw;

interface

uses
  sweepdefs;

procedure SetActive(r, g, b, a: Integer);

procedure PutPixel(x, y: Integer);

procedure Line(x1, y1, x2, y2: Integer);

procedure Circle(cx, cy, radius: Integer);

procedure FillCircle(cx, cy, radius: Integer);

procedure FillRect(x, y, w, h: Integer);

procedure RectOutline(x, y, w, h: Integer);

procedure RectThick(x, y, w, h, t: Integer);

procedure CLine(x1, y1, x2, y2, r, g, b: Integer);

procedure CCircle(cx, cy, rad, r, g, b: Integer);

procedure CFillCircle(cx, cy, rad, r, g, b: Integer);

procedure CFillRect(x, y, w, h, r, g, b: Integer);

procedure CRectThick(x, y, w, h, t, r, g, b: Integer);

procedure DrawBevel(x, y, w, h, thickness: Integer; pressed: Boolean);

function SegCode(d: Integer): Byte;

procedure DrawSevenSeg(x, y, w, h, digit: Integer);

procedure DrawCounter(x, y, w, h, value: Integer);

procedure DrawMine(x, y, w, h: Integer);

procedure DrawFlag(x, y, w, h: Integer);

procedure DrawX(x, y, w, h, r, g, b: Integer);

procedure DrawQMark(x, y, w, h: Integer);

procedure DrawFace(x, y, w, h, face: Integer);

procedure NumColour(n: Integer);

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

procedure Line(x1, y1, x2, y2: Integer);
var
  diff_x, diff_y: Integer;
  slope_x, slope_y: Integer;
  err, e2: Integer;
begin
  diff_x := x2 - x1;
  if diff_x < 0 then diff_x := -diff_x;
  diff_y := y2 - y1;
  if diff_y < 0 then diff_y := -diff_y;
  if x1 < x2 then slope_x := 1 else slope_x := -1;
  if y1 < y2 then slope_y := 1 else slope_y := -1;
  err := diff_x - diff_y;
  while true do
  begin
    PutPixel(x1, y1);
    if (x1 = x2) and (y1 = y2) then Break;
    e2 := 2 * err;
    if e2 > -diff_y then
    begin
      err := err - diff_y;
      x1 := x1 + slope_x;
    end;
    if e2 < diff_x then
    begin
      err := err + diff_x;
      y1 := y1 + slope_y;
    end;
  end;
end;

procedure Circle(cx, cy, radius: Integer);
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

procedure FillRect(x, y, w, h: Integer);
var
  i, j: Integer;
begin
  if (w <= 0) or (h <= 0) then Exit;
  for j := 0 to h - 1 do
    for i := 0 to w - 1 do
      PutPixel(x + i, y + j);
end;

procedure RectOutline(x, y, w, h: Integer);
begin
  if (w <= 0) or (h <= 0) then Exit;
  Line(x, y, x + w - 1, y);
  Line(x, y, x, y + h - 1);
  Line(x, y + h - 1, x + w - 1, y + h - 1);
  Line(x + w - 1, y, x + w - 1, y + h - 1);
end;

procedure RectThick(x, y, w, h, t: Integer);
var
  tt: Integer;
begin
  for tt := 0 to t - 1 do
  begin
    if (w - tt * 2 <= 0) or (h - tt * 2 <= 0) then Break;
    RectOutline(x + tt, y + tt, w - tt * 2, h - tt * 2);
  end;
end;

procedure CLine(x1, y1, x2, y2, r, g, b: Integer);
begin
  SetActive(r, g, b, 255);
  Line(x1, y1, x2, y2);
end;

procedure CCircle(cx, cy, rad, r, g, b: Integer);
begin
  SetActive(r, g, b, 255);
  Circle(cx, cy, rad);
end;

procedure CFillCircle(cx, cy, rad, r, g, b: Integer);
begin
  SetActive(r, g, b, 255);
  FillCircle(cx, cy, rad);
end;

procedure CFillRect(x, y, w, h, r, g, b: Integer);
begin
  SetActive(r, g, b, 255);
  FillRect(x, y, w, h);
end;

procedure CRectThick(x, y, w, h, t, r, g, b: Integer);
begin
  SetActive(r, g, b, 255);
  RectThick(x, y, w, h, t);
end;

procedure DrawBevel(x, y, w, h, thickness: Integer; pressed: Boolean);
var
  t: Integer;
  x1, y1, x2, y2: Integer;
begin
  for t := 0 to thickness - 1 do
  begin
    x1 := x + t;
    y1 := y + t;
    x2 := x + w - 1 - t;
    y2 := y + h - 1 - t;
    if pressed then
    begin
      CLine(x1, y1, x2, y1, 128, 128, 128);   // top
      CLine(x1, y1, x1, y2, 128, 128, 128);   // left
      CLine(x1, y2, x2, y2, 255, 255, 255);   // bottom
      CLine(x2, y1, x2, y2, 255, 255, 255);   // right
    end
    else
    begin
      CLine(x1, y1, x2, y1, 255, 255, 255);
      CLine(x1, y1, x1, y2, 255, 255, 255);
      CLine(x1, y2, x2, y2, 128, 128, 128);
      CLine(x2, y1, x2, y2, 128, 128, 128);
    end;
  end;
  bix := x + thickness;
  biy := y + thickness;
  biw := w - thickness * 2;
  bih := h - thickness * 2;
end;

function SegCode(d: Integer): Byte;
begin
  case d of
    0: SegCode := SEVEN_SEG_0;
    1: SegCode := SEVEN_SEG_1;
    2: SegCode := SEVEN_SEG_2;
    3: SegCode := SEVEN_SEG_3;
    4: SegCode := SEVEN_SEG_4;
    5: SegCode := SEVEN_SEG_5;
    6: SegCode := SEVEN_SEG_6;
    7: SegCode := SEVEN_SEG_7;
    8: SegCode := SEVEN_SEG_8;
    else SegCode := SEVEN_SEG_9;
  end;
end;

procedure DrawSevenSeg(x, y, w, h, digit: Integer);
var
  code: Byte;
  t, half: Integer;
begin
  if (digit < 0) or (digit > 9) then Exit;
  code := SegCode(digit);
  t := w div 5;
  if t < 2 then t := 2;
  half := h div 2;
  if (code and $01) <> 0 then FillRect(x + t, y, w - 2 * t, t);          // a
  if (code and $40) <> 0 then FillRect(x + t, y + half - t div 2, w - 2 * t, t); // g
  if (code and $08) <> 0 then FillRect(x + t, y + h - t, w - 2 * t, t);  // d
  if (code and $20) <> 0 then FillRect(x, y + t, t, half - t);           // f
  if (code and $02) <> 0 then FillRect(x + w - t, y + t, t, half - t);   // b
  if (code and $10) <> 0 then FillRect(x, y + half, t, half - t);        // e
  if (code and $04) <> 0 then FillRect(x + w - t, y + half, t, half - t);// c
end;

procedure DrawCounter(x, y, w, h, value: Integer);
var
  v, av: Integer;
  d0, d1, d2: Integer;
  dw: Integer;
  neg: Boolean;
begin
  v := value;
  if v > 999 then v := 999;
  if v < -99 then v := -99;
  CFillRect(x, y, w, h, 0, 0, 0);
  neg := v < 0;
  if neg then av := -v else av := v;
  if neg then
  begin
    d0 := 10; d1 := (av div 10) mod 10; d2 := av mod 10;
  end
  else
  begin
    d0 := (av div 100) mod 10; d1 := (av div 10) mod 10; d2 := av mod 10;
  end;
  dw := w div 3;
  if d0 = 10 then
    CFillRect(x + 2, y + h div 2 - 1, dw - 4, 2, 220, 30, 30)
  else
  begin
    SetActive(220, 30, 30, 255);
    DrawSevenSeg(x + 2, y + 2, dw - 4, h - 4, d0);
  end;
  SetActive(220, 30, 30, 255);
  DrawSevenSeg(x + dw + 2, y + 2, dw - 4, h - 4, d1);
  DrawSevenSeg(x + 2 * dw + 2, y + 2, dw - 4, h - 4, d2);
end;

procedure DrawMine(x, y, w, h: Integer);
var
  cx, cy, rad: Integer;
begin
  cx := x + w div 2;
  cy := y + h div 2;
  rad := w div 2 - 6;
  CLine(cx - rad - 2, cy, cx + rad + 2, cy, 0, 0, 0);
  CLine(cx, cy - rad - 2, cx, cy + rad + 2, 0, 0, 0);
  CLine(cx - rad, cy - rad, cx + rad, cy + rad, 0, 0, 0);
  CLine(cx - rad, cy + rad, cx + rad, cy - rad, 0, 0, 0);
  SetActive(0, 0, 0, 255);
  FillCircle(cx, cy, rad);
  SetActive(220, 220, 220, 255);
  FillCircle(cx - 2, cy - 2, 2);
end;

procedure DrawFlag(x, y, w, h: Integer);
var
  cx, top, bottom: Integer;
begin
  cx := x + w div 2;
  top := y + 4;
  bottom := y + h - 4;
  CLine(cx - 4, top, cx - 4, bottom, 0, 0, 0);
  CFillRect(cx - 4, top, 8, 7, 200, 20, 20);
  CLine(cx - 7, bottom, cx + 1, bottom, 0, 0, 0);
end;

procedure DrawX(x, y, w, h, r, g, b: Integer);
begin
  CLine(x + 3, y + 3, x + w - 3, y + h - 3, r, g, b);
  CLine(x + w - 3, y + 3, x + 3, y + h - 3, r, g, b);
end;

procedure DrawQMark(x, y, w, h: Integer);
const
var
  scale, gw, gh, ox, oy: Integer;
  bits: Byte;
  row, ci: Integer;
begin
  scale := 2;
  gw := 5 * scale;
  gh := 7 * scale;
  ox := x + (w - gw) div 2;
  oy := y + (h - gh) div 2;
  SetActive(0, 0, 0, 255);
  for row := 0 to 6 do
  begin
    case row of
      0: bits := 14;
      1: bits := 17;
      2: bits := 1;
      3: bits := 6;
      4: bits := 4;
      5: bits := 0;
      else bits := 4;
    end;
    for ci := 0 to 4 do
      if ((bits shr (4 - ci)) and 1) = 1 then
        FillRect(ox + ci * scale, oy + row * scale, scale, scale);
  end;
end;

procedure DrawFace(x, y, w, h, face: Integer);
var
  cx, cy, rad, eye_dx, eye_dy, dx: Integer;
begin
  cx := x + w div 2;
  cy := y + h div 2;
  rad := w div 2 - 1;
  SetActive(255, 205, 20, 255);
  FillCircle(cx, cy, rad);
  CCircle(cx, cy, rad, 0, 0, 0);
  eye_dx := rad div 2;
  eye_dy := rad div 3;
  if face = FS_LOST then
  begin
    for dx := -eye_dx to eye_dx do
    begin
      if dx = 0 then continue;
      CLine(cx + dx - 2, cy - eye_dy - 2, cx + dx + 2, cy - eye_dy + 2, 0, 0, 0);
      CLine(cx + dx - 2, cy - eye_dy + 2, cx + dx + 2, cy - eye_dy - 2, 0, 0, 0);
    end;
    CLine(cx - 4, cy + rad div 2 + 1, cx + 4, cy + rad div 2 + 1, 0, 0, 0);
  end
  else if face = FS_WON then
  begin
    CFillRect(cx - eye_dx - 3, cy - eye_dy - 2, (eye_dx + 3) * 2, 4, 0, 0, 0);
    CLine(cx - eye_dx - 3, cy - eye_dy, cx - eye_dx - 3, cy - eye_dy + 3, 0, 0, 0);
    CLine(cx + eye_dx + 3, cy - eye_dy, cx + eye_dx + 3, cy - eye_dy + 3, 0, 0, 0);
    CLine(cx - 5, cy + rad div 2 - 2, cx, cy + rad div 2 + 2, 0, 0, 0);
    CLine(cx, cy + rad div 2 + 2, cx + 5, cy + rad div 2 - 2, 0, 0, 0);
  end
  else if face = FS_WORRIED then
  begin
    SetActive(0, 0, 0, 255);
    FillCircle(cx - eye_dx, cy - eye_dy, 2);
    FillCircle(cx + eye_dx, cy - eye_dy, 2);
    FillCircle(cx, cy + rad div 2, 3);
  end
  else
  begin
    SetActive(0, 0, 0, 255);
    FillCircle(cx - eye_dx, cy - eye_dy, 2);
    FillCircle(cx + eye_dx, cy - eye_dy, 2);
    CLine(cx - 5, cy + rad div 2 - 2, cx + 5, cy + rad div 2 - 2, 0, 0, 0);
  end;
end;

procedure NumColour(n: Integer);
begin
  case n of
    1: begin num_r := 0;   num_g := 0;   num_b := 255; end;
    2: begin num_r := 0;   num_g := 128; num_b := 0;   end;
    3: begin num_r := 255; num_g := 0;   num_b := 0;   end;
    4: begin num_r := 0;   num_g := 0;   num_b := 128; end;
    5: begin num_r := 128; num_g := 0;   num_b := 0;   end;
    6: begin num_r := 0;   num_g := 128; num_b := 128; end;
    7: begin num_r := 0;   num_g := 0;   num_b := 0;   end;
    8: begin num_r := 128; num_g := 128; num_b := 128; end;
    else begin num_r := 0; num_g := 0; num_b := 0; end;
  end;
end;

begin
end.
