# Builtins

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

**Arithmetic**

`Inc`/`Dec` (with optional delta), `Sqrt`, `Sqr`, `Trunc`, `Round`, `Abs`, `Frac`, `Int`, `Pi` (a bare `Pi` is a pre-defined `Double` constant; `Pi()` works too — both are the same value). Integer literals are decimal, `$FF` hex, or `%1010` binary.

 **Trigonometry (radians)**

`Sin`, `Cos`, `Tan`, `ArcTan`, `ArcSin`, `ArcCos`, `ArcTan2(y, x)`, plus the hyperbolic `Sinh`/`Cosh`/`Tanh`.

 **Exponential & logs**

`Exp`, `Ln`, `Log10`, `Log2`, `Power(b, e)`, `Hypot(x, y)` (Euclidean length).

These math builtins are emitted as `odin_env` imports (JS `Math.*`); integer arguments are promoted to `f64`. See `../../examples/math.pas`.

 **Memory & pointers**

`FillChar`, `Move(src, dst, count)` (copies bytes), `pointer()`/`PByte()`/`PWord()`/ `PCardinal()`/`PLongInt()`/`PInteger()` casts, `nil` (the null pointer constant, for assignment and `=`/`<>` checks — `p <> 0` also works), and `Inc(p)`/`Dec(p, n)` on typed pointers (the step is scaled by element size). `SizeOf(T)`/`SizeOf(var)` is a compile-time constant — note `SizeOf(String)` = 8 (the (addr,len) pair model) and `SizeOf(String[n])` = n+1.

String helpers: `StrAddr('lit')` → byte address, `StrLen('lit')` → byte count. `F32Bits(f)` reinterprets an `f32` as `i32` (bit pattern).

 **Console & timing**

`Delay(ms)` (pause; console programs sleep in a worker), `GotoXY(x, y)` (position the console cursor, 1-based), `ClrScr` (clear the console), `TextColor`, `TextBackground`.

**Random numbers:** `Random` (no args) is a `Real` in [0, 1); `Random(n)` is an `Integer` in [0, n-1] (n ≤ 0 gives 0). A xorshift PRNG is compiled into the program; unseeded runs are deterministic (same sequence every run, TP behavior). `Randomize` reseeds it from host entropy (`crypto.getRandomValues`).

**Keys:** `KeyPressed` (non-blocking poll) and `ReadKey` (blocking pop) read the host's key buffer while a console program runs. Arrow keys arrive TP-style as the extended pair `#0` + scan code (left `#75`, right `#77`); other single-char keys pass their char code. See `../../examples/breakout.pas`.

 **Ordinals & characters**

`Ord(x)` (ordinal of an enum/char/bool), `Chr(n)`, `Pred`/`Succ` (±1, no range check — TP `{$R-}` semantics), `Odd(n)` → `Boolean`, `UpCase(ch)`, `Pack(a, i, z)` / `Unpack(z, a, i)` (ISO array packing, `packed` is a no-op), `MaxInt` (the standard `2147483647` constant), and `Halt` (terminate the program from anywhere). Enumerated types (`type Color = (Red, Green, Blue)`) and named subranges (`type Index = 1..10`) write as their ordinals.

 **Strings**

`Length(s)`, `Concat(a, b, ...)`, `Copy(s, i, n)`, `Pos(sub, s)` (1-based; 0 if absent), `Val(s, v, code)`, `Str(x, s)`, `StrToInt(s)` (parse an integer string), `StringOfChar(c, n)`, the `+` concatenation operator, and full string comparison (`= <> < > <= >=`, with prefix ordering). `UpCase(ch)` uppercases an ASCII char; `Flush(output)` is a console no-op (output is line-flushed). String constants (`const G = 'Hi'`) work. `Str`/`Val` v1 handle Integer targets only; a single-char literal is a `Char`, so use 2+ char literals in string contexts. See `../../examples/strings.pas`.
