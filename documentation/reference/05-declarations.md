# Declarations

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

``

```pascal
const RANGE: Cardinal = 100;
var a, b: Integer;
function Add(x, y: Integer): Integer;
procedure Swap(var a, b: Integer);  // by-address
type
  TPoint = record x, y: Integer; end;
  TGrid = array [0..9] of Integer;
```

`var` params are passed by address and work with globals, fields, indexed elements, pointer derefs, and **locals** — every function with an address-taken local gets a per-call stack frame in linear memory (`__frame_ptr`), so `Swap(a, b)` with local `a`/`b` just works. Locals of any type (scalars, and multi-word strings/arrays/records/sets) are frame-resident when their address is taken. Args must be type-identical lvalues (no `P(1+2)`). See `../../examples/var_params_demo.pas`.

`type` sections support records, static arrays, **`set of <ordinal>`** (bitmask sets: `set of 0..6` = one `i32`, `set of Byte` = 8 words; ops `+ - * in = <> <= >=` and constructors `[1, 3..5]`/`[]`), and named aliases. Pointers: `^T` declares, `@x` takes an address, `p^` dereferences. Set variables must be **globals** (they need an address, like arrays). See `../../examples/set_demo.pas`.

**Procedural / functional parameters** — a routine can take another routine as a value: `procedure Apply(p: procedure(x: Integer); v: Integer)` or `function Call(f: function(a, b: Integer): Integer; ...)`, with proc-typed globals, locals, record fields, aliases, arrays of proc values, and even proc-typed function results (via the wasm indirect-call table). See `../../examples/flrender.pas`.

Foreign functions use `external` (see Program structure).
