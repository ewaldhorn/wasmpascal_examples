# Program structure

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

``

```pascal
program Hello;
uses u_math;              // your units are project files; Crt/Classes/WEB are built in
var x: Integer;
begin
  ...
end.
```

`program`, `library`, and `unit` headers are supported. A unit has `interface` / `implementation` sections and an optional `begin..end.` init body that runs in the module start function.

`uses` pulls in a unit's consts/globals/functions (deduped by name, loaded depth-first, transitive deps first). Your own units are project files (or bundled in `UNIT_LIBRARY`); three **embedded** units come from the compiler itself and need no registration — `Crt` (the 16 TP7 colour constants), `Classes` (the `TStringList` family) and `WEB` (the DOM/canvas bridge; `uses WEB` is how a canvas program reaches the host — see **Host ABIs**).

`exports foo name 'foo'` clauses live only in the root `program`/`library`.

Foreign functions: `external 'mod' name 'fn'` (FPC form) — name the module, because that is exactly where the import lands. A bare `external name 'fn'` compiles, but its import goes to wasm module `""`, which nothing provides: it fails at instantiate, not at compile time (`Import #0 "": module is not an object or function`). The math *builtins* (`Sin`, `Cos`, `Power`…) import from `odin_env` (JS `Math.*`); a hand-written math external names `odin_env` itself, as `sweepdefs.pas` does.
