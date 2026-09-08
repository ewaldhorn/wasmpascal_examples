# Host ABIs (wasmpascal-specific)

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

- **pascaldom** — exports `pascaldom_main`; self-wires canvas + event loop via `pascaldom_env` DOM/canvas imports. Example: `sweep.pas`.
- **batchiness** — exports `batchiness_main`; batched-canvas game + Web Audio SFX via `app_env`. Examples: `pascaloids.pas`, `pong.pas`, `transforms.pas`, `sparks.pas`, `growable.pas`, `flightleader.pas` (FLIGHT LEADER — a 6-unit arcade space-combat-style game), `xonix.pas` (Xonix — the fill floods from the balls, so it can never cover one), `floaty_car.pas` (Floaty Car — stay on the winding road; it only gets faster), `dugster.pas` (DUGSTER — a Digger-style dig-em-up in 5 units).
- **basic_canvas** — exports `wasm_init`/`wasm_update`/`wasm_click`/`wasm_get_pixels`/`wasm_get_width`/`wasm_get_height`, plus optional `wasm_pointer_down`/`wasm_pointer_move`/`wasm_pointer_up` for press-and-drag (mouse or touch); the host drives a fixed-step animation loop and blits the RGBA buffer. Examples: `basic_canvas.pas`, `classic_dots.pas`.
- **console-only** — no entry export; `write`/`writeln`/`read`/`readln`/`TextColor` programs via `wasmpascal_env` imports. Example: `hello_write.pas`.

The ABI is chosen automatically by peeking the compiled program's exports. `odin_env` provides the runtime hooks (write, trap, abort, `Math.*`, `rand_bytes`); `wasmpascal_env` is emitted only when the program uses console I/O.

**batchiness keyboard** — games self-wire their own keyboard via `batch_add_event_listener` on `document` (the bridge forwards the raw event and sets `batchiness_set_last_event` before the callback), then read `evt.key` / `evt.code` with `batch_get_property_str`. There is no host key mapping, so a game can use any key it wants. See `pong.pas` (and `pascaloids.pas`, `transforms.pas`) for the pattern: export `SetLastEvent name 'batchiness_set_last_event'`, wire `keydown`/`keyup` on `bGetGlobal('document')`, and in the callback map `evt.key` to your own key slots.
