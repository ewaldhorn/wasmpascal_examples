# Types

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

- `Integer`/`LongInt` — 32-bit signed (`i32`); `Cardinal`/`Card`/`LongWord` — unsigned.
- `ShortInt` — `i8`; `SmallInt`/`Word` — `i16`; `Byte` — `u8`.
- `Single` → `f32`; `Double`/`Real` → `f64`.
- `Boolean` — normalized to 0/1; `Char` — one byte.
- `Pointer` — untyped 32-bit pointer; `^T` typed pointers.
- Records, static arrays, pointers (`^`, `@`, typed indexing `p[i]`). Multi-dim arrays use the TP sugar: `array[1..3, 1..4] of T` with `a[i, j]` indexing (desugars to nested arrays). Record variants work: `case tag: Byte of 0: (r: Single); 1: (w, h: Single); else (x: Single); end` (arms union at the tag's offset; an `else` arm is the default).
- **Conformant array parameters** — ISO `procedure P(a: array[lo..hi: Integer] of T)`: the caller passes an array of the same element type, and the bounds `lo`/`hi` become implicit value parameters. `packed` anywhere is a no-op (wasm memory is flat). See `../../examples/flrender.pas` (FLIGHT LEADER's polygon renderer).
- Float literals accept scientific notation (`1e10`, `5e-3`, `87.35E+8`).
- `set of <ordinal>` — bitmask sets: `set of 0..6` = one `i32`, `set of Byte` = 8 words. Ops `+ - * in = <> <= >=`, constructors `[1, 3..5]` / `[]`. Variables must be globals. See `../../examples/set_demo.pas`.
- String literals are static `[len:byte][bytes]`; foreign `string` params pass `(ptr,len)`. `String[n]` declares a fixed-length buffer (`n` ≤ 255) that truncates on store — globals are inline buffers; local `String[n]` vars behave as dynamic (addr,len) pairs (full short-string semantics are roadmap). `s[i]` indexes into a string (read or write).
- `object` / `class` — TP7 OOP (see **Objects & classes** below).
