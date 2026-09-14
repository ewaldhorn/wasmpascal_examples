# Web DOM

The DOM, in Pascal, with the boilerplate gone — the guided tour of `uses WEB`. Compiled with [WasmPascal](https://wasmpascal.com/).

Compare it with `pascaldom_probe.pas`, which fills one canvas with its imports hand-declared. What is *not* in this example is the point:

- no `external` declarations for the `pascaldom` bridge — `uses WEB` brings the whole surface in, resolved from the compiler binary exactly like `Crt` or `Classes`, with no `WEB.pas` on disk.
- no `CB_*` callback-id constants and no `case id of` dispatcher — handlers register by name with `web.On` / `web.OnTick`, and the unit owns the dispatch table.
- no `exports pascaldom_main` / `pascaldom_invoke_callback` / `pascaldom_set_last_event` — the program body *is* the entry point.
- no `cv_h` / `ctx_h` globals — the canvas and its context are `TWeb` fields.

It builds a styled panel, paints and animates a 160×100 RGBA canvas, reads pointer coordinates with `EventClientX`/`EventClientY`, and passes string *expressions* to the bridge, not just literals.
