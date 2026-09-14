# Paint

A small paint program whose entire interface — toolbar, colour swatches, brush-size buttons, undo, and a live status line — is built from the DOM in Pascal, compiled with [WasmPascal](https://wasmpascal.com/).

Covers:
- Page construction from Pascal: `web.CreateElement`, `web.AppendChild`, `web.SetClassName`, `web.SetStyle`, and an injected stylesheet via `web.AddStyle`, so hover and selection states stay in CSS.
- Controls wired by name with `web.On(...)` — the program declares no imports, picks no callback ids, and owns no dispatcher.
- A retained RGBA framebuffer blitted with `web.RenderCanvas`, with each stroke stamped along the segment between two pointer samples.
- An undo ring of three framebuffer snapshots, and a canvas that repaints only when something changed.

The markup, the styling, and the behaviour all originate in `paint.pas`; nothing on the page comes from the host's `index.html` except the `#stage` element it mounts into.
