# Directives

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

`{$mode fpc}`, `{$inline on}`, `{$WARN n off}`, `{$R+}` / `{$R-}` range-checking switches, `{$Q/$B/$H}` switches, and `//` line comments are accepted. `{$R+}` is the default: subrange/enum values, array indices, set members, and conformant-array bounds are checked at runtime (an out-of-range value traps TP7 runtime error 201), and per-function `{$R-}` disables the checks. `{$IF expr}` / `{$FATAL msg}` / `{$ENDIF}` are evaluated by a mini preprocessor: `{$IF}` supports integer consts (from a prescanned `const` section), dec/hex literals, and `+ - * div mod and or xor ( ) < > <> <= >= = shl shr not`.

`{$M n}` sets the program's linear memory size: `{$M 32M}` (MiB), `{$M 512K}` (KiB), or `{$M 1048576}` (bytes). Default is 16 MiB; clamped to 64 KiB..4 GiB. The status bar's `RAM` readout shows the available total vs the static data used (globals + string literals), plus `· heap` when the program allocates. `GetMem`/`FreeMem`/`New`/ `Dispose` allocate from a heap after the static data (bump allocator with a free list; no coalescing). A bare `readln;` pauses until Enter is pressed. `{$Screen cols rows}` sets the text screen size (default 80×25), e.g. `{$Screen 80 40}`. Unknown `{$...}` directives are silently ignored.
