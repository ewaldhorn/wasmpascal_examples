// flfx.pas — FLIGHT LEADER effects: screen-space explosion particles, debris
// shards, expanding shockwave rings, and camera shake. Everything is 2D on
// the projected position where the victim died (the classic DOS feel —
// explosions are sprites, not 3D). Pools are fixed arrays; no allocation.
unit flfx;

interface

uses
  fldefs,
  flmath;

// Burst an explosion at canvas position (sx, sy); `scale` grows the effect
// with the victim (fighters small, capital ships huge).
procedure fxSpawnExplosion(sx, sy, scale: Single; big: Boolean);

// Advance/decay all pools; draw them (called inside the world transform so
// screen shake moves them with the world).
procedure fxUpdate(dt: Single);
procedure fxDraw;

// Clear all pools (new mission).
procedure fxReset;

// Camera shake.
procedure fxTriggerShake(amount: Single);
procedure fxUpdateShake(dt: Single);

implementation

procedure fxSpawnExplosion(sx, sy, scale: Single; big: Boolean);
var
  i, made: Integer;
  dir, spd: Single;
  n: Integer;
begin
  // particles
  made := 0;
  n := 16 + Integer(scale * 10.0);
  for i := 0 to MAX_PARTICLES - 1 do
  begin
    if made >= n then break;
    if particles[i].active then continue;
    particles[i].active := true;
    particles[i].x := sx;
    particles[i].y := sy;
    dir := RandRange(0.0, 6.283185307);
    spd := RandRange(30.0, 90.0 + scale * 90.0);
    particles[i].vx := fCos(dir) * spd;
    particles[i].vy := fSin(dir) * spd;
    particles[i].max_life := RandRange(0.35, 0.85);
    particles[i].life := particles[i].max_life;
    made := made + 1;
  end;
  // debris shards
  made := 0;
  n := 4 + Integer(scale * 4.0);
  for i := 0 to MAX_DEBRIS - 1 do
  begin
    if made >= n then break;
    if debris[i].active then continue;
    debris[i].active := true;
    debris[i].x := sx;
    debris[i].y := sy;
    dir := RandRange(0.0, 6.283185307);
    spd := RandRange(60.0, 120.0 + scale * 110.0);
    debris[i].vx := fCos(dir) * spd;
    debris[i].vy := fSin(dir) * spd;
    debris[i].ang := RandRange(0.0, 6.283185307);
    debris[i].spin := RandRange(-7.0, 7.0);
    debris[i].len := RandRange(3.0, 7.0) * (0.7 + scale * 0.5);
    debris[i].max_life := RandRange(0.5, 1.1);
    debris[i].life := debris[i].max_life;
    made := made + 1;
  end;
  // shockwave ring
  for i := 0 to MAX_SHOCKWAVES - 1 do
  begin
    if shocks[i].active then continue;
    shocks[i].active := true;
    shocks[i].x := sx;
    shocks[i].y := sy;
    shocks[i].r := 3.0;
    shocks[i].max_r := (26.0 + scale * 46.0);
    shocks[i].max_life := 0.42;
    shocks[i].life := 0.42;
    if big then shocks[i].max_r := shocks[i].max_r * 1.6;
    break;
  end;
end;

procedure fxUpdate(dt: Single);
var
  i: Integer;
  decay: Single;
begin
  decay := fPow(0.15, dt);
  for i := 0 to MAX_PARTICLES - 1 do
  begin
    if not particles[i].active then continue;
    particles[i].x := particles[i].x + particles[i].vx * dt;
    particles[i].y := particles[i].y + particles[i].vy * dt;
    particles[i].vx := particles[i].vx * decay;
    particles[i].vy := particles[i].vy * decay;
    particles[i].life := particles[i].life - dt;
    if particles[i].life <= 0 then particles[i].active := false;
  end;
  for i := 0 to MAX_DEBRIS - 1 do
  begin
    if not debris[i].active then continue;
    debris[i].x := debris[i].x + debris[i].vx * dt;
    debris[i].y := debris[i].y + debris[i].vy * dt;
    debris[i].vx := debris[i].vx * decay;
    debris[i].vy := debris[i].vy * decay;
    debris[i].ang := debris[i].ang + debris[i].spin * dt;
    debris[i].life := debris[i].life - dt;
    if debris[i].life <= 0 then debris[i].active := false;
  end;
  for i := 0 to MAX_SHOCKWAVES - 1 do
  begin
    if not shocks[i].active then continue;
    shocks[i].life := shocks[i].life - dt;
    if shocks[i].life <= 0 then
    begin
      shocks[i].active := false;
      continue;
    end;
    shocks[i].r := shocks[i].max_r * (1.0 - shocks[i].life / shocks[i].max_life);
  end;
end;

procedure fxDraw;
var
  i: Integer;
  a, c, s, hx, hy: Single;
begin
  // particles: warm glow dots, alpha by remaining life
  bSetFill(StrAddr('#ffce7a'), 7);
  for i := 0 to MAX_PARTICLES - 1 do
  begin
    if not particles[i].active then continue;
    a := particles[i].life / particles[i].max_life;
    bSetGlobalAlpha(a);
    bFillRect(particles[i].x - 1, particles[i].y - 1, 2, 2);
  end;
  bSetGlobalAlpha(1.0);

  // debris: bright shards
  bSetStroke(StrAddr('#ffe8c0'), 7);
  bSetLineWidth(1.4);
  for i := 0 to MAX_DEBRIS - 1 do
  begin
    if not debris[i].active then continue;
    a := debris[i].life / debris[i].max_life;
    bSetGlobalAlpha(a);
    c := fCos(debris[i].ang);
    s := fSin(debris[i].ang);
    hx := c * debris[i].len * 0.5;
    hy := s * debris[i].len * 0.5;
    bBeginPath;
    bMoveTo(debris[i].x - hx, debris[i].y - hy);
    bLineTo(debris[i].x + hx, debris[i].y + hy);
    bStroke;
  end;
  bSetGlobalAlpha(1.0);

  // shockwaves: expanding cyan rings
  bSetStroke(StrAddr('#8fd8ff'), 7);
  for i := 0 to MAX_SHOCKWAVES - 1 do
  begin
    if not shocks[i].active then continue;
    a := shocks[i].life / shocks[i].max_life;
    bSetGlobalAlpha(a * 0.8);
    bSetLineWidth(2.0 + 3.0 * (1.0 - a));
    bBeginPath;
    bArc(shocks[i].x, shocks[i].y, shocks[i].r, 0.0, 6.283185307);
    bStroke;
  end;
  bSetGlobalAlpha(1.0);
end;

procedure fxReset;
var
  i: Integer;
begin
  for i := 0 to MAX_PARTICLES - 1 do particles[i].active := false;
  for i := 0 to MAX_DEBRIS - 1 do debris[i].active := false;
  for i := 0 to MAX_SHOCKWAVES - 1 do shocks[i].active := false;
  shake_mag := 0; shake_x := 0; shake_y := 0;
end;

procedure fxTriggerShake(amount: Single);
begin
  if amount > shake_mag then shake_mag := amount;
end;

procedure fxUpdateShake(dt: Single);
begin
  if shake_mag > 0.05 then
  begin
    shake_x := RandRange(-shake_mag, shake_mag);
    shake_y := RandRange(-shake_mag, shake_mag);
    shake_mag := shake_mag * fPow(0.02, dt);
  end else begin
    shake_mag := 0;
    shake_x := 0;
    shake_y := 0;
  end;
end;

end.
