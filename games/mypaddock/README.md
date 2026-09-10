# My Paddock (WasmPascal port)

Sheep-farming idle game ported from Odin (`dinn/games/mypaddock`) to WasmPascal.
See [PLAN.md](PLAN.md) for the full port plan.

## Status: M1 — baked background + title

Renders the level-0 paddock (grass, fence, barn) with a `MY PADDOCK` title.
No sim, no input yet.

## How to run

In the WasmPascal web IDE ([wasmpascal.com](https://wasmpascal.com/)):

1. Click **Upload files** and select all `.pas` files in this folder at once.
2. The editor picks `mypaddock.pas` (the `library` root) automatically.
3. Click **Run**.

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
