# WasmPascal Examples

[WasmPascal](https://wasmpascal.com/) is an online Pascal to Wasm compiler that runs entirely in your browser. The idea behind the project is that you just sometimes want to write some Wasm code, but getting the toolchain configured can be a real pain.

WasmPascal makes it possible to use the browser as the development platform for, well, the browser! Write Pascal code and compile it to a WebAssembly binary right in your browser. You can then download that binary from your browser to use as you please.

## This Repo

I want to make the examples in WasmPascal more accessible, and I also don't want to update the compiler every time I add a new example. So my plan is to, over time, put all the example programs in this repo, possibly with more and/or better documentation. WasmPascal has grown a bit beyond the quick experiment I originally intended, so bear with me as I get the supporting documentation in place!

## Caution

Not all of these examples are working. I am still fine-tuning the Pascal compiler and here and there some of the examples might not behave as expected. For example, wasmtools has some issue that I'm working on.

## Examples

| Example | Description |
|---|---|
| [alloc](examples/alloc/) | Demonstrates heap allocation with `New`/`Dispose` and `GetMem`/`FreeMem` by building, traversing, and freeing a singly linked list of records. |
| [basic_canvas](examples/basic_canvas/) | Draws 2D graphics primitives like circles, lines, and animated scanlines directly on an HTML Canvas without JavaScript glue code. |
| [breakout](examples/breakout/) | A full Breakout arcade game rendered in 80x25 text mode using the `Crt` unit, with paddle physics, score, lives, and win/loss states. |
| [breakout_graphics](examples/breakout_graphics/) | The HTML5 Canvas version of Breakout with 60 fps batched rendering, synthesized Web Audio effects, and smooth ball and paddle physics. |
| [case_ranges_demo](examples/case_ranges_demo/) | Shows range expressions (`lo..hi`) in `case` statements, compiling dense spans to `br_table` jump tables and sparse spans to branches. |
| [classes_demo](examples/classes_demo/) | Demonstrates Delphi-style classes with fields, methods, `Create` constructors, single inheritance, overrides, and heap lifetime management. |
| [classic_dots](examples/classic_dots/) | A DOS-era style screensaver updated for the web, using WasmPascal's Canvas extensions to animate graphics from Pascal. |
| [colors](examples/colors/) | Renders color gradients on the HTML5 canvas while printing colored text via `TextColor`/`TextBackground`, showing dual console plus canvas output. |
| [crt_demo](examples/crt_demo/) | Recreates the Turbo Pascal 7 `Crt` environment in the browser, exercising the 16 classic text colors, `ClrScr`, and `GotoXY` placement. |
| [delay](examples/delay/) | Demonstrates non-blocking `Delay(ms)` pauses, which safely block the Web Worker thread without freezing the browser UI. |
| [dugster](examples/dugster/) | A complete multi-unit Dig Dug / Boulder Dash style arcade game with procedural caverns, digging, rock gravity, and monster AI. |
| [enhanced_colours](examples/enhanced_colours/) | Explores rich text-mode palettes with zigzagging color ramps and repeating colored banners on the virtual console. |
| [enums](enums/) | Demonstrates enumerations and subranges as array indices, loop bounds, and `case` targets, with ordinal conversions and set operations. |
| [fibonacci](fibonacci/) | A classic recursion and iteration benchmark that also highlights Delphi-style inline ternary expressions. |
| [flightleader](flightleader/) | A sophisticated 3D wireframe flight combat game built from modular units for vector math, batched rendering, particles, and flight physics. |
| [floaty_car](floaty_car/) | A top-down arcade racing game with a scrolling road grid, keyboard and touch steering, boost mechanics, and synthesized engine sounds. |
| [gotoxy](gotoxy/) | Demonstrates cursor positioning with `GotoXY` and screen clearing with `ClrScr` to draw borders and banners on the 80x25 terminal grid. |
| [growable](growable/) | Demonstrates a swap-remove particle pool where mouse-held spawns drift upward and fade, with constant-time removal and no heap churn. |
| [guess](guess/) | The classic number-guessing game using `readln`/`writeln` and a repeat-until loop, giving the player 7 tries to find the secret number. |
| [heap_demo](heap_demo/) | Shows heap growth inside a constrained `{$M 64K}` limit by allocating 10 blocks step by step, then freeing them all. |
| [hello](hello/) | A minimal Pascal `library` exporting `add` and `wasm_init` to the JavaScript host while also writing to standard output. |
| [hello_write](hello_write/) | Demonstrates `write`/`writeln` output for strings, integers, floats, and newline control through the WebAssembly host. |
| [looped_fibonacci](looped_fibonacci/) | Computes and formats Fibonacci numbers iteratively on an extended 80x50 text-mode screen. |
| [math](math/) | Exercises the built-in math functions (`Sin`, `Cos`, `ArcTan`, `Ln`, `Exp`, `Sqrt`, `Round`, `Trunc`, `Abs`) on WebAssembly. |
| [multidim](multidim/) | Demonstrates multi-dimensional arrays, including enum-indexed matrices, 3D cubes, nested traversal, and memory layout. |
| [objects_demo](objects_demo/) | Demonstrates Turbo Pascal 7 `object` types with constructors, virtual methods, inheritance via `inherited`, and stack plus heap semantics. |
| [ordinals](ordinals/) | Exercises the ordinal built-ins `Ord`, `Chr`, `Pred`, `Succ`, `Odd`, and `Halt` for characters and enums. |
| [pascaldom_probe](pascaldom_probe/) | A minimal diagnostic for the `pascaldom` DOM layer that acquires a canvas, paints it, and exports `pascaldom_main`. |
| [pascaloids](pascaloids/) | A full Asteroids-style shooter with inertial ship physics, fracturing asteroids, batched Canvas2D rendering, and synthesized audio. |
| [pointers](pointers/) | Demonstrates typed pointers (`^T`), `nil`, `SizeOf`, and pointer arithmetic with `Inc`/`Dec` across array elements. |
| [pong](pong/) | A complete real-time Pong game with a player paddle, tracking AI, angle-based deflection, Web Audio effects, and 60 fps canvas rendering. |
| [read_demo](read_demo/) | Demonstrates interactive `readln` input for integers and floats, routed through browser dialogs by the Web Worker runtime. |
| [runner](runner/) | An endless runner platformer with procedural platforms, variable jump physics, parallax backgrounds, day-night transitions, and synth sound effects. |
| [screen40](screen40/) | Demonstrates a compact 40x10 virtual console via the `{$Screen 40 10}` directive, with cursor placement and text wrapping. |
| [set_demo](set_demo/) | Explores `set of` types, covering constructors, union, difference, intersection, `in` membership, and subset and equality comparisons. |
| [shapes](shapes/) | Draws text-mode geometric patterns like triangles, diamonds, and bordered rectangles on an 80x40 console using only `write`/`writeln`. |
| [sparks](sparks/) | An interactive mouse-aimed particle fountain with gravity and a fixed free-list pool for zero per-frame heap allocation. |
| [strings](strings/) | Demonstrates string concatenation, `Length`, `Copy`, `Pos`, `Str`/`Val` conversions, and fixed-length `String[n]` buffers. |
| [sweep](sweep/) | A complete multi-unit Minesweeper engine and UI with seeded mine placement, flood-fill clearing, canvas rendering, and persistent high scores. |
| [ternary](ternary/) | Demonstrates Delphi-style inline ternary expressions (`if cond then a else b`) in assignments and arguments, with type promotion. |
| [transforms](transforms/) | Showcases the Canvas 2D transform stack (`save`, `restore`, `translate`, `rotate`, `scale`) with gears, orbits, and pulsating waves. |
| [typed_const_demo](typed_const_demo/) | Demonstrates initialized typed constants for records and arrays, compiled into the WebAssembly data section. |
| [unicode](unicode/) | Demonstrates Unicode handling with raw UTF-8 literals, `#nn` and `#$hh` character codes, and adjacent literal concatenation. |
| [var_params_demo](var_params_demo/) | Demonstrates pass-by-reference with `var` parameters for in-place mutation of variables, record fields, and array elements. |
| [variants](variants/) | Demonstrates variant records (`case tag of`) as memory-efficient tagged unions, such as shape definitions. |
| [wasmtools](wasmtools/) | A PC Tools / Turbo Vision tribute with pulldown menus, dialog boxes, a directory browser, and an 80x25 terminal UI. |
| [with_demo](with_demo/) | Demonstrates the `with` statement for simplifying record field access, including chained scopes and shadowed-field resolution. |
| [xonix](xonix/) | A faithful Xonix territory-capture port with trail carving, flood-fill capture logic, multi-level difficulty, and batched canvas rendering. |
