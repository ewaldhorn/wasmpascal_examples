# My Paddock (WasmPascal port)

Sheep-farming idle game ported from Odin (`dinn/games/mypaddock`) to WasmPascal.
See [PLAN.md](PLAN.md) for the full port plan.

## Status: M6 — budget screen (new feature, no Odin equivalent)

Lifetime income vs expenses overlay: SHEARING / SALES / UPKEEP / PURCHASES /
START / NET, opened with the BUDGET panel button or `E` (any tap, `E` or
`Esc` closes). Four counters hooked at every money mutation (shear, all
livestock sales, upkeep bills, all purchases, incl. offline bulk sim),
persisted as four save keys, with the invariant
`coins = 40 + shear + sales - upkeep - spent` covered by tests (incl.
accumulation across reloads and wipe on reset). Note the panel's
`UPKEEP: -N` is the per-60s *rate* while the budget's `UPKEEP` is lifetime
*paid* — they only agree after bills have actually fired. Offline simulates
1/10th of the elapsed time at full rates (upkeep included), so an hour away
plays ~6 live minutes — deliberate retune, diverges from Odin.

### Earlier: M5 — sound + playable host page

Shop row purchases (all 7 rows, live gates), upkeep bills with sell-off drain
and bill/bankrupt banners, autosave every 5s, localStorage saves readable
across reloads, offline catch-up with welcome banner, working reset (progress
wiped, SFX preference kept — Odin parity). Sound: 7 SFX through host
`app_env.play_sound(id)` with Web Audio patches transcribed from
`sound.odin`; mute state lives in `mp_sound.pas` and persists. Verified: all
7 ids fire end-to-end (denied/coin/purchase/sold via UI script, shear in the
200s sim, feed+water on worker refills in a ~720s run), mute suppresses all,
plus a real headless-Chromium screenshot of `index.html` showing the live
game. Still open: one IDE Run to confirm the web IDE host provides the
`mp_env` (`date_now`/`js_reload`) and `app_env` (`play_sound`) imports.

## How to run

In the WasmPascal web IDE ([wasmpascal.com](https://wasmpascal.com/)):

1. Click **Upload files** and select all `.pas` files in this folder at once.
2. The editor picks `mypaddock.pas` (the `library` root) automatically.
3. Click **Run**. (Needs IDE host support for `mp_env` + `app_env`; unconfirmed.)

## Play locally (no IDE)

`index.html` + `host.js` implement the full import surface
(`pascaldom_env`, `odin_env`, `mp_env`, `app_env.play_sound`), so the game
runs from any static server — `.wasm` won't load over `file://`:

```bash
cd games/mypaddock
/path/to/dinn/wasmpascal/wasmpascal -o mypaddock.wasm mypaddock.pas
python3 -m http.server 8931
# open http://localhost:8931/index.html (click once to unlock audio)
```

## How to test (local compiler)

The compiler lives at `dinn/wasmpascal` (binary `wasmpascal`); the harness
stubs `pascaldom_env`/`odin_env` under Node:

```bash
cd games/mypaddock
/path/to/dinn/wasmpascal/wasmpascal -o /tmp/mypaddock_m2.wasm mypaddock.pas
node tests/mp_test.js /tmp/mypaddock_m2.wasm   # expect SUCCESS
```

## Files

| File | Contents |
|---|---|
| `mypaddock.pas` | `library` root, `{$M 32M}`, exports |
| `mp_defs.pas` | constants, full palette, pixel/bg buffers, host imports |
| `mp_rand.pas` | xorshift RNG + `ParseF64` buffer helper |
| `mp_world.pas` | world size / bounds (port of `world.odin`) |
| `mp_draw.pas` | pixel rects/circles, 5x7 font + text |
| `mp_render.pas` | background bake + viewport blit |
| `mp_game.pas` | camera/input/panel + sim glue (sheep needs, workers, effects) |
| `mp_sheep.pas` / `mp_trough.pas` / `mp_worker.pas` / `mp_effect.pas` | entity data + logic (ports of `sheep.odin` etc.) |
| `mp_sprites.pas` | entity sprites + effect text |
| `mp_host.pas` | canvas bootstrap + event loop (port of `main.odin`) |
| `mp_sound.pas` | 7 sound events + `sfx_on` mute state (port of `sound.odin` API) |
| `mp_store.pas` | save/load/offline/reset via localStorage (port of `storage.odin`) |
| `mp_env.pas` | `mp_env` externals: wall clock + reload (port of `mypaddock_env`) |
| `host.js` + `index.html` | local browser host: full import surface + 7 Web Audio patches |
| `mypaddock.wasm` | compiled game (rebuild with the command above) |
