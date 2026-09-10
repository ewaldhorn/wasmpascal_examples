unit mp_world;

{ Port of world.odin. Bounds are world-space; outputs go through globals
  (wasmpascal has no local-address, same convention as sweep's bix/biy). }

interface

uses
  mp_defs,
  mp_rand;

var
  bnd_l: Double = 0.0;
  bnd_t: Double = 0.0;
  bnd_r: Double = 0.0;
  bnd_b: Double = 0.0;

function WorldW(level: Integer): Integer;

function WorldH(level: Integer): Integer;

function PaddockCap(level: Integer): Integer;

procedure BoundsFor(level: Integer);

procedure BoundsRandomPoint;

implementation

function WorldW(level: Integer): Integer;
begin
  WorldW := WORLD_BASE_W + level * WORLD_EXPAND_W;
end;

function WorldH(level: Integer): Integer;
begin
  WorldH := WORLD_BASE_H + level * WORLD_EXPAND_H;
end;

function PaddockCap(level: Integer): Integer;
begin
  PaddockCap := 10 + level * 10;
end;

procedure BoundsFor(level: Integer);
var
  w, h: Integer;
begin
  w := WorldW(level);
  h := WorldH(level);
  bnd_l := PADDOCK_MARGIN;
  bnd_t := PADDOCK_MARGIN;
  bnd_r := Double(w) - PADDOCK_MARGIN;
  bnd_b := Double(h) - PADDOCK_MARGIN;
end;

procedure BoundsRandomPoint;
begin
  rnd_x := bnd_l + RngFloat * (bnd_r - bnd_l);
  rnd_y := bnd_t + RngFloat * (bnd_b - bnd_t);
end;

begin
end.
