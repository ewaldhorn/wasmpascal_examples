// dugfx.pas — DUGSTER effects: small particle bursts on emerald pickup and
// player death. Fixed pool, no allocation; drawn by the renderer.
unit dugfx;

interface

uses
  dugdefs;

const
  FX_MAX = 24;
  FX_MAX1 = 23;

// Spawn a burst centred on cell (cx, cy): kind 0 = green, 1 = red, 2 = gold.
procedure fxBurst(cx, cy: Single; kind: Integer);

// Spawn ONE particle on cell (cx, cy) (G4: fireball drip trail).
procedure fxPuff(cx, cy: Single; kind: Integer);

// Advance all live particles by dt seconds.
procedure fxUpdate(dt: Single);

// Draw live particles as small rects.
procedure fxDraw;

implementation

var
  // Ring buffer: fxNext wraps on overflow, evicting the oldest particle.
  // No dynamic allocation; pool is always exactly FX_MAX slots.
  fxX, fxY, fxVx, fxVy, fxLife: array[0..FX_MAX1] of Single;
  fxKind: array[0..FX_MAX1] of Integer;
  fxNext: Integer;

procedure fxBurst(cx, cy: Single; kind: Integer);
var
  i: Integer;
  px, py: Single;
begin
  px := cx * Single(CELL) + Single(CELL) / 2.0;
  py := Single(BOARD_Y) + cy * Single(CELL) + Single(CELL) / 2.0;
  for i := 0 to 7 do
  begin
    fxX[fxNext] := px;
    fxY[fxNext] := py;
    fxVx[fxNext] := (dgRandF - 0.5) * 260.0;
    fxVy[fxNext] := (dgRandF - 0.5) * 260.0;
    fxLife[fxNext] := 0.45;
    fxKind[fxNext] := kind;
    fxNext := fxNext + 1;
    if fxNext >= FX_MAX then fxNext := 0;  // ring wrap
  end;
end;

procedure fxPuff(cx, cy: Single; kind: Integer);
begin
  fxX[fxNext] := cx * Single(CELL) + Single(CELL) / 2.0;
  fxY[fxNext] := Single(BOARD_Y) + cy * Single(CELL) + Single(CELL) / 2.0;
  fxVx[fxNext] := (dgRandF - 0.5) * 120.0;
  fxVy[fxNext] := (dgRandF - 0.5) * 120.0;
  fxLife[fxNext] := 0.3;
  fxKind[fxNext] := kind;
  fxNext := fxNext + 1;
  if fxNext >= FX_MAX then fxNext := 0;  // ring wrap
end;

procedure fxUpdate(dt: Single);
var
  i: Integer;
begin
  for i := 0 to FX_MAX1 do
  begin
    if fxLife[i] <= 0.0 then continue;
    fxLife[i] := fxLife[i] - dt;
    fxX[i] := fxX[i] + fxVx[i] * dt;
    fxY[i] := fxY[i] + fxVy[i] * dt;
  end;
  // Score popups (G6) age on the same clock as particles.
  // Piggybacks on the particle update to avoid a separate dt-forwarding call.
  for i := 0 to POP_MAX1 do
  begin
    if dgPopT[i] > 0.0 then dgPopT[i] := dgPopT[i] - dt;
  end;
end;

procedure fxDraw;
var
  i: Integer;
begin
  for i := 0 to FX_MAX1 do
  begin
    if fxLife[i] <= 0.0 then continue;
    // kind 0 = green burst; 1 = red burst; 2 = gold (fireball drip / gold pile)
    if fxKind[i] = 0 then
      dgSetFill(StrAddr(COL_FX_GREEN), 7)
    else if fxKind[i] = 1 then
      dgSetFill(StrAddr(COL_FX_RED), 7)
    else if fxKind[i] = 2 then
      dgSetFill(StrAddr(COL_GOLD), 7)  // gold particles use COL_GOLD, not COL_BAG
    else
      dgSetFill(StrAddr(COL_FX_GREEN), 7);  // safe fallback
    dgFillRect(fxX[i] - 2.0, fxY[i] - 2.0, 4.0, 4.0);
  end;
end;

end.
