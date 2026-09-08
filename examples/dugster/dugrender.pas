// dugrender.pas — DUGSTER renderer: board tiles, emerald/player/monster
// sprites (canvas rect/circle primitives), HUD, and state overlays.
// One frame = one batch buffer flushed once.
//
// All actor render positions arrive by value from the root to avoid the
// browser unit-merge bug (2026-09-04): this unit's own global reads of
// sim state — and rdTrack anchor banks — went stale in the browser build
// while the sim's live copies proved correct (see rdDrawSprite).
// frame is the root's tick counter for the title blink (same ferry —
// dgTime freezes outside PLAY). Hunters are NOT frame params: the root
// draws rdDrawMonster per live slot between rdDrawFrame and rdFlushFrame.
unit dugrender;

interface

uses
  dugdefs,
  duglevel,
  dugfx;

// All actor render positions + facing + active flags arrive by value from
// the root (see rdDrawSprite / rdDrawMonster): this unit's own reads of
// sim globals go stale in the browser build. frame is the root's tick
// counter for the title blink (same ferry — dgTime freezes outside PLAY).
// Hunters are NOT frame params: the root draws rdDrawMonster per live
// slot between rdDrawFrame and rdFlushFrame (A4 dispenser).
procedure rdDrawFrame(ox, oy: Single; pdir: Integer; shT: Single);

// One hunter at glide pos (ox, oy): body color + player-ward gaze.
// Called by the root per live slot after rdDrawFrame but before
// rdFlushFrame (same-tick present — see rdFlushFrame).
procedure rdDrawMonster(ox, oy: Single; col: Integer; clen: Integer;
  gazeX: Single);

// Present the frame drawn by rdDrawFrame + the per-slot rdDrawMonster
// calls. Must run in the same tick (see rdFlushFrame).
procedure rdFlushFrame(frame: Integer; shT: Single);

// Spilled-gold piles (A5). Exported like rdDrawMonster (per-item draw).
procedure rdDrawGold;

// Hang offset for a bag cell (G8): unsupported resting bags visibly hang
// 2 px (straining before the wobble starts); supported and falling bags
// sit at 0. Exported for the render-closure probe.
function rdBagHang(x, y: Integer): Single;

implementation

var
  rdText: array[0..63] of Byte;
  rdTmp: array[0..15] of Byte;

// Decimal-write n into rdText at off; returns the new offset.
// rdTmp accumulates digits in reverse (least-significant first);
// the final loop copies them into rdText in the correct order.
function rdWriteInt(off, n: Integer): Integer;
var
  d, x, c: Integer;
begin
  x := n;
  d := 0;
  if x = 0 then
  begin
    rdTmp[0] := 48;
    d := 1;
  end
  else
  begin
    while x > 0 do
    begin
      rdTmp[d] := Byte(48 + (x mod 10));
      x := x div 10;
      d := d + 1;
    end;
  end;
  for c := 0 to d - 1 do
  begin
    if off + c < 64 then rdText[off + c] := rdTmp[d - 1 - c];
  end;
  rdWriteInt := off + d;
end;

// Copy a literal's bytes into rdText at off; returns the new offset.
function rdWriteLit(p, n, off: Integer): Integer;
var
  i: Integer;
begin
  for i := 0 to n - 1 do
  begin
    if off + i < 64 then rdText[off + i] := PByte(p)[i];
  end;
  rdWriteLit := off + n;
end;

procedure rdTextSetup(size: Integer);
begin
  if size = 0 then dgSetFont(StrAddr(FONT_HUD), 14)       // HUD
  else if size = 1 then dgSetFont(StrAddr(FONT_HINT), 15) // hint bar
  else if size = 2 then dgSetFont(StrAddr(FONT_TITLE), 15) // big title
  else dgSetFont(StrAddr(FONT_BIG), 15);                   // large overlay
  dgSetAlign(StrAddr('center'), 6);
  dgSetBaseline(StrAddr('top'), 3);
end;

procedure rdCellXY(x, y: Integer; var px, py: Single);
begin
  px := Single(x * CELL);
  py := Single(BOARD_Y + y * CELL);
end;

// G1 interpolation: glide from the previous cell to the current one by the
// step-accumulator fraction. Logic cells are untouched; only pixels move.
function rdClamp01(f: Single): Single;
begin
  if f < 0.0 then rdClamp01 := 0.0
  else if f > 1.0 then rdClamp01 := 1.0
  else rdClamp01 := f;
end;

// (rdTrack + its anchor banks lived here until all three actors moved to
// root-side glides — GlidePlayer/GlideNobbin/GlideHobbin — after this
// unit's locals went stale in the browser build. Removed 2026-09-04.)

procedure rdDrawBoard;
var
  x, y: Integer;
  px, py: Single;
  h3: Integer;  // (x*7 + y*13) mod 3 hash; computed once per undug cell
begin
  for y := 0 to ROWS1 do
    for x := 0 to COLS1 do
    begin
      rdCellXY(x, y, px, py);
      if lvIsDug(x, y) = 1 then
        dgSetFill(StrAddr(COL_BG), 7)
      else
        dgSetFill(StrAddr(COL_DIRT), 7);
      dgFillRect(px, py, Single(CELL), Single(CELL));
      // Hash speckle: (x*7 + y*13) mod 3 picks one of three layouts,
      // so no tiling. (All operands small non-negative Integers.)
      if lvIsDug(x, y) = 0 then
      begin
        // Compute hash once: used for both speckle layout and sunlit fleck.
        h3 := (x * 7 + y * 13) mod 3;
        dgSetFill(StrAddr(COL_DIRT_DARK), 7);
        if h3 = 0 then
        begin
          dgFillRect(px + 8.0, py + 10.0, 10.0, 8.0);
          dgFillRect(px + 22.0, py + 24.0, 8.0, 6.0);
        end
        else if h3 = 1 then
        begin
          dgFillRect(px + 24.0, py + 8.0, 8.0, 8.0);
          dgFillRect(px + 8.0, py + 24.0, 12.0, 6.0);
        end
        else
        begin
          dgFillRect(px + 14.0, py + 6.0, 12.0, 8.0);
          dgFillRect(px + 12.0, py + 24.0, 8.0, 8.0);
        end;
        // Sunlit fleck (G7): one light chip per cell, placed by the same
        // hash so the dirt reads richer without re-tiling.
        dgSetFill(StrAddr(COL_DIRT_LITE), 7);
        if h3 = 0 then
          dgFillRect(px + 24.0, py + 8.0, 6.0, 5.0)
        else if h3 = 1 then
          dgFillRect(px + 10.0, py + 10.0, 5.0, 6.0)
        else
          dgFillRect(px + 26.0, py + 22.0, 6.0, 5.0);
      end
      else
      begin
        // Edge rims: where a dug cell meets undug dirt, shade a 4 px rim
        // on that edge for depth. lvIsDug is bounds-safe, so border
        // cells rim against the outside for free.
        dgSetFill(StrAddr(COL_RIM), 7);
        if lvIsDug(x - 1, y) = 0 then
          dgFillRect(px, py, 4.0, Single(CELL));
        if lvIsDug(x + 1, y) = 0 then
          dgFillRect(px + Single(CELL) - 4.0, py, 4.0, Single(CELL));
        if lvIsDug(x, y - 1) = 0 then
          dgFillRect(px, py, Single(CELL), 4.0);
        if lvIsDug(x, y + 1) = 0 then
          dgFillRect(px, py + Single(CELL) - 4.0, Single(CELL), 4.0);
        // Tunnel dust (G8): a sparse near-black fleck so dug floors
        // aren't flat voids. Two spots off a mod-6 hash — no visible
        // march, and static (pause-safe by construction).
        dgSetFill(StrAddr(COL_FLECK), 7);
        if ((x * 5 + y * 11) mod 6) = 0 then
          dgFillRect(px + 17.0, py + 15.0, 5.0, 4.0)
        else if ((x * 5 + y * 11) mod 6) = 3 then
          dgFillRect(px + 9.0, py + 23.0, 5.0, 4.0);
      end;
      // Emerald: true 4-point diamond + light facet triangle (G2).
      if lvHasEmerald(x, y) = 1 then
      begin
        dgSetFill(StrAddr(COL_EMERALD), 7);
        dgBeginPath;
        dgMoveTo(px + 20.0, py + 4.0);
        dgLineTo(px + 34.0, py + 20.0);
        dgLineTo(px + 20.0, py + 36.0);
        dgLineTo(px + 6.0, py + 20.0);
        dgClosePath;
        dgFill;
        dgSetFill(StrAddr(COL_EMERALD_HI), 7);
        dgBeginPath;
        dgMoveTo(px + 20.0, py + 4.0);
        dgLineTo(px + 20.0, py + 20.0);
        dgLineTo(px + 6.0, py + 20.0);
        dgClosePath;
        dgFill;
        // Gem glint (G7): the original emeralds flash — an eye-white
        // spark near the crown on alternating ~3 Hz phases off sim time
        // (freezes on pause with everything else dgTime-driven).
        if (Trunc(dgTime * 3.0) mod 2) = 0 then
        begin
          dgSetFill(StrAddr(COL_EYE), 7);
          dgFillRect(px + 17.0, py + 7.0, 6.0, 6.0);
        end;
      end;
    end;
end;

// NOTE (browser unit-merge bug, 2026-09-04): the player arrives here as a
// finished render position + facing, all by value. Reading dgPx/dgPAcc/
// dgEffP/dgPdir as globals — or keeping the glide anchor in this unit's
// locals (rdTrack banks) — went stale in the browser build (sprite lagged
// while the sim sprinted at full speed, proven by score+tunnels advancing
// ahead of it), while other procs here read live state. The glide itself
// lives in the root (GlidePlayer, root-local anchors). TODO: minimize +
// file against the compiler (suspect symbol binding in
// merge_unit_into/rebuild_sym_maps).
procedure rdDrawSprite(ox, oy: Single; pdir: Integer);
var
  cx, cy: Single;
begin
  cx := ox * Single(CELL) + Single(CELL) / 2.0;
  cy := Single(BOARD_Y) + oy * Single(CELL) + Single(CELL) / 2.0;
  dgSetFill(StrAddr(COL_PLAYER), 7);
  dgBeginPath;
  dgArc(cx, cy, 14.0, 0.0, TAU);
  dgFill;
  // Visor faces the direction of travel (pdir by value, same workaround).
  dgSetFill(StrAddr(COL_VISOR), 7);
  if pdir = D_LEFT then
    dgFillRect(cx - 14.0, cy - 5.0, 10.0, 10.0)
  else if pdir = D_UP then
    dgFillRect(cx - 5.0, cy - 14.0, 10.0, 10.0)
  else if pdir = D_DOWN then
    dgFillRect(cx - 5.0, cy + 4.0, 10.0, 10.0)
  else
    dgFillRect(cx + 4.0, cy - 5.0, 10.0, 10.0);
end;

// Pure draw proc: finished render position + player render x (for the
// eye gaze) arrive by value from the root. The old version read the
// monster cells/accumulators here (plus rdTrack anchor banks); those
// reads go stale in the browser build, freezing both hunter sprites at
// their spawn cells while the sim's live hunters roamed and caught real
// kills. Glide now happens in the root (GlideNobbin/GlideHobbin).
//
// col/clen: StrAddr/StrLen pair of the body colour string (COL_MONSTER or
// COL_HOBBIN). Overridden by bonus flash when dgBonusT > 0.
procedure rdDrawMonster(ox, oy: Single; col: Integer; clen: Integer; gazeX: Single);
var
  cx, cy: Single;
begin
  cx := ox * Single(CELL) + Single(CELL) / 2.0;
  cy := Single(BOARD_Y) + oy * Single(CELL) + Single(CELL) / 2.0;
  // Bonus fright (P2): scared ice-blue flashing ~6 Hz off sim time.
  // dgBonusT/dgTime read here directly (timer class — same proven-live
  // reads as the cherry clock and bag wobble, verified by probe).
  if dgBonusT > 0.0 then
  begin
    if (Trunc(dgTime * 6.0) mod 2) = 0 then dgSetFill(StrAddr(COL_SCARED), 7)
    else dgSetFill(col, clen);
  end
  else dgSetFill(col, clen);
  dgBeginPath;
  dgArc(cx, cy, 14.0, 0.0, TAU);
  dgFill;
  // Eyes look toward the player, blinking shut one frame in three
  // (G4: one blink every ~1.4 s off sim time, play only since dgTime
  // freezes outside PLAY).
  if (Trunc(dgTime * 0.7) mod 3) <> 0 then
  begin
    dgSetFill(StrAddr(COL_EYE), 7);
    if gazeX < ox then
    begin
      dgFillRect(cx - 11.0, cy - 6.0, 6.0, 8.0);
      dgFillRect(cx - 11.0, cy + 2.0, 6.0, 8.0);
    end
    else
    begin
      dgFillRect(cx + 5.0, cy - 6.0, 6.0, 8.0);
      dgFillRect(cx + 5.0, cy + 2.0, 6.0, 8.0);
    end;
  end;
end;

// Spilled gold (A5): small amber diamond + dark facet, blinking over
// its last 2 s of life. Reads the duglevel pile grids (timer-class
// render-live, like the bag clocks).
procedure rdDrawGold;
var
  x, y: Integer;
  px, py, life: Single;
begin
  life := Single(150 - 10 * dgLevel) * 0.08;
  for y := 0 to ROWS1 do
    for x := 0 to COLS1 do
    begin
      if lvHasGold(x, y) = 0 then continue;
      if (lvGoldT[y, x] > life - 2.0) and
        ((Trunc(dgTime * 6.0) mod 2) = 0) then
        continue;
      rdCellXY(x, y, px, py);
      dgSetFill(StrAddr(COL_GOLD), 7);
      dgBeginPath;
      dgMoveTo(px + 20.0, py + 10.0);
      dgLineTo(px + 30.0, py + 20.0);
      dgLineTo(px + 20.0, py + 30.0);
      dgLineTo(px + 10.0, py + 20.0);
      dgClosePath;
      dgFill;
      dgSetFill(StrAddr(COL_GOLD_DARK), 7);
      dgBeginPath;
      dgMoveTo(px + 20.0, py + 10.0);
      dgLineTo(px + 20.0, py + 20.0);
      dgLineTo(px + 10.0, py + 20.0);
      dgClosePath;
      dgFill;
    end;
end;

// A resting bag unsupported from below hangs 2 px — the visible strain
// before the wobble starts (render-side mirror of simBagSupported;
// render uses level only, never sim, keeping the dep graph acyclic).
function rdBagHang(x, y: Integer): Single;
begin
  rdBagHang := 0.0;
  if lvBagAt(x, y) <> BAG_REST then Exit;
  if y >= ROWS1 then Exit;
  if lvIsDug(x, y + 1) = 0 then Exit;
  if lvBagAt(x, y + 1) <> BAG_NONE then Exit;
  rdBagHang := 2.0;
end;

procedure rdDrawBags;
var
  x, y: Integer;
  px, py, sway, hang: Single;
begin
  for y := 0 to ROWS1 do
    for x := 0 to COLS1 do
    begin
      if lvBagAt(x, y) = BAG_NONE then continue;
      rdCellXY(x, y, px, py);
      // Bag sway (G4): a wobbling bag strains ±3 px sideways, flipping
      // ten times a second off its own wobble clock. Falling bags ride
      // the sim, not this.
      sway := 0.0;
      if (lvBagAt(x, y) = BAG_REST) and (lvBagT[y, x] > 0.0) then
      begin
        if (Trunc(lvBagT[y, x] * 10.0) mod 2) = 0 then sway := 3.0
        else sway := -3.0;
      end;
      // Hang (G8) rides under the sway so the drop reads continuous.
      hang := rdBagHang(x, y);
      dgSetFill(StrAddr(COL_BAG), 7);
      dgBeginPath;
      dgArc(px + 20.0 + sway, py + 22.0 + hang, 12.0, 0.0, TAU);
      dgFill;
      dgSetFill(StrAddr(COL_BAG_DARK), 7);
      dgFillRect(px + 10.0 + sway, py + 20.0 + hang, 20.0, 4.0);
      dgFillRect(px + 17.0 + sway, py + 6.0 + hang, 6.0, 6.0);
      // Knot sheen (G7): a gold catchlight on the tied knot.
      dgSetFill(StrAddr(COL_GOLD), 7);
      dgFillRect(px + 18.0 + sway, py + 7.0 + hang, 3.0, 3.0);
    end;
end;

procedure rdDrawCherry;
var
  cx, cy: Single;
begin
  if dgChT <= 0.0 then Exit;
  cx := Single(dgChX * CELL) + Single(CELL) / 2.0;
  cy := Single(BOARD_Y + dgChY * CELL) + Single(CELL) / 2.0;
  dgSetFill(StrAddr(COL_CHERRY), 7);
  dgBeginPath;
  // Cherry pulse (G4): centre slightly below centroid (y+4); radius breathes
  // 8.5 ± 1.5 px at 5 rad/s. Uses the dgSin Double external with explicit
  // casts — NEVER call the Sin builtin on a Single (emits f32 against f64
  // import; the import goes missing silently).
  dgArc(cx, cy + 4.0, 8.5 + Single(dgSin(Double(dgTime) * 5.0)) * 1.5, 0.0, TAU);
  dgFill;
  dgSetFill(StrAddr(COL_STEM), 7);
  dgFillRect(cx - 1.0, cy - 12.0, 3.0, 12.0);
end;

procedure rdDrawFire;
var
  cx, cy: Single;
begin
  if dgFAx < 0 then Exit;
  cx := Single(dgFAx * CELL) + Single(CELL) / 2.0;
  cy := Single(BOARD_Y + dgFAy * CELL) + Single(CELL) / 2.0;
  dgSetFill(StrAddr(COL_FIRE), 7);
  dgBeginPath;
  dgArc(cx, cy, 7.0, 0.0, TAU);
  dgFill;
  dgSetFill(StrAddr(COL_TEXT), 7);
  dgBeginPath;
  dgArc(cx, cy, 3.0, 0.0, TAU);
  dgFill;
end;

procedure rdDrawHUD;
var
  n: Integer;
  p, top: Single;
begin
  dgSetFill(StrAddr(COL_PANEL), 7);
  dgFillRect(0.0, 0.0, Single(W), Single(HUD_H));

  dgSetFill(StrAddr(COL_SOFT), 7);
  rdTextSetup(0);
  n := rdWriteLit(StrAddr('Score:'), 6, 0);
  n := rdWriteInt(n, dgScore);
  dgFillText(Integer(@rdText), n, 70, 10);

  n := rdWriteLit(StrAddr('Best:'), 5, 0);
  n := rdWriteInt(n, dgBest);
  dgFillText(Integer(@rdText), n, 240, 10);

  n := rdWriteLit(StrAddr('Lives:'), 6, 0);
  n := rdWriteInt(n, dgLives);
  dgFillText(Integer(@rdText), n, 390, 10);

  n := rdWriteLit(StrAddr('Level '), 6, 0);
  n := rdWriteInt(n, dgLevel);
  dgFillText(Integer(@rdText), n, 505, 10);

  // ---- Reload indicator ----
  // Dim disc always; a COL_FIRE pie sweep grows clockwise from the top
  // while reloading; full bright disc when a shot is ready.
  // Fraction from dgFMax (stamped at fire time — never drifts from the formula).
  dgSetFill(StrAddr(COL_DIM), 7);
  dgBeginPath;
  dgArc(572.0, 22.0, 7.0, 0.0, TAU);
  dgFill;
  if (dgFCool <= 0.0) and (dgFAx < 0) then
  begin
    dgSetFill(StrAddr(COL_FIRE), 7);
    dgBeginPath;
    dgArc(572.0, 22.0, 7.0, 0.0, TAU);
    dgFill;
  end
  else
  begin
    // dgFMax = 1.0 sentinel before the first shot; never actually reaches zero.
    if dgFMax <= 0.0 then p := 1.0
    else p := 1.0 - dgFCool / dgFMax;
    if p < 0.0 then p := 0.0;
    if p > 1.0 then p := 1.0;
    if p > 0.0 then
    begin
      top := 0.0 - TAU / 4.0;
      dgSetFill(StrAddr(COL_FIRE), 7);
      dgBeginPath;
      dgMoveTo(572.0, 22.0);
      dgArc(572.0, 22.0, 7.0, top, top + p * TAU);
      dgFill;
    end;
  end;

  dgSetFill(StrAddr(COL_DIM), 7);
  rdTextSetup(1);
  dgFillText(StrAddr('Arrows/WASD steer - SPACE start/pause - F1 fire - P pause'),
    StrLen('Arrows/WASD steer - SPACE start/pause - F1 fire - P pause'), W div 2, HINT_Y);
end;

procedure rdOverlay(title, sub: Integer; tlen, slen: Integer);
begin
  dgSetFill(StrAddr(COL_TEXT), 7);
  rdTextSetup(2);
  dgFillText(title, tlen, W div 2, 150);
  if slen > 0 then
  begin
    dgSetFill(StrAddr(COL_SOFT), 7);
    rdTextSetup(0);
    dgFillText(sub, slen, W div 2, 220);
  end;
end;

// Score popups (G6): white text floating up 30 px over the 0.8 s pool
// age. Pool state is sim-written/render-drawn (dugdefs arrays).
procedure rdDrawPopups;
var
  i, n: Integer;
  px, py: Single;
begin
  for i := 0 to POP_MAX1 do
  begin
    if dgPopT[i] <= 0.0 then continue;
    px := Single(dgPopX[i] * CELL) + Single(CELL) / 2.0;
    py := Single(BOARD_Y + dgPopY[i] * CELL) + Single(CELL) / 2.0
      - (POP_T - dgPopT[i]) / POP_T * 30.0;
    dgSetFill(StrAddr(COL_TEXT), 7);
    rdTextSetup(0);
    n := rdWriteInt(0, dgPopN[i]);
    dgFillText(Integer(@rdText), n, Trunc(px), Trunc(py));
  end;
end;

// frame arrives by value from the root (title blink clock): dgTime
// freezes outside PLAY, and dugrender-owned mutable state is the class
// that went stale twice — so the root counts ticks in a root local and
// ferries it, same as the actor glides. See rdDrawFrame.
procedure rdDrawOverlays(frame: Integer);
var
  n: Integer;
begin
  if dgState = ST_TITLE then
  begin
    // Dim the live board, then full-alpha logo block on top. Alpha is
    // paired (0.7 then straight back to 1.0) so nothing leaks into PLAY.
    dgSetGlobalAlpha(0.7);
    dgSetFill(StrAddr(COL_BG), 7);
    dgFillRect(0.0, 0.0, Single(W), Single(H));
    dgSetGlobalAlpha(1.0);
    rdOverlay(StrAddr('DUGSTER'), StrAddr('Emeralds good - monsters bad - mind the gold!'),
      StrLen('DUGSTER'), StrLen('Emeralds good - monsters bad - mind the gold!'));
    dgSetFill(StrAddr(COL_DIM), 7);
    rdTextSetup(0);
    dgFillText(StrAddr('Arrows/WASD move - SPACE fire - P pause'),
      StrLen('Arrows/WASD move - SPACE fire - P pause'), W div 2, 250);
    dgSetFill(StrAddr(COL_BAG), 7);
    n := rdWriteLit(StrAddr('Best: '), 6, 0);
    n := rdWriteInt(n, dgBest);
    dgFillText(Integer(@rdText), n, W div 2, 278);
    // Blinking prompt: visible half the time on a 30-frame toggle
    // (div, not /: Integer / Integer stays i32 here and starves Trunc).
    if ((frame div 30) mod 2) = 0 then
    begin
      dgSetFill(StrAddr(COL_TEXT), 7);
      dgFillText(StrAddr('SPACE to start'), StrLen('SPACE to start'), W div 2, 312);
    end;
  end
  else if dgState = ST_DEAD then
  begin
    rdOverlay(StrAddr('OUCH!'), 0, StrLen('OUCH!'), 0);
  end
  else if dgState = ST_WIN then
  begin
    rdOverlay(StrAddr('LEVEL CLEAR!'), StrAddr('+250 bonus'),
      StrLen('LEVEL CLEAR!'), StrLen('+250 bonus'));
  end
  else if dgState = ST_OVER then
  begin
    rdOverlay(StrAddr('GAME OVER'), 0, StrLen('GAME OVER'), 0);
    dgSetFill(StrAddr(COL_SOFT), 7);
    rdTextSetup(0);
    n := rdWriteLit(StrAddr('Final score: '), 13, 0);
    n := rdWriteInt(n, dgScore);
    dgFillText(Integer(@rdText), n, W div 2, 220);
    dgSetFill(StrAddr(COL_DIM), 7);
    dgFillText(StrAddr('SPACE to retry'), StrLen('SPACE to retry'), W div 2, 260);
  end
  else if dgPaused then
  begin
    rdOverlay(StrAddr('PAUSED'), 0, StrLen('PAUSED'), 0);
  end;
end;

procedure rdDrawFrame(ox, oy: Single; pdir: Integer; shT: Single);
begin
  dgReset;

  dgSetFill(StrAddr(COL_BG), 7);
  dgFillRect(0.0, 0.0, Single(W), Single(H));

  // Screenshake (G6): save + jittered translate around the world draws,
  // restore before HUD so panels stay rock-steady. shT arrives by value
  // (simShakeT ferry — same stale class as the accumulators). The bg fill
  // above stays unshaken so no unfilled strips show at the edges.
  if shT > 0.0 then
  begin
    dgSave;
    dgTranslate(Single((Trunc(shT * 60.0) * 7) mod 5) - 2.0,
      Single((Trunc(shT * 60.0) * 13) mod 5) - 2.0);
  end;

  rdDrawBoard;
  rdDrawBags;
  rdDrawGold;
  rdDrawCherry;
  rdDrawFire;
  if (dgState = ST_PLAY) or (dgState = ST_DEAD) or (dgState = ST_WIN) or dgPaused then
  begin
    // All actor render positions arrive pre-glid by the root
    // (GlidePlayer + per-slot GlideSlot): this unit's own global reads
    // of actor cells/accumulators — and rdTrack's anchor banks — go stale
    // in the browser build. Hunters draw via root-called rdDrawMonster
    // per live slot (A4: type can morph mid-level). See rdDrawSprite.
    rdDrawSprite(ox, oy, pdir);
  end;
  fxDraw;
  rdDrawPopups;
end;

// Finish + present the frame: the root draws hunters (rdDrawMonster per
// live slot) between rdDrawFrame and here, so they shake with the world
// but the HUD/overlays stay rock-steady and last (WIN fx over everything).
// MUST run in the same tick — anything drawn after dgFlush sits in the
// buffer until the next frame's dgReset wipes it, which silently
// un-rendered every hunter (A4 render bug, found by playtest).
procedure rdFlushFrame(frame: Integer; shT: Single);
begin
  if shT > 0.0 then dgRestore;

  rdDrawHUD;
  rdDrawOverlays(frame);

  // Level-clear celebration (G6), phased off dgWinT (counts down through
  // WIN; dgTime is frozen there): white flash sheet first, then an
  // expanding stroked ring from board center. Drawn last — over everything.
  if dgState = ST_WIN then
  begin
    if dgWinT > WIN_PAUSE - 0.2 then
    begin
      dgSetGlobalAlpha(0.6);
      dgSetFill(StrAddr(COL_TEXT), 7);
      dgFillRect(0.0, 0.0, Single(W), Single(H));
      dgSetGlobalAlpha(1.0);
    end
    else
    begin
      dgSetStroke(StrAddr(COL_TEXT), 7);
      dgBeginPath;
      dgArc(Single(W) / 2.0,
        Single(BOARD_Y) + Single(ROWS1 + 1) * Single(CELL) / 2.0,
        (WIN_PAUSE - dgWinT) * 175.0, 0.0, TAU);
      dgStroke;
    end;
  end;

  dgFlush(dgCtx, Integer(@dgCmd), dgCmdLen);  // all draws for this tick complete
end;

end.
