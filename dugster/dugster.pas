// dugster.pas — DUGSTER: a Digger-style arcade dig-em-up for WasmPascal.
//
// Dig tunnels through solid dirt, collect every emerald, and dodge the
// nobbins that hunt you through your own tunnels. Three lives per game,
// bonus points per level, endless levels.
//
// Batchiness ABI (batchiness_main / batchiness_invoke_callback /
// batchiness_set_last_event), same host wiring as pong.pas. All state,
// rules, and rendering live in the units; this root is just bootstrap,
// tick dispatch, and keyboard translation:
//   dugdefs    shared constants/state + host imports + batch writers + RNG
//   duglevel   dirt/emerald grids + level generation
//   dugfx      particle bursts
//   dugsim     digging, collection, monster AI, scoring, state flow
//   dugrender  tiles, sprites, HUD, overlays (one batch flush per frame)
//
// Controls: arrows or WASD steer while held (release stops, as in the
// 1983 original — a 0.25 s tap grace keeps quick taps reliable); F1 or
// Enter fires; SPACE starts/pauses; P also pauses mid-game.
library dugster;

uses
  dugdefs,
  duglevel,
  dugfx,
  dugsim,
  dugrender;

var
  keyBuf: array[0..15] of Byte;
  // Actor-glide state (player + both hunters). Root locals stay live
  // (see rdDrawSprite NOTE): anchor + last render (cells, fractional) +
  // last logic cell + the sim time and step time of the last logic step.
  // The fraction is (simTime - stepTime) / stepEff, so it needs no
  // accumulator reads at all (those go stale). A logic step starts the
  // new glide from the last RENDERED spot, so turns corner smoothly;
  // jumps over two cells snap to the logic cell. Hunters ride here too:
  // dugrender's monster-cell/accumulator reads go stale the same way the
  // player's did (sprites froze at spawn while live hunters caught real
  // kills), so the root glides both hunters and ferries finished render
  // positions by value. See rdDrawMonster.
  gAx, gAy, gRx, gRy: Single;
  gLx, gLy: Integer;
  gStepT, gStepEff: Single;
  gVert: Boolean;
  gInit: Boolean;
  // A4: one glide anchor set per dispenser slot (array elements ride as
  // var params — verified by probe). Slot state persists across spawns;
  // a fresh dispense always snaps (teleport rule in GlideActor).
  mAx, mAy, mRx, mRy: array[0..MON_SLOTS1] of Single;
  mLx, mLy: array[0..MON_SLOTS1] of Integer;
  mStepT, mStepEff: array[0..MON_SLOTS1] of Single;
  mVert: array[0..MON_SLOTS1] of Boolean;
  mInit: array[0..MON_SLOTS1] of Boolean;
  // Title-blink clock (G5): root-owned tick counter ferried by value.
  // dgTime freezes outside PLAY, and dugrender-owned mutable state went
  // stale twice — so the root counts, same as the actor glides.
  frTick: Integer;
  // Screenshake ferry (G6): simShakeT by value, same stale class as the
  // actor accumulators.
  shT: Single;

// Direction keys: press sets the held dir, release falls back to any
// other held dir (handled in the sim so key-up order doesn't stick).
procedure DirKey(k, down: Integer);
begin
  if down <> 0 then
    simKeyDown(k)
  else
    simKeyUp(k);
end;

// SPACE: guarded against key-repeat so one press pauses exactly once
// (A5: Space pauses mid-game, still starts/restarts on title/game-over).
// K_SPACE and K_PAUSE are separate slots so both can be held simultaneously.
procedure SpaceKey(down: Integer);
begin
  if down <> 0 then
  begin
    if not dgKeys[K_SPACE] then
    begin
      dgKeys[K_SPACE] := true;
      simPauseButton;
    end;
  end
  else
    dgKeys[K_SPACE] := false;
end;

// F1 / Enter: the fire button (A5 Remastered default). Firing is edge
// triggered and simTryFire carries its own cooldown guard, so no held
// slot is needed (auto-repeat keydowns just re-hit the guard).
procedure FireKey(down: Integer);
begin
  if down <> 0 then simPressSpace;
end;

// P / Pause key: edge-triggered like Space (same guard pattern).
// K_SPACE and K_PAUSE are separate slots so both can be held simultaneously.
procedure PauseKey(down: Integer);
begin
  if down <> 0 then
  begin
    if not dgKeys[K_PAUSE] then
    begin
      dgKeys[K_PAUSE] := true;
      simTogglePause;
    end;
  end
  else
    dgKeys[K_PAUSE] := false;
end;

// Self-wired keyboard: keydown/keyup on `document`, read via
// batch_get_property_str('key'). evt.key is a NAMED string, so dispatch
// on length first: single-char keys (len 1) vs named keys (len >= 5).
// Checking the first byte without the length gate misreads 'ArrowLeft'
// as the A key ('A' = 65) — the classic batchiness keyboard gotcha.
//
// Byte values: ASCII for single-character keys; named keys ('ArrowUp' etc.)
// are all ASCII-only, so each byte is just the character code.
procedure HandleKey(down: Integer);
var
  n: Integer;
  c0: Byte;
begin
  n := dgGetPropStr(dgLastEvent, StrAddr('key'), 3, Integer(@keyBuf), 16);
  if n <= 0 then Exit;

  if n = 1 then
  begin
    c0 := keyBuf[0];
    if (c0 = 119) or (c0 = 87) then DirKey(K_UP, down)          // w / W
    else if (c0 = 115) or (c0 = 83) then DirKey(K_DOWN, down)   // s / S
    else if (c0 = 97) or (c0 = 65) then DirKey(K_LEFT, down)    // a / A
    else if (c0 = 100) or (c0 = 68) then DirKey(K_RIGHT, down)  // d / D
    else if c0 = 32 then SpaceKey(down)                        // space
    else if (c0 = 112) or (c0 = 80) then PauseKey(down);        // p / P
  end
  else if n = 2 then
  begin
    // F1 (A5: the fire button)
    if (keyBuf[0] = 70) and (keyBuf[1] = 49) then FireKey(down);
  end
  else if n = 5 then
  begin
    // Enter (fires, like F1 — unchanged from the old Space behavior)
    if (keyBuf[0] = 69) and (keyBuf[1] = 110) and (keyBuf[2] = 116) and
       (keyBuf[3] = 101) and (keyBuf[4] = 114) then FireKey(down);
  end
  else if n = 7 then
  begin
    // ArrowUp
    if (keyBuf[0] = 65) and (keyBuf[1] = 114) and (keyBuf[2] = 114) and
       (keyBuf[3] = 111) and (keyBuf[4] = 119) and (keyBuf[5] = 85) and
       (keyBuf[6] = 112) then DirKey(K_UP, down);
  end
  else if n = 9 then
  begin
    // ArrowDown (9 chars: A r r o w D o w n)
    if (keyBuf[0] = 65) and (keyBuf[1] = 114) and (keyBuf[2] = 114) and
       (keyBuf[3] = 111) and (keyBuf[4] = 119) and (keyBuf[5] = 68) and
       (keyBuf[6] = 111) and (keyBuf[7] = 119) and (keyBuf[8] = 110) then
      DirKey(K_DOWN, down);
    // ArrowLeft (9 chars: A r r o w L e f t)
    if (keyBuf[0] = 65) and (keyBuf[1] = 114) and (keyBuf[2] = 114) and
       (keyBuf[3] = 111) and (keyBuf[4] = 119) and (keyBuf[5] = 76) and
       (keyBuf[6] = 101) and (keyBuf[7] = 102) and (keyBuf[8] = 116) then
      DirKey(K_LEFT, down);
  end
  else if n = 10 then
  begin
    // ArrowRight
    if (keyBuf[0] = 65) and (keyBuf[1] = 114) and (keyBuf[2] = 114) and
       (keyBuf[3] = 111) and (keyBuf[4] = 119) and (keyBuf[5] = 82) and
       (keyBuf[6] = 105) and (keyBuf[7] = 103) and (keyBuf[8] = 104) and
       (keyBuf[9] = 116) then DirKey(K_RIGHT, down);
  end;
end;

procedure SetLastEvent(h: Integer);
begin
  dgLastEvent := h;
end;

procedure DugsterMain;
var
  app, canvas, doc: Integer;
begin
  app := dgGetElement(StrAddr('stage'), 5);
  canvas := dgCanvasCreate(app, W, H);
  dgCtx := dgGetContext(canvas);

  // Seed the xorshift RNG from the clock (pong pattern).
  dgRng := Cardinal((dgNow - Trunc(dgNow)) * 1000000.0) xor $9E3779B9;
  if dgRng = 0 then dgRng := 1;

  simInitGame;

  // Persistent best (P1): load after simInitGame so the reset can't
  // clobber it (simInitGame never touches dgBest, but order is armor).
  dgBest := dgGetBest;

  doc := dgGetGlobal(StrAddr('document'), 8);
  dgAddListener(doc, StrAddr('keydown'), 7, CB_KEYDOWN);
  dgAddListener(doc, StrAddr('keyup'), 5, CB_KEYUP);

  dgLastMs := dgNow;
  dgStartLoop(CB_TICK);
end;

// Actor glide with root-local anchor state (all inputs live). A logic
// step starts the new glide from the last rendered spot, so turns corner
// smoothly instead of snapping; jumps over two cells (respawn, catch,
// new level) snap to the logic cell. effH/effV are the axis step times
// for THIS step (hunters pass stepForDir of their facing, which always
// equals their last move direction); the Fresh-step snapshot (stepEff)
// drives mid-glide frames so a later turn-tax facing change can't warp
// an in-flight glide. Logic static (turn tax, blocked) holds the render.
procedure GlideActor(cx, cy: Integer; effH, effV: Single;
  var ax, ay, rx, ry, stepT, stepEff: Single;
  var lx, ly: Integer; var vert, init: Boolean;
  var ox, oy: Single);
var
  dx, dy: Integer;
  frac: Single;  // interpolation fraction [0, 1] for the current glide
begin
  if not init then
  begin
    lx := -999;
    ly := -999;
    rx := 0.0;
    ry := 0.0;
    vert := false;
    stepT := 0.0;
    stepEff := effH;
    init := true;
  end;
  if (cx = lx) and (cy = ly) then
  begin
    // Mid-glide: advance from the anchor by elapsed sim time.
    frac := (simTime - stepT) / stepEff;
    if frac < 0.0 then frac := 0.0;
    if frac > 1.0 then frac := 1.0;
    ox := ax + (Single(lx) - ax) * frac;
    oy := ay + (Single(ly) - ay) * frac;
    // rx/ry persist the last render position for the next-step anchor.
    rx := ox;
    ry := oy;
    Exit;
  end;
  // Fresh logic step: anchor the new glide at the last rendered spot
  // (smooth cornering), or snap on teleports.
  dx := cx - lx;
  if dx < 0 then dx := -dx;
  dy := cy - ly;
  if dy < 0 then dy := -dy;
  if (dx > 2) or (dy > 2) then
  begin
    ax := Single(cx);
    ay := Single(cy);
  end
  else
  begin
    ax := rx;
    ay := ry;
  end;
  vert := cy <> ly;
  if vert then stepEff := effV
  else stepEff := effH;
  lx := cx;
  ly := cy;
  stepT := simTime;
  ox := ax;
  oy := ay;
  rx := ox;
  ry := oy;
end;

procedure GlidePlayer(var ox, oy: Single);
begin
  GlideActor(simPX, simPY, Single(STEP_PH), Single(STEP_PV),
    gAx, gAy, gRx, gRy, gStepT, gStepEff, gLx, gLy, gVert, gInit, ox, oy);
end;

// A4: glide one dispenser slot (type rides separately via simMonNob).
procedure GlideSlot(s: Integer; var ox, oy: Single);
var
  eff: Single;
begin
  eff := stepForDir(simMonDir(s));
  GlideActor(simMonX(s), simMonY(s), eff, eff,
    mAx[s], mAy[s], mRx[s], mRy[s], mStepT[s], mStepEff[s],
    mLx[s], mLy[s], mVert[s], mInit[s], ox, oy);
end;

// Draw one live hunter: glide its slot, color by current type.
procedure DrawSlot(s: Integer; gazeX: Single);
var
  mox, moy: Single;
begin
  GlideSlot(s, mox, moy);
  if simMonNob(s) = 1 then
    rdDrawMonster(mox, moy, StrAddr(COL_MONSTER), StrLen(COL_MONSTER), gazeX)
  else
    rdDrawMonster(mox, moy, StrAddr(COL_HOBBIN), StrLen(COL_HOBBIN), gazeX);
end;

procedure InvokeCallback(id: Integer);
var
  nowMs, dt: Double;
  ox, oy: Single;
  s: Integer;
begin
  if id = CB_TICK then
  begin
    nowMs := dgNow;
    dt := (nowMs - dgLastMs) / 1000.0;
    dgLastMs := nowMs;
    if dt > 0.0 then
    begin
      // Cap at 0.05 s (~20 fps): prevents spiral-out on tab-restore and
      // headless rAF slow-downs that can run below 20 fps.
      if dt > 0.05 then dt := 0.05;
      simStep(Single(dt));
      fxUpdate(Single(dt));
      // Actor state crosses the unit boundary by value: dugrender's own
      // global reads of dgPx/dgPAcc/dgEffP — and rdTrack's anchor banks —
      // go stale in the browser build (sprite lagged while the sim
      // sprinted). simPX/simPY/simTime/simPdir read live; the glide
      // anchors ride in root locals. See rdDrawSprite. Hunters ride the
      // same ferry: dugrender's monster-cell/accumulator reads freeze
      // their sprites at spawn while live hunters catch real kills.
      GlidePlayer(ox, oy);
      frTick := frTick + 1;
      shT := simShakeT;
      rdDrawFrame(ox, oy, simPdir, shT);
      // A4: hunters draw per live slot (type can morph mid-level) —
      // always before rdFlushFrame (same-tick present; post-flush
      // draws are wiped by the next frame's dgReset).
      for s := 0 to MON_SLOTS1 do
        if simMonActive(s) = 1 then DrawSlot(s, ox);
      rdFlushFrame(frTick, shT);
    end;
  end
  else if id = CB_KEYDOWN then
    HandleKey(1)
  else if id = CB_KEYUP then
    HandleKey(0);
end;

exports
  DugsterMain name 'batchiness_main',
  InvokeCallback name 'batchiness_invoke_callback',
  SetLastEvent name 'batchiness_set_last_event';

begin
end.
