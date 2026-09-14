# Flight! We have Flight!

Code from the blog post [Flight! We have Flight!](https://nofuss.co.za/blog/flight_we_have_flight/).

Flight Leader is a keyboard-only 3D wireframe space-combat sim in the tradition of Elite and Star Raiders: first-person view, three waves of enemies (fighters, a gunboat, a capital ship), shields, hull, radar, and a scored debrief. Written with the v0.3.0 compiler, which also introduced the export pipeline that turns any compiled program into a standalone web app.

The game is a multi-unit project, so the source lives under [examples/flightleader/](../../examples/flightleader/):

| File | Description |
|---|---|
| `flightleader.pas` | Root program, input orchestration, and combat loop. |
| `fldefs.pas` | Shared state and host imports. |
| `flmath.pas` | 3D vector math, xorshift RNG, world-to-screen projection. |
| `flbatch.pas` | Batch command buffer and canvas wrappers. |
| `flfx.pas` | Explosion effects. |
| `flsim.pas` | Flight model, weapons, enemy AI, waves, scoring. |
| `flrender.pas` | Starfield, ships, HUD, radar, overlays. |

To run it: open [WasmPascal](https://wasmpascal.com/), click **Upload files**, select all `.pas` files at once, and hit **Run**.

Note: this post contains no Pascal listings — the code is the Flight Leader example itself.
