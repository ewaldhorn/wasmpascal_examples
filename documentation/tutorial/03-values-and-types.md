# Values and types

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

Pascal is a typed language: every variable and function result has a type, declared ahead of use. wasmpascal's types are:

- **Integers**: `Integer`/`LongInt` (32-bit signed), `Cardinal`/`LongWord` (unsigned), plus `ShortInt` (8-bit), `SmallInt`/`Word` (16-bit), `Byte` (unsigned 8-bit).
- **Floats**: `Real`/`Double` (64-bit), `Single` (32-bit).
- **Booleans**: `Boolean`, `true` / `false`.
- **Characters**: `Char` (one byte).
- **Enumerations**: `type Color = (Red, Green, Blue)` gives named values with ordinals 0, 1, 2 — usable in `case`, array bounds, and `for` counters. Named subranges (`type Index = 1..10`) bound arrays and variables the same way.
- **Structured**: records, static arrays (including multi-dim `array[1..3, 1..4] of T` with `a[i, j]` indexing), pointers, and strings (including fixed `String[n]`) — their own lessons below.

Floats and integers mix in expressions: integer arguments to math builtins are promoted to floats automatically.
