# Program structure

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

``

```pascal
program Hello;
uses u_math;              // units registered with the host
var x: Integer;
begin
  ...
end.
```

`program`, `library`, and `unit` headers are supported. A unit has `interface` / `implementation` sections and an optional `begin..end.` init body that runs in the module start function.

`uses` pulls in a unit's consts/globals/functions (deduped by name, loaded depth-first, transitive deps first). Units must be registered with the host (bundled in `UNIT_LIBRARY` or added as project files).

`exports foo name 'foo'` clauses live only in the root `program`/`library`.

Foreign functions: `external 'mod' name 'fn'` (FPC form) or `external name 'fn'` — the import lands in wasm module `mod` (default `env`). Math imports (`sin`/`cos`/`pow`/`sqrt`) resolve to `odin_env` (JS `Math.*`).
