// flbatch.pas — FLIGHT LEADER batch renderer: the batchiness wire-format
// command buffer (opcodes + payloads), Canvas2D wrappers, HUD text helpers,
// and the generic polygon drawer. The polygon drawer takes a CONFORMANT
// ARRAY parameter (`array[0..n: Integer] of Single`) — the ISO 7185
// feature — so any ship shape (any point count) flows through one routine
// with its runtime bounds.
unit flbatch;

interface

uses
  fldefs;

procedure cbReset;
procedure cbPutU8(v: Integer);
procedure cbPutU16(v: Integer);
procedure cbPutF32(v: Single);
procedure cbPutLit(p: Integer; n: Integer);

procedure bSetFill(p: Integer; n: Integer);
procedure bSetStroke(p: Integer; n: Integer);
procedure bSetLineWidth(w: Single);
procedure bSetFont(p: Integer; n: Integer);
procedure bSetTextAlign(p: Integer; n: Integer);
procedure bSetTextBaseline(p: Integer; n: Integer);
procedure bSetGlobalAlpha(a: Single);
procedure bSetLineCap(p: Integer; n: Integer);
procedure bSetShadow(p: Integer; n: Integer; blur: Single);
procedure bClearShadow;

procedure bFillRect(x, y, w, h: Single);
procedure bStrokeRect(x, y, w, h: Single);
procedure bClearRect(x, y, w, h: Single);

procedure bBeginPath;
procedure bMoveTo(x, y: Single);
procedure bLineTo(x, y: Single);
procedure bClosePath;
procedure bStroke;
procedure bFill;
procedure bArc(x, y, r, a0, a1: Single);
procedure bEllipse(x, y, rx, ry, rot, a0, a1: Single);
procedure bRect(x, y, w, h: Single);

procedure bSave;
procedure bRestore;
procedure bTranslate(x, y: Single);
procedure bRotate(a: Single);

// Draw text bytes at (x, y) using the current fill/font/align.
procedure bFillText(ptr: Integer; tlen, x, y: Integer);

// Write a decimal integer into text_buf starting at `off`; returns the new
// offset (pascaloids pattern — no heap, no string machinery).
function WriteInt(off, n: Integer): Integer;
// Build "PREFIX<num>" into text_buf; returns the total length.
function HUDText(prefix: PByte; plen, num: Integer): Integer;

// Draw a closed polygon from a conformant point array (x,y pairs), rotated
// by `rot`, scaled by `scale`, translated to (x, y). Filled or stroked.
procedure DrawPolyShape(pts: array[0..n: Integer] of Single; x, y, scale, rot: Single; filled: Boolean);

implementation

procedure cbReset;
begin
  cb_len := 0;
end;

procedure cbPutU8(v: Integer);
begin
  if cb_len + 1 > CMD_CAPACITY then Exit;
  cb_cmd[cb_len] := Byte(v);
  cb_len := cb_len + 1;
end;

procedure cbPutU16(v: Integer);
begin
  if cb_len + 2 > CMD_CAPACITY then Exit;
  cb_cmd[cb_len] := Byte(v and $FF);
  cb_cmd[cb_len + 1] := Byte((v shr 8) and $FF);
  cb_len := cb_len + 2;
end;

procedure cbPutF32(v: Single);
var
  bits: Cardinal;
begin
  bits := F32Bits(v);
  if cb_len + 4 > CMD_CAPACITY then Exit;
  cb_cmd[cb_len] := Byte(bits and $FF);
  cb_cmd[cb_len + 1] := Byte((bits shr 8) and $FF);
  cb_cmd[cb_len + 2] := Byte((bits shr 16) and $FF);
  cb_cmd[cb_len + 3] := Byte((bits shr 24) and $FF);
  cb_len := cb_len + 4;
end;

procedure cbPutLit(p: Integer; n: Integer);
var
  i: Integer;
begin
  if cb_len + 2 + n > CMD_CAPACITY then Exit;
  cbPutU16(n);
  for i := 0 to n - 1 do
  begin
    cb_cmd[cb_len] := PByte(p)[i];
    cb_len := cb_len + 1;
  end;
end;

procedure bSetFill(p: Integer; n: Integer);
begin
  cbPutU8(OP_SET_FILL); cbPutLit(p, n);
end;

procedure bSetStroke(p: Integer; n: Integer);
begin
  cbPutU8(OP_SET_STROKE); cbPutLit(p, n);
end;

procedure bSetLineWidth(w: Single);
begin
  cbPutU8(OP_SET_LINE_WIDTH); cbPutF32(w);
end;

procedure bSetFont(p: Integer; n: Integer);
begin
  cbPutU8(OP_SET_FONT); cbPutLit(p, n);
end;

procedure bSetTextAlign(p: Integer; n: Integer);
begin
  cbPutU8(OP_SET_TEXT_ALIGN); cbPutLit(p, n);
end;

procedure bSetTextBaseline(p: Integer; n: Integer);
begin
  cbPutU8(OP_SET_TEXT_BASELINE); cbPutLit(p, n);
end;

procedure bSetGlobalAlpha(a: Single);
begin
  cbPutU8(OP_SET_GLOBAL_ALPHA); cbPutF32(a);
end;

procedure bSetLineCap(p: Integer; n: Integer);
begin
  cbPutU8(OP_SET_LINE_CAP); cbPutLit(p, n);
end;

procedure bSetShadow(p: Integer; n: Integer; blur: Single);
begin
  cbPutU8(OP_SET_SHADOW); cbPutLit(p, n); cbPutF32(blur);
end;

procedure bClearShadow;
begin
  cbPutU8(OP_CLEAR_SHADOW);
end;

procedure bFillRect(x, y, w, h: Single);
begin
  cbPutU8(OP_FILL_RECT); cbPutF32(x); cbPutF32(y); cbPutF32(w); cbPutF32(h);
end;

procedure bStrokeRect(x, y, w, h: Single);
begin
  cbPutU8(OP_STROKE_RECT); cbPutF32(x); cbPutF32(y); cbPutF32(w); cbPutF32(h);
end;

procedure bClearRect(x, y, w, h: Single);
begin
  cbPutU8(OP_CLEAR_RECT); cbPutF32(x); cbPutF32(y); cbPutF32(w); cbPutF32(h);
end;

procedure bBeginPath;
begin
  cbPutU8(OP_BEGIN_PATH);
end;

procedure bMoveTo(x, y: Single);
begin
  cbPutU8(OP_MOVE_TO); cbPutF32(x); cbPutF32(y);
end;

procedure bLineTo(x, y: Single);
begin
  cbPutU8(OP_LINE_TO); cbPutF32(x); cbPutF32(y);
end;

procedure bClosePath;
begin
  cbPutU8(OP_CLOSE_PATH);
end;

procedure bStroke;
begin
  cbPutU8(OP_STROKE);
end;

procedure bFill;
begin
  cbPutU8(OP_FILL);
end;

procedure bArc(x, y, r, a0, a1: Single);
begin
  cbPutU8(OP_ARC); cbPutF32(x); cbPutF32(y); cbPutF32(r); cbPutF32(a0); cbPutF32(a1); cbPutU8(0);
end;

procedure bEllipse(x, y, rx, ry, rot, a0, a1: Single);
begin
  cbPutU8(OP_ELLIPSE); cbPutF32(x); cbPutF32(y); cbPutF32(rx); cbPutF32(ry);
  cbPutF32(rot); cbPutF32(a0); cbPutF32(a1); cbPutU8(0);
end;

procedure bRect(x, y, w, h: Single);
begin
  cbPutU8(OP_RECT); cbPutF32(x); cbPutF32(y); cbPutF32(w); cbPutF32(h);
end;

procedure bSave;
begin
  cbPutU8(OP_SAVE);
end;

procedure bRestore;
begin
  cbPutU8(OP_RESTORE);
end;

procedure bTranslate(x, y: Single);
begin
  cbPutU8(OP_TRANSLATE); cbPutF32(x); cbPutF32(y);
end;

procedure bRotate(a: Single);
begin
  cbPutU8(OP_ROTATE); cbPutF32(a);
end;

procedure bFillText(ptr: Integer; tlen, x, y: Integer);
var
  i: Integer;
begin
  cbPutU8(OP_FILL_TEXT);
  if cb_len + 2 + tlen > CMD_CAPACITY then Exit;
  cbPutU16(tlen);
  for i := 0 to tlen - 1 do
  begin
    cb_cmd[cb_len] := PByte(ptr)[i];
    cb_len := cb_len + 1;
  end;
  cbPutF32(Single(x));
  cbPutF32(Single(y));
end;

function WriteInt(off, n: Integer): Integer;
var
  d, x, c: Integer;
begin
  x := n;
  d := 0;
  if x = 0 then
  begin
    tmp16[0] := 48;
    d := 1;
  end else begin
    while x > 0 do
    begin
      tmp16[d] := Byte(48 + (x mod 10));
      x := x div 10;
      d := d + 1;
    end;
  end;
  for c := 0 to d - 1 do
  begin
    if off + c < 64 then text_buf[off + c] := tmp16[d - 1 - c];
  end;
  WriteInt := off + d;
end;

function HUDText(prefix: PByte; plen, num: Integer): Integer;
var
  i, o: Integer;
begin
  o := 0;
  for i := 0 to plen - 1 do
  begin
    if o < 64 then text_buf[o] := prefix[i];
    o := o + 1;
  end;
  o := WriteInt(o, num);
  HUDText := o;
end;

procedure DrawPolyShape(pts: array[0..n: Integer] of Single; x, y, scale, rot: Single; filled: Boolean);
var
  i, npts: Integer;
  c, s: Single;
  px, py: Single;
begin
  npts := (n + 1) div 2;
  if npts < 2 then Exit;
  c := fCos(rot);
  s := fSin(rot);
  bBeginPath;
  for i := 0 to npts - 1 do
  begin
    px := x + (pts[i * 2] * c - pts[i * 2 + 1] * s) * scale;
    py := y + (pts[i * 2] * s + pts[i * 2 + 1] * c) * scale;
    if i = 0 then bMoveTo(px, py) else bLineTo(px, py);
  end;
  bClosePath;
  if filled then bFill else bStroke;
end;

begin
end.
