# PLAN.md — Port `mypaddock` (Odin → WasmPascal)

Source: `/Users/ewaldhorn/repos/ewald/dinn/games/mypaddock` (~2,614 lines Odin, 14 files).
Target: this dir, WasmPascal multi-unit project run in the web IDE at wasmpascal.com
(upload all `.pas` files at once, `program` file is the root) plus a host HTML harness
for local testing (see §7).

## 0. Difficulty verdict: MEDIUM, mostly mechanical

Why not hard: the game is pure logic + pixel primitives. No images, no audio files,
no physics engine, no third-party deps beyond the `odindom` bridge. Every subsystem
has a direct WasmPascal precedent in this repo:

| mypaddock need | Precedent in `examples/` |
|---|---|
| pixel-buffer canvas game, 800×600 | `sweep` (pascaldom, `PIXEL_COUNT` pixel array, `dom_canvas_render`) |
| multi-unit layout (defs/sim/render/host/store) | `sweep` (8 units), `dugster` (6), `flightleader` (7) |
| Odin original ported to Pascal | `pascaloids` (header says so explicitly) |
| host `play_sound(id)` SFX | `pong`, `pascaloids` (`app_env` `play_sound`) |
| localStorage save/load + int↔string helpers | `sweepstore` (`ls_get_item`/`ls_set_item`, `ParseInt`/`IntToBuf`) |
| xorshift RNG replacing `core:math/rand` | `pong`, `pascaloids`, `sweeprand` |
| pointer down/move/up + keydown wiring, rect-settle | `sweephost` (copy the pattern wholesale) |
| 5×7 bitmap font | ports line-for-line as a const table; draw with rects |

The work is volume (~3k lines Pascal), not invention. Two structural conversions
(§4 dynamic arrays, §5 sound) are the only places that are redesign rather than
transliteration.

## 1. ABI decision: pascaldom pixel-buffer (like `sweep`), NOT batchiness

`mypaddock` renders via `odindom:canvas` pixel primitives (rects, circles, baked
background + row-wise `copy()` blit) and a 5×7 bitmap font drawn as rects.
That maps 1:1 onto the `sweep` pascaldom pattern: a global
`pixels: array[0..PIXEL_COUNT-1] of Byte` buffer, per-frame `GameUpdate` +
`DrawFrame`, then `dom_canvas_render`. Choosing batchiness (Canvas2D vector ops,
like `dugster`/`pascaloids`) would force a rewrite of the 595-line renderer —
reject it. Copy `sweepdefs.pas` externals block and `sweephost.pas` structure
as the starting template.

- `CANVAS_W = 800`, `CANVAS_H = 600`, `PIXEL_COUNT = 800*600*4` (1.92 MB static —
  `sweep` already does a static pixel array, so this is proven to fit).
- Right panel (`RIGHT_PANEL_W = 220`) stays pixel-drawn; no DOM UI needed.
- Keep the Odin input model exactly: `mousedown`/`mousemove`/`mouseup` +
  `keydown` only, no `click` listener (tap = short low-movement press-release;
  see `game.odin` input section).

## 2. Source inventory (what gets ported)

| Odin file | Lines | Pascal target | Notes |
|---|---|---|---|
| `src/main.odin` | 120 | `mp_host.pas` | template from `sweephost.pas`; §7 extras |
| `src/game/constants.odin` | 120 | `mp_defs.pas` (consts) | transliterate; keep economy comments |
| `src/game/palette.odin` | 76 | `mp_defs.pas` (colours) | RGB consts |
| `src/game/world.odin` | 47 | `mp_world.pas` | pure math, trivial |
| `src/game/trough.odin` | 63 | `mp_sim.pas` or own unit | trivial logic |
| `src/game/sheep.odin` | 132 | `mp_sheep.pas` | movement only; needs RNG unit |
| `src/game/worker.odin` | 108 | `mp_worker.pas` | movement + state/task enums only |
| `src/game/effect.odin` | 34 | `mp_sim.pas` | trivial |
| `src/game/shop.odin` | 180 | `mp_shop.pas` | costs/caps/upkeep math + buy/sell; container edits (§4) |
| `src/game/game.odin` | 556 | `mp_game.pas` | brain: `update_sheep_needs`, `update_workers` + claim bufs, upkeep timer, autosave, input hit-testing; biggest file, §4 applies |
| `src/game/font.odin` | 122 | `mp_draw.pas` | `font5x7` table verbatim + `draw_text`/`draw_text_large` via rects |
| `src/game/renderer.odin` | 595 | `mp_draw.pas` + `mp_render.pas` | bg bake, `blit_world`, panel/shop/minimap rects (single source of truth — keep that invariant), sprites |
| `src/game/sound.odin` | 176 | `mp_sound.pas` (thin) + host JS (§5) | 7 SFX → integer IDs |
| `src/game/storage.odin` | 285 | `mp_store.pas` | template from `sweepstore.pas`; composite flock/trough codecs stay `;`/`,`-delimited |

Proposed units: `mypaddock.pas` (program root) + `mp_defs`, `mp_rand`,
`mp_world`, `mp_sheep`, `mp_worker`, `mp_sim` (effects + trough glue if not
separate), `mp_shop`, `mp_game`, `mp_draw`, `mp_render`, `mp_sound`,
`mp_store`, `mp_host`. Merge tiny ones as convenient, but keep `mp_host`,
`mp_store`, `mp_draw` separate — they mirror proven `sweep` units and make
review against the Odin source 1:1.

## 3. Phase 0 (first): port leaf modules with zero dependencies

`constants → palette → world → trough → effect → font table → xorshift RNG`.
Verify by compiling in the IDE immediately (a `program` root that paints the
baked background + one text line proves the ABI, pixel buffer, font, and host
harness in one shot). Do NOT start with `game.odin`.

## 4. Cross-cutting conversion A: dynamic arrays → fixed arrays + counts

WasmPascal precedent (`pascaloids` `MAX_ASTEROIDS`/`MAX_BULLETS`/…, `sweep`
`MAX_W*MAX_H` cells, `dugster` slots) is fixed-size arrays, so assume no
`SetLength`/dynamic arrays and convert:

- `MAX_SHEEP = 120` (gameplay cap stays 50 at paddock level 4: base 10 + 4×10;
  120 is array headroom only — raising the real cap needs rebalancing, out of scope),
  `MAX_WORKERS = 1 + 4` (farmer + hands; dog is NOT a worker — keep that design),
  `MAX_TROUGHS = 20`, `MAX_EFFECTS = 64`.
- `append` → `arr[count] := x; Inc(count)`; `pop` (sell_one_sheep pops the
  most-recent) → `Dec(count)` — LIFO order is load-bearing for upkeep sell-off.
- Deletion elsewhere (none for troughs — indices are stable by design, keep that
  invariant so `Worker.target_trough` stays valid).
- Reusable scratch bufs (`effect_buf`, `claimed_sheep_buf`, `claimed_troughs_buf`)
  become fixed arrays; sizes: claimed lists ≤ worker/task counts.
- Enums (`WorkerState`, `WorkerTask`, `WorkerKind`, `TroughKind`) → Integer consts
  (matches `sweep`/`dugster` style: `ST_PLAYING = 1`, etc.).

## 5. Cross-cutting conversion B: sound via host `play_sound(id)`

The Odin code synthesises 7 SFX with raw Web Audio oscillator/gain nodes through
the `dom` bridge. WasmPascal convention (per `pong`/`pascaloids`) is
`procedure aPlaySound(id: Integer); external 'app_env' name 'play_sound';`
with the host implementing the sounds. So:

- `mp_sound.pas` keeps the call sites (`play_feed`, `play_water`, `play_shear`,
  `play_coin`, `play_purchase`, `play_denied`, `play_sold`) and the
  `sfx_enabled` toggle, but each body becomes `if enabled then aPlaySound(ID)`.
- IDs: `SND_FEED=0 … SND_SOLD=6` (document in `mp_defs.pas`).
- Re-implement the 7 tones/sweeps in the host harness JS (Web Audio, same
  freqs/durations/waveforms as `sound.odin` §§108–176 — they are fully specified
  there). This intentionally changes where synthesis lives; game code stays dumb.
- `init_sound` user-gesture rule still applies: init/resume AudioContext on first
  pointer/key handler, idempotent.

## 6. Cross-cutting conversion C: everything else, itemised

- **RNG**: drop `core:math/rand`; add `mp_rand.pas` xorshift (copy `pong`'s
  `NextRand` + helpers for range/float). Seed once at startup. Note: save format
  stores needs, not RNG state, so stream differences vs Odin are unobservable.
- **Floats**: game uses `f64` throughout; WasmPascal `Double` + `mSqrt`-style
  `odin_env` imports where needed (`sweepdefs` shows the pattern). Keep `Double`
  everywhere, do not downgrade to `Single`.
- **Strings**: minimal use — fixed labels + `IntToBuf`/`ParseInt` on scratch
  buffers (`sweepdefs` `scratch`/`text_buf` pattern; wasmpascal has no
  local-address, so keep these globals). Composite codecs
  (`mypaddockFlock`, `mypaddockTroughs`) stay byte-identical formats so saves
  are conceptually interchangeable.
- **Hard constraint (verified M1 against compiler source + runtime trap)**:
  indexing a by-value `string` param (`s[i]`) emits base address 0 and traps —
  `cg_emit_index_addr` only handles Global / frame / `var`-param strings.
  `Length(s)` on a by-value param works, but never index one. Pass text as
  `(addr, len)` Integer pairs via `StrAddr`/`StrLen` builtins and read bytes
  with `PByte` (dugster's `dgSetFill(StrAddr(...), …)` pattern); `mp_draw`'s
  `DrawText`/`DrawTextLarge` already follow this. Same caution applies to any
  future `string` value param — prefer addr/len or `var` params throughout.
- **Case-insensitivity (bit M2 hard)**: Pascal folds identifiers, so an
  `mm_w` var silently collides with an `MM_W` const from another unit — unit
  merge keeps the FIRST (the const) and stores to the "variable" emit a bare
  value with no store, producing wasm that fails validation (leftover stack).
  Rule: unit globals get a per-unit prefix (`mwr_*` for minimap-world-rect,
  `rr_*` for shop rows, `bnd_*`, `cw_*`…), layout consts stay UPPER_SNAKE,
  and never reuse a const name (any case) as a variable. When adding a unit,
  grep all names lowercased for collisions before compiling.
- **Record-type visibility (bit M3 hard)**: a unit cannot declare a var/array
  of another unit's record type — `unknown type 'TSHEEP'` (bisected to a
  minimal repro). Co-locate each record type with its arrays in one
  uses-free unit (fldefs pattern: `mp_defs` owns `TSheep`+`sheep[]`,
  `TWorker`+`workers[]`, …); logic units (`mp_sheep`, `mp_sprites`, `mp_game`)
  take `var` record params and index the shared arrays, which works
  cross-unit. Single record vars in the root are fine.
- **Error positions lie across units**: errors inside a used unit are reported
  at the root file with nonsense lines (a 6-line root "errors" at :50).
  When that happens, suspect the merged unit: bisect with `--export-all` +
  `wasm2wat --no-check` to map the failing function index back to a name.
- **Break inside `if` is a silent no-op (bit M4 hard)**: `br` targets the
  `if`-block, not the loop — verified in disassembly (`br 0 (;@3;)` on the
  `if` vs correct `br 2` without enclosing fors) and at runtime
  (`/tmp/bisect/brk2.pas`: loop runs 100× instead of breaking at 51).
  With `while true` this hangs forever (offline progress did). Rule: never
  `Break` inside an `if` — use done-flags or guards. Bare `Break` directly
  in a loop body works. `Exit` (early return) works everywhere tested.
- **Storage keys**: identical key names (`mypaddockCoins`, …) — a ported game
  can read an Odin-written save.
- **`reset_save`**: same "write empty, treat empty as unset" trick; no
  `removeItem` bridge needed.
- **`reload_page`**: needs a host import (Odin uses its own `mypaddock_env`
  block for this + `date_now`). Same for Pascal: one small app-specific
  external block (`mp_env`: `date_now → Double`, `js_reload`), mirroring the
  established "app-specific interop" pattern. Host harness implements both
  (`Date.now()`, `location.reload()`).
- **Wall clock**: read `date_now()` exactly once at startup into
  `wall_ms_origin`; everything else derives from `time` accumulator
  (`current_wall_ms`). No per-frame JS round-trips.
- **Frame loop**: `dt` clamp at 0.1 s, `rect_settle_frames = 30`, `version`
  element write — copy from `sweephost.pas`/`main.odin`.
- **Background bake**: `bg` becomes a second static buffer (world max is
  `(580+4*240) × (600+4*160)` = 1540×1240×4 ≈ 7.6 MB — check IDE memory
  limits; if too big, bake at viewport size and tile, or bake per-frame
  procedurally. Flag as the top memory risk; decide in Phase 0 with a
  compile-and-run test).
- **Minimap/panel/shop rects**: keep the single-source-of-truth procs shared
  between draw and hit-testing; do not hardcode a second copy.

## 7. Host harness (needed for local testing + sound)

The web IDE provides its own host (`PascalDom.instantiate` — no host JS exists
in this repo), so the primary loop is upload-and-Run in the IDE. The local `index.html` + `host.js` landed in M5: it implements the full
`pascaldom_env` surface used (import list in `mp_defs.pas`),
`app_env.play_sound(id)` with the 7 synth patches, and the `mp_env` block
(`date_now` / `js_reload`, which landed with `mp_store.pas` in M4).
Canvas id is `stage` + `#version` element (sweep convention, already served
by the IDE host). Serve local harness via `python3 -m http.server` (same as
`blog_posts/` demos) since `.wasm` won't load over `file://`.
- **OPEN RISK (M4): `mp_env` import.** Offline progress and reset-reload need
  `date_now`/`js_reload` from a new `mp_env` import module (mirrors Odin's
  `mypaddock_env`). `odin_env` only provides `Math.*`, and `pascaldom_env`
  has no wall clock — there is no other source. If the web IDE host does not
  provide `mp_env`, the module will fail to instantiate there even though it
  passes locally. Verify with one IDE Run; if it breaks, the fallback is
  dropping offline catch-up (session-only saves) — say so explicitly rather
  than shipping a game that boots nowhere.

## 8. Milestones & verification (in order)

1. **M1 — ABI + pixels**: program root paints baked bg + text line; runs in IDE
   and via local harness. Kills the bg-memory risk (§6) early.
2. **M2 — world + camera**: pan/drag, clamp, minimap rect, panel chrome, no sim.
3. **M3 — sim**: sheep needs/wander/trough self-serve + worker state machine;
   eyeball against Odin build side-by-side (same seed → same wander is NOT
   required; behaviour parity is).
4. **M4 — economy**: shop buy/sell/gates, upkeep bill + sell-off, autosave +
   reload persistence, offline catch-up (test with forged `LastSeen`).
5. **M5 — sound + polish** (DONE): 7 SFX through host `app_env.play_sound`,
   `index.html` + `host.js` local host page (full import surface, synth
   patches from `sound.odin`), all ids verified end-to-end under Node plus a
   headless-Chromium screenshot of the live game. Welcome/bill banners and
   reset flow already landed in M4.
6. Each milestone: play the Odin `dist/` build and the Pascal build side by
   side; keep a checklist of divergences in this file. Economy rates
   (`constants.odin` §§33–68 comments record two rounds of playtest tuning) must
   transfer exactly — they are the game balance.
7. **Divergences found by side-by-side**: (a) single-char string literals are
   `Char`, not `String`, so `StrAddr`/`StrLen` miscompile on them — every
   one-char glyph (`+`, `)`, `/`, `!`, `*`, space) was silently missing until
   fixed with doubled literals + len 1 (no Odin equivalent; compiler-side).
   (b) none in game balance or layout: the clipped panel hint text
   (`DRAG/ARROWS: SCROLL` overrunning the panel) reproduces the Odin `dist/`
   build exactly.
8. **M6 — Budget screen (new feature, deliberately beyond the port)**: `E`
   key + BUDGET panel button open an income-vs-expenses overlay
   (SHEARING/SALES/UPKEEP/PURCHASES/START/NET). Four counters hooked at every
   coin mutation incl. the offline bulk sim, persisted as four save keys;
   invariant `coins = 40 + shear + sales - upkeep - spent` is test-covered.
9. **M6b — offline runs at 1/10th speed (retune, diverges from Odin)**:
   the elapsed window is divided by `OFFLINE_TIME_DIV` before the normal
   offline sim, so pay rates AND upkeep bills are unchanged — 1h away plays
   ~6 live minutes. Measured 1h-from-fresh: 60 gross, 18 billed over 6
   cycles, flock intact, welcome shows net +42.

## 9. Risks (honest list)

1. **IDE memory ceiling** for two big static buffers (1.9 MB frame + up to
   ~7.6 MB bg). Mitigation: measure in M1; fall back to smaller bg or no bake.
2. **No dynamic arrays** (assumed) — mechanical but touches every sim file; §4.
3. **String handling is the weakest area** of the target — contained by keeping
   strings to labels + serialised ints, reusing `sweep` helpers verbatim.
4. **Sound fidelity** depends on host JS re-implementation; game-side is trivial.
5. **Scope**: ~2.6k lines Odin → ~3k lines Pascal. Straightforward but not short;
   resist adding features (no new shop rows, no music loop — Odin has neither).
