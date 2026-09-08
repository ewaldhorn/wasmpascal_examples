# Control flow

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

``

```pascal
if x > 0 then ... else ...;
case n of 0..4: ...; 11, 15..20: ... else ... end;
if cond then a else b;   // ternary: value of a or b (Delphi 13 style)
for i := 1 to 10 do ...;
while cond do ...;
repeat ... until cond;
break; continue; exit;
with rect do s := x + y;   // bare field names
```

`for` loops run the step at the top (counter starts at `from-1`, or `from+1` for `downto`) so `continue` still advances.

`exit` leaves the current function (optionally returning a value: `exit(42)`). `break`/`continue` apply to the innermost loop. `case` arms accept comma-separated value lists, **lo..hi ranges** (`0..4`, `11, 15..20`), and an `else` arm. Dense ranges dispatch via `br_table`; very wide or sparse spans fall back to an if-chain. Numeric `label`/`goto` (`label 10;` … `goto 10;`) work within a routine.

**Ternary expressions** (Delphi 13 style, 2026-08-26): `if cond then a else b` used where an expression is expected (an assignment, a call argument, inside a larger expression). The condition must be Boolean and the two branches must be the same type — numeric kinds promote (so `if c then 1 else 2.5` is Real), and **strings work too** (an `(addr,len)` pair via a scratch-pair if/else; a String[n] and dynamic String mix resolves to dynamic). Sets, records and arrays are not allowed. Only the taken branch runs (short-circuit), so a divide-by-zero or nil-deref in the untaken branch never executes. Nested ternaries are dangling-else safe: the inner `if` binds its own `else`. See `../../examples/ternary.pas`.

`with <record> do` opens a member scope: a bare identifier matching the record's fields resolves to that field (locals/params still shadow; the innermost `with` wins for comma chains like `with a, b do`, and a `with` scope shadows a same-named global). See `../../examples/with_demo.pas`.
