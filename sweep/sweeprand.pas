unit sweeprand;

interface

uses
  sweepdefs;

function RngNext: Cardinal;

function RngInt(n: Integer): Integer;

function PB(buf: Integer; i: Integer): Byte;

procedure SB(buf, i, v: Integer);

function ParseInt(buf: Integer; blen: Integer): Integer;

function ParseF64(buf: Integer; blen: Integer): Double;

function IntToBuf(v: Integer; buf: Integer): Integer;

implementation


function RngNext: Cardinal;
begin
  rng_state := rng_state xor (rng_state shl 13);
  rng_state := rng_state xor (rng_state shr 17);
  rng_state := rng_state xor (rng_state shl 5);
  RngNext := rng_state;
end;

function RngInt(n: Integer): Integer;
begin
  RngInt := Integer(RngNext mod Cardinal(n));
end;

function PB(buf: Integer; i: Integer): Byte;
begin
  PB := PByte(buf)[i];
end;

procedure SB(buf, i, v: Integer);
var
  p: PByte;
begin
  p := PByte(buf);
  p[i] := Byte(v);
end;

function ParseInt(buf: Integer; blen: Integer): Integer;
var
  i, v, s: Integer;
begin
  v := 0; s := 1; i := 0;
  if blen > 0 then
  begin
    if PB(buf, 0) = 45 then begin s := -1; i := 1; end   // '-'
    else if PB(buf, 0) = 43 then i := 1;                  // '+'
    while i < blen do
    begin
      v := v * 10 + (PB(buf, i) - 48);
      i := i + 1;
    end;
  end;
  ParseInt := v * s;
end;

function ParseF64(buf: Integer; blen: Integer): Double;
var
  i, s: Integer;
  ip, frac, scale: Double;
begin
  ip := 0.0; frac := 0.0; scale := 0.1; s := 1; i := 0;
  if blen > 0 then
  begin
    if PB(buf, 0) = 45 then begin s := -1; i := 1; end   // '-'
    else if PB(buf, 0) = 43 then i := 1;                  // '+'
    while (i < blen) and (PB(buf, i) <> 46) do            // '.'
    begin
      ip := ip * 10.0 + Double(PB(buf, i) - 48);
      i := i + 1;
    end;
    if (i < blen) and (PB(buf, i) = 46) then
    begin
      i := i + 1;
      while i < blen do
      begin
        frac := frac + Double(PB(buf, i) - 48) * scale;
        scale := scale * 0.1;
        i := i + 1;
      end;
    end;
  end;
  ParseF64 := (ip + frac) * Double(s);
end;

function IntToBuf(v: Integer; buf: Integer): Integer;
var
  x, d, c, off: Integer;
begin
  x := v;
  if x < 0 then x := -x;
  d := 0;
  if x = 0 then
  begin
    tmp16[0] := 48;
    d := 1;
  end
  else
  begin
    while x > 0 do
    begin
      tmp16[d] := Byte(48 + (x mod 10));
      x := x div 10;
      d := d + 1;
    end;
  end;
  off := 0;
  if v < 0 then
  begin
    SB(buf, 0, 45);
    off := 1;
  end;
  for c := 0 to d - 1 do
    SB(buf, off + c, tmp16[d - 1 - c]);
  IntToBuf := off + d;
end;

begin
end.
