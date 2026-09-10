# My Paddock (WasmPascal port)

Sheep-farming idle game ported from Odin (`dinn/games/mypaddock`) to WasmPascal.
See [PLAN.md](PLAN.md) for the full port plan.

## Status: M2 — camera + panel chrome

Scrollable-world camera (drag pan with clamp, arrow keys, minimap tap-jump),
right panel (coins/sheep/upkeep lines, shop/mute/reset buttons, minimap with
viewport box), shop overlay shell with 7 rows, reset confirmation dialog.
No sim yet: coins/sheep/trough counts are placeholders; shop row clicks and
reset-YES are no-ops wired in M4.

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
| `mp_game.pas` | init / update / frame seam (sim lands in M3) |
| `mp_host.pas` | canvas bootstrap + event loop (port of `main.odin`) |
