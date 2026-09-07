// flsim.pas — FLIGHT LEADER simulation: flight model, weapons (lasers +
// missiles + lock), enemy AI (inbound/attack/evade/retreat/capital), wave
// spawning, collisions, damage, scoring, and mission flow. All entities live
// in world space; the camera (player pos/yaw/pitch) is applied at render
// time. Pools are fixed arrays — no allocation, no pointers.
unit flsim;

interface

uses
  fldefs,
  flmath,
  flfx;

// mission flow
procedure simStartMission;
procedure simStartWave;
procedure simUpdate(dt: Single);
procedure simInitStars;
procedure simHandleMissile;      // Tab: acquire lock / fire
procedure simAdvanceState;       // Enter: skip an overlay
procedure simRespawnStar(i: Integer);

// accessors for the debrief / HUD
function simEnemiesAlive: Integer;
function simAccuracy: Integer;          // percent
function simRankText(buf: PByte): Integer;  // writes rank string, returns len

implementation

// ---------------------------------------------------------------------------
// Messages (top-of-screen mission text)
// ---------------------------------------------------------------------------
var
  // rank words for the debrief (filled by the unit init body; no array
  // constants/initializers in this Pascal subset)
  RW_ROOKIE: array[0..5] of Byte;
  RW_OFFICER: array[0..6] of Byte;
  RW_CAPTAIN: array[0..6] of Byte;
  RW_ACE: array[0..2] of Byte;

procedure simSetMsg(p: PByte; n: Integer);
var
  i: Integer;
begin
  msg_len := n;
  msg_timer := 3.2;
  for i := 0 to n - 1 do
  begin
    if i < 64 then msg_buf[i] := p[i];
  end;
end;

// ---------------------------------------------------------------------------
// Starfield
// ---------------------------------------------------------------------------
procedure simInitStars;
var
  i: Integer;
  layer: Integer;
  dir_x, dir_y, dir_z, r: Single;
begin
  for i := 0 to MAX_STARS - 1 do
  begin
    layer := i mod 3;
    stars[i].layer := layer;
    // random direction, random radius per layer (far: small+dense, near: big)
    dir_x := RandRange(-1.0, 1.0);
    dir_y := RandRange(-1.0, 1.0);
    dir_z := RandRange(0.2, 1.0);   // bias to the front hemisphere
    v3norm(dir_x, dir_y, dir_z, dir_x, dir_y, dir_z);
    if layer = 0 then r := RandRange(2200.0, 5200.0)
    else if layer = 1 then r := RandRange(1100.0, 2400.0)
    else r := RandRange(350.0, 1200.0);
    stars[i].wx := player.px + dir_x * r;
    stars[i].wy := player.py + dir_y * r;
    stars[i].wz := player.pz + dir_z * r;
    stars[i].tw := RandRange(0.0, 6.283185307);
  end;
end;

// Respawn stars that fall behind the camera (called per frame by the renderer).
procedure simRespawnStar(i: Integer);
var
  dir_x, dir_y, dir_z, r: Single;
begin
  dir_x := RandRange(-1.0, 1.0);
  dir_y := RandRange(-1.0, 1.0);
  dir_z := RandRange(0.2, 1.0);
  v3norm(dir_x, dir_y, dir_z, dir_x, dir_y, dir_z);
  if stars[i].layer = 0 then r := RandRange(2200.0, 5200.0)
  else if stars[i].layer = 1 then r := RandRange(1100.0, 2400.0)
  else r := RandRange(350.0, 1200.0);
  stars[i].wx := player.px + dir_x * r;
  stars[i].wy := player.py + dir_y * r;
  stars[i].wz := player.pz + dir_z * r;
end;

// ---------------------------------------------------------------------------
// Wave / enemy spawning
// ---------------------------------------------------------------------------
procedure simSpawnEnemy(cls: Integer; ox, oy, oz: Single);
var
  i: Integer;
begin
  for i := 0 to MAX_ENEMIES - 1 do
  begin
    if enemies[i].alive then continue;
    enemies[i].alive := true;
    enemies[i].px := player.px + ox;
    enemies[i].py := player.py + oy;
    enemies[i].pz := player.pz + oz;
    enemies[i].vx := 0; enemies[i].vy := 0; enemies[i].vz := 0;
    enemies[i].cooldown := RandRange(0.4, 1.6);
    enemies[i].jink_phase := RandRange(0.0, 6.283185307);
    enemies[i].evade_timer := 0;
    enemies[i].hit_flash := 0;
    if cls = EC_FIGHTER then
    begin
      enemies[i].max_hp := 30.0;
      enemies[i].radius := 22.0;
      enemies[i].score := SCORE_FIGHTER;
    end
    else if cls = EC_GUNBOAT then
    begin
      enemies[i].max_hp := 90.0;
      enemies[i].radius := 34.0;
      enemies[i].score := SCORE_GUNBOAT;
    end
    else begin
      enemies[i].max_hp := 420.0;
      enemies[i].radius := 80.0;
      enemies[i].score := SCORE_CAPITAL;
    end;
    enemies[i].hp := enemies[i].max_hp;
    enemies[i].cls := cls;
    if cls = EC_CAPITAL then enemies[i].state := ES_CAPITAL
    else enemies[i].state := ES_INBOUND;
    exit;
  end;
end;

procedure simStartWave;
var
  fwd_x, fwd_y, fwd_z: Single;
  i: Integer;
  off_yaw, off_pitch: Single;
  t1x, t1y, t1z: Single;
begin
  wave := wave + 1;
  game_state := GS_FLIGHT;   // leave the briefing overlay; the sim now runs
  PlayerForward(fwd_x, fwd_y, fwd_z);

  // spread spawn points around the forward point
  if wave = 1 then
  begin
    for i := 0 to 2 do
    begin
      off_yaw := RandRange(-0.9, 0.9);
      off_pitch := RandRange(-0.5, 0.5);
      RotY(off_yaw, 0, 0, 1, t1x, t1y, t1z);
      RotX(off_pitch, t1x, t1y, t1z, fwd_x, fwd_y, fwd_z);
      simSpawnEnemy(EC_FIGHTER, fwd_x * ENEMY_SPAWN_SPREAD, fwd_y * ENEMY_SPAWN_SPREAD, fwd_z * ENEMY_SPAWN_SPREAD);
    end;
    simSetMsg(StrAddr('WAVE 1 - HOSTILES INBOUND'), 23);
  end
  else if wave = 2 then
  begin
    for i := 0 to 3 do
    begin
      off_yaw := RandRange(-1.2, 1.2);
      off_pitch := RandRange(-0.6, 0.6);
      RotY(off_yaw, 0, 0, 1, t1x, t1y, t1z);
      RotX(off_pitch, t1x, t1y, t1z, fwd_x, fwd_y, fwd_z);
      simSpawnEnemy(EC_FIGHTER, fwd_x * ENEMY_SPAWN_SPREAD, fwd_y * ENEMY_SPAWN_SPREAD, fwd_z * ENEMY_SPAWN_SPREAD);
    end;
    RotY(0.2, 0, 0, 1, t1x, t1y, t1z);
    RotX(0.1, t1x, t1y, t1z, fwd_x, fwd_y, fwd_z);
    simSpawnEnemy(EC_GUNBOAT, fwd_x * 500.0, fwd_y * 500.0, fwd_z * 500.0);
    simSetMsg(StrAddr('WAVE 2 - GUNBOAT DETECTED'), 24);
  end
  else begin
    for i := 0 to 2 do
    begin
      off_yaw := RandRange(-1.4, 1.4);
      off_pitch := RandRange(-0.7, 0.7);
      RotY(off_yaw, 0, 0, 1, t1x, t1y, t1z);
      RotX(off_pitch, t1x, t1y, t1z, fwd_x, fwd_y, fwd_z);
      simSpawnEnemy(EC_FIGHTER, fwd_x * ENEMY_SPAWN_SPREAD, fwd_y * ENEMY_SPAWN_SPREAD, fwd_z * ENEMY_SPAWN_SPREAD);
    end;
    RotY(-0.15, 0, 0, 1, t1x, t1y, t1z);
    RotX(-0.05, t1x, t1y, t1z, fwd_x, fwd_y, fwd_z);
    simSpawnEnemy(EC_GUNBOAT, fwd_x * 600.0, fwd_y * 600.0, fwd_z * 600.0);
    RotY(0.1, 0, 0, 1, t1x, t1y, t1z);
    simSpawnEnemy(EC_CAPITAL, fwd_x * 900.0, fwd_y * 900.0, fwd_z * 900.0);
    simSetMsg(StrAddr('WAVE 3 - CAPITAL SHIP!'), 21);
  end;
end;

// ---------------------------------------------------------------------------
// Mission setup
// ---------------------------------------------------------------------------
procedure simStartMission;
var
  i: Integer;
begin
  // player
  player.px := 0; player.py := 0; player.pz := 0;
  player.yaw := 0; player.pitch := 0; player.bank := 0;
  player.throttle := 50.0;
  player.speed := 0;
  player.afterburn := false;
  player.shields := PLAYER_MAX_SHIELDS;
  player.hull := PLAYER_MAX_HULL;
  player.missile_count := MISSILE_START;
  player.laser_cd := 0;
  player.shield_cd := 0;
  player.lock_target := -1;
  player.lock_timer := 0;
  player.locked := false;
  lock_beeped := false;

  // pools
  for i := 0 to MAX_ENEMIES - 1 do enemies[i].alive := false;
  for i := 0 to MAX_PBOLTS - 1 do pbolts[i].active := false;
  for i := 0 to MAX_EBOLTS - 1 do ebolts[i].active := false;
  for i := 0 to MAX_MISSILES - 1 do missiles[i].active := false;
  fxReset;

  score := 0;
  kills := 0;
  shots_fired := 0;
  shots_hit := 0;
  wave := 0;
  paused := false;
  state_timer := 0;
  shake_mag := 0;
  game_state := GS_BRIEFING;
  if thrust_on then
  begin
    thrust_on := false;
    aSetThrust(0);
  end;
  simInitStars;
end;

// ---------------------------------------------------------------------------
// Player flight + weapons
// ---------------------------------------------------------------------------
procedure simUpdateFlight(dt: Single);
var
  yaw_rate, pitch_rate, target_bank: Single;
  fwd_x, fwd_y, fwd_z, spd: Single;
  accel: Single;
  kb_yaw, kb_pitch: Single;
begin
  // keyboard steering (arrow keys) — the only steering; there is no mouse.
  kb_yaw := 0.0;
  kb_pitch := 0.0;
  if keys[KEY_LEFT] then kb_yaw := kb_yaw - 1.0;
  if keys[KEY_RIGHT] then kb_yaw := kb_yaw + 1.0;
  if keys[KEY_UP] then kb_pitch := kb_pitch + 1.0;
  if keys[KEY_DOWN] then kb_pitch := kb_pitch - 1.0;

  yaw_rate := kb_yaw * TURN_RATE;
  pitch_rate := kb_pitch * TURN_RATE;

  player.yaw := player.yaw + yaw_rate * dt;
  player.pitch := fclamp(player.pitch + pitch_rate * dt, -1.45, 1.45);

  // bank into the turn (visual roll), eased
  target_bank := -yaw_rate * 0.55;
  if target_bank > 0.9 then target_bank := 0.9;
  if target_bank < -0.9 then target_bank := -0.9;
  player.bank := flerp(player.bank, target_bank, fclamp(6.0 * dt, 0.0, 1.0));

  // throttle (W/S; the arrow keys are flight controls now)
  if keys[KEY_W] then
    player.throttle := fclamp(player.throttle + THROTTLE_RATE * dt, 0.0, 100.0);
  if keys[KEY_S] then
    player.throttle := fclamp(player.throttle - THROTTLE_RATE * dt, 0.0, 100.0);

  player.afterburn := keys[KEY_SHIFT] and (player.throttle > 4.0);
  spd := if player.afterburn then AFTERBURN_SPEED else CRUISE_SPEED * (player.throttle / 100.0);
  // smooth speed (accelerate, don't teleport)
  accel := fclamp(3.0 * dt, 0.0, 1.0);
  player.speed := flerp(player.speed, spd, accel);

  // engine hum
  if (player.speed > 30.0) <> thrust_on then
  begin
    thrust_on := player.speed > 30.0;
    if thrust_on then aSetThrust(1) else aSetThrust(0);
  end;

  // move
  PlayerForward(fwd_x, fwd_y, fwd_z);
  player.px := player.px + fwd_x * player.speed * dt;
  player.py := player.py + fwd_y * player.speed * dt;
  player.pz := player.pz + fwd_z * player.speed * dt;

  // shield regen
  if player.shield_cd > 0 then player.shield_cd := player.shield_cd - dt;
  if player.shield_cd <= 0 then
    player.shields := fclamp(player.shields + SHIELD_REGEN * dt, 0.0, PLAYER_MAX_SHIELDS);
  if player.laser_cd > 0 then player.laser_cd := player.laser_cd - dt;
end;

// Fire the twin wing lasers from the player position.
procedure simFireLasers;
var
  i, made: Integer;
  fwd_x, fwd_y, fwd_z, right_x, right_y, right_z, up_x, up_y, up_z: Single;
  spd_x, spd_y, spd_z: Single;
begin
  made := 0;
  PlayerForward(fwd_x, fwd_y, fwd_z);
  up_x := 0; up_y := 1; up_z := 0;
  v3cross(up_x, up_y, up_z, fwd_x, fwd_y, fwd_z, right_x, right_y, right_z);
  v3norm(right_x, right_y, right_z, right_x, right_y, right_z);
  spd_x := fwd_x * LASER_SPEED + fwd_x * player.speed;
  spd_y := fwd_y * LASER_SPEED + fwd_y * player.speed;
  spd_z := fwd_z * LASER_SPEED + fwd_z * player.speed;
  for i := 0 to MAX_PBOLTS - 1 do
  begin
    if made >= 2 then break;
    if pbolts[i].active then continue;
    pbolts[i].active := true;
    if made = 0 then
    begin
      pbolts[i].px := player.px + right_x * 9.0;
      pbolts[i].py := player.py + right_y * 9.0;
      pbolts[i].pz := player.pz + right_z * 9.0;
    end else begin
      pbolts[i].px := player.px - right_x * 9.0;
      pbolts[i].py := player.py - right_y * 9.0;
      pbolts[i].pz := player.pz - right_z * 9.0;
    end;
    pbolts[i].vx := spd_x;
    pbolts[i].vy := spd_y;
    pbolts[i].vz := spd_z;
    pbolts[i].life := LASER_LIFE;
    made := made + 1;
  end;
  shots_fired := shots_fired + made;
  aPlaySound(SND_FIRE);
end;

// Acquire or refresh a missile lock; fire when locked.
procedure simHandleMissile;
var
  i, best: Integer;
  best_dot, dist, dotv: Single;
  fwd_x, fwd_y, fwd_z: Single;
  tx, ty, tz: Single;
begin
  if player.missile_count <= 0 then
  begin
    simSetMsg(StrAddr('NO MISSILES'), 11);
    exit;
  end;
  PlayerForward(fwd_x, fwd_y, fwd_z);

  if player.locked then
  begin
    // fire at the locked target
    if (player.lock_target >= 0) and enemies[player.lock_target].alive then
    begin
      for i := 0 to MAX_MISSILES - 1 do
      begin
        if missiles[i].active then continue;
        missiles[i].active := true;
        missiles[i].px := player.px + fwd_x * 24.0;
        missiles[i].py := player.py + fwd_y * 24.0;
        missiles[i].pz := player.pz + fwd_z * 24.0;
        missiles[i].vx := fwd_x * 320.0;
        missiles[i].vy := fwd_y * 320.0;
        missiles[i].vz := fwd_z * 320.0;
        missiles[i].life := MISSILE_LIFE;
        missiles[i].target := player.lock_target;
        player.missile_count := player.missile_count - 1;
        aPlaySound(SND_LAUNCH);
        break;
      end;
    end;
    player.locked := false;
    player.lock_target := -1;
    lock_beeped := false;
    exit;
  end;

  // acquire: nearest enemy inside the lock cone
  best := -1;
  best_dot := LOCK_CONE;
  for i := 0 to MAX_ENEMIES - 1 do
  begin
    if not enemies[i].alive then continue;
    tx := enemies[i].px - player.px;
    ty := enemies[i].py - player.py;
    tz := enemies[i].pz - player.pz;
    dist := v3len(tx, ty, tz);
    if dist > LOCK_RANGE then continue;
    if dist < 1.0 then continue;
    dotv := (tx * fwd_x + ty * fwd_y + tz * fwd_z) / dist;
    if dotv > best_dot then
    begin
      best_dot := dotv;
      best := i;
    end;
  end;
  player.lock_target := best;
  player.lock_timer := 0;
  player.locked := false;
  lock_beeped := false;
  if best >= 0 then aPlaySound(SND_LOCK);
end;

procedure simUpdateLock(dt: Single);
var
  i: Integer;
  fwd_x, fwd_y, fwd_z: Single;
  tx, ty, tz, dist, dotv: Single;
  still: Boolean;
begin
  still := false;
  i := player.lock_target;
  if i >= 0 then
  begin
    if enemies[i].alive then
    begin
      tx := enemies[i].px - player.px;
      ty := enemies[i].py - player.py;
      tz := enemies[i].pz - player.pz;
      dist := v3len(tx, ty, tz);
      if dist <= LOCK_RANGE then
      begin
        PlayerForward(fwd_x, fwd_y, fwd_z);
        dotv := (tx * fwd_x + ty * fwd_y + tz * fwd_z) / dist;
        if dotv > LOCK_CONE * 0.6 then still := true;
      end;
    end;
  end;
  if not still then
  begin
    player.lock_target := -1;
    player.locked := false;
    lock_beeped := false;
    exit;
  end;
  player.lock_timer := player.lock_timer + dt;
  if (player.lock_timer >= LOCK_TIME) and (not player.locked) then
  begin
    player.locked := true;
    aPlaySound(SND_LOCK);
  end;
end;

// ---------------------------------------------------------------------------
// Enemy AI
// ---------------------------------------------------------------------------
// Steer `vx,vy,vz` toward the DESIRED VELOCITY `dx,dy,dz` (any magnitude):
// the direction rotates at max `turn` rad/s, and the speed eases to |desired|.
// Generic — used by every AI state. Desired velocities are built as
// player_velocity + pursuit offset, so enemies glide WITH the player instead
// of falling behind a fast-moving target.
procedure simSteer(var vx, vy, vz: Single; dx, dy, dz: Single; turn, dt: Single);
var
  dlen, cur_x, cur_y, cur_z: Single;
  mix: Single;
begin
  dlen := v3len(dx, dy, dz);
  if dlen < 1.0 then dlen := 1.0;
  v3norm(vx, vy, vz, cur_x, cur_y, cur_z);
  mix := fclamp(turn * dt, 0.0, 1.0);
  vx := cur_x + (dx / dlen - cur_x) * mix;
  vy := cur_y + (dy / dlen - cur_y) * mix;
  vz := cur_z + (dz / dlen - cur_z) * mix;
  v3norm(vx, vy, vz, cur_x, cur_y, cur_z);
  vx := cur_x * dlen; vy := cur_y * dlen; vz := cur_z * dlen;
end;

procedure simEnemyFire(ei: Integer; dx, dy, dz: Single; spread: Single);
var
  i: Integer;
  bd_x, bd_y, bd_z: Single;
begin
  for i := 0 to MAX_EBOLTS - 1 do
  begin
    if ebolts[i].active then continue;
    ebolts[i].active := true;
    bd_x := dx; bd_y := dy; bd_z := dz;
    if spread > 0 then
    begin
      RotY(RandRange(-spread, spread), bd_x, bd_y, bd_z, bd_x, bd_y, bd_z);
      RotX(RandRange(-spread * 0.6, spread * 0.6), bd_x, bd_y, bd_z, bd_x, bd_y, bd_z);
    end;
    ebolts[i].px := enemies[ei].px + bd_x * enemies[ei].radius;
    ebolts[i].py := enemies[ei].py + bd_y * enemies[ei].radius;
    ebolts[i].pz := enemies[ei].pz + bd_z * enemies[ei].radius;
    ebolts[i].vx := bd_x * ENEMY_LASER_SPEED;
    ebolts[i].vy := bd_y * ENEMY_LASER_SPEED;
    ebolts[i].vz := bd_z * ENEMY_LASER_SPEED;
    ebolts[i].life := 3.0;
    aPlaySound(SND_THUD);
    exit;
  end;
end;

procedure simUpdateEnemy(ei: Integer; dt: Single);
var
  e: Integer;
  tp_x, tp_y, tp_z, dist: Single;
  dir_x, dir_y, dir_z: Single;
  side_x, side_y, side_z: Single;
  up_x, up_y, up_z: Single;
  fwd_x, fwd_y, fwd_z: Single;
  pv_x, pv_y, pv_z: Single;
  d_x, d_y, d_z: Single;
  turn: Single;
  jink, close: Single;
begin
  e := ei;
  // the player's current velocity (world)
  PlayerForward(fwd_x, fwd_y, fwd_z);
  pv_x := fwd_x * player.speed;
  pv_y := fwd_y * player.speed;
  pv_z := fwd_z * player.speed;
  // unit vector toward the player
  tp_x := player.px - enemies[e].px;
  tp_y := player.py - enemies[e].py;
  tp_z := player.pz - enemies[e].pz;
  dist := v3len(tp_x, tp_y, tp_z);
  if dist < 0.001 then dist := 0.001;
  dir_x := tp_x / dist; dir_y := tp_y / dist; dir_z := tp_z / dist;

  // per-state behaviour. Every state builds a DESIRED VELOCITY
  // (player velocity + an offset), so the enemy keeps pace with the player
  // instead of falling behind a fast-moving target.
  if enemies[e].state = ES_INBOUND then
  begin
    // close in: pursuit at a closing speed that brakes as it nears
    close := fclamp(dist * 0.5, 130.0, ENEMY_MAX_SPEED);
    d_x := pv_x + dir_x * close;
    d_y := pv_y + dir_y * close;
    d_z := pv_z + dir_z * close;
    turn := ENEMY_TURN;
    if dist < 720.0 then enemies[e].state := ES_ATTACK;
  end
  else if enemies[e].state = ES_ATTACK then
  begin
    // orbit: player velocity + a slow lateral circle with attack darts
    up_x := 0; up_y := 1; up_z := 0;
    v3cross(dir_x, dir_y, dir_z, up_x, up_y, up_z, side_x, side_y, side_z);
    v3norm(side_x, side_y, side_z, side_x, side_y, side_z);
    enemies[e].jink_phase := enemies[e].jink_phase + dt * 1.3;
    jink := fclamp(fSin(enemies[e].jink_phase), 0.0, 1.0);  // 0..1 dart pulse
    if dist < 430.0 then
    begin
      // too close: circle outward
      d_x := pv_x + (-dir_x * 0.7 + side_x * 0.75) * 150.0;
      d_y := pv_y + (-dir_y * 0.7 + side_y * 0.75) * 150.0;
      d_z := pv_z + (-dir_z * 0.7 + side_z * 0.75) * 150.0;
    end else begin
      d_x := pv_x + (dir_x * (0.35 + 0.5 * jink) + side_x * 0.85) * 150.0;
      d_y := pv_y + (dir_y * (0.35 + 0.5 * jink) + side_y * 0.85) * 150.0;
      d_z := pv_z + (dir_z * (0.35 + 0.5 * jink) + side_z * 0.85) * 150.0;
    end;
    turn := ENEMY_TURN * 0.95;
    // fire when aligned
    if enemies[e].cooldown <= 0 then
    begin
      if dist < ENEMY_FIRE_RANGE then
      begin
        // facing check: velocity direction vs the player, normalised
        if v3dot(enemies[e].vx, enemies[e].vy, enemies[e].vz, dir_x, dir_y, dir_z)
           > v3len(enemies[e].vx, enemies[e].vy, enemies[e].vz) * ENEMY_FIRE_ALIGN then
        begin
          simEnemyFire(e, dir_x, dir_y, dir_z, 0.05);
          enemies[e].cooldown := ENEMY_COOLDOWN;
        end;
      end;
    end;
  end
  else if enemies[e].state = ES_EVADE then
  begin
    // flee + jink (velocity-matched: still keeps pace with the player)
    up_x := 0; up_y := 1; up_z := 0;
    v3cross(dir_x, dir_y, dir_z, up_x, up_y, up_z, side_x, side_y, side_z);
    v3norm(side_x, side_y, side_z, side_x, side_y, side_z);
    enemies[e].jink_phase := enemies[e].jink_phase + dt * 6.0;
    jink := fSin(enemies[e].jink_phase) * 0.5;
    d_x := pv_x + (-dir_x * 1.15 + side_x * jink) * ENEMY_MAX_SPEED;
    d_y := pv_y + (-dir_y * 1.15 + side_y * jink) * ENEMY_MAX_SPEED;
    d_z := pv_z + (-dir_z * 1.15 + side_z * jink) * ENEMY_MAX_SPEED;
    turn := ENEMY_TURN * 1.4;
    enemies[e].evade_timer := enemies[e].evade_timer - dt;
    if enemies[e].evade_timer <= 0 then enemies[e].state := ES_ATTACK;
  end
  else if enemies[e].state = ES_RETREAT then
  begin
    // run away fast (velocity-matched: pulls ahead of the player)
    d_x := pv_x - dir_x * ENEMY_MAX_SPEED * 1.4;
    d_y := pv_y - dir_y * ENEMY_MAX_SPEED * 1.4;
    d_z := pv_z - dir_z * ENEMY_MAX_SPEED * 1.4;
    turn := ENEMY_TURN * 1.5;
    if dist > 3600.0 then
    begin
      enemies[e].alive := false;  // fled the sector
      exit;
    end;
  end
  else begin
    // ES_CAPITAL: slow, relentless, turrets (keeps pace with the player)
    d_x := pv_x + dir_x * CAPITAL_SPEED;
    d_y := pv_y + dir_y * CAPITAL_SPEED;
    d_z := pv_z + dir_z * CAPITAL_SPEED;
    turn := 0.15;
    if enemies[e].cooldown <= 0 then
    begin
      if dist < ENEMY_FIRE_RANGE * 1.25 then
      begin
        simEnemyFire(e, dir_x, dir_y, dir_z, 0.16);
        enemies[e].cooldown := 0.9;
      end;
    end;
  end;

  if enemies[e].cooldown > 0 then enemies[e].cooldown := enemies[e].cooldown - dt;
  if enemies[e].hit_flash > 0 then enemies[e].hit_flash := enemies[e].hit_flash - dt;

  // steer + integrate
  simSteer(enemies[e].vx, enemies[e].vy, enemies[e].vz, d_x, d_y, d_z, turn, dt);
  enemies[e].px := enemies[e].px + enemies[e].vx * dt;
  enemies[e].py := enemies[e].py + enemies[e].vy * dt;
  enemies[e].pz := enemies[e].pz + enemies[e].vz * dt;
end;

// ---------------------------------------------------------------------------
// Damage / deaths
// ---------------------------------------------------------------------------
procedure simKillEnemy(i: Integer);
var
  sx, sy, scale: Single;
  visible: Boolean;
begin
  score := score + enemies[i].score;
  kills := kills + 1;
  if enemies[i].cls = EC_FIGHTER then
  begin
    aPlaySound(SND_BANG_SMALL);
    fxTriggerShake(5.0);
  end
  else if enemies[i].cls = EC_GUNBOAT then
  begin
    aPlaySound(SND_BANG_MED);
    fxTriggerShake(9.0);
  end
  else begin
    aPlaySound(SND_BANG_LARGE);
    fxTriggerShake(16.0);
  end;
  ProjToScreen(enemies[i].px, enemies[i].py, enemies[i].pz, sx, sy, scale, visible);
  if visible then
  begin
    if enemies[i].cls = EC_FIGHTER then fxSpawnExplosion(sx, sy, 1.0, false)
    else if enemies[i].cls = EC_GUNBOAT then fxSpawnExplosion(sx, sy, 2.0, false)
    else fxSpawnExplosion(sx, sy, 3.4, true);
  end;
  enemies[i].alive := false;
end;

procedure simDamageEnemy(i: Integer; dmg: Single);
var
  sx, sy, scale: Single;
  visible: Boolean;
begin
  enemies[i].hp := enemies[i].hp - dmg;
  enemies[i].hit_flash := 0.12;
  if enemies[i].hp <= 0 then
  begin
    simKillEnemy(i);
    exit;
  end;
  // hurt → evade/retreat (class-based: fighters fight to the death, the
  // gunboat quits at ~30%, the capital never retreats)
  if (enemies[i].cls <> EC_CAPITAL) and (enemies[i].state <> ES_RETREAT) then
  begin
    if (enemies[i].cls = EC_GUNBOAT) and (enemies[i].hp < enemies[i].max_hp * RETREAT_HP) then
      enemies[i].state := ES_RETREAT
    else if (enemies[i].cls = EC_FIGHTER) and (enemies[i].hp < enemies[i].max_hp * 0.05) then
      enemies[i].state := ES_RETREAT
    else if enemies[i].state <> ES_EVADE then
    begin
      enemies[i].state := ES_EVADE;
      enemies[i].evade_timer := EVADE_TIME;
    end;
  end;
  // small impact puff at the projected hit point
  ProjToScreen(enemies[i].px, enemies[i].py, enemies[i].pz, sx, sy, scale, visible);
  if visible then fxSpawnExplosion(sx, sy, 0.35, false);
end;

procedure simKillPlayer;
var
  i: Integer;
begin
  aPlaySound(SND_SHIP_DEATH);
  fxSpawnExplosion(Single(CW) * 0.5, Single(CH) * 0.5, 2.6, true);
  fxTriggerShake(15.0);
  if thrust_on then
  begin
    thrust_on := false;
    aSetThrust(0);
  end;
  game_state := GS_DEAD;
  state_timer := 2.2;
end;

procedure simDamagePlayer(dmg: Single);
begin
  player.shield_cd := SHIELD_DELAY;
  player.shields := player.shields - dmg;
  aPlaySound(SND_SHIELD);
  fxTriggerShake(2.5);
  if player.shields < 0 then
  begin
    player.hull := player.hull + player.shields;
    player.shields := 0;
    if player.hull <= 0 then
    begin
      player.hull := 0;
      simKillPlayer;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Collisions
// ---------------------------------------------------------------------------
procedure simUpdateCollisions(dt: Single);
var
  i, j: Integer;
  d2, rr: Single;
  sx, sy, scale: Single;
  visible: Boolean;
begin
  // player lasers vs enemies
  for i := 0 to MAX_PBOLTS - 1 do
  begin
    if not pbolts[i].active then continue;
    for j := 0 to MAX_ENEMIES - 1 do
    begin
      if not enemies[j].alive then continue;
      rr := enemies[j].radius + BOLT_RADIUS;
      d2 := (pbolts[i].px - enemies[j].px) * (pbolts[i].px - enemies[j].px)
          + (pbolts[i].py - enemies[j].py) * (pbolts[i].py - enemies[j].py)
          + (pbolts[i].pz - enemies[j].pz) * (pbolts[i].pz - enemies[j].pz);
      if d2 <= rr * rr then
      begin
        pbolts[i].active := false;
        shots_hit := shots_hit + 1;
        simDamageEnemy(j, LASER_DAMAGE);
        break;
      end;
    end;
  end;

  // missiles vs enemies (proximity fuse)
  for i := 0 to MAX_MISSILES - 1 do
  begin
    if not missiles[i].active then continue;
    j := missiles[i].target;
    if (j >= 0) and enemies[j].alive then
    begin
      rr := enemies[j].radius + MISSILE_FUSE;
      d2 := (missiles[i].px - enemies[j].px) * (missiles[i].px - enemies[j].px)
          + (missiles[i].py - enemies[j].py) * (missiles[i].py - enemies[j].py)
          + (missiles[i].pz - enemies[j].pz) * (missiles[i].pz - enemies[j].pz);
      if d2 <= rr * rr then
      begin
        missiles[i].active := false;
        simDamageEnemy(j, MISSILE_DAMAGE);
        ProjToScreen(missiles[i].px, missiles[i].py, missiles[i].pz, sx, sy, scale, visible);
        if visible then fxSpawnExplosion(sx, sy, 1.6, false);
        fxTriggerShake(6.0);
        continue;
      end;
    end;
  end;

  // enemy lasers vs player
  for i := 0 to MAX_EBOLTS - 1 do
  begin
    if not ebolts[i].active then continue;
    d2 := (ebolts[i].px - player.px) * (ebolts[i].px - player.px)
        + (ebolts[i].py - player.py) * (ebolts[i].py - player.py)
        + (ebolts[i].pz - player.pz) * (ebolts[i].pz - player.pz);
    if d2 <= PLAYER_RADIUS * PLAYER_RADIUS then
    begin
      ebolts[i].active := false;
      simDamagePlayer(ENEMY_LASER_DAMAGE);
      if game_state <> GS_FLIGHT then exit;
    end;
  end;

  // ramming
  if game_state = GS_FLIGHT then
  begin
    for j := 0 to MAX_ENEMIES - 1 do
    begin
      if not enemies[j].alive then continue;
      rr := enemies[j].radius + PLAYER_RADIUS;
      d2 := (enemies[j].px - player.px) * (enemies[j].px - player.px)
          + (enemies[j].py - player.py) * (enemies[j].py - player.py)
          + (enemies[j].pz - player.pz) * (enemies[j].pz - player.pz);
      if d2 <= rr * rr then
      begin
        simKillEnemy(j);
        simDamagePlayer(28.0);
        if game_state <> GS_FLIGHT then exit;
      end;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Projectile updates
// ---------------------------------------------------------------------------
procedure simUpdateBolts(dt: Single);
var
  i: Integer;
  spd: Single;
begin
  for i := 0 to MAX_PBOLTS - 1 do
  begin
    if not pbolts[i].active then continue;
    pbolts[i].px := pbolts[i].px + pbolts[i].vx * dt;
    pbolts[i].py := pbolts[i].py + pbolts[i].vy * dt;
    pbolts[i].pz := pbolts[i].pz + pbolts[i].vz * dt;
    pbolts[i].life := pbolts[i].life - dt;
    if pbolts[i].life <= 0 then pbolts[i].active := false;
  end;
  for i := 0 to MAX_EBOLTS - 1 do
  begin
    if not ebolts[i].active then continue;
    ebolts[i].px := ebolts[i].px + ebolts[i].vx * dt;
    ebolts[i].py := ebolts[i].py + ebolts[i].vy * dt;
    ebolts[i].pz := ebolts[i].pz + ebolts[i].vz * dt;
    ebolts[i].life := ebolts[i].life - dt;
    if ebolts[i].life <= 0 then ebolts[i].active := false;
  end;
end;

procedure simUpdateMissiles(dt: Single);
var
  i: Integer;
  tgt: Integer;
  tx, ty, tz, dist, spd, mix: Single;
  dx, dy, dz: Single;
  cx, cy, cz: Single;
begin
  for i := 0 to MAX_MISSILES - 1 do
  begin
    if not missiles[i].active then continue;
    tgt := missiles[i].target;
    if (tgt >= 0) and enemies[tgt].alive then
    begin
      tx := enemies[tgt].px - missiles[i].px;
      ty := enemies[tgt].py - missiles[i].py;
      tz := enemies[tgt].pz - missiles[i].pz;
      dist := v3len(tx, ty, tz);
      if dist > 0.001 then
      begin
        dx := tx / dist; dy := ty / dist; dz := tz / dist;
      end else begin
        dx := 0; dy := 0; dz := 1;
      end;
      // steer toward the target
      v3norm(missiles[i].vx, missiles[i].vy, missiles[i].vz, cx, cy, cz);
      mix := fclamp(MISSILE_TURN * dt, 0.0, 1.0);
      missiles[i].vx := cx + (dx - cx) * mix;
      missiles[i].vy := cy + (dy - cy) * mix;
      missiles[i].vz := cz + (dz - cz) * mix;
    end;
    // accelerate to cruise
    spd := v3len(missiles[i].vx, missiles[i].vy, missiles[i].vz);
    if spd < MISSILE_SPEED then
      spd := spd + 900.0 * dt;
    v3norm(missiles[i].vx, missiles[i].vy, missiles[i].vz, cx, cy, cz);
    missiles[i].vx := cx * spd;
    missiles[i].vy := cy * spd;
    missiles[i].vz := cz * spd;
    missiles[i].px := missiles[i].px + missiles[i].vx * dt;
    missiles[i].py := missiles[i].py + missiles[i].vy * dt;
    missiles[i].pz := missiles[i].pz + missiles[i].vz * dt;
    missiles[i].life := missiles[i].life - dt;
    if missiles[i].life <= 0 then missiles[i].active := false;
  end;
end;

// ---------------------------------------------------------------------------
// Wave progression
// ---------------------------------------------------------------------------
function simEnemiesAlive: Integer;var
  i, n: Integer;
begin
  n := 0;
  for i := 0 to MAX_ENEMIES - 1 do
    if enemies[i].alive then n := n + 1;
  simEnemiesAlive := n;
end;

procedure simAdvanceState;
begin
  if game_state = GS_WAVECLEAR then
  begin
    if wave >= WAVE_COUNT then
    begin
      game_state := GS_DEBRIEF;
      state_timer := 0;
    end else begin
      game_state := GS_BRIEFING;
      state_timer := 0;
    end;
  end
  else if game_state = GS_DEAD then
  begin
    game_state := GS_DEBRIEF;
    state_timer := 0;
  end;
end;

procedure simCheckWaveClear;
begin
  if simEnemiesAlive = 0 then
  begin
    aPlaySound(SND_WAVE);
    game_state := GS_WAVECLEAR;
    state_timer := 2.4;
  end;
end;

// ---------------------------------------------------------------------------
// Master update
// ---------------------------------------------------------------------------
function simAccuracy: Integer;
begin
  if shots_fired <= 0 then simAccuracy := 0
  else simAccuracy := (shots_hit * 100) div shots_fired;
end;

function simRankText(buf: PByte): Integer;
var
  i, n: Integer;
  src: PByte;
begin
  if score >= 2200 then begin src := @RW_ACE[0]; n := 3; end
  else if score >= 1200 then begin src := @RW_CAPTAIN[0]; n := 7; end
  else if score >= 500 then begin src := @RW_OFFICER[0]; n := 7; end
  else begin src := @RW_ROOKIE[0]; n := 6; end;
  for i := 0 to n - 1 do buf[i] := src[i];
  simRankText := n;
end;

procedure simUpdate(dt: Single);
var
  i: Integer;
  fwd_x, fwd_y, fwd_z: Single;
begin
  if msg_timer > 0 then msg_timer := msg_timer - dt;

  if game_state = GS_TITLE then
  begin
    fxUpdate(dt);
    fxUpdateShake(dt);
    exit;
  end;

  if game_state = GS_BRIEFING then
  begin
    fxUpdate(dt);
    fxUpdateShake(dt);
    exit;
  end;

  if game_state = GS_DEBRIEF then
  begin
    fxUpdate(dt);
    fxUpdateShake(dt);
    exit;
  end;

  if game_state = GS_DEAD then
  begin
    fxUpdate(dt);
    fxUpdateShake(dt);
    state_timer := state_timer - dt;
    if state_timer <= 0 then simAdvanceState;
    exit;
  end;

  if game_state = GS_WAVECLEAR then
  begin
    fxUpdate(dt);
    fxUpdateShake(dt);
    state_timer := state_timer - dt;
    if state_timer <= 0 then simAdvanceState;
    exit;
  end;

  // GS_FLIGHT
  if paused then exit;

  simUpdateFlight(dt);

  // firing (hold space)
  if keys[KEY_SPACE] and (player.laser_cd <= 0) then
  begin
    simFireLasers;
    player.laser_cd := LASER_COOLDOWN;
  end;

  simUpdateLock(dt);
  simUpdateBolts(dt);
  simUpdateMissiles(dt);
  for i := 0 to MAX_ENEMIES - 1 do
    if enemies[i].alive then simUpdateEnemy(i, dt);
  simUpdateCollisions(dt);
  fxUpdate(dt);
  fxUpdateShake(dt);

  if game_state = GS_FLIGHT then simCheckWaveClear;
end;

// fill the rank-word tables at program init (runs before the root's init)
begin
  RW_ROOKIE[0] := 82;  RW_ROOKIE[1] := 111; RW_ROOKIE[2] := 111;
  RW_ROOKIE[3] := 107; RW_ROOKIE[4] := 105; RW_ROOKIE[5] := 101;
  RW_OFFICER[0] := 79; RW_OFFICER[1] := 102; RW_OFFICER[2] := 102;
  RW_OFFICER[3] := 105; RW_OFFICER[4] := 99; RW_OFFICER[5] := 101;
  RW_OFFICER[6] := 114;
  RW_CAPTAIN[0] := 67; RW_CAPTAIN[1] := 97; RW_CAPTAIN[2] := 112;
  RW_CAPTAIN[3] := 116; RW_CAPTAIN[4] := 97; RW_CAPTAIN[5] := 105;
  RW_CAPTAIN[6] := 110;
  RW_ACE[0] := 65; RW_ACE[1] := 99; RW_ACE[2] := 101;
end.
