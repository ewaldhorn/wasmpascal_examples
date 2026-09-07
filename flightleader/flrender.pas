// flrender.pas — FLIGHT LEADER renderer: 3-layer starfield, perspective ship
// drawing (polygon shapes projected + rotated to their screen heading),
// laser/missile streaks, the player ship with engine glow, the HUD (reticle,
// throttle, shields/hull, radar, lock brackets, damage vignette), mission
// messages, and the state overlays (title/briefing/wave-clear/debrief).
//
// One frame = one batch command buffer flushed once (batchiness wire format).
unit flrender;

interface

uses
  fldefs,
  flmath,
  flbatch,
  flfx;

procedure rdInit;
procedure rdDrawFrame;
procedure rdDrawPlayerShip;

implementation

// ---------------------------------------------------------------------------
// Ship shapes (world-unit coordinates, nose pointing -y so "up" on screen).
// The fighter/gunboat flow through DrawPolyShape's CONFORMANT ARRAY param —
// each shape is just a flat (x,y) point list with its own length.
// ---------------------------------------------------------------------------
var
  fighter_shape: array[0..15] of Single;   // 8 points
  gunboat_shape: array[0..15] of Single;   // 8 points
  capital_hull: array[0..19] of Single;    // 10 points
  capital_bridge: array[0..11] of Single;  // 6 points
  fighter_core: array[0..7] of Single;     // 4 points (cockpit slit)
  gunboat_core: array[0..9] of Single;     // 5 points (bridge block)

procedure rdInit;
begin
  // fighter: swept delta wing
  fighter_shape[0] := 0;    fighter_shape[1] := -22;
  fighter_shape[2] := 6;    fighter_shape[3] := -8;
  fighter_shape[4] := 22;   fighter_shape[5] := 10;
  fighter_shape[6] := 7;    fighter_shape[7] := 9;
  fighter_shape[8] := 0;    fighter_shape[9] := 15;
  fighter_shape[10] := -7;  fighter_shape[11] := 9;
  fighter_shape[12] := -22; fighter_shape[13] := 10;
  fighter_shape[14] := -6;  fighter_shape[15] := -8;

  // gunboat: chunky gunship
  gunboat_shape[0] := 0;    gunboat_shape[1] := -30;
  gunboat_shape[2] := 10;   gunboat_shape[3] := -10;
  gunboat_shape[4] := 17;   gunboat_shape[5] := 6;
  gunboat_shape[6] := 9;    gunboat_shape[7] := 14;
  gunboat_shape[8] := 0;    gunboat_shape[9] := 20;
  gunboat_shape[10] := -9;  gunboat_shape[11] := 14;
  gunboat_shape[12] := -17; gunboat_shape[13] := 6;
  gunboat_shape[14] := -10; gunboat_shape[15] := -10;

  // capital: long cruiser hull + bridge fin
  capital_hull[0] := 0;     capital_hull[1] := -78;
  capital_hull[2] := 14;    capital_hull[3] := -44;
  capital_hull[4] := 20;    capital_hull[5] := 0;
  capital_hull[6] := 16;    capital_hull[7] := 44;
  capital_hull[8] := 0;     capital_hull[9] := 62;
  capital_hull[10] := -16;  capital_hull[11] := 44;
  capital_hull[12] := -20;  capital_hull[13] := 0;
  capital_hull[14] := -14;  capital_hull[15] := -44;
  capital_hull[16] := 0;    capital_hull[17] := -56;
  capital_hull[18] := 6;    capital_hull[19] := -64;

  capital_bridge[0] := 0;   capital_bridge[1] := -30;
  capital_bridge[2] := 8;   capital_bridge[3] := -14;
  capital_bridge[4] := 6;   capital_bridge[5] := 0;
  capital_bridge[6] := 0;   capital_bridge[7] := 8;
  capital_bridge[8] := -6;  capital_bridge[9] := 0;
  capital_bridge[10] := -8; capital_bridge[11] := -14;

  // cockpit slit (fighter)
  fighter_core[0] := 0;    fighter_core[1] := -14;
  fighter_core[2] := 4;    fighter_core[3] := -3;
  fighter_core[4] := -4;   fighter_core[5] := -3;
  fighter_core[6] := 0;    fighter_core[7] := -6;

  // bridge block (gunboat)
  gunboat_core[0] := 0;    gunboat_core[1] := -16;
  gunboat_core[2] := 7;    gunboat_core[3] := -6;
  gunboat_core[4] := 5;    gunboat_core[5] := 2;
  gunboat_core[6] := -5;   gunboat_core[7] := 2;
  gunboat_core[8] := -7;   gunboat_core[9] := -6;
end;

// ---------------------------------------------------------------------------
// Starfield
// ---------------------------------------------------------------------------
procedure rdDrawStars;
var
  i: Integer;
  sz: Single;
  a: Single;
  sx, sy, scale: Single;
  visible: Boolean;
begin
  for i := 0 to MAX_STARS - 1 do
  begin
    if DepthOf(stars[i].wx, stars[i].wy, stars[i].wz) <= NEARZ then
      simRespawnStar(i);
    ProjToScreen(stars[i].wx, stars[i].wy, stars[i].wz, sx, sy, scale, visible);
    if not visible then continue;
    if (sx < -4) or (sx > CW + 4) or (sy < -4) or (sy > CH + 4) then continue;
    a := 0.35 + 0.3 * fSin(anim_time * 2.0 + stars[i].tw);
    if stars[i].layer = 2 then
    begin
      a := 0.55 + 0.35 * fSin(anim_time * 3.0 + stars[i].tw);
      sz := 2;
    end
    else if stars[i].layer = 1 then
      sz := 1.6
    else
      sz := 1;
    bSetFill(StrAddr('#ffffff'), 7);
    bSetGlobalAlpha(a);
    bFillRect(sx, sy, sz, sz);
  end;
  bSetGlobalAlpha(1.0);
end;

// ---------------------------------------------------------------------------
// Projectiles
// ---------------------------------------------------------------------------
procedure rdDrawBolts;
var
  i: Integer;
  sx, sy, scale: Single;
  visible: Boolean;
  tx, ty: Single;
begin
  // player lasers: green streaks
  bSetShadow(StrAddr('#7dffb0'), 7, 5.0);
  bSetStroke(StrAddr('#a8ffce'), 7);
  bSetLineWidth(2.2);
  bSetLineCap(StrAddr('round'), 5);
  for i := 0 to MAX_PBOLTS - 1 do
  begin
    if not pbolts[i].active then continue;
    ProjToScreen(pbolts[i].px, pbolts[i].py, pbolts[i].pz, sx, sy, scale, visible);
    if not visible then continue;
    ProjToScreen(pbolts[i].px - pbolts[i].vx * 0.03, pbolts[i].py - pbolts[i].vy * 0.03,
                 pbolts[i].pz - pbolts[i].vz * 0.03, tx, ty, scale, visible);
    if not visible then continue;
    bBeginPath;
    bMoveTo(tx, ty);
    bLineTo(sx, sy);
    bStroke;
  end;
  bClearShadow;

  // enemy lasers: red/orange streaks
  bSetShadow(StrAddr('#ff5a4c'), 7, 5.0);
  bSetStroke(StrAddr('#ff8a5c'), 7);
  bSetLineWidth(2.2);
  for i := 0 to MAX_EBOLTS - 1 do
  begin
    if not ebolts[i].active then continue;
    ProjToScreen(ebolts[i].px, ebolts[i].py, ebolts[i].pz, sx, sy, scale, visible);
    if not visible then continue;
    ProjToScreen(ebolts[i].px - ebolts[i].vx * 0.03, ebolts[i].py - ebolts[i].vy * 0.03,
                 ebolts[i].pz - ebolts[i].vz * 0.03, tx, ty, scale, visible);
    if not visible then continue;
    bBeginPath;
    bMoveTo(tx, ty);
    bLineTo(sx, sy);
    bStroke;
  end;
  bClearShadow;
end;

procedure rdDrawMissiles;
var
  i: Integer;
  sx, sy, scale: Single;
  visible: Boolean;
  tx, ty: Single;
begin
  bSetShadow(StrAddr('#ffce7a'), 7, 6.0);
  bSetStroke(StrAddr('#ffe8c0'), 7);
  bSetLineWidth(1.8);
  for i := 0 to MAX_MISSILES - 1 do
  begin
    if not missiles[i].active then continue;
    ProjToScreen(missiles[i].px, missiles[i].py, missiles[i].pz, sx, sy, scale, visible);
    if not visible then continue;
    ProjToScreen(missiles[i].px - missiles[i].vx * 0.05, missiles[i].py - missiles[i].vy * 0.05,
                 missiles[i].pz - missiles[i].vz * 0.05, tx, ty, scale, visible);
    bBeginPath;
    bMoveTo(tx, ty);
    bLineTo(sx, sy);
    bStroke;
  end;
  bClearShadow;
end;

// ---------------------------------------------------------------------------
// Enemies
// ---------------------------------------------------------------------------
// Small filled engine-glow dot at a ship-space offset (rotated + scaled
// with the ship, drawn at the ship's screen position).
procedure GlowDot(ox, oy, r, col: Integer; clen: Integer; sx, sy, scale, rot: Single);
var
  c, s: Single;
begin
  c := fCos(rot);
  s := fSin(rot);
  bSetFill(col, clen);
  bBeginPath;
  bArc(sx + (ox * c - oy * s) * scale,
       sy + (ox * s + oy * c) * scale,
       r * scale, 0.0, 6.283185307);
  bFill;
end;

procedure rdDrawEnemy(ei: Integer);
var
  sx, sy, scale: Single;
  visible: Boolean;
  hx, hy, hscale: Single;
  hvx, hvy, hvz: Single;
  rot, lw: Single;
  pct: Single;
  bar_y: Single;
begin
  ProjToScreen(enemies[ei].px, enemies[ei].py, enemies[ei].pz, sx, sy, scale, visible);
  if not visible then exit;
  if (sx < -80) or (sx > CW + 80) or (sy < -80) or (sy > CH + 80) then exit;

  // screen heading from velocity
  hvx := enemies[ei].vx * 0.35;
  hvy := enemies[ei].vy * 0.35;
  hvz := enemies[ei].vz * 0.35;
  ProjToScreen(enemies[ei].px + hvx, enemies[ei].py + hvy, enemies[ei].pz + hvz,
               hx, hy, hscale, visible);
  if not visible then rot := 0.0
  else rot := fAtan2(hx - sx, -(hy - sy));

  // capital: dark-red hull + pale bridge + engine glows
  if enemies[ei].cls = EC_CAPITAL then
  begin
    bSetStroke(StrAddr('#c07078'), 7);
    bSetLineWidth(2.0);
    bSetFill(StrAddr('rgba(120,60,66,0.45)'), 20);
    DrawPolyShape(capital_hull, sx, sy, scale, rot, true);
    bSetStroke(StrAddr('#f0c8cc'), 7);
    bSetLineWidth(1.6);
    DrawPolyShape(capital_bridge, sx, sy, scale, rot, false);
    GlowDot(-8, 58, 3.0, StrAddr('#ff6a5c'), 7, sx, sy, scale, rot);
    GlowDot(0, 64, 3.0, StrAddr('#ff6a5c'), 7, sx, sy, scale, rot);
    GlowDot(8, 58, 3.0, StrAddr('#ff6a5c'), 7, sx, sy, scale, rot);
  end
  else if enemies[ei].cls = EC_GUNBOAT then
  begin
    bSetStroke(StrAddr('#ffb070'), 7);
    bSetLineWidth(1.8);
    bSetFill(StrAddr('rgba(140,85,40,0.40)'), 20);
    DrawPolyShape(gunboat_shape, sx, sy, scale, rot, true);
    bSetStroke(StrAddr('#ffd0a0'), 7);
    bSetLineWidth(1.2);
    DrawPolyShape(gunboat_core, sx, sy, scale, rot, false);
    GlowDot(-6, 22, 2.2, StrAddr('#ff8a5c'), 7, sx, sy, scale, rot);
    GlowDot(6, 22, 2.2, StrAddr('#ff8a5c'), 7, sx, sy, scale, rot);
  end
  else begin
    bSetStroke(StrAddr('#ff8a7a'), 7);
    bSetLineWidth(1.6);
    bSetFill(StrAddr('rgba(150,55,45,0.40)'), 20);
    DrawPolyShape(fighter_shape, sx, sy, scale, rot, true);
    bSetStroke(StrAddr('#ffb0a0'), 7);
    bSetLineWidth(1.0);
    DrawPolyShape(fighter_core, sx, sy, scale, rot, false);
    GlowDot(0, 17, 2.2, StrAddr('#ff6a5c'), 7, sx, sy, scale, rot);
  end;

  // hit flash: white overlay
  if enemies[ei].hit_flash > 0 then
  begin
    bSetStroke(StrAddr('#ffffff'), 7);
    lw := 1.6 + 2.0 * (enemies[ei].hit_flash / 0.12);
    bSetLineWidth(lw);
    if enemies[ei].cls = EC_CAPITAL then
      DrawPolyShape(capital_hull, sx, sy, scale, rot, false)
    else if enemies[ei].cls = EC_GUNBOAT then
      DrawPolyShape(gunboat_shape, sx, sy, scale, rot, false)
    else
      DrawPolyShape(fighter_shape, sx, sy, scale, rot, false);
  end;

  // hp bar above the ship
  pct := enemies[ei].hp / enemies[ei].max_hp;
  if pct < 0 then pct := 0;
  bar_y := sy - enemies[ei].radius * scale - 12.0;
  if bar_y > 8 then
  begin
    bSetFill(StrAddr('rgba(20,30,44,0.8)'), 18);
    bFillRect(sx - 16.0, bar_y, 32.0, 4.0);
    if pct > 0.5 then bSetFill(StrAddr('#7fe0a0'), 7)
    else if pct > 0.25 then bSetFill(StrAddr('#ffce7a'), 7)
    else bSetFill(StrAddr('#ff5a4c'), 7);
    bFillRect(sx - 16.0, bar_y, 32.0 * pct, 4.0);
  end;
end;

procedure rdDrawEnemies;
var
  i: Integer;
begin
  for i := 0 to MAX_ENEMIES - 1 do
    if enemies[i].alive then rdDrawEnemy(i);
end;

// ---------------------------------------------------------------------------
// Player ship (screen center, banks with the turn)
// ---------------------------------------------------------------------------
procedure rdDrawPlayerShip;
var
  cx, cy: Single;
  flame: Single;
  i: Integer;
begin
  cx := Single(CW) * 0.5;
  cy := Single(CH) * 0.5 + 8.0;
  bSave;
  bTranslate(cx, cy);
  bRotate(player.bank);

  // hull (filled)
  bSetStroke(StrAddr('#9fe8ff'), 7);
  bSetLineWidth(2.2);
  bSetFill(StrAddr('rgba(90,170,230,0.30)'), 21);
  bBeginPath;
  bMoveTo(0, -26);
  bLineTo(9, -4);
  bLineTo(7, 16);
  bLineTo(0, 21);
  bLineTo(-7, 16);
  bLineTo(-9, -4);
  bClosePath;
  bFill;
  bStroke;

  // cockpit (filled)
  bSetStroke(StrAddr('#4ecdc4'), 7);
  bSetLineWidth(1.4);
  bSetFill(StrAddr('rgba(78,205,196,0.45)'), 21);
  bBeginPath;
  bMoveTo(0, -18);
  bLineTo(4, -2);
  bLineTo(-4, -2);
  bClosePath;
  bFill;
  bStroke;

  // idle engine glow at the nozzle base (always on)
  bSetFill(StrAddr('#9fe8ff'), 7);
  bBeginPath;
  bArc(-3.5, 19, 1.8, 0.0, 6.283185307);
  bFill;
  bBeginPath;
  bArc(3.5, 19, 1.8, 0.0, 6.283185307);
  bFill;

  // engine flame (grows with speed)
  flame := player.speed / AFTERBURN_SPEED;
  if flame > 0.05 then
  begin
    bSetStroke(StrAddr('#ff9a3c'), 7);
    bSetLineWidth(2.0);
    if player.afterburn then
      bSetStroke(StrAddr('#ffd0a0'), 7);
    bBeginPath;
    bMoveTo(3, 19);
    bLineTo(0, 19 + 14.0 * flame + 6.0 * fSin(anim_time * 30.0));
    bLineTo(-3, 19);
    bStroke;
    if player.afterburn then
    begin
      // afterburner spark trail (screen space behind the ship)
      for i := 0 to 2 do
      begin
        bSetFill(StrAddr('#ffce7a'), 7);
        bSetGlobalAlpha(0.5);
        bFillRect(-2 + RandRange(-2.0, 2.0), 26 + RandRange(0.0, 10.0), 2, 2);
      end;
      bSetGlobalAlpha(1.0);
    end;
  end;
  bRestore;
end;

// ---------------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------------
procedure rdDrawBar(x, y, w, pct: Single; col: Integer; clen: Integer);
begin
  bSetFill(StrAddr('rgba(20,30,44,0.85)'), 18);
  bFillRect(x, y, w, 9.0);
  if pct < 0 then pct := 0;
  if pct > 1 then pct := 1;
  if pct > 0.02 then
  begin
    bSetFill(col, clen);
    bFillRect(x, y, w * pct, 9.0);
  end;
  bSetStroke(StrAddr('#3a4a68'), 7);
  bSetLineWidth(1.0);
  bStrokeRect(x, y, w, 9.0);
end;

// The targeting computer: a small amber diamond at the PREDICTED position of
// the enemy nearest the reticle (pos + vel * flight-time). Put the diamond on
// the target and the lasers connect — the classic WC lead indicator.
procedure rdDrawLead;
var
  i, best: Integer;
  best_d2, d2: Single;
  sx, sy, scale: Single;
  lx, ly, lscale: Single;
  visible: Boolean;
  flight: Single;
  px, py, pz: Single;
  len: Single;
begin
  // nearest enemy to the fixed screen-center reticle (keyboard aim)
  best := -1;
  best_d2 := 130.0 * 130.0;
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
  if best < 0 then exit;
  // predicted position after laser flight time
  px := enemies[best].px - player.px;
  py := enemies[best].py - player.py;
  pz := enemies[best].pz - player.pz;
  len := v3len(px, py, pz);
  if len < 1.0 then exit;
  flight := len / LASER_SPEED;
  ProjToScreen(enemies[best].px + enemies[best].vx * flight,
               enemies[best].py + enemies[best].vy * flight,
               enemies[best].pz + enemies[best].vz * flight,
               lx, ly, lscale, visible);
  if not visible then exit;
  // amber diamond
  bSetStroke(StrAddr('#ffce7a'), 7);
  bSetLineWidth(1.8);
  bBeginPath;
  bMoveTo(lx, ly - 6);
  bLineTo(lx + 6, ly);
  bLineTo(lx, ly + 6);
  bLineTo(lx - 6, ly);
  bClosePath;
  bStroke;
end;

procedure rdDrawLock;
var
  sx, sy, scale: Single;
  visible: Boolean;
  j: Integer;
  sz, ox, oy: Single;
begin
  j := player.lock_target;
  if (j < 0) or (not enemies[j].alive) then exit;
  ProjToScreen(enemies[j].px, enemies[j].py, enemies[j].pz, sx, sy, scale, visible);
  if not visible then exit;
  if (sx < -40) or (sx > CW + 40) or (sy < -40) or (sy > CH + 40) then exit;
  sz := 26.0 + enemies[j].radius * scale * 0.8;
  if sz < 30 then sz := 30;
  if sz > 120 then sz := 120;
  if player.locked then bSetStroke(StrAddr('#ffce7a'), 7)
  else bSetStroke(StrAddr('#9fd0ff'), 7);
  bSetLineWidth(2.0);
  ox := sz * 0.5; oy := sz * 0.5;
  // corner brackets
  bBeginPath;
  bMoveTo(sx - ox, sy - oy + 10); bLineTo(sx - ox, sy - oy); bLineTo(sx - ox + 10, sy - oy);
  bMoveTo(sx + ox - 10, sy - oy); bLineTo(sx + ox, sy - oy); bLineTo(sx + ox, sy - oy + 10);
  bMoveTo(sx - ox, sy + oy - 10); bLineTo(sx - ox, sy + oy); bLineTo(sx - ox + 10, sy + oy);
  bMoveTo(sx + ox - 10, sy + oy); bLineTo(sx + ox, sy + oy); bLineTo(sx + ox, sy + oy - 10);
  bStroke;
  if player.locked then
  begin
    bSetFill(StrAddr('#ffce7a'), 7);
    bSetFont(StrAddr('bold 14px monospace'), 20);
    bSetTextAlign(StrAddr('center'), 6);
    bFillText(StrAddr('LOCK'), 4, Integer(sx), Integer(sy - oy - 22));
    bSetTextAlign(StrAddr('left'), 4);
  end;
end;

procedure rdDrawRadar;
var
  r, cx, cy: Single;
  i: Integer;
  rel_x, rel_z: Single;
  rx, rz, rx2, ry2, rz2: Single;
  bx, by: Single;
begin
  cx := Single(CW) - 74.0;
  cy := Single(CH) - 196.0;
  r := 54.0;
  bSetStroke(StrAddr('rgba(120,160,220,0.5)'), 23);
  bSetLineWidth(1.0);
  bBeginPath;
  bArc(cx, cy, r, 0.0, 6.283185307);
  bStroke;
  bBeginPath;
  bArc(cx, cy, r * 0.5, 0.0, 6.283185307);
  bStroke;
  // player
  bSetFill(StrAddr('#7fe0a0'), 7);
  bFillRect(cx - 1.5, cy - 1.5, 3, 3);
  // enemies: rotate world (x,z) by -yaw only
  for i := 0 to MAX_ENEMIES - 1 do
  begin
    if not enemies[i].alive then continue;
    rel_x := enemies[i].px - player.px;
    rel_z := enemies[i].pz - player.pz;
    rx := rel_x;
    rz := rel_z;
    RotY(-player.yaw, rx, 0, rz, rx2, ry2, rz2);
    bx := cx + (rx2 / 3500.0) * r;
    by := cy - (rz2 / 3500.0) * r;
    if (bx >= cx - r) and (bx <= cx + r) and (by >= cy - r) and (by <= cy + r) then
    begin
      if enemies[i].cls = EC_CAPITAL then
      begin
        bSetFill(StrAddr('#ff5a4c'), 7);
        bFillRect(bx - 2.5, by - 2.5, 5, 5);
      end else begin
        bSetFill(StrAddr('#ff9a8c'), 7);
        bFillRect(bx - 1.5, by - 1.5, 3, 3);
      end;
    end;
  end;
  bSetFill(StrAddr('#9fb2d0'), 7);
  bSetFont(StrAddr('10px monospace'), 14);
  bSetTextAlign(StrAddr('center'), 6);
  bFillText(StrAddr('RADAR'), 5, Integer(cx), Integer(cy + r + 8));
  bSetTextAlign(StrAddr('left'), 4);
end;

procedure rdDrawHUD;
var
  n: Integer;
  x: Single;
  i: Integer;
  th, sh, hu: Single;
begin
  // top row
  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('14px monospace'), 14);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
  n := HUDText(StrAddr('SCORE '), 6, score);
  bFillText(Integer(@text_buf), n, 14, 12);

  bSetTextAlign(StrAddr('center'), 6);
  n := HUDText(StrAddr('WAVE '), 5, wave);
  text_buf[n] := Byte(47);            // '/'
  text_buf[n + 1] := Byte(48 + WAVE_COUNT);
  bFillText(Integer(@text_buf), n + 2, CW div 2, 12);

  bSetTextAlign(StrAddr('right'), 5);
  n := HUDText(StrAddr('KILLS '), 6, kills);
  bFillText(Integer(@text_buf), n, CW - 14, 12);
  bSetTextAlign(StrAddr('left'), 4);

  // center reticle (keyboard aim)
  bSetStroke(StrAddr('#9fd0ff'), 7);
  bSetLineWidth(1.4);
  bBeginPath;
  bArc(Single(CW) * 0.5, Single(CH) * 0.5, 13.0, 0.0, 6.283185307);
  bStroke;
  bBeginPath;
  bMoveTo(Single(CW) * 0.5 - 20, Single(CH) * 0.5); bLineTo(Single(CW) * 0.5 - 7, Single(CH) * 0.5);
  bMoveTo(Single(CW) * 0.5 + 7, Single(CH) * 0.5); bLineTo(Single(CW) * 0.5 + 20, Single(CH) * 0.5);
  bMoveTo(Single(CW) * 0.5, Single(CH) * 0.5 - 20); bLineTo(Single(CW) * 0.5, Single(CH) * 0.5 - 7);
  bMoveTo(Single(CW) * 0.5, Single(CH) * 0.5 + 7); bLineTo(Single(CW) * 0.5, Single(CH) * 0.5 + 20);
  bStroke;

  // throttle (bottom-left)
  x := 30.0;
  th := player.throttle;
  bSetFill(StrAddr('#3a4a68'), 7);
  bFillRect(x, Single(CH) - 152.0, 14.0, 112.0);
  bSetFill(StrAddr('#4ecdc4'), 7);
  bFillRect(x, Single(CH) - 152.0 + (112.0 - 112.0 * th / 100.0), 14.0, 112.0 * th / 100.0);
  bSetStroke(StrAddr('#e8f0ff'), 7);
  bSetLineWidth(1.0);
  bStrokeRect(x, Single(CH) - 152.0, 14.0, 112.0);
  // afterburn marker
  if player.afterburn then
  begin
    bSetStroke(StrAddr('#ffce7a'), 7);
    bStrokeRect(x - 2, Single(CH) - 152.0, 18.0, 112.0);
  end;
  bSetFill(StrAddr('#9fb2d0'), 7);
  bSetFont(StrAddr('12px monospace'), 14);
  n := HUDText(StrAddr('THR '), 4, Integer(th));
  bFillText(Integer(@text_buf), n, Integer(x) - 8, CH - 30);
  bSetTextAlign(StrAddr('left'), 4);

  // shields + hull (bottom-center)
  sh := player.shields / PLAYER_MAX_SHIELDS;
  hu := player.hull / PLAYER_MAX_HULL;
  x := Single(CW) * 0.5 - 110.0;
  bSetFill(StrAddr('#7fd0ff'), 7);
  bSetFont(StrAddr('11px monospace'), 14);
  bFillText(StrAddr('SHD'), 3, Integer(x) - 34, CH - 66);
  rdDrawBar(x, Single(CH) - 64.0, 220.0, sh, StrAddr('#4ecdc4'), 7);
  bFillText(StrAddr('HUL'), 3, Integer(x) - 34, CH - 46);
  if hu > 0.5 then
    rdDrawBar(x, Single(CH) - 44.0, 220.0, hu, StrAddr('#7fe0a0'), 7)
  else if hu > 0.25 then
    rdDrawBar(x, Single(CH) - 44.0, 220.0, hu, StrAddr('#ffce7a'), 7)
  else
    rdDrawBar(x, Single(CH) - 44.0, 220.0, hu, StrAddr('#ff5a4c'), 7);

  // missiles (bottom-right)
  bSetTextAlign(StrAddr('right'), 5);
  bSetFill(StrAddr('#ffce7a'), 7);
  bSetFont(StrAddr('14px monospace'), 14);
  n := HUDText(StrAddr('MSL '), 4, player.missile_count);
  bFillText(Integer(@text_buf), n, CW - 22, CH - 44);
  for i := 0 to player.missile_count - 1 do
  begin
    bSetStroke(StrAddr('#ffce7a'), 7);
    bSetLineWidth(1.5);
    bBeginPath;
    bMoveTo(Single(CW) - 22 + Single(i) * 14.0, CH - 22);
    bLineTo(Single(CW) - 28 + Single(i) * 14.0, CH - 30);
    bLineTo(Single(CW) - 16 + Single(i) * 14.0, CH - 30);
    bClosePath;
    bStroke;
  end;
  bSetTextAlign(StrAddr('left'), 4);

  rdDrawLock;
  rdDrawLead;
  rdDrawRadar;

  // damage vignette
  if player.shields < 30.0 then
  begin
    bSetFill(StrAddr('rgba(255,60,50,0.14)'), 20);
    bFillRect(0, 0, CW, 10);
    bFillRect(0, CH - 10, CW, 10);
    bFillRect(0, 0, 10, CH);
    bFillRect(CW - 10, 0, 10, CH);
  end;
  if player.hull < 30.0 then
  begin
    bSetFill(StrAddr('rgba(255,40,30,0.22)'), 20);
    bFillRect(0, 0, CW, 16);
    bFillRect(0, CH - 16, CW, 16);
    bFillRect(0, 0, 16, CH);
    bFillRect(CW - 16, 0, 16, CH);
  end;
end;

// ---------------------------------------------------------------------------
// Messages + overlays
// ---------------------------------------------------------------------------
procedure rdDrawMessage;
begin
  if (msg_timer > 0) and (msg_len > 0) then
  begin
    bSetFill(StrAddr('#ffce7a'), 7);
    bSetFont(StrAddr('bold 18px monospace'), 20);
    bSetTextAlign(StrAddr('center'), 6);
    bSetTextBaseline(StrAddr('top'), 3);
    bFillText(Integer(@msg_buf), msg_len, CW div 2, 44);
    bSetTextAlign(StrAddr('left'), 4);
  end;
end;

procedure rdDim(alpha: Single);
begin
  bSetFill(StrAddr('rgba(3,5,10,0.78)'), 17);
  bSetGlobalAlpha(alpha);
  bFillRect(0, 0, CW, CH);
  bSetGlobalAlpha(1.0);
end;

procedure rdDrawTitle;
var
  blink: Boolean;
begin
  rdDim(0.85);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('middle'), 6);

  bSetFill(StrAddr('#9fe8ff'), 7);
  bSetFont(StrAddr('bold 58px monospace'), 21);
  bFillText(StrAddr('FLIGHT LEADER'), 13, CW div 2, 150);
  bSetFill(StrAddr('#7fe0a0'), 7);
  bSetFont(StrAddr('16px monospace'), 14);
  bFillText(StrAddr('AN ARCADE SPACE COMBAT TRIBUTE'), 30, CW div 2, 205);

  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('17px monospace'), 14);
  bFillText(StrAddr('ARROWS: FLY    W/S: THROTTLE    SHIFT: AFTERBURN'), 48, CW div 2, 300);
  bFillText(StrAddr('SPACE: LASERS    TAB: MISSILE    P: PAUSE'), 45, CW div 2, 330);

  bSetFill(StrAddr('#ff8a7a'), 7);
  bSetFont(StrAddr('bold 16px monospace'), 19);
  bFillText(StrAddr('SOLO MISSION - NO WINGMEN. ALL CONTACTS ARE HOSTILE'), 51, CW div 2, 380);

  bSetFill(StrAddr('#9fb2d0'), 7);
  bSetFont(StrAddr('13px monospace'), 14);
  bFillText(StrAddr('CYAN = YOU  RED = HOSTILE  BAR = HP'), 35, CW div 2, 410);

  blink := (Integer(anim_time * 2.0) mod 2) = 0;
  if blink then
  begin
    bSetFill(StrAddr('#ffce7a'), 7);
    bSetFont(StrAddr('bold 20px monospace'), 19);
    bFillText(StrAddr('PRESS ENTER TO BEGIN'), 20, CW div 2, 450);
  end;
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
end;

procedure rdDrawBriefing;
var
  n: Integer;
begin
  rdDim(0.88);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('middle'), 6);

  bSetFill(StrAddr('#9fe8ff'), 7);
  bSetFont(StrAddr('bold 34px monospace'), 20);
  n := HUDText(StrAddr('MISSION '), 8, wave + 1);   // wave is 0 until launch
  bFillText(Integer(@text_buf), n, CW div 2, 150);

  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('17px monospace'), 14);
  if wave = 1 then
  begin
    bFillText(StrAddr('PIRATE RAIDERS ARE HITTING CONVOY ROUTES IN THE'), 47, CW div 2, 250);
    bFillText(StrAddr('VEGA SECTOR. SWEEP THE AREA CLEAN, PILOT.'), 41, CW div 2, 280);
  end
  else if wave = 2 then
  begin
    bFillText(StrAddr('INTELLIGENCE REPORTS A GUNBOAT ESCORTING THE'), 44, CW div 2, 250);
    bFillText(StrAddr('RAIDERS. IT PACKS HEAVIER ARMAMENT - STAY SHARP.'), 48, CW div 2, 280);
  end
  else begin
    bFillText(StrAddr('THE CAPITAL SHIP "REVENANT" IS THE RAIDERS BASE.'), 48, CW div 2, 250);
    bFillText(StrAddr('DESTROY IT AND THE VEGA SECTOR IS SECURE. GOOD LUCK.'), 52, CW div 2, 280);
  end;

  bSetFill(StrAddr('#ff8a7a'), 7);
  bSetFont(StrAddr('bold 16px monospace'), 19);
  bFillText(StrAddr('SOLO MISSION - YOU ALONE AGAINST THE FLEET'), 42, CW div 2, 330);
  bSetFill(StrAddr('#9fb2d0'), 7);
  bSetFont(StrAddr('13px monospace'), 14);
  bFillText(StrAddr('CYAN = YOU  RED = HOSTILE  BAR = HP'), 35, CW div 2, 356);

  bSetFill(StrAddr('#ffce7a'), 7);
  bSetFont(StrAddr('bold 18px monospace'), 19);
  bFillText(StrAddr('PRESS ENTER TO LAUNCH'), 21, CW div 2, 410);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
end;

procedure rdDrawWaveClear;
var
  n: Integer;
begin
  rdDim(0.6);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('middle'), 6);
  bSetFill(StrAddr('#7fe0a0'), 7);
  bSetFont(StrAddr('bold 40px monospace'), 19);
  n := HUDText(StrAddr('WAVE '), 5, wave);
  text_buf[n] := Byte(32);
  text_buf[n + 1] := Byte(67); text_buf[n + 2] := Byte(76); text_buf[n + 3] := Byte(69);
  text_buf[n + 4] := Byte(65); text_buf[n + 5] := Byte(82); text_buf[n + 6] := Byte(69);
  text_buf[n + 7] := Byte(68);
  bFillText(Integer(@text_buf), n + 8, CW div 2, CH div 2 - 40);
  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('18px monospace'), 14);
  n := HUDText(StrAddr('SCORE '), 6, score);
  bFillText(Integer(@text_buf), n, CW div 2, CH div 2 + 20);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
end;

procedure rdDrawDead;
begin
  rdDim(0.7);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('middle'), 6);
  bSetFill(StrAddr('#ff5a4c'), 7);
  bSetFont(StrAddr('bold 44px monospace'), 19);
  bFillText(StrAddr('SHIP DESTROYED'), 14, CW div 2, CH div 2 - 30);
  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('18px monospace'), 14);
  bFillText(StrAddr('EJECTION SEQUENCE COMPLETE'), 25, CW div 2, CH div 2 + 20);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
end;

procedure rdDrawDebrief;
var
  n, rl: Integer;
  won: Boolean;
begin
  won := wave >= WAVE_COUNT;
  rdDim(0.9);
  bSetTextAlign(StrAddr('center'), 6);
  bSetTextBaseline(StrAddr('middle'), 6);

  if won then
  begin
    bSetFill(StrAddr('#7fe0a0'), 7);
    bSetFont(StrAddr('bold 44px monospace'), 19);
    bFillText(StrAddr('MISSION COMPLETE'), 16, CW div 2, 140);
  end else begin
    bSetFill(StrAddr('#ff5a4c'), 7);
    bSetFont(StrAddr('bold 44px monospace'), 19);
    bFillText(StrAddr('MISSION FAILED'), 15, CW div 2, 140);
  end;

  bSetFill(StrAddr('#e8f0ff'), 7);
  bSetFont(StrAddr('20px monospace'), 14);
  n := HUDText(StrAddr('SCORE '), 6, score);
  bFillText(Integer(@text_buf), n, CW div 2, 230);
  n := HUDText(StrAddr('KILLS '), 6, kills);
  bFillText(Integer(@text_buf), n, CW div 2, 264);
  n := HUDText(StrAddr('ACCURACY '), 9, simAccuracy);
  text_buf[n] := Byte(37);
  bFillText(Integer(@text_buf), n + 1, CW div 2, 298);

  bSetFill(StrAddr('#ffce7a'), 7);
  bSetFont(StrAddr('22px monospace'), 14);
  // "RANK " + rank word, built in text_buf
  text_buf[0] := 82; text_buf[1] := 65; text_buf[2] := 78; text_buf[3] := 75; text_buf[4] := 32;
  rl := simRankText(PByte(Integer(@text_buf) + 5));
  bFillText(Integer(@text_buf), rl + 5, CW div 2, 348);

  bSetFill(StrAddr('#9fb2d0'), 7);
  bSetFont(StrAddr('15px monospace'), 14);
  bFillText(StrAddr('PRESS ENTER TO RETURN TO BASE'), 30, CW div 2, 420);
  bSetTextAlign(StrAddr('left'), 4);
  bSetTextBaseline(StrAddr('top'), 3);
end;

// ---------------------------------------------------------------------------
// Frame
// ---------------------------------------------------------------------------
procedure rdDrawFrame;
begin
  cbReset;

  bSetFill(StrAddr('#05070d'), 7);
  bFillRect(0, 0, CW, CH);

  bSave;
  bTranslate(shake_x, shake_y);

  rdDrawStars;
  rdDrawBolts;
  rdDrawMissiles;
  rdDrawEnemies;
  if game_state <> GS_DEAD then rdDrawPlayerShip;
  fxDraw;

  bRestore;

  rdDrawHUD;
  rdDrawMessage;

  if game_state = GS_TITLE then rdDrawTitle
  else if game_state = GS_BRIEFING then rdDrawBriefing
  else if game_state = GS_WAVECLEAR then rdDrawWaveClear
  else if game_state = GS_DEAD then rdDrawDead
  else if game_state = GS_DEBRIEF then rdDrawDebrief;

  bBatchFlush(ctx_h, Integer(@cb_cmd), cb_len);
end;

end.
