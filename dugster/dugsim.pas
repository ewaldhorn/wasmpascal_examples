// dugsim.pas — DUGSTER simulation: held-key movement (release stops;
// a 0.25 s tap grace keeps quick taps reliable — verified vs the 1983
// original), emerald collection, gold bags (wobble, fall, crush, shatter),
// nobbin chase AI, hobbin dirt-eating AI, crush respawns, cherry bonus,
// scoring, lives, and level/state flow.
unit dugsim;

interface

uses
  dugdefs,
  duglevel,
  dugfx;

// Full reset (score/lives/level) then start level 1.
procedure simInitGame;

// Start (or restart) the current level: fresh board, actors placed.
procedure simStartLevel;

// Add score through the P4 extra-life rule (20,000 multiples, 5-life cap).
procedure simAddScore(n: Integer);

// Advance the sim by dt seconds.
procedure simStep(dt: Single);

// Input from the root's keyboard handler. Steering is sticky by design:
// pressing a direction rolls that way until a new direction or a wall.
procedure simKeyDown(d: Integer);
procedure simKeyUp(d: Integer);
procedure simPressSpace;
procedure simPauseButton;
// Live readouts for the renderer. dugrender's own global reads of the
// player pos/acc went stale in the browser build (sprite lag) while the
// sim's copies stay live (tunnels/score/catches prove it), so the root
// ferries these by value each frame instead of letting dugrender read
// the globals. See rdDrawPlayer.
function simPX: Integer;
function simPY: Integer;
function simPDir: Integer;
function simTime: Single;
// Monster readouts (A4: 6 dispenser slots, not a fixed pair). Same
// stale-global story as the player ones above: the root ferries these by
// value each frame. See rdDrawMonster.
function simMonX(s: Integer): Integer;
function simMonY(s: Integer): Integer;
function simMonDir(s: Integer): Integer;
function simMonNob(s: Integer): Integer;    // 1 = nobbin, 0 = hobbin
function simMonActive(s: Integer): Integer;
// Monsters remaining: on screen + still owed by the quota (original
// monleft — extermination clears the level, delta 8).
function simMonLeft: Integer;
// Screenshake clock readout. Ferried root-side like the actors (same
// stale class as the accumulator reads).
function simShakeT: Single;
procedure simTogglePause;

implementation

// A4: live slots re-rack to the dispenser (same individuals — type and
// morph clock survive death; position resets to the spawn point top-right);
// dead slots stay dead; the quota is per-level and lives in simStartLevel.
procedure simPlaceActors;
var
  k, s: Integer;
begin
  dgPx := 0; dgPy := ROWS1; dgPdir := D_RIGHT; dgWantDir := D_NONE;
  dgBufT := 0.0;
  // Re-derive from physically held keys: respawning mid-hold must keep
  // rolling (no fresh keydown arrives for an already-held key).
  for k := K_UP to K_RIGHT do
    if dgKeys[k] then dgWantDir := k + 1;
  for s := 0 to MON_SLOTS1 do
    if dgMonActive[s] then
    begin
      dgMonX[s] := COLS1; dgMonY[s] := 0;
      dgMonDir[s] := D_LEFT;  // original spawns heading left
      dgMonAcc[s] := 0.0; dgMonSkip[s] := false;
    end;
  dgPAcc := 0.0; dgBagAcc := 0.0;
  dgTime := 0.0;
  // Octave streak restarts on death and level alike (original resets
  // emn/emocttime at respawn); the bonus multiplier rests at msc base 1
  // (death ends bonus, so it is moot after a catch anyway).
  dgEmStreak := 0;
  dgEmWindow := 0.0;
  dgEatStreak := 1;
  // (No cherry reset: a waiting cherry survives death — only eaten and
  // level-end clear it. simStartLevel owns the per-level reset.)
  dgFAx := -1; dgFAy := 0; dgFDir := D_NONE;
  dgFAcc := 0.0; dgFCool := 0.0; dgFMax := 1.0;
  dgEffP := STEP_PH;
end;

// Difficulty divisor for the nobbin double-step: 1 in N extra steps,
// N shrinking 14 (level 1) to a 5 floor — the original's randno(15-level).
// Floor 5 matches the original's cap: the 1983 game only had 10 levels.
function monDivisor: Integer;
begin
  monDivisor := 15 - dgLevel;
  if monDivisor < 5 then monDivisor := 5;
end;

// P4 (A3 numbers): every score flows through here. Each 20,000 multiple
// awards an extra life (level-clear chime + gold burst on the player) up
// to 5 lives total — further multiples are silently consumed, exactly
// like the original.
procedure simAddScore(n: Integer);
begin
  dgScore := dgScore + n;
  while dgNextExtra <= dgScore do
  begin
    dgNextExtra := dgNextExtra + EXTRA_EVERY;
    if dgLives < LIVES_MAX then
    begin
      dgLives := dgLives + 1;
      dgPlaySound(SND_LEVEL);
      fxBurst(Single(dgPx), Single(dgPy), 2);
    end;
  end;
end;

procedure simInitGame;
var
  i: Integer;
begin
  dgScore := 0;
  dgNextExtra := EXTRA_EVERY;
  dgLives := LIVES_START;
  dgLevel := 1;
  dgPaused := false;
  for i := 0 to 5 do dgKeys[i] := false;
  simStartLevel;
  dgState := ST_TITLE;
end;

procedure simStartLevel;
var
  s: Integer;
begin
  lvNewLevel;
  // A4 quota (original initmonsters): level+5 owed; first dispense 10
  // ticks (0.8 s) in. Slots start empty — the spawner fills them.
  dgMonTotal := dgLevel + 5;
  dgMonSpawned := 0;
  dgSpawnT := 0.8;
  for s := 0 to MON_SLOTS1 do dgMonActive[s] := false;
  // A1: no cherry yet this level; the eat multiplier rests at its msc
  // base of 1.
  dgChT := -1.0;
  dgCherryDone := false;
  dgEatStreak := 1;
  simPlaceActors;
  // Bonus never carries across levels (P2); simInitGame funnels
  // through here too, so new games reset as well.
  dgBonusT := 0.0;
end;

procedure simKeyDown(d: Integer);
begin
  if d < K_UP then Exit;
  if d > K_PAUSE then Exit;
  dgKeys[d] := true;
  // Direction keys only (K_UP..K_RIGHT = 0..3): set wantDir + clear grace.
  if (d = K_UP) or (d = K_DOWN) or (d = K_LEFT) or (d = K_RIGHT) then
  begin
    dgWantDir := d + 1;  // K_UP..K_RIGHT map to D_UP..D_RIGHT
    dgBufT := 0.0;
  end;
end;

procedure simKeyUp(d: Integer);
var
  k: Integer;
begin
  if d < K_UP then Exit;
  if d > K_PAUSE then Exit;
  dgKeys[d] := false;
  // Original rule (digger.c updatedigger): mdir re-derives from the held
  // key every frame; no key held means stop. Release falls back to any
  // other held dir; with nothing held a short grace keeps rolling so the
  // in-flight tap still steps exactly once (consumed on step, below).
  if dgWantDir = d + 1 then
  begin
    for k := K_UP to K_RIGHT do
      if dgKeys[k] then dgWantDir := k + 1;
    // Nothing else held: KEEP wantDir + grace so the in-flight tap steps
    // once (consumed on step); the step gate stops us when grace expires.
    // dgWantDir >= 1 here — the outer guard (d = wantDir-1, d >= K_UP=0)
    // ensures wantDir was at least 1 before this block.
    if not dgKeys[dgWantDir - 1] then dgBufT := BUFFER_T;
  end;
end;

procedure simTryFire;
begin
  if dgPaused then Exit;
  if dgFCool > 0.0 then Exit;
  if dgFAx >= 0 then Exit;  // one fireball in flight at a time
  // Original recharge: level*3+60 ticks at 12.5 ticks/s, i.e. 5.0 s base
  // + 0.24 s per level, hard-capped at level 10 (7.2 s).
  dgFCool := FIRE_COOL + 0.24 * Single(dgLevel - 1);
  if dgFCool > 7.2 then dgFCool := 7.2;
  dgFMax := dgFCool;  // A2: stamp the full recharge for the indicator
  dgFAx := dgPx; dgFAy := dgPy;
  dgFDir := dgPdir;
  if dgFDir = D_NONE then dgFDir := D_RIGHT;
  dgFAcc := 0.0;
  dgPlaySound(SND_FIRE);
end;

procedure simPressSpace;
begin
  if dgState = ST_TITLE then
  begin
    dgState := ST_PLAY;
    dgPlaySound(SND_START);
  end
  else if dgState = ST_OVER then
  begin
    simInitGame;
    dgState := ST_PLAY;
    dgPlaySound(SND_START);
  end
  else if dgState = ST_PLAY then
    simTryFire;
end;

procedure simTogglePause;
begin
  if dgState = ST_PLAY then dgPaused := not dgPaused;
end;

// A5 keymap (Remastered defaults): Space pauses mid-game but still
// starts/restarts on the title and game-over screens.
procedure simPauseButton;
begin
  if dgState = ST_PLAY then simTogglePause
  else simPressSpace;
end;

function simPX: Integer;
begin
  simPX := dgPx;
end;

function simPY: Integer;
begin
  simPY := dgPy;
end;

function simPDir: Integer;
begin
  simPDir := dgPdir;
end;

function simTime: Single;
begin
  simTime := dgTime;
end;

// A4 slot getters. Out-of-range slots read 0 (defensive; callers use
// 0..MON_SLOTS1).
function simMonX(s: Integer): Integer;
begin
  simMonX := 0;
  if (s >= 0) and (s <= MON_SLOTS1) then simMonX := dgMonX[s];
end;

function simMonY(s: Integer): Integer;
begin
  simMonY := 0;
  if (s >= 0) and (s <= MON_SLOTS1) then simMonY := dgMonY[s];
end;

function simMonDir(s: Integer): Integer;
begin
  simMonDir := D_NONE;
  if (s >= 0) and (s <= MON_SLOTS1) then simMonDir := dgMonDir[s];
end;

function simMonNob(s: Integer): Integer;
begin
  simMonNob := 0;
  if (s >= 0) and (s <= MON_SLOTS1) and dgMonNob[s] then simMonNob := 1;
end;

function simMonActive(s: Integer): Integer;
begin
  simMonActive := 0;
  if (s >= 0) and (s <= MON_SLOTS1) and dgMonActive[s] then
    simMonActive := 1;
end;

function simActiveCount: Integer;
var
  s: Integer;
begin
  simActiveCount := 0;
  for s := 0 to MON_SLOTS1 do
    if dgMonActive[s] then simActiveCount := simActiveCount + 1;
end;

function simMonLeft: Integer;
begin
  simMonLeft := simActiveCount + dgMonTotal - dgMonSpawned;
end;

// A4 on-screen cap (original initmonsters): 3 on L1, 4 on L2-7, 5 on L8+.
function simMonCap: Integer;
begin
  if dgLevel <= 1 then simMonCap := 3
  else if dgLevel <= 7 then simMonCap := 4
  else simMonCap := 5;
end;

function simShakeT: Single;
begin
  simShakeT := dgShakeT;
end;

// Score popup spawn (G6): round-robin into the dugdefs pool the
// renderer draws. Declared before first use (emerald site in
// simStepPlayer below).
procedure simSpawnPop(cx, cy, pts: Integer);
begin
  dgPopX[dgPopNext] := cx;
  dgPopY[dgPopNext] := cy;
  dgPopN[dgPopNext] := pts;
  dgPopT[dgPopNext] := POP_T;
  dgPopNext := dgPopNext + 1;
  if dgPopNext > POP_MAX1 then dgPopNext := 0;
end;

procedure simCaught;
begin
  dgLives := dgLives - 1;
  dgPlaySound(SND_DEATH);
  fxBurst(Single(dgPx), Single(dgPy), 1);
  dgShakeT := SHAKE_T;
  // Death ends bonus mode (verified: bonusmode && !isalive →
  // endbonusmode). A waiting cherry survives death (only eaten and
  // level-end clear it), so simPlaceActors must not touch it.
  dgBonusT := 0.0;
  simPlaceActors;
  dgState := ST_DEAD;
  dgDeadT := DEAD_PAUSE;
end;

procedure simTakeCherry;
begin
  dgChT := -1.0;
  simAddScore(SCORE_CHERRY);
  dgPlaySound(SND_EMERALD);
  fxBurst(Single(dgChX), Single(dgChY), 2);
  simSpawnPop(dgChX, dgChY, SCORE_CHERRY);
  // Bonus mode (P2/A1): fright duration shrinks per level, 4 s floor;
  // the eat multiplier restarts at 1 with every cherry (original msc).
  dgEatStreak := 1;
  dgBonusT := 18.4 - 1.6 * Single(dgLevel - 1);
  if dgBonusT < 4.0 then dgBonusT := 4.0;
end;

// A6 cell occupant: any live hunter on (x, y) (original pushbag blocks
// on digger/monster overlap). O(slots) — fine for the 6-slot cap.
function simMonAt(x, y: Integer): Integer;
var
  s: Integer;
begin
  simMonAt := 0;
  for s := 0 to MON_SLOTS1 do
    if dgMonActive[s] and (dgMonX[s] = x) and (dgMonY[s] = y) then
    begin
      simMonAt := 1;
      Exit;
    end;
end;

// A6 pushable bags (original pushbag/pushbags): shoving horizontally into
// a resting bag slides the whole consecutive resting run one cell, far
// end first (the original recurses the same way). The far cell must be
// in bounds with no bag and no hunter; falling bags never push; a gold
// pile in the far cell is eaten for its 500 (original getgold-on-push).
// Pushed bags land unwobbled (the original restarts wt=15 on push).
function simPushBags(bx, by, dir: Integer): Integer;
var
  dx, ex, cx: Integer;
begin
  simPushBags := 0;
  dx := 1;
  if dir = D_LEFT then dx := -1;
  if lvBagAt(bx, by) <> BAG_REST then Exit;
  ex := bx;
  while (lvInBounds(ex + dx, by) = 1) and
    (lvBagAt(ex + dx, by) = BAG_REST) do
    ex := ex + dx;
  ex := ex + dx;
  if lvInBounds(ex, by) = 0 then Exit;
  if lvBagAt(ex, by) <> BAG_NONE then Exit;
  if simMonAt(ex, by) = 1 then Exit;
  if lvHasGold(ex, by) = 1 then
  begin
    lvClearGold(ex, by);
    simAddScore(SCORE_GOLD);
    dgPlaySound(SND_EMERALD);
    fxBurst(Single(ex), Single(by), 2);
    simSpawnPop(ex, by, SCORE_GOLD);
  end;
  cx := ex - dx;
  // Slide bags toward the player, far end first: start at the far bag,
  // move it one cell in the push direction, then walk back to bx.
  repeat
    lvClearBag(cx, by);
    lvSetBag(cx + dx, by, BAG_REST);
    cx := cx - dx;
  until cx = bx - dx;
  simPushBags := 1;
end;

procedure simStepPlayer;
var
  nx, ny, k: Integer;
begin
  // Held keys re-assert every step (the original re-reads input each
  // frame): pushing against a wall or bag resumes the moment it opens.
  if dgWantDir = D_NONE then
    for k := K_UP to K_RIGHT do
      if dgKeys[k] then dgWantDir := k + 1;
  if dgWantDir = D_NONE then Exit;
  // Released with grace expired: stop, like the original's DIR_NONE.
  if not dgKeys[dgWantDir - 1] then
  begin
    if dgBufT <= 0.0 then
    begin
      dgWantDir := D_NONE;
      Exit;
    end;
  end;
  nx := dgPx;
  ny := dgPy;
  if dgWantDir = D_UP then ny := dgPy - 1
  else if dgWantDir = D_DOWN then ny := dgPy + 1
  else if dgWantDir = D_LEFT then nx := dgPx - 1
  else if dgWantDir = D_RIGHT then nx := dgPx + 1;
  // Walls stop the roll.
  if lvInBounds(nx, ny) = 0 then
  begin
    dgWantDir := D_NONE;
    Exit;
  end;
  // Resting bags shove sideways by play (A6 pushbag, horizontal only);
  // falling bags, blocked pushes, and vertical shoves stop the roll.
  if lvBagAt(nx, ny) <> BAG_NONE then
    if not (((dgWantDir = D_LEFT) or (dgWantDir = D_RIGHT)) and
      (simPushBags(nx, ny, dgWantDir) = 1)) then Exit;
  dgPx := nx;
  dgPy := ny;
  dgPdir := dgWantDir;
  // A step on released keys consumes the grace: taps move exactly once.
  if not dgKeys[dgWantDir - 1] then dgBufT := 0.0;
  if lvIsDug(nx, ny) = 0 then
  begin
    lvDig(nx, ny);
    simAddScore(SCORE_DIG);
    dgPlaySound(SND_DIG);
  end;
  if lvTakeEmerald(nx, ny) = 1 then
  begin
    // Octave (A5, verified): a lapsed window restarts the streak; every
    // 8th consecutive emerald pays +250 with a popup on top of its 25.
    if dgEmWindow <= 0.0 then dgEmStreak := 0;
    simAddScore(SCORE_EMERALD);
    dgPlaySound(SND_EMERALD);
    fxBurst(Single(nx), Single(ny), 0);
    simSpawnPop(nx, ny, SCORE_EMERALD);
    dgEmStreak := dgEmStreak + 1;
    if dgEmStreak >= 8 then
    begin
      dgEmStreak := 0;
      simAddScore(SCORE_OCTAVE);
      simSpawnPop(nx, ny, SCORE_OCTAVE);
    end;
    dgEmWindow := EM_WINDOW;
  end;
  // Spilled gold (A5): walking in collects the 500-pt pile.
  if lvHasGold(nx, ny) = 1 then
  begin
    lvClearGold(nx, ny);
    simAddScore(SCORE_GOLD);
    dgPlaySound(SND_EMERALD);
    fxBurst(Single(nx), Single(ny), 2);
    simSpawnPop(nx, ny, SCORE_GOLD);
  end;
  // Cherry pickup: tested after the move so the step that lands on
  // the cherry is the one that collects it (same-tick collection).
  if (dgChT > 0.0) and (dgPx = dgChX) and (dgPy = dgChY) then simTakeCherry;
end;

// Reverse a move direction (A4 no-reverse rule).
function simRevDir(d: Integer): Integer;
begin
  if d = D_UP then simRevDir := D_DOWN
  else if d = D_DOWN then simRevDir := D_UP
  else if d = D_LEFT then simRevDir := D_RIGHT
  else if d = D_RIGHT then simRevDir := D_LEFT
  else simRevDir := D_NONE;
end;

// A4 chase for one slot (original monai): ordered pref list, major axis
// first; bonus fully reverses it (flee); reverse-of-travel demotes to
// last (never removed); levels <6 swap best with third at 1/(level+5)
// (the wander). Nobbins take the first legal pref (bounds + dug +
// bagless = fieldclear); hobbins take the top pref and dig through.
procedure simStepChaser(s: Integer);
var
  i, d, t, nx, ny, dx, dy, adx, ady: Integer;
  mx, my: Integer;
  nob: Boolean;
  p0, p1, p2, p3: Integer;
begin
  mx := dgMonX[s];
  my := dgMonY[s];
  nob := dgMonNob[s];
  // Morph clocks (monster.c): nobbins morph on contact/stuck ticks, past
  // 10-level; hobbins revert on age ticks, past 30+2*level.
  if nob then
  begin
    if dgMonHnt[s] > 10 - dgLevel then
    begin
      dgMonNob[s] := false;
      dgMonHnt[s] := 0;
      nob := false;
    end;
  end
  else if dgMonHnt[s] > 30 + 2 * dgLevel then
  begin
    dgMonNob[s] := true;
    dgMonHnt[s] := 0;
    nob := true;
  end;
  dx := dgPx - mx;
  dy := dgPy - my;
  adx := dx;
  if adx < 0 then adx := -adx;
  ady := dy;
  if ady < 0 then ady := -ady;
  if ady > adx then
  begin
    if dy < 0 then p0 := D_UP else p0 := D_DOWN;
    p3 := simRevDir(p0);
    if dx < 0 then
    begin
      p1 := D_LEFT;
      p2 := D_RIGHT;
    end
    else
    begin
      p1 := D_RIGHT;
      p2 := D_LEFT;
    end;
  end
  else
  begin
    if dx < 0 then p0 := D_LEFT else p0 := D_RIGHT;
    p3 := simRevDir(p0);
    if dy < 0 then
    begin
      p1 := D_UP;
      p2 := D_DOWN;
    end
    else
    begin
      p1 := D_DOWN;
      p2 := D_UP;
    end;
  end;
  if dgBonusT > 0.0 then
  begin
    t := p0; p0 := p3; p3 := t;
    t := p1; p1 := p2; p2 := t;
  end;
  d := simRevDir(dgMonDir[s]);
  if d = p0 then
  begin
    p0 := p1; p1 := p2; p2 := p3; p3 := d;
  end
  else if d = p1 then
  begin
    p1 := p2; p2 := p3; p3 := d;
  end
  else if d = p2 then
  begin
    p2 := p3; p3 := d;
  end;
  if (dgLevel < 6) and (dgRandRangeI(0, dgLevel + 4) = 1) then
  begin
    t := p0; p0 := p2; p2 := t;
  end;
  if nob then
  begin
    // Monster contact ticks the morph clock (the spawn pile-up is what
    // makes hobbins, per monster.c).
    for i := 0 to MON_SLOTS1 do
      if (i <> s) and dgMonActive[i] and (dgMonX[i] = mx) and
        (dgMonY[i] = my) then
        dgMonHnt[s] := dgMonHnt[s] + 1;
    d := D_NONE;
    for i := 0 to 3 do
    begin
      if i = 0 then t := p0
      else if i = 1 then t := p1
      else if i = 2 then t := p2
      else t := p3;
      nx := mx;
      ny := my;
      if t = D_UP then ny := my - 1
      else if t = D_DOWN then ny := my + 1
      else if t = D_LEFT then nx := mx - 1
      else nx := mx + 1;
      if lvInBounds(nx, ny) = 0 then continue;
      if lvIsDug(nx, ny) = 0 then continue;
      // A top pref blocked by a bag is "stuck on h-bag" (hnt++); bags
      // are walls to nobbins either way (fieldclear).
      if lvBagAt(nx, ny) <> BAG_NONE then
      begin
        if i = 0 then dgMonHnt[s] := dgMonHnt[s] + 1;
        continue;
      end;
      d := t;
      break;
    end;
  end
  else
  begin
    // Hobbins take the top pref and dig through; aging ticks here.
    // (The original edge-stops instead of leaving the board.)
    d := p0;
    nx := mx;
    ny := my;
    if d = D_UP then ny := my - 1
    else if d = D_DOWN then ny := my + 1
    else if d = D_LEFT then nx := mx - 1
    else nx := mx + 1;
    if lvInBounds(nx, ny) = 0 then d := D_NONE
    else if dgMonHnt[s] < 100 then dgMonHnt[s] := dgMonHnt[s] + 1;
  end;
  if d = D_NONE then Exit;
  // Turn tax (original: t++ delays the next move on direction change).
  if d <> dgMonDir[s] then
  begin
    dgMonSkip[s] := true;
    dgMonDir[s] := d;
  end;
  if d = D_UP then my := my - 1
  else if d = D_DOWN then my := my + 1
  else if d = D_LEFT then mx := mx - 1
  else mx := mx + 1;
  if not nob then
    if lvIsDug(mx, my) = 0 then lvDig(mx, my);
  dgMonX[s] := mx;
  dgMonY[s] := my;
  // Hobbins plow through bags, eating them (original removebags).
  if not nob then
    if lvBagAt(mx, my) <> BAG_NONE then lvClearBag(mx, my);
end;

// A4: a kill frees the slot — the dispenser sends the replacement
// (quota permitting), never a respawn timer.
procedure simShootMonster(s: Integer);
begin
  simAddScore(SCORE_FIRE);
  dgPlaySound(SND_HIT);
  fxBurst(Single(dgMonX[s]), Single(dgMonY[s]), 1);
  simSpawnPop(dgMonX[s], dgMonY[s], SCORE_FIRE);
  dgMonActive[s] := false;
end;

procedure simStepFire;
var
  nx, ny, hit, s: Integer;
begin
  if dgFAx < 0 then Exit;
  nx := dgFAx;
  ny := dgFAy;
  if dgFDir = D_UP then ny := dgFAy - 1
  else if dgFDir = D_DOWN then ny := dgFAy + 1
  else if dgFDir = D_LEFT then nx := dgFAx - 1
  else if dgFDir = D_RIGHT then nx := dgFAx + 1
  else
  begin
    dgFAx := -1;
    Exit;
  end;
  // Dirt and walls stop the shot; monsters die to it.
  if (lvInBounds(nx, ny) = 0) or (lvIsDug(nx, ny) = 0) then
  begin
    dgFAx := -1;
    Exit;
  end;
  dgFAx := nx;
  dgFAy := ny;
  fxPuff(Single(nx), Single(ny), 2);  // G4: gold drip each travelled cell
  hit := 0;
  for s := 0 to MON_SLOTS1 do
    if dgMonActive[s] and (dgMonX[s] = nx) and (dgMonY[s] = ny) then
    begin
      simShootMonster(s);
      hit := 1;
    end;
  if hit = 1 then dgFAx := -1;  // the shot is spent
end;

procedure simCrushMonster(s: Integer);
begin
  simAddScore(SCORE_CRUSH);
  dgPlaySound(SND_LEVEL);
  dgShakeT := SHAKE_T;
  fxBurst(Single(dgMonX[s]), Single(dgMonY[s]), 2);
  simSpawnPop(dgMonX[s], dgMonY[s], SCORE_CRUSH);
  dgMonActive[s] := false;
end;

// Bonus eat (P2/A1/A4): doubling multiplier (original msc <<= 1 after
// each scoreeatm: 200, 400, 800, ...), red burst + kill popup. Every
// bonus kill EXTENDS the quota (original killmon: totalmonsters++ while
// bonusmode), so eaten hunters always come back.
procedure simEatMonster(s: Integer);
var
  pts: Integer;
begin
  pts := dgEatStreak * 200;
  simAddScore(pts);
  dgEatStreak := dgEatStreak * 2;
  dgPlaySound(SND_HIT);
  fxBurst(Single(dgMonX[s]), Single(dgMonY[s]), 1);
  simSpawnPop(dgMonX[s], dgMonY[s], pts);
  dgMonActive[s] := false;
  if dgBonusT > 0.0 then dgMonTotal := dgMonTotal + 1;
end;

// Touch resolver (P2): a live bonus eats the monster, else death.
procedure simTouchMonster(s: Integer);
begin
  if dgBonusT > 0.0 then simEatMonster(s)
  else simCaught;
end;

// Returns 1 if the bag has solid ground below (floor, solid dirt, or another
// bag) and should stay put; 0 if it should fall.
function simBagSupported(x, y: Integer): Integer;
begin
  simBagSupported := 1;
  if y >= ROWS1 then Exit;                       // the floor
  if lvIsDug(x, y + 1) = 0 then Exit;            // solid dirt below
  if lvBagAt(x, y + 1) <> BAG_NONE then Exit;    // stacked on a bag
  simBagSupported := 0;
end;

procedure simLandBag(x, y: Integer);
begin
  // A long fall shatters the bag into a collectible 500-pt gold pile
  // (A5, verified: no immediate points — only the later collection pays).
  if Trunc(lvBagT[y, x]) >= BAG_BREAK_FALL then
  begin
    lvClearBag(x, y);
    lvSetGold(x, y);
    dgPlaySound(SND_DIG);
    fxBurst(Single(x), Single(y), 2);
  end
  else
    lvSetBag(x, y, BAG_REST);
end;

procedure simFallBag(x, y: Integer);
var
  fallen: Single;
  s: Integer;
begin
  // Move one cell down; crush whoever is underneath.
  fallen := lvBagT[y, x] + 1.0;
  lvClearBag(x, y);
  if (dgPx = x) and (dgPy = y + 1) then
  begin
    lvSetBag(x, y + 1, BAG_FALL);
    lvBagT[y + 1, x] := fallen;
    simCaught;
    Exit;
  end;
  for s := 0 to MON_SLOTS1 do
    if dgMonActive[s] and (dgMonX[s] = x) and (dgMonY[s] = y + 1) then
      simCrushMonster(s);
  lvSetBag(x, y + 1, BAG_FALL);
  lvBagT[y + 1, x] := fallen;
  if simBagSupported(x, y + 1) = 1 then simLandBag(x, y + 1);
end;

procedure simStepBags(dt: Single);
var
  x, y: Integer;
begin
  // Scan bottom-up so a falling bag never moves twice in one step.
  for y := ROWS1 downto 0 do
    for x := 0 to COLS1 do
    begin
      // A falling bag may have killed the player mid-sweep; freeze the rest.
      if dgState <> ST_PLAY then Exit;
      // Spilled gold (A5) ages out on the bag cadence: (150-10*level)
      // ticks at 12.5 ticks/s, exactly like the original's gt/goldtime.
      if lvGold[y, x] then
      begin
        // lvGoldT/lvGold indexed [row, col] = [y, x] — consistent with all grids.
        lvGoldT[y, x] := lvGoldT[y, x] + dt;
        if lvGoldT[y, x] >= Single(150 - 10 * dgLevel) * 0.08 then
          lvClearGold(x, y);
        continue;
      end;
      if lvBag[y, x] = BAG_NONE then continue;
      if lvBag[y, x] = BAG_REST then
      begin
        if simBagSupported(x, y) = 1 then
          lvBagT[y, x] := 0.0
        // A bag never STARTS wobbling with Digger underneath (original
        // checkdiggerunderbag); walking under mid-wobble doesn't stop it.
        else if ((dgPx <> x) or (dgPy <> y + 1) or (lvBagT[y, x] > 0.0)) then
        begin
          lvBagT[y, x] := lvBagT[y, x] + dt;
          if lvBagT[y, x] >= WOBBLE_T then lvSetBag(x, y, BAG_FALL);
        end;
      end
      else
      begin
        if simBagSupported(x, y) = 1 then
          simLandBag(x, y)
        else
          simFallBag(x, y);
      end;
    end;
end;

// A1 quota cherry (original createbonus, verified drawbonus(292, 18)):
// once the whole quota has entered plus one spawn gap, the cherry waits
// at the dispenser cell (14, 0) until eaten — the original never times
// it out (only eaten and level-end clear it).
procedure simStepCherry;
begin
  if dgCherryDone then Exit;
  if dgMonSpawned < dgMonTotal then Exit;
  if dgSpawnT > 0.0 then Exit;
  dgCherryDone := true;
  dgChX := COLS1;
  dgChY := 0;
  dgChT := 1.0;
end;

// A4 dispenser (original domonsters/createmonster): while the quota owes
// monsters and the screen isn't full, dispense a fresh nobbin top-right
// heading left every spawn gap. Nothing dispenses during bonus.
procedure simSpawnMonster;
var
  s: Integer;
begin
  for s := 0 to MON_SLOTS1 do
    if not dgMonActive[s] then
    begin
      dgMonX[s] := COLS1; dgMonY[s] := 0;
      dgMonDir[s] := D_LEFT;
      dgMonNob[s] := true;
      dgMonHnt[s] := 0;
      dgMonAcc[s] := 0.0;
      dgMonSkip[s] := false;
      dgMonActive[s] := true;
      dgMonSpawned := dgMonSpawned + 1;
      Exit;
    end;
end;

// Spawn gap in seconds: 45-2*level ticks at 12.5 ticks/s (monster.c).
function simSpawnGap: Single;
begin
  simSpawnGap := Single(45 - 2 * dgLevel) * 0.08;
end;

procedure simStepSpawner(dt: Single);
begin
  // The gap clock ticks whenever play runs outside bonus (original
  // nextmontime); only the dispense itself needs quota + cap. A full
  // screen leaves the clock at zero so the next freed slot fills
  // immediately — and the quota cherry fires one gap after the last
  // dispense, exactly like the original.
  if dgBonusT > 0.0 then Exit;
  dgSpawnT := dgSpawnT - dt;
  if dgSpawnT > 0.0 then Exit;
  if dgMonSpawned >= dgMonTotal then Exit;
  if simActiveCount >= simMonCap then Exit;
  simSpawnMonster;
  dgSpawnT := simSpawnGap;
end;

function simPlayerCaught: Integer;
var
  s: Integer;
begin
  simPlayerCaught := 0;
  for s := 0 to MON_SLOTS1 do
    if dgMonActive[s] and (dgPx = dgMonX[s]) and (dgPy = dgMonY[s]) then
      simPlayerCaught := 1;
end;

// Persist a new best (P1): called on the game-over and level-clear
// transitions only, never per-frame.
procedure simSaveBest;
begin
  if dgScore > dgBest then
  begin
    dgBest := dgScore;
    dgSetBest(dgBest);
  end;
end;

procedure simStep(dt: Single);
var
  s: Integer;
begin
  // Screenshake clock (G6): decays in every live state (PLAY plus the
  // DEAD/WIN pauses the death shake plays out in), frozen while paused
  // so the pause-freeze assertion still holds pixel-perfect.
  if (not dgPaused) and (dgShakeT > 0.0) then
    dgShakeT := dgShakeT - dt;
  if (dgState = ST_DEAD) or (dgState = ST_WIN) then
  begin
    if dgState = ST_DEAD then
    begin
      dgDeadT := dgDeadT - dt;
      if dgDeadT <= 0.0 then
      begin
        if dgLives <= 0 then
        begin
          simSaveBest;
          dgState := ST_OVER;
        end
        else dgState := ST_PLAY;
      end;
    end
    else
    begin
      dgWinT := dgWinT - dt;
      if dgWinT <= 0.0 then
      begin
        dgLevel := dgLevel + 1;
        simStartLevel;
        dgState := ST_PLAY;
      end;
    end;
    Exit;
  end;

  if (dgState <> ST_PLAY) or dgPaused then Exit;

  dgTime := dgTime + dt;
  // Bonus clock (P2): PLAY-only decay like dgTime.
  if dgBonusT > 0.0 then dgBonusT := dgBonusT - dt;
  // Octave window (A5, emocttime): PLAY-only decay; a lapse restarts the
  // streak at the next emerald (checked at the take site).
  if dgEmWindow > 0.0 then dgEmWindow := dgEmWindow - dt;
  dgEffP := stepForDir(dgWantDir);
  if dgBufT > 0.0 then dgBufT := dgBufT - dt;

  dgPAcc := dgPAcc + dt;
  while dgPAcc >= dgEffP do
  begin
    dgPAcc := dgPAcc - dgEffP;
    simStepPlayer;
    // Player stepped onto a monster: attribute per-slot (P2 bonus eats).
    for s := 0 to MON_SLOTS1 do
      if dgMonActive[s] and (dgMonX[s] = dgPx) and (dgMonY[s] = dgPy) then
      begin
        simTouchMonster(s);
        Exit;  // early exit propagates through simStep — the tick is over
      end;
    // Level clears on emeralds-out OR extermination (delta 8: monleft).
    if (dgEmLeft <= 0) or (simMonLeft <= 0) then
    begin
      simAddScore(SCORE_LEVEL);
      simSaveBest;
      dgPlaySound(SND_LEVEL);
      dgState := ST_WIN;
      dgWinT := WIN_PAUSE;
      Exit;
    end;
  end;

  // A4 slot loop: per-slot acc/skip; nobbins double-step like before.
  for s := 0 to MON_SLOTS1 do
  begin
    if not dgMonActive[s] then continue;
    dgMonAcc[s] := dgMonAcc[s] + dt;
    while dgMonAcc[s] >= stepForDir(dgMonDir[s]) do
    begin
      dgMonAcc[s] := dgMonAcc[s] - stepForDir(dgMonDir[s]);
      if dgMonSkip[s] then
        dgMonSkip[s] := false  // turn tax: this step is spent turning
      else
      begin
        simStepChaser(s);
        if dgMonActive[s] and (dgMonX[s] = dgPx) and
          (dgMonY[s] = dgPy) then
        begin
          simTouchMonster(s);
          Exit;
        end;
        // Hunters eat spilled gold for free (original mongold: no score,
        // no penalty — the pile just vanishes).
        if lvHasGold(dgMonX[s], dgMonY[s]) = 1 then
          lvClearGold(dgMonX[s], dgMonY[s]);
        // Random extra step for nobbins, likelier per level
        // (original randno(15-lev), nob-only second monai).
        if dgMonNob[s] and (dgRandRangeI(0, monDivisor - 1) = 0) then
        begin
          simStepChaser(s);
          if dgMonActive[s] and (dgMonX[s] = dgPx) and
            (dgMonY[s] = dgPy) then
          begin
            simTouchMonster(s);
            Exit;
          end;
          if lvHasGold(dgMonX[s], dgMonY[s]) = 1 then
            lvClearGold(dgMonX[s], dgMonY[s]);
        end;
      end;
    end;
  end;

  dgBagAcc := dgBagAcc + dt;
  while dgBagAcc >= STEP_B do
  begin
    dgBagAcc := dgBagAcc - STEP_B;
    simStepBags(STEP_B);
    if dgState <> ST_PLAY then Exit;  // a falling bag may have killed us
  end;

  if dgFCool > 0.0 then dgFCool := dgFCool - dt;
  dgFAcc := dgFAcc + dt;
  while dgFAcc >= STEP_F do
  begin
    dgFAcc := dgFAcc - STEP_F;
    simStepFire;
  end;

  simStepSpawner(dt);
  simStepCherry;
end;

end.
