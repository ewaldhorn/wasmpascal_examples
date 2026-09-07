// dugdefs.pas — DUGSTER shared definitions: geometry, game state, host
// imports, batch wire writers, and the xorshift RNG.
//
// One unit owns every cross-unit name (unit merge keeps the FIRST
// declaration on collision), so nothing here is re-declared elsewhere.
// The fldefs StrAddr pattern is used for host imports: string params are
// passed as (addr, len) Integer pairs, never raw literals.
unit dugdefs;

interface

const
  // ---- Canvas & board geometry ----
  W = 600;
  H = 480;
  HUD_H = 44;        // top score bar height
  BOARD_Y = 44;      // board top (below the HUD)
  CELL = 40;         // square cell size in pixels
  COLS = 15;         // board width in cells  (15*40 = 600)
  ROWS = 10;         // board height in cells (10*40 = 400)
  COLS1 = 14;        // last valid column index
  ROWS1 = 9;         // last valid row index
  HINT_Y = 452;      // bottom hint text baseline area

  // ---- Host callbacks (batchiness_invoke_callback id) ----
  CB_TICK = 0;
  CB_KEYDOWN = 1;
  CB_KEYUP = 2;

  // ---- Held-key slots (dgKeys) ----
  K_UP = 0;
  K_DOWN = 1;
  K_LEFT = 2;
  K_RIGHT = 3;
  K_SPACE = 4;
  K_PAUSE = 5;

  // ---- Move directions ----
  D_NONE = 0;
  D_UP = 1;
  D_DOWN = 2;
  D_LEFT = 3;
  D_RIGHT = 4;

  // ---- Game states ----
  ST_TITLE = 0;
  ST_PLAY = 1;
  ST_DEAD = 2;   // caught: brief pause, then respawn or game over
  ST_WIN = 3;    // level cleared: brief pause, then next level
  ST_OVER = 4;

  // ---- Tuning ----
  // Verified vs the 1983 original (12.5 game ticks/s): Digger runs 4px
  // horizontal / 3px vertical per tick over 20x18px cells, i.e. ~0.40 s
  // horizontal and ~0.48 s vertical per cell — and never speeds up.
  // Monsters run the same pixel rate (parity) but pay a turn tax; their
  // threat ramps via double-steps, wander loss, and spawn quota (A4).
  STEP_PH = 0.40;    // player horizontal cell step (all levels)
  STEP_PV = 0.48;    // player vertical cell step (all levels)
  STEP_F = 0.06;     // fireball cell step (always fast)
  FIRE_COOL = 5.0;   // base recharge s (original: (60 + level*3) ticks at
                     // 12.5 ticks/s ≈ 5.04 s L1; this constant is the nominal
                     // floor — simTryFire applies the exact per-level formula)
  BUFFER_T = 0.25;   // tap grace: released dirs keep rolling this long, so a
                     // sub-step tap still steps exactly once (consumed on step)
  STEP_B = 0.12;     // seconds per falling-bag cell step
  WOBBLE_T = 1.2;    // s a bag wobbles before falling (original: 15 ticks)
  SHAKE_T = 0.35;    // s of screen shake on death/crush (G6)
  POP_T = 0.8;       // s a score popup floats (G6)
  POP_MAX = 8;
  POP_MAX1 = 7;
  BAG_BREAK_FALL = 2; // cells fallen that shatter a bag on landing
  // (A1 removed the timer cherry — the quota cherry waits indefinitely,
  // like the original.)
  // A4 dispenser: 6 slots like the original's MONSTERS=6.
  MON_SLOTS = 6;
  MON_SLOTS1 = 5;
  DEAD_PAUSE = 1.4;
  WIN_PAUSE = 2.0;
  SCORE_DIG = 1;
  SCORE_EMERALD = 25;
  SCORE_LEVEL = 250;
  SCORE_CRUSH = 250;   // monster crushed by a gold bag
  SCORE_GOLD = 500;    // A5: collected gold nugget (verified scoregold)
  SCORE_OCTAVE = 250;  // A5: every 8th consecutive emerald (scoreoctave)
  EM_WINDOW = 0.72;    // A5: octave streak window, s (9 ticks)
  SCORE_CHERRY = 1000;  // A1: verified scorebonus (was 100)
  SCORE_FIRE = 250;    // monster shot with the fireball
  LIVES_START = 3;
  EXTRA_EVERY = 20000;  // P4 (A3): extra life at every 20,000 multiple
  LIVES_MAX = 5;        // P4 (A3): never exceed 5 lives total
  // (EM_COUNT removed: was the old scatter count, superseded by P3
  // map-driven emerald counts from lvLoadRows.)

  CMD_CAPACITY = 32768;  // bytes; 32 KiB; raise if opcode budget overflows
  TAU = 6.283185307179586;  // 2π — full circle in radians

  // ---- Batch opcodes (wire format from batch.odin / batchiness.js) ----
  OP_SET_FILL = $01;
  OP_SET_STROKE = $02;   // batchiness.js case 0x02 (mirrors flbatch OP_SET_STROKE)
  OP_SET_GLOBAL_ALPHA = $07;  // batchiness.js case 0x07 (mirrors flbatch bSetGlobalAlpha)
  OP_SET_FONT = $04;
  OP_SET_TEXT_ALIGN = $05;
  OP_SET_TEXT_BASELINE = $06;
  OP_FILL_RECT = $10;
  OP_BEGIN_PATH = $20;
  OP_MOVE_TO = $21;      // batchiness.js case 0x21 (mirrors flbatch bMoveTo)
  OP_LINE_TO = $22;      // batchiness.js case 0x22 (mirrors flbatch bLineTo)
  OP_CLOSE_PATH = $23;
  OP_ARC = $24;
  OP_FILL = $28;
  OP_STROKE = $29;       // batchiness.js case 0x29 (mirrors flbatch OP_STROKE)
  OP_FILL_TEXT = $30;
  OP_SAVE = $40;         // batchiness.js cases 0x40-0x42 (flbatch has all three)
  OP_RESTORE = $41;
  OP_TRANSLATE = $42;

  // ---- SFX ids (app_env play_sound) ----
  SND_EMERALD = 0;   // blip
  SND_HIT = 3;       // small bang (fireball kill)
  SND_DEATH = 4;     // ship death boom
  SND_LEVEL = 5;     // wave-clear chime
  SND_START = 6;     // jump blip
  SND_DIG = 7;       // thud
  SND_FIRE = 9;      // launch zap

  // ---- Palette (each colour named once) ----
  COL_BG = '#0b0b12';
  COL_PANEL = '#10101d';
  COL_DIRT = '#7a4a1e';
  COL_DIRT_DARK = '#5e3a16';
  COL_DIRT_LITE = '#96602a';  // G7: sunlit fleck (r150 — clear of every
                              // bot pixel filter: yellow/orange/red)
  COL_FLECK = '#16161f';      // G8: tunnel dust (near-black, bot-safe)
  COL_RIM = '#3d2610';
  COL_TEXT = '#ffffff';
  COL_SOFT = '#cdd7ea';
  COL_DIM = '#7f8ba6';
  COL_EMERALD = '#2fe87a';
  COL_EMERALD_HI = '#b8ffd6';
  COL_PLAYER = '#ffe66d';
  COL_VISOR = '#20242e';
  COL_GOLD = '#ffc93c';   // A5: gold nugget (amber, off player-yellow)
  COL_GOLD_DARK = '#b98a1e';
  COL_MONSTER = '#ff5252';
  COL_HOBBIN = '#c07fe0';
  COL_SCARED = '#cfe8ff';
  COL_EYE = '#ffffff';
  COL_BAG = '#e8b53a';
  COL_BAG_DARK = '#8a6420';
  COL_CHERRY = '#ff3355';
  COL_STEM = '#3fe07f';
  COL_FIRE = '#ff7b00';
  COL_FX_GREEN = '#7fe0a0';
  COL_FX_RED = '#ff6b6b';

  FONT_HUD = '16px monospace';
  FONT_HINT = '13px monospace';
  FONT_TITLE = '44px monospace';
  FONT_BIG = '28px monospace';

var
  dgState, dgScore, dgLives, dgLevel: Integer;
  dgNextExtra: Integer;  // P4: next score threshold awarding an extra life
  dgBest: Integer;   // persistent best (localStorage via host; P1)
  dgPx, dgPy, dgPdir, dgWantDir: Integer;  // player cell + facing + roll dir
  // Monster slots (A4): the original's 6-slot dispenser (MONSTERS=6).
  // dgMonNob = true means nobbin (tunnel chase); false means hobbin
  // (dirt-eating). dgMonHnt is the morph clock: monster-contact ticks
  // for nobbins, hobbin-age ticks for hobbins (monster.c).
  dgMonX, dgMonY, dgMonDir: array[0..MON_SLOTS1] of Integer;
  dgMonNob: array[0..MON_SLOTS1] of Boolean;
  dgMonHnt: array[0..MON_SLOTS1] of Integer;
  dgMonAcc: array[0..MON_SLOTS1] of Single;
  dgMonSkip, dgMonActive: array[0..MON_SLOTS1] of Boolean;
  dgMonTotal, dgMonSpawned: Integer;  // quota: owed total / dispensed so far
  dgSpawnT: Single;                   // next-dispense countdown, seconds
  dgChX, dgChY: Integer;                   // cherry cell
  dgChT: Single;                           // >0 = cherry waiting (never
                                           // decays — the original waits
                                           // until eaten); -1 = none
  dgCherryDone: Boolean;                   // quota cherry spent this level
  dgBonusT: Single;                        // bonus fright time left, 0 = off (P2)
  dgEatStreak: Integer;                    // bonus kills this streak (P2/A1)
  dgTime: Single;                          // total PLAY seconds this level
  dgFAx, dgFAy, dgFDir: Integer;           // fireball cell + dir (-1 = none)
  dgFAcc, dgFCool: Single;                 // fireball step + shot cooldown
  dgFMax: Single;                          // A2: full recharge stamped at
                                           // fire time (reload indicator)
  dgBufT: Single;                          // tap-grace countdown, sim seconds
  dgEffP: Single;                          // player step time, stored per tick
  // (A4 removed the fixed-pair headings/skips: per-slot dgMonDir/Skip.)
  dgEmLeft: Integer;
  dgEmStreak: Integer;   // A5: consecutive emeralds in the window (octave)
  dgEmWindow: Single;    // A5: streak time left, s (original emocttime)
  dgPaused: Boolean;
  dgPAcc, dgBagAcc: Single; // player + bag step accumulators
  // (A4: monster accs are per-slot dgMonAcc.)
  dgDeadT, dgWinT: Single;                 // pause timers
  dgShakeT: Single;                        // screen-shake time left (G6)
  // Score popups (G6): sim-written, render-drawn (keeps uses acyclic).
  // Cell coords + points + age; dgPopT <= 0 hides. Round-robin cursor.
  dgPopX, dgPopY, dgPopN: array[0..POP_MAX1] of Integer;
  dgPopT: array[0..POP_MAX1] of Single;
  dgPopNext: Integer;
  dgKeys: array[0..5] of Boolean;
  dgRng: Cardinal;
  dgLastEvent, dgCtx: Integer;
  dgCmd: array[0..CMD_CAPACITY - 1] of Byte;
  dgCmdLen: Integer;
  dgLastMs: Double;

// ---- Host imports (StrAddr pattern: explicit addr+len Integers) ----
procedure dgFlush(c, buf, len: Integer); external 'batch_env' name 'batch_cmd_flush';
function  dgNow: Double; external 'batch_env' name 'batch_now';
function  dgCanvasCreate(parent, pw, ph: Integer): Integer; external 'batch_env' name 'batch_canvas_create';
function  dgGetElement(p, n: Integer): Integer; external 'batch_env' name 'batch_get_element_by_id';
function  dgGetGlobal(nm, n: Integer): Integer; external 'batch_env' name 'batch_get_global';
function  dgGetContext(canvas: Integer): Integer; external 'batch_env' name 'batch_canvas_get_context';
procedure dgStartLoop(cbId: Integer); external 'batch_env' name 'batch_start_animation_loop';
procedure dgAddListener(elem, ev, evn, cb: Integer); external 'batch_env' name 'batch_add_event_listener';
function  dgGetPropStr(h, k, kn, buf, maxlen: Integer): Integer;
          external 'batch_env' name 'batch_get_property_str';

procedure dgPlaySound(id: Integer); external 'app_env' name 'play_sound';
function dgGetBest: Integer; external 'app_env' name 'get_dugster_best';
procedure dgSetBest(s: Integer); external 'app_env' name 'set_dugster_best';

// Float math through a Double external with explicit casts: the Sin/Cos/...
// builtins promote only Integer args to f64 — a Single arg is passed as f32
// and produces invalid wasm (the odin_env import silently goes missing;
// G4 cherry pulse hit exactly this). Same pascaloids pattern as fldefs mSin.
function dgSin(x: Double): Double; external 'odin_env' name 'sin';

// ---- Batch wire writers (one buffer, one flush per frame) ----
// Step time for a heading: horizontal and vertical paces differ, exactly
// like the original's 4px/3px tick rates over 20x18px cells.
function stepForDir(d: Integer): Single;
procedure dgReset;
procedure dgU8(v: Integer);
procedure dgU16(v: Integer);
procedure dgF32(v: Single);
procedure dgLit(p, n: Integer);
procedure dgSetFill(p, n: Integer);
procedure dgSetStroke(p, n: Integer);
procedure dgStroke;
procedure dgSetGlobalAlpha(a: Single);
procedure dgSave;
procedure dgRestore;
procedure dgTranslate(x, y: Single);
procedure dgSetFont(p, n: Integer);
procedure dgSetAlign(p, n: Integer);
procedure dgSetBaseline(p, n: Integer);
procedure dgFillRect(x, y, w, h: Single);
procedure dgBeginPath;
procedure dgMoveTo(x, y: Single);
procedure dgLineTo(x, y: Single);
procedure dgClosePath;
procedure dgFill;
procedure dgArc(x, y, r, a0, a1: Single);
procedure dgFillText(ptr, tlen, x, y: Integer);

// ---- RNG (xorshift; seed once from the clock at boot) ----
function dgRand: Cardinal;
function dgRandF: Single;
function dgRandRangeI(lo, hi: Integer): Integer;

implementation

// Mirrors the 1983 original's 4 px horizontal / 3 px vertical per-tick
// pixel rates over 20x18 px cells: vertical cells take 20% longer to cross.
function stepForDir(d: Integer): Single;
begin
  if (d = D_UP) or (d = D_DOWN) then stepForDir := STEP_PV
  else stepForDir := STEP_PH;
end;

procedure dgReset;
begin
  dgCmdLen := 0;
end;

procedure dgU8(v: Integer);
begin
  if dgCmdLen + 1 > CMD_CAPACITY then Exit;  // soft overflow guard: silent, not a crash
  dgCmd[dgCmdLen] := Byte(v);
  dgCmdLen := dgCmdLen + 1;
end;

procedure dgU16(v: Integer);
begin
  if dgCmdLen + 2 > CMD_CAPACITY then Exit;  // soft overflow guard: silent, not a crash
  dgCmd[dgCmdLen] := Byte(v and $FF);
  dgCmd[dgCmdLen + 1] := Byte((v shr 8) and $FF);
  dgCmdLen := dgCmdLen + 2;
end;

procedure dgF32(v: Single);
var
  bits: Cardinal;
begin
  bits := F32Bits(v);
  if dgCmdLen + 4 > CMD_CAPACITY then Exit;
  dgCmd[dgCmdLen] := Byte(bits and $FF);
  dgCmd[dgCmdLen + 1] := Byte((bits shr 8) and $FF);
  dgCmd[dgCmdLen + 2] := Byte((bits shr 16) and $FF);
  dgCmd[dgCmdLen + 3] := Byte((bits shr 24) and $FF);
  dgCmdLen := dgCmdLen + 4;
end;

procedure dgLit(p, n: Integer);
var
  i: Integer;
begin
  if dgCmdLen + 2 + n > CMD_CAPACITY then Exit;
  dgU16(n);
  for i := 0 to n - 1 do
  begin
    dgCmd[dgCmdLen] := PByte(p)[i];
    dgCmdLen := dgCmdLen + 1;
  end;
end;

procedure dgSetFill(p, n: Integer);
begin
  dgU8(OP_SET_FILL); dgLit(p, n);
end;

procedure dgSetStroke(p, n: Integer);
begin
  dgU8(OP_SET_STROKE); dgLit(p, n);
end;

procedure dgStroke;
begin
  dgU8(OP_STROKE);
end;

procedure dgSetGlobalAlpha(a: Single);
begin
  dgU8(OP_SET_GLOBAL_ALPHA); dgF32(a);
end;

procedure dgSave;
begin
  dgU8(OP_SAVE);
end;

procedure dgRestore;
begin
  dgU8(OP_RESTORE);
end;

procedure dgTranslate(x, y: Single);
begin
  dgU8(OP_TRANSLATE); dgF32(x); dgF32(y);
end;

procedure dgSetFont(p, n: Integer);
begin
  dgU8(OP_SET_FONT); dgLit(p, n);
end;

procedure dgSetAlign(p, n: Integer);
begin
  dgU8(OP_SET_TEXT_ALIGN); dgLit(p, n);
end;

procedure dgSetBaseline(p, n: Integer);
begin
  dgU8(OP_SET_TEXT_BASELINE); dgLit(p, n);
end;

procedure dgFillRect(x, y, w, h: Single);
begin
  dgU8(OP_FILL_RECT); dgF32(x); dgF32(y); dgF32(w); dgF32(h);
end;

procedure dgBeginPath;
begin
  dgU8(OP_BEGIN_PATH);
end;

procedure dgMoveTo(x, y: Single);
begin
  dgU8(OP_MOVE_TO); dgF32(x); dgF32(y);
end;

procedure dgLineTo(x, y: Single);
begin
  dgU8(OP_LINE_TO); dgF32(x); dgF32(y);
end;

procedure dgClosePath;
begin
  dgU8(OP_CLOSE_PATH);
end;

procedure dgFill;
begin
  dgU8(OP_FILL);
end;

procedure dgArc(x, y, r, a0, a1: Single);
begin
  dgU8(OP_ARC); dgF32(x); dgF32(y); dgF32(r); dgF32(a0); dgF32(a1); dgU8(0);
end;

procedure dgFillText(ptr, tlen, x, y: Integer);
var
  i: Integer;
begin
  dgU8(OP_FILL_TEXT);
  if dgCmdLen + 2 + tlen > CMD_CAPACITY then Exit;
  dgU16(tlen);
  for i := 0 to tlen - 1 do
  begin
    dgCmd[dgCmdLen] := PByte(ptr)[i];
    dgCmdLen := dgCmdLen + 1;
  end;
  dgF32(Single(x));
  dgF32(Single(y));
end;

function dgRand: Cardinal;
begin
  dgRng := dgRng xor (dgRng shl 13);
  dgRng := dgRng xor (dgRng shr 17);
  dgRng := dgRng xor (dgRng shl 5);
  dgRand := dgRng;
end;

function dgRandF: Single;
begin
  dgRandF := Single(dgRand and $FFFFFF) / 16777216.0;
end;

function dgRandRangeI(lo, hi: Integer): Integer;
begin
  dgRandRangeI := lo + Integer(dgRandF * Single(hi - lo + 1));
end;

end.
