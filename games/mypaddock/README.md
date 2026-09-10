# My Paddock (WasmPascal port)

Sheep-farming idle game ported from Odin (`dinn/games/mypaddock`) to WasmPascal.
See [PLAN.md](PLAN.md) for the full port plan.

## Status: M4 — economy + persistence

Shop row purchases (all 7 rows, live gates), upkeep bills with sell-off drain
and bill/bankrupt banners, autosave every 5s, localStorage saves readable
across reloads, offline catch-up with welcome banner, working reset (wipe +
reload). Verified: sell→save→reload restores (50 coins, 2 sheep), exact
upkeep bill (40→37 at 60s), 1h offline earns net +600 with welcome banner,
250s run never goes negative. Still M5: sound. Needs one IDE Run to confirm
the host provides the `mp_env` import (`date_now`/`js_reload`).

## How to run

In the WasmPascal web IDE ([wasmpascal.com](https://wasmpascal.com/)):

1. Click **Upload files** and select all `.pas` files in this folder at once.
2. The editor picks `mypaddock.pas` (the `library` root) automatically.
3. Click **Run**.

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
