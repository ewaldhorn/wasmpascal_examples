unit mp_sheep;

{ Port of sheep.odin: entity data + generic movement/needs. Knows nothing
  about troughs — trough-seeking lives in mp_game (mirrors the Odin split). }

interface

uses
  mp_defs,
  mp_rand,
  mp_world;

procedure NewSheep(var s: TSheep; id: Integer);

procedure SheepTickNeeds(var s: TSheep; dt: Double);

procedure SheepPickWander(var s: TSheep);

procedure SheepWander(var s: TSheep; dt: Double);

function SheepStepToward(var s: TSheep; tx, ty, dt: Double): Boolean;

procedure SheepFeed(var s: TSheep);

procedure SheepWater(var s: TSheep);

function SheepCanShear(var s: TSheep): Boolean;

function SheepShear(var s: TSheep): Integer;

implementation

procedure NewSheep(var s: TSheep; id: Integer);
begin
  BoundsRandomPoint;
  s.id := id;
  s.x := rnd_x;
  s.y := rnd_y;
  s.target_x := rnd_x;
  s.target_y := rnd_y;
  s.facing := 1.0;
  s.hunger := 65.0;
  s.thirst := 60.0;
  s.wool := 35.0;
  s.wander_timer := RngFloat * SHEEP_WANDER_MAX;
  s.bob_timer := RngFloat * 6.283185307179586;
  s.flash_timer := 0.0;
end;

procedure SheepTickNeeds(var s: TSheep; dt: Double);
begin
  if s.flash_timer > 0.0 then
    s.flash_timer := s.flash_timer - dt;
  s.hunger := s.hunger - HUNGER_DECAY_PER_SEC * dt;
  if s.hunger < 0.0 then s.hunger := 0.0;
  s.thirst := s.thirst - THIRST_DECAY_PER_SEC * dt;
  if s.thirst < 0.0 then s.thirst := 0.0;
  s.wool := s.wool + WOOL_GROWTH_PER_SEC * dt;
  if s.wool > 100.0 then s.wool := 100.0;
  s.bob_timer := s.bob_timer + dt;
end;

procedure SheepPickWander(var s: TSheep);
begin
  BoundsRandomPoint;
  s.target_x := rnd_x;
  s.target_y := rnd_y;
  s.wander_timer := SHEEP_WANDER_MIN +
    RngFloat * (SHEEP_WANDER_MAX - SHEEP_WANDER_MIN);
end;

function SheepStepToward(var s: TSheep; tx, ty, dt: Double): Boolean;
var
  dx, dy, dist, step: Double;
begin
  dx := tx - s.x;
  dy := ty - s.y;
  dist := mSqrt(dx * dx + dy * dy);
  if dist <= SHEEP_ARRIVE_DIST then
  begin
    SheepStepToward := true;
    Exit;
  end;
  step := SHEEP_SPEED * dt;
  if step > dist then step := dist;
  s.x := s.x + (dx / dist) * step;
  s.y := s.y + (dy / dist) * step;
  if dx > 0.5 then s.facing := 1.0
  else if dx < -0.5 then s.facing := -1.0;
  SheepStepToward := false;
end;

procedure SheepWander(var s: TSheep; dt: Double);
begin
  s.wander_timer := s.wander_timer - dt;
  if s.wander_timer <= 0.0 then
    SheepPickWander(s);
  SheepStepToward(s, s.target_x, s.target_y, dt);
end;

procedure SheepFeed(var s: TSheep);
begin
  s.hunger := 100.0;
  s.flash_timer := 0.5;
end;

procedure SheepWater(var s: TSheep);
begin
  s.thirst := 100.0;
  s.flash_timer := 0.5;
end;

function SheepCanShear(var s: TSheep): Boolean;
begin
  if s.wool >= SHEAR_THRESHOLD then SheepCanShear := true
  else SheepCanShear := false;
end;

function SheepShear(var s: TSheep): Integer;
begin
  SheepShear := Trunc(s.wool) div WOOL_TO_COIN_DIV;
  s.wool := 0.0;
  s.flash_timer := 0.5;
end;

begin
end.
