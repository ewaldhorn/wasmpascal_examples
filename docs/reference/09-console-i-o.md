# Console I/O

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

``

```pascal
write(x:5);            // field width, right-aligned
writeln('hi', x);       // newline
readln(n);            // prompts in the browser
GotoXY(10, 5);         // position the cursor (1-based)
ClrScr;               // clear the screen
if KeyPressed then ch := ReadKey;  // poll keys
```

`write`/`writeln` accept strings, integers, floats, and `x:N` field widths (negative width left-aligns). A single-char literal (`write(' ')`, `Write('#')`) prints the character itself, not its ASCII code (TP7: `'Y'` is a `Char`). `read`/`readln` prompt once per scalar argument (integers or floats) via the browser's inline input line (or a dialog in fallback mode when the page isn't cross-origin-isolated).

**Keys (ReadKey / KeyPressed)** — while a console program runs, key presses are forwarded to it through the same input bridge as `read`/`readln`. `KeyPressed` is a non-blocking poll (safe in a game loop); `ReadKey` pops the next key and blocks when none are pending. Arrow keys arrive Turbo-Pascal-style as the extended pair `#0` + scan code (left `#75`, right `#77`, up `#72`, down `#80`), so check `if ch = #0 then ch := ReadKey;` — `'ArrowLeft'` alone is not a single code. Other single-char keys pass their char code, so `'a'`/`'A'`/`'d'`/`'D'` work as alternates. Escape is reserved for the host (Stop). See `../../examples/breakout.pas`, the first game built on this (its canvas twin is `../../examples/breakout_graphics.pas`, which moves the same game onto the batchiness canvas ABI with self-wired `keydown` listeners instead of the console key buffer).

`GotoXY(x, y)` moves the cursor to column `x` and row `y` (1-based, clamped to the screen size); `ClrScr` clears the screen and homes the cursor. All console output renders as a fixed character screen (Turbo Pascal style): 80×25 by default, or the size set by `{$Screen cols rows}` (e.g. `{$Screen 80 40}`). When output scrolls past the last row the top rows are discarded (no scrollback), and `GotoXY(1,1)` addresses the current top row. See `../../examples/gotoxy.pas`.

Strings are TP7-style: `'...'` or `"..."` (styles may mix between adjacent elements), doubled quotes (`''`/`""`) are an escaped quote, backslash is a LITERAL character (no C-style `\n` escapes), and char codes `#nn` (decimal) / `#$hh` (hex) concatenate with adjacent elements: `'Hello'#13#10'World'`, `#65#66#67`. Char codes are byte values 0..255 — a code past 255 is a compile error (no silent truncation). A lone `#0` is a Char (TP7, used for the extended ReadKey pair). Raw UTF-8 passes through.
