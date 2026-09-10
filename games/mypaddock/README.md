# My Paddock — a WasmPascal example game

My Paddock is a complete sheep-farming game written in Pascal, compiled to
WebAssembly with the browser-based [WasmPascal](https://wasmpascal.com/)
compiler, and run by a small hand-written JavaScript host page.

It's meant as a worked example. This is what a *finished, multi-file* WasmPascal
project looks like: 18 Pascal files (one `library` root plus 17 units), a
pixel-buffer canvas renderer, a live simulation with its own little economy,
synthesised sound, and a save file that survives reloads — plus the handful of
files it takes to host the compiled result.

Everything on screen is drawn from code. No images, no assets, no framework.
Hosting it takes three files: `index.html`, `host.js` and `mypaddock.wasm`.

The game started life as an Odin project (`dinn/games/mypaddock`) and was ported
unit by unit.

## The game

You own a paddock. Buy sheep — then keep them alive: they get hungry and thirsty,
so you buy food and water troughs and hire farm hands to feed, water and shear
them. Wool sells for coins. Every 60 seconds an upkeep bill falls due; if you
can't pay, the game sells sheep to cover it.

Progression runs to paddock level 10, which caps the flock at 110 sheep (10 plus
10 per level). Troughs stop at 44 (22 food/water pairs), and the flock starts
demanding a sheep dog as it grows. Ten farm hands keep 110 sheep fed and shorn;
the engine allows eleven. Every purchase gets more expensive than the last, and
upkeep never stops growing — 164 coins a minute at a full flock.

The BUDGET screen (`E`, or the BUDGET button) is a lifetime ledger: shearing
income, livestock sales, upkeep paid, purchases, the 40 starting coins, and the
net. It always satisfies `coins = 40 + shear + sales - upkeep - spent`.

The HELP card (`H`, or the HELP button) restates the goal and every control on
screen — the same list as below, for anyone who never reads this file.

Close the page and the game simulates what you missed when you come back — at
one tenth of the elapsed time and full rates, so an hour away plays about six
live minutes.

**Controls** (also printed on the page):

- Drag the paddock — or the minimap — to pan; tap the minimap to jump
  somewhere.
- Tap (or click) a feed or water trough to pick it up, then tap where it should
  go — a yellow ring marks the one in hand and the outline follows the cursor.
  `Esc` puts it back. Troughs keep the spot you chose, across reloads.
- `B` — shop, `E` — budget, `H` — help, `M` — mute sound, arrow keys — pan.
- The right-hand panel carries the SHOP, SFX, RESET, BUDGET and HELP buttons;
  tapping anywhere closes an open overlay (`Esc` too).
- Sound needs one click or keypress first — browsers don't allow audio before a
  user gesture.

## Build it in the WasmPascal web IDE

1. Open [wasmpascal.com](https://wasmpascal.com/).
2. Click **Upload files** and select **all the `.pas` files** in this folder at
   once. (Only `.pas` files — `index.html`, `host.js` and the test harness are
   for hosting, not compiling.)
3. Fix the root file. The IDE picks the root by looking for a file that starts
   with `program`; `mypaddock.pas` starts with `library`, so nothing matches and
   the IDE falls back to the alphabetically first file — which is `mp_defs.pas`.
   Select `mypaddock.pas` in the file dropdown, then choose
   **Files… → Set as root**. (The IDE's "doesn't start with `program` — Run may
   fail" note is expected here; a `library` root is what this project uses.)
4. Optional but tidy: **Rename project** to `mypaddock`, so the compiler names
   its output `mypaddock.wasm`, which is the filename the host page asks for.
5. Click **Run** (`Ctrl`/`Cmd`+`Enter`). What matters is the compile: the
   console reports something like `Compiled mypaddock (35430 bytes) — running…`
   (it uses your project name — `mp_defs` if you skipped the rename). Then the
   IDE's own runner says **Program failed to start**. That is expected, not a
   broken build — see the next section. Click **Stop** if the toolbar stays
   locked.
6. Choose **Download… → Compiled .wasm**, and keep the file next to
   `index.html` as `mypaddock.wasm`.

There is no separate Build button in the IDE — **Run** is what compiles, and the
download stays available afterwards even though starting the program failed.

### Why the IDE can't run this game

The IDE's runner supplies `pascaldom_env`, `odin_env` and `wasmpascal_env`. This
game also imports two modules that only exist because this game wants them:

- `mp_env` — `date_now` (wall clock, for offline progress) and `js_reload`
  (page reload after a reset).
- `app_env` — `play_sound`, the seven sound effects.

The IDE has no way to know about those, so the module can't be instantiated
there (the failure is a WebAssembly link error naming `mp_env`/`app_env`).
Compiling and downloading still work fine; the IDE's exported standalone app
would hit the same wall, for the same reason.

That's exactly what `host.js` in this folder is for: it implements the whole
import surface, which is why the game runs here. The imports this build
actually needs are:

- `pascaldom_env` — 13 calls: the DOM handle bridge, the pixel-buffer canvas
  (`create` / `get_context` / `render`), the animation loop, events, and
  `localStorage`.
- `odin_env` — `sqrt`, `sin`.
- `mp_env` — `date_now`, `js_reload`.
- `app_env` — `play_sound`.

## Host it

The game is three static files in one folder — `index.html`, `host.js`,
`mypaddock.wasm` — with no build step and no server-side code:

```bash
cd games/mypaddock
python3 -m http.server 8931
# then open http://localhost:8931/
```

Any static host will do: GitHub Pages, Netlify drop, Cloudflare Pages, S3,
nginx on a VPS. Upload the three files and you're done. Three things to know:

- **Keep them together.** The page fetches `mypaddock.wasm` from its own folder,
  so the names and the directory layout matter. If the IDE named your download
  something else (say `mp_defs.wasm`), rename it — or point
  `host.js`'s `mypaddock.wasm` reference at the new name.
- **Serve over HTTP(S), not `file://`.** Browsers refuse to fetch a `.wasm`
  binary from the filesystem; double-clicking `index.html` shows
  `load failed: …` instead of the game.
- **Saves are per-origin.** Progress lives in the browser's `localStorage`
  (12 keys prefixed `mypaddock`), so a save made on `localhost` won't appear on
  your deployed site. RESET wipes progress but keeps the sound preference, as in
  the original game.

## How it works

One frame at a time, entirely in Pascal:

- `pascaldom_main` is called once by the host after instantiation. The game
  builds a background image of the whole world once (a pixel buffer, then
  blitted each frame through `dom_canvas_render`) and only redraws what moves.
- At level 10 that background bake is 2980 × 2200 × 4 bytes ≈ 26 MB, which is
  why the root file asks for a larger heap with `{$M 48M}` — a real WasmPascal
  ceiling worth knowing about before you build something big.
- The simulation runs off host wall-clock deltas (`dom_now`), so bills,
  shearing, needs and the autosave (every 5 seconds) all advance by elapsed time
  rather than frame count.
- Sound is seven events (`mp_sound.pas`), each one call to
  `app_env.play_sound(id)`; the oscillator patches live in `host.js`, mirroring
  the original Odin implementation.
- Saves are flat `localStorage` keys written through `pascaldom_env`, with the
  flock and trough arrays packed into composite strings. A trough record is
  `kind,x,y,amount` (position in tenths of a world pixel, because you can move
  them); a save written before troughs were movable is `kind,amount`, and those
  troughs land at random exactly as they used to.

## Files

| File | Contents |
|---|---|
| `mypaddock.pas` | `library` root, `{$M 48M}`, the exports the host calls |
| `mp_defs.pas` | constants, full palette, pixel/bg buffers, host imports |
| `mp_rand.pas` | xorshift RNG + float parsing helper |
| `mp_world.pas` | world size and camera bounds |
| `mp_draw.pas` | pixel rects/circles, 5×7 font and text |
| `mp_render.pas` | background bake + viewport blit |
| `mp_game.pas` | init, frame update, input, overlays, save glue, debug getters |
| `mp_shop.pas` | economy: progression state, costs/caps/gates, upkeep, shop UI |
| `mp_sim.pas` | simulation glue: task assignment, needs, worker machine, offline |
| `mp_sheep.pas` / `mp_trough.pas` / `mp_worker.pas` / `mp_effect.pas` | entity data + logic |
| `mp_sprites.pas` | entity sprites and floating effect text |
| `mp_host.pas` | canvas bootstrap + event loop |
| `mp_sound.pas` | sound events + `sfx_on` mute state |
| `mp_store.pas` | save/load/offline/reset via localStorage |
| `mp_env.pas` | the `mp_env` externals: wall clock + reload |
| `index.html` + `host.js` | the browser host: full import surface + 7 Web Audio patches |
| `mypaddock.wasm` | the compiled game — this is the file the host page loads |
| `tests/mp_test.js` | Node harness that boots the `.wasm` against stub hosts |

The `.wasm` here is a current build of these sources. The harness needs no
compiler — it runs the binary under Node with stub hosts and covers the economy,
save/load, offline catch-up, and the budget identity:

```bash
node tests/mp_test.js mypaddock.wasm   # prints PASS lines, ends in SUCCESS
```

## Credits

Original game in Odin: `dinn/games/mypaddock`. Compiler and IDE:
[wasmpascal.com](https://wasmpascal.com/). Licensed under the repository's MIT
license.
