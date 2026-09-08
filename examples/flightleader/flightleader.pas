// flightleader.pas — FLIGHT LEADER: a arcade space-combat-style space combat game.
//
// Keyboard-only: Arrow keys fly (Left/Right yaw, Up/Down pitch), W/S throttle
// with Shift afterburner, twin lasers (hold Space), homing missiles with a
// beeping lock (Tab), three waves of enemies (fighters,
// a gunboat, and a capital ship), shield/hull damage, radar, and a debrief
// with rank. Enter advances the title/briefing/debrief overlays.
//
// Batchiness ABI: exports batchiness_main / batchiness_invoke_callback /
// batchiness_set_last_event; the host calls batchiness_main after
// instantiation, and the game self-wires its canvas, keyboard events,
// and animation loop via batch_env imports. Code is split into units:
//   fldefs    shared constants/types/state + host imports
//   flmath    3D vector math, RNG, world→screen projection
//   flbatch   batch command buffer + Canvas2D wrappers + text
//   flfx      2D explosion effects (particles/debris/shockwaves/shake)
//   flsim     flight, weapons, enemy AI, waves, collisions, scoring
//   flrender  starfield, ships, HUD, radar, overlays
library flightleader;

uses
  fldefs,
  flmath,
  flbatch,
  flfx,
  flsim,
  flrender;

var
  last_ms: Double;
  fps_frames: Integer;
  fps_accum: Single;

// ---------------------------------------------------------------------------
// State transitions (Enter)
// ---------------------------------------------------------------------------
procedure AdvanceState;
begin
  if game_state = GS_TITLE then
    simStartMission
  else if game_state = GS_BRIEFING then
    simStartWave
  else if game_state = GS_WAVECLEAR then
    simAdvanceState
  else if game_state = GS_DEAD then
    simAdvanceState
  else if game_state = GS_DEBRIEF then
    simStartMission;
end;

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------
procedure SetKey(code, down: Integer);
begin
  if code < KEY_COUNT then
  begin
    keys[code] := (down <> 0);
    if down <> 0 then just_pressed[code] := true;
  end;
end;

procedure HandleKey(down: Integer);
var
  n: Integer;
  c0: Byte;
  rep: Integer;
begin
  // skip auto-repeat keydown edges (we still want held state)
  if down <> 0 then
  begin
    rep := bGetPropStr(last_event, StrAddr('repeat'), 6, Integer(@text_buf), 8);
    if (rep = 4) and (text_buf[0] = 116) and (text_buf[1] = 114) and
       (text_buf[2] = 117) and (text_buf[3] = 101) then exit;  // 'true'
  end;
  n := bGetPropStr(last_event, StrAddr('key'), 3, Integer(@text_buf), 16);
  if n <= 0 then exit;
  c0 := text_buf[0];
  if n = 1 then
  begin
    // single-char keys
    if (c0 = 119) or (c0 = 87) then SetKey(KEY_W, down)          // w/W
    else if (c0 = 115) or (c0 = 83) then SetKey(KEY_S, down)     // s/S
    else if (c0 = 112) or (c0 = 80) then SetKey(KEY_P, down)     // p/P
    else if c0 = 32 then SetKey(KEY_SPACE, down);                // space
  end
  else if n >= 3 then
  begin
    // 'Tab' (3)
    if (n = 3) and (text_buf[0] = 84) and (text_buf[1] = 97) and (text_buf[2] = 98) then
      SetKey(KEY_TAB, down)
    // 'Enter' (5) / 'Shift' (5)
    else if (n = 5) and (text_buf[0] = 69) and (text_buf[1] = 110) and
       (text_buf[2] = 116) and (text_buf[3] = 101) and (text_buf[4] = 114) then
      SetKey(KEY_ENTER, down)
    else if (n = 5) and (text_buf[0] = 83) and (text_buf[1] = 104) and
       (text_buf[2] = 105) and (text_buf[3] = 102) and (text_buf[4] = 116) then
      SetKey(KEY_SHIFT, down)
    // 'ArrowUp' (7)
    else if (n = 7) and (text_buf[0] = 65) and (text_buf[1] = 114) and
       (text_buf[2] = 114) and (text_buf[3] = 111) and (text_buf[4] = 119) and
       (text_buf[5] = 85) and (text_buf[6] = 112) then
      SetKey(KEY_UP, down)
    // 'ArrowDown' (9)
    else if (n = 9) and (text_buf[0] = 65) and (text_buf[1] = 114) and
       (text_buf[2] = 114) and (text_buf[3] = 111) and (text_buf[4] = 119) and
       (text_buf[5] = 68) and (text_buf[6] = 111) and (text_buf[7] = 119) and
       (text_buf[8] = 110) then
      SetKey(KEY_DOWN, down)
    // 'ArrowLeft' (9)
    else if (n = 9) and (text_buf[0] = 65) and (text_buf[1] = 114) and
       (text_buf[2] = 114) and (text_buf[3] = 111) and (text_buf[4] = 119) and
       (text_buf[5] = 76) and (text_buf[6] = 101) and (text_buf[7] = 102) and
       (text_buf[8] = 116) then
      SetKey(KEY_LEFT, down)
    // 'ArrowRight' (10)
    else if (n = 10) and (text_buf[0] = 65) and (text_buf[1] = 114) and
       (text_buf[2] = 114) and (text_buf[3] = 111) and (text_buf[4] = 119) and
       (text_buf[5] = 82) and (text_buf[6] = 105) and (text_buf[7] = 103) and
       (text_buf[8] = 104) and (text_buf[9] = 116) then
      SetKey(KEY_RIGHT, down);
  end;
end;

// RefreshCanvasRect + the mouse handlers were removed when the game became
// keyboard-only (no reticle-aimed steering, no click-to-advance).

// ---------------------------------------------------------------------------
// Callbacks
// ---------------------------------------------------------------------------
procedure ConsumeEdges;
var
  i: Integer;
  just_enter, just_tab, just_p: Boolean;
begin
  just_enter := just_pressed[KEY_ENTER];
  just_tab := just_pressed[KEY_TAB];
  just_p := just_pressed[KEY_P];
  for i := 0 to KEY_COUNT - 1 do just_pressed[i] := false;

  if just_enter then AdvanceState;

  if game_state = GS_FLIGHT then
  begin
    if just_tab then simHandleMissile;
    if just_p then paused := not paused;
  end;
end;

procedure InvokeCallback(id: Integer);
var
  now_ms, dt: Double;
begin
  if id = CB_TICK then
  begin
    now_ms := bNow;
    dt := (now_ms - last_ms) / 1000.0;
    last_ms := now_ms;
    if dt > 0.0 then
    begin
      if dt > 0.05 then dt := 0.05;
      fps_accum := fps_accum + Single(1.0 / dt);
      fps_frames := fps_frames + 1;
      if fps_frames >= 24 then
      begin
        aSetFps(fps_accum / Single(fps_frames));
        fps_accum := 0;
        fps_frames := 0;
      end;
      anim_time := anim_time + Single(dt);
      ConsumeEdges;
      simUpdate(Single(dt));
      rdDrawFrame;
    end;
  end
  else if id = CB_KEYDOWN then
    HandleKey(1)
  else if id = CB_KEYUP then
    HandleKey(0);
end;

procedure SetLastEvent(h: Integer);
begin
  last_event := h;
end;

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------
procedure FlightLeaderMain;
var
  app: Integer;
begin
  app := bGetElement(StrAddr('stage'), 5);
  cv_h := bCanvasCreate(app, CW, CH);
  ctx_h := bGetContext(cv_h);

  rdInit;
  game_state := GS_TITLE;
  paused := false;
  thrust_on := false;
  msg_timer := 0;
  msg_len := 0;
  simInitStars;

  // self-wired input: keys on `document` (keyboard-only)
  doc_h := bGetGlobal(StrAddr('document'), 8);
  bAddListener(doc_h, StrAddr('keydown'), 7, CB_KEYDOWN);
  bAddListener(doc_h, StrAddr('keyup'), 5, CB_KEYUP);

  last_ms := bNow;
  bStartLoop(CB_TICK);
end;

// ---------------------------------------------------------------------------
// Debug/test hooks (extra exports; the host boot path ignores them, but the
// headless browser test asserts real game state through them)
// ---------------------------------------------------------------------------
function flGameState: Integer;
begin
  flGameState := game_state;
end;

function flThrottle: Integer;
begin
  flThrottle := Integer(player.throttle);
end;

function flWave: Integer;
begin
  flWave := wave;
end;

function flEnemies: Integer;
begin
  flEnemies := simEnemiesAlive;
end;

function flScore: Integer;
begin
  flScore := score;
end;

function flLastEvent: Integer;
begin
  flLastEvent := last_event;
end;

function flTextBuf: Integer;
begin
  flTextBuf := Integer(@text_buf);
end;

function flShots: Integer;
begin
  flShots := shots_fired;
end;

function flEnemyDist: Integer;
var
  fwd_x, fwd_y, fwd_z: Single;
begin
  PlayerForward(fwd_x, fwd_y, fwd_z);
  flEnemyDist := if enemies[0].alive then Integer(DepthOf(enemies[0].px, enemies[0].py, enemies[0].pz)) else -1;
end;

function flEnemySpeed: Integer;
begin
  flEnemySpeed := if enemies[0].alive then Integer(v3len(enemies[0].vx, enemies[0].vy, enemies[0].vz)) else -1;
end;

function flEnemyTrue: Integer;
begin
  flEnemyTrue := if enemies[0].alive then Integer(v3len(enemies[0].px - player.px, enemies[0].py - player.py, enemies[0].pz - player.pz)) else -1;
end;

function flEnemyRelX: Integer;
var
  rx, rz, ry, rx2, ry2, rz2: Single;
begin
  if enemies[0].alive then
  begin
    rx := enemies[0].px - player.px;
    rz := enemies[0].pz - player.pz;
    RotY(-player.yaw, rx, 0, rz, rx2, ry2, rz2);
    flEnemyRelX := Integer(rx2);
  end
  else
    flEnemyRelX := -1;
end;

function flPlayerZ: Integer;
begin
  flPlayerZ := Integer(player.pz);
end;

function flPlayerSpeed: Integer;
begin
  flPlayerSpeed := Integer(player.speed);
end;

function flPlayerYaw: Integer;
begin
  flPlayerYaw := Integer(player.yaw * 100.0);
end;

function flPlayerPitch: Integer;
begin
  flPlayerPitch := Integer(player.pitch * 100.0);
end;

function flEnemyVZ: Integer;
begin
  if enemies[0].alive then flEnemyVZ := Integer(enemies[0].vz)
  else flEnemyVZ := -1;
end;

function flEnemySX: Integer;
var
  sx, sy, scale: Single;
  visible: Boolean;
begin
  if enemies[0].alive then
  begin
    ProjToScreen(enemies[0].px, enemies[0].py, enemies[0].pz, sx, sy, scale, visible);
    if visible then flEnemySX := Integer(sx) else flEnemySX := -1;
  end
  else
    flEnemySX := -1;
end;

function flEnemySY: Integer;
var
  sx, sy, scale: Single;
  visible: Boolean;
begin
  if enemies[0].alive then
  begin
    ProjToScreen(enemies[0].px, enemies[0].py, enemies[0].pz, sx, sy, scale, visible);
    if visible then flEnemySY := Integer(sy) else flEnemySY := -1;
  end
  else
    flEnemySY := -1;
end;

function flEnemyState: Integer;
begin
  if enemies[0].alive then flEnemyState := enemies[0].state
  else flEnemyState := -1;
end;

function flMinDist: Integer;
var
  i: Integer;
  d, m: Single;
begin
  m := 99999.0;
  for i := 0 to MAX_ENEMIES - 1 do
  begin
    if not enemies[i].alive then continue;
    d := v3len(enemies[i].px - player.px, enemies[i].py - player.py, enemies[i].pz - player.pz);
    if d < m then m := d;
  end;
  if m > 90000.0 then flMinDist := -1 else flMinDist := Integer(m);
end;

// Screen position of the enemy nearest the reticle (same selection the lead
// diamond uses) — the test hook aims here, exactly like a real player.
procedure flAimAt(var ox, oy: Integer);
var
  i, best: Integer;
  best_d2, d2: Single;
  sx, sy, scale: Single;
  visible: Boolean;
begin
  // nearest enemy to the fixed screen-center reticle (keyboard aim)
  best := -1;
  best_d2 := 99999999.0;
  for i := 0 to MAX_ENEMIES - 1 do
  begin
    if not enemies[i].alive then continue;
    ProjToScreen(enemies[i].px, enemies[i].py, enemies[i].pz, sx, sy, scale, visible);
    if not visible then continue;
    d2 := (sx - Single(CW) * 0.5) * (sx - Single(CW) * 0.5) +
          (sy - Single(CH) * 0.5) * (sy - Single(CH) * 0.5);
    if d2 < best_d2 then
    begin
      best_d2 := d2;
      best := i;
    end;
  end;
  if best < 0 then begin ox := -1; oy := -1; end
  else begin
    ProjToScreen(enemies[best].px, enemies[best].py, enemies[best].pz, sx, sy, scale, visible);
    ox := Integer(sx); oy := Integer(sy);
  end;
end;

function flAimSX: Integer;
var
  x, y: Integer;
begin
  flAimAt(x, y);
  flAimSX := x;
end;

function flAimSY: Integer;
var
  x, y: Integer;
begin
  flAimAt(x, y);
  flAimSY := y;
end;

exports
  FlightLeaderMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event',
  flGameState name 'fl_game_state',
  flThrottle name 'fl_throttle',
  flWave name 'fl_wave',
  flEnemies name 'fl_enemies',
  flScore name 'fl_score',
  flLastEvent name 'fl_last_event',
  flTextBuf name 'fl_text_buf',
  flShots name 'fl_shots',
  flEnemyDist name 'fl_enemy_dist',
  flEnemySpeed name 'fl_enemy_speed',
  flEnemyTrue name 'fl_enemy_true',
  flEnemyRelX name 'fl_enemy_relx',
  flPlayerZ name 'fl_player_z',
  flPlayerSpeed name 'fl_player_speed',
  flPlayerYaw name 'fl_player_yaw',
  flPlayerPitch name 'fl_player_pitch',
  flEnemyVZ name 'fl_enemy_vz',
  flEnemySX name 'fl_enemy_sx',
  flEnemySY name 'fl_enemy_sy',
  flEnemyState name 'fl_enemy_state',
  flMinDist name 'fl_min_dist',
  flAimSX name 'fl_aim_sx',
  flAimSY name 'fl_aim_sy';

begin
end.
