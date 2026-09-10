unit mp_rand;

{ Xorshift RNG replacing Odin's core:math/rand. Same pattern as pong /
  pascaloids / sweeprand. Save format stores needs, not RNG state, so stream
  differences vs the Odin build are unobservable. }

interface

uses
  mp_defs;

procedure SeedRand(s: Cardinal);

function RngNext: Cardinal;

function RngInt(n: Integer): Integer;

function RngFloat: Double;

function BufByte(buf: Integer; i: Integer): Byte;

function ParseF64(buf: Integer; blen: Integer): Double;

function ParseInt(buf: Integer; blen: Integer): Integer;

implementation

const
  { ASCII codes for the parsers below (named: Byte/Char mixing is fragile). }
  CH_MINUS = 45;
  CH_PLUS = 43;
  CH_DOT = 46;
  CH_ZERO = 48;

procedure SeedRand(s: Cardinal);
begin
  rng_state := s;
  if rng_state = 0 then rng_state := 1;
end;

function RngNext: Cardinal;
begin
  rng_state := rng_state xor (rng_state shl 13);
  rng_state := rng_state xor (rng_state shr 17);
  rng_state := rng_state xor (rng_state shl 5);
  RngNext := rng_state;
end;

function RngInt(n: Integer): Integer;
begin
  if n <= 0 then RngInt := 0
  else RngInt := Integer(RngNext mod Cardinal(n));
end;

function RngFloat: Double;
begin
  RngFloat := Double(RngNext) / 4294967296.0;
end;

function BufByte(buf: Integer; i: Integer): Byte;
begin
  BufByte := PByte(buf)[i];
end;

function ParseF64(buf: Integer; blen: Integer): Double;
var
  i, s: Integer;
  ip, frac, scale: Double;
begin
  ip := 0.0; frac := 0.0; scale := 0.1; s := 1; i := 0;
  if blen > 0 then
  begin
    if BufByte(buf, 0) = CH_MINUS then begin s := -1; i := 1; end
    else if BufByte(buf, 0) = CH_PLUS then i := 1;
    while (i < blen) and (BufByte(buf, i) <> CH_DOT) do
    begin
      ip := ip * 10.0 + Double(BufByte(buf, i) - CH_ZERO);
      i := i + 1;
    end;
    if (i < blen) and (BufByte(buf, i) = CH_DOT) then
    begin
      i := i + 1;
      while i < blen do
      begin
        frac := frac + Double(BufByte(buf, i) - CH_ZERO) * scale;
        scale := scale * 0.1;
        i := i + 1;
      end;
    end;
  end;
  ParseF64 := (ip + frac) * Double(s);
end;

function ParseInt(buf: Integer; blen: Integer): Integer;
var
  i, v, s: Integer;
begin
  v := 0; s := 1; i := 0;
  if blen > 0 then
  begin
    if BufByte(buf, 0) = CH_MINUS then begin s := -1; i := 1; end
    else if BufByte(buf, 0) = CH_PLUS then i := 1;
    while i < blen do
    begin
      v := v * 10 + (BufByte(buf, i) - CH_ZERO);
      i := i + 1;
    end;
  end;
  ParseInt := v * s;
end;

begin
end.
