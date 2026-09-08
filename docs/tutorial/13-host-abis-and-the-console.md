# Host ABIs and the console

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

wasmpascal detects how to boot a compiled program by peeking its exports — you never pick the ABI yourself. There are four:

- **console-only** — no entry export; plain `write`/`writeln`/`readln`/ `TextColor` programs (all the lessons above).
- **pascaldom** — exports `pascaldom_main`; self-wires its canvas + event loop via `pascaldom_env` DOM/canvas imports. Example: `sweep.pas`.
- **batchiness** — exports `batchiness_main`; batched-canvas games + Web Audio SFX via `app_env`. Games self-wire their own keyboard (see the `?` reference's Host ABIs section). Examples: `pascaloids.pas`, `pong.pas`, `transforms.pas`, `sparks.pas`, `growable.pas`, `flightleader.pas` (FLIGHT LEADER, a 6-unit space combat game), `xonix.pas` (a Xonix clone: draw lines to claim land — the fill floods from the balls, so it can never cover one), `floaty_car.pas` (Floaty Car endless driver — stay on the winding road; it only gets faster), `dugster.pas` (DUGSTER — a Digger-style dig-em-up in five units).
- **basic_canvas** — exports `wasm_init`/`wasm_update`/ `wasm_click`/`wasm_get_pixels`/ `wasm_get_width`/`wasm_get_height`, plus optional `wasm_pointer_down`/`wasm_pointer_move`/ `wasm_pointer_up` for press-and-drag (mouse or touch); the host drives a fixed-step loop and blits your RGBA buffer. Examples: `basic_canvas.pas`, `classic_dots.pas`.

The `? `quick reference's **Host ABIs** section has the full details and examples. When you want to draw pixels or build a game, load one of those examples, Run it, and study how it wires its `external 'pascaldom_env' ...` / `'app_env'` imports before writing your own.
