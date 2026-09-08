# Editor shortcuts & toolbar

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

- **Syntax highlighting** — keywords, numbers, strings, comments, and operators are colored live as you type; unterminated strings/comments get a wavy red underline. A line-number gutter marks the current error line.
- `Tab` — indent / smart-indent; `Shift+Tab` — un-indent.
- `Ctrl/Cmd+Enter` — Run.
- `Ctrl/Cmd+X` — cut the current line (no selection) or the selection.
- `Ctrl/Cmd+Z` — undo; `Ctrl/Cmd+Shift+Z` (or `Ctrl/Cmd+Y`) — redo. Tab, auto-close, comment toggle, and cut-line are all undoable.
- `Enter` — auto-indent to the current line's indent.
- `(` `[` `{` `'` `"` — auto-close.
- `Ctrl+/` — toggle a `(* ... *)` comment.
- `A` — cycle editor font size; `Clear Console` (output panel) — clear the console output.
- `Help…` menu / `F1` — this reference; `Esc` — close.
- Toolbar: `Run`, `Stop`, `Download…` (compiled `.wasm` / project `.zip` / standalone app `.zip` or `.html`), `Upload files`, `A` (cycle editor font size), `Help…` (quick reference / lessons), `Examples…`, `Rename project`, file dropdown, `Files…` (`+ File`/`Rename file`/`Set as root`/`− File`).
- **Standalone apps** — the `Download…` standalone `.zip` is a ready-to-host folder: its runner page loads the compiled `.wasm` file, so host the folder over HTTP (opening `index.html` from `file://` shows a "serve this folder over HTTP" error). The single-file `.html` has everything inlined and opens straight from disk.
