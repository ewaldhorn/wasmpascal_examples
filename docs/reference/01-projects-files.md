# Projects & files

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

A **project** is a named set of Pascal files with one **root** file (the one compiled). Every other file is registered as a `uses` unit at run time.

- **File dropdown** (right of the Examples… menu) switches between the project's files; the root is marked `(root)`.
- **Files…** menu (next to the file dropdown): **+ File** adds a new unit file with a starter skeleton; **Rename file** renames the selected file (updating `uses` references); **Set as root** promotes it to the project's root; **− File** removes it. The per-file options are disabled while the root file is selected.
- **Rename project** renames the project (shown in the Download .wasm and .zip filenames).
- **Upload files** opens any number of `.pas` files from your computer and replaces the current project with them (confirming if you have unsaved changes). The file whose first Pascal keyword is `program` becomes the root; if none — or several — do, `main.pas` wins, then alphabetical order.
- Projects autosave to `localStorage` (`wasmpascal:project`).
