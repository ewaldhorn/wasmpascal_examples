# WasmPascal Examples

[![WasmPascal IDE](https://img.shields.io/badge/IDE-wasmpascal.com-2ea44f?style=flat&logo=webassembly&logoColor=white)](https://wasmpascal.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Pascal](https://img.shields.io/badge/Language-Pascal-blue)](https://wasmpascal.com/)
[![WebAssembly](https://img.shields.io/badge/Target-WebAssembly-654FF0?logo=webassembly&logoColor=white)](https://webassembly.org/)

[WasmPascal](https://wasmpascal.com/) is an online Pascal to Wasm compiler that runs entirely in your browser. The idea behind the project is that you just sometimes want to write some Wasm code, but getting the toolchain configured can be a real pain.

WasmPascal makes it possible to use the browser as the development platform for, well, the browser! Write Pascal code and compile it to a WebAssembly binary right in your browser. You can then download that binary from your browser to use as you please.

---

**Quick Navigation**

- [How to Run](#how-to-run-the-examples)
- [Repository Structure](#repository-structure)
- [Pascal Reference](#pascal-quick-reference)
- [Learn Pascal Tutorial](#learn-pascal-tutorial)
- [Examples](#examples)
- [Games](#games)
- [Blog Posts](#blog-posts)

---

## About This Repo

I want to make the examples in WasmPascal more accessible, and I also don't want to update the compiler every time I add a new example. So my plan is to, over time, put all the example programs in this repo, possibly with more and/or better documentation. WasmPascal has grown a bit beyond the quick experiment I originally intended, so bear with me as I get the supporting documentation in place!

> **Note:** Not all examples are working yet. The Pascal compiler is still being fine-tuned and a handful of examples may not behave as expected. Known issues are called out inline (e.g. `wasmtools` has an active compiler investigation underway).

## Repository Structure

| Folder | Contents |
|---|---|
| [`examples/`](examples/) | 48 standalone Pascal programs, demos, and games showcasing language syntax, standard units (`Crt`, math, strings), memory management, and HTML5 Canvas graphics. |
| [`games/`](games/) | Complete multi-file games — full Pascal source trees, hand-written browser host pages, and compiled `.wasm` binaries ready to serve. |
| [`docs/reference/`](docs/reference/) | 14 quick-reference guides covering types, control flow, host ABIs, directives, and compiler builtins. |
| [`docs/tutorial/`](docs/tutorial/) | 15-part "Learn Pascal" tutorial, from your first `writeln` to multi-file OOP architectures. |
| [`blog_posts/`](blog_posts/) | Runnable companion code and HTML test harnesses for articles published on [nofuss.co.za](https://nofuss.co.za/). |

## How to Run the Examples

### 1. In the WasmPascal Web IDE

The fastest way to try any example is directly in your browser at **[wasmpascal.com](https://wasmpascal.com/)**.

**Single-file examples** (e.g. `hello`, `basic_canvas`, `breakout`, `crt_demo`):
1. Open [wasmpascal.com](https://wasmpascal.com/).
2. Copy and paste the `.pas` code into the editor, or click **Upload files** on the toolbar.
3. Click **Run** (or press `Ctrl+Enter` / `Cmd+Enter`).

**Multi-unit projects** (`dugster`, `flightleader`, `sweep`):
1. Open [wasmpascal.com](https://wasmpascal.com/).
2. Click **Upload files** and select all `.pas` files in the example folder at once.
3. The editor automatically identifies the `program` file as root and loads the accompanying units (`uses`).
4. Click **Run**.

### 2. Running Blog Post Demos Locally

The [`blog_posts/`](blog_posts/) folder includes standalone HTML host pages that load WebAssembly modules. Because browsers restrict loading `.wasm` files over `file://`, you'll need a local HTTP server:

```bash
# Run from the repository root
python3 -m http.server 8080
```

Then open `http://localhost:8080/blog_posts/wasm_pascal_add_numbers/` (or any other subfolder) in your browser.

### 3. Running the Games

The projects in [`games/`](games/) are multi-unit builds, with two key differences: their root file is a `library` rather than a `program`, and they import host modules the IDE does not supply. They will compile in the IDE but won't run there — each game's README covers its IDE build steps, and [Games](#games) below explains how to serve one locally.

## Documentation

Quick-reference and tutorial docs ported from the WasmPascal web IDE help (`?`) and Learn overlays.

### Pascal Quick Reference

| Doc | Description |
|---|---|
| [Projects & files](docs/reference/01-projects-files.md) | How projects, files, the root unit, and the Files menu work in the IDE. |
| [Program structure](docs/reference/02-program-structure.md) | Program, library, and unit headers, uses clauses, exports, and external imports. |
| [Types](docs/reference/03-types.md) | Integer, float, boolean, char, pointer, record, array, string, set, object, and class types. |
| [Objects & classes](docs/reference/04-objects-classes.md) | TP7 objects and Delphi-style classes: inheritance, virtual dispatch, constructors. |
| [Declarations](docs/reference/05-declarations.md) | Constants, variables, types, procedures, and functions. |
| [Control flow](docs/reference/06-control-flow.md) | if, case, for, while, repeat, break, continue, exit, and with. |
| [Operators & precedence](docs/reference/07-operators-precedence.md) | Arithmetic, logical, bitwise, comparison, and set operators with precedence. |
| [Builtins](docs/reference/08-builtins.md) | Compiler builtins: Inc/Dec, math, strings, memory, Delay, GotoXY, Random, and more. |
| [Console I/O](docs/reference/09-console-i-o.md) | write/writeln, read/readln, field widths, and console input semantics. |
| [Colours (TextColor / TextBackground)](docs/reference/10-colours-textcolor-textbackground.md) | TextColor/TextBackground palette and RGB variants for colored console output. |
| [Directives](docs/reference/11-directives.md) | Compiler directives: mode, defines, conditionals, memory limits, screen size. |
| [Host ABIs (wasmpascal-specific)](docs/reference/12-host-abis-wasmpascal-specific.md) | How compiled programs talk to the browser: pascaldom, batchiness, canvas, console ABIs. |
| [Editor shortcuts & toolbar](docs/reference/13-editor-shortcuts-toolbar.md) | Keyboard shortcuts and toolbar actions in the web IDE. |
| [Acknowledgements & Credits](docs/reference/14-acknowledgements-credits.md) | Third-party components and credits. |

### Learn Pascal Tutorial

| Lesson | Description |
|---|---|
| [Start here](docs/tutorial/01-start-here.md) | What WasmPascal is and how to run your first program. |
| [Program structure](docs/tutorial/02-program-structure.md) | Headers, blocks, and your first writeln program. |
| [Values and types](docs/tutorial/03-values-and-types.md) | Integers, floats, booleans, and characters. |
| [Variables and constants](docs/tutorial/04-variables-and-constants.md) | Declaring and using variables and constants. |
| [Numbers: integer math](docs/tutorial/05-numbers-integer-math.md) | Integer arithmetic, div, mod, and precedence. |
| [Floats](docs/tutorial/06-floats.md) | Real numbers, float math, and conversions. |
| [Console I/O: write, readln](docs/tutorial/07-console-i-o-write-readln.md) | Printing output and reading input with readln. |
| [Control flow](docs/tutorial/08-control-flow.md) | Branching and looping: if, case, for, while, repeat. |
| [Procedures and functions](docs/tutorial/09-procedures-and-functions.md) | Splitting code into reusable procedures and functions. |
| [Records, arrays, and pointers](docs/tutorial/10-records-arrays-and-pointers.md) | Grouping data with records, arrays, and pointers. |
| [with and set of](docs/tutorial/11-with-and-set-of.md) | Simplifying record access and working with sets. |
| [Units and multi-file projects](docs/tutorial/12-units-and-multi-file-projects.md) | Splitting programs across files with units. |
| [Host ABIs and the console](docs/tutorial/13-host-abis-and-the-console.md) | How programs reach the browser: console, canvas, and events. |
| [Objects & classes](docs/tutorial/14-objects-classes.md) | Object-oriented Pascal: objects, classes, and inheritance. |
| [What next](docs/tutorial/15-what-next.md) | Where to go from here: examples to explore. |

## Examples

Looking for something specific? Here are all 48 examples organized by focus area:

### 🕹️ Arcade Games & Interactive Demos

| Example | Description |
|---|---|
| [breakout](examples/breakout/) | Full Breakout in 80×25 text mode using the `Crt` unit, with paddle physics, score, lives, and win/loss states. |
| [breakout_graphics](examples/breakout_graphics/) | The HTML5 Canvas version of Breakout with 60 fps batched rendering, synthesized Web Audio effects, and smooth physics. |
| [dugster](examples/dugster/) *(multi-unit)* | A complete multi-unit Dig Dug / Boulder Dash style game with procedural caverns, digging, rock gravity, and monster AI. |
| [flightleader](examples/flightleader/) *(multi-unit)* | A 3D wireframe flight combat game with modular units for vector math, batched rendering, particles, and flight physics. |
| [floaty_car](examples/floaty_car/) | Top-down arcade racer with a scrolling road grid, keyboard and touch steering, boost mechanics, and synthesized engine sounds. |
| [pascaloids](examples/pascaloids/) | Asteroids-style shooter with inertial ship physics, fracturing asteroids, batched Canvas2D rendering, and synthesized audio. |
| [pong](examples/pong/) | Complete real-time Pong with a player paddle, tracking AI, angle-based deflection, Web Audio effects, and 60 fps canvas rendering. |
| [runner](examples/runner/) | Endless runner platformer with procedural platforms, variable jump physics, parallax backgrounds, day-night transitions, and synth SFX. |
| [sweep](examples/sweep/) *(multi-unit)* | Complete multi-unit Minesweeper with seeded mine placement, flood-fill clearing, canvas rendering, and persistent high scores. |
| [xonix](examples/xonix/) | Faithful Xonix territory-capture port with trail carving, flood-fill capture logic, multi-level difficulty, and batched canvas rendering. |

### 🎨 HTML5 Canvas Graphics & Simulation

| Example | Description |
|---|---|
| [basic_canvas](examples/basic_canvas/) | Draws 2D graphics primitives (circles, lines, animated scanlines) directly on an HTML Canvas without JavaScript glue code. |
| [classic_dots](examples/classic_dots/) | A DOS-era screensaver updated for the web, using WasmPascal's Canvas extensions to animate graphics from Pascal. |
| [colors](examples/colors/) | Renders color gradients on the HTML5 canvas while printing colored text via `TextColor`/`TextBackground` — dual console plus canvas output. |
| [growable](examples/growable/) | Swap-remove particle pool where mouse-held spawns drift upward and fade, with constant-time removal and no heap churn. |
| [pascaldom_probe](examples/pascaldom_probe/) | Minimal diagnostic for the `pascaldom` DOM layer: acquires a canvas, paints it, and exports `pascaldom_main`. |
| [sparks](examples/sparks/) | Interactive mouse-aimed particle fountain with gravity and a fixed free-list pool for zero per-frame heap allocation. |
| [transforms](examples/transforms/) | Showcases the Canvas 2D transform stack (`save`, `restore`, `translate`, `rotate`, `scale`) with gears, orbits, and pulsating waves. |

### 🖥️ Virtual Console & Turbo Pascal `Crt`

| Example | Description |
|---|---|
| [crt_demo](examples/crt_demo/) | Recreates the Turbo Pascal 7 `Crt` environment in the browser: 16 classic text colors, `ClrScr`, and `GotoXY` placement. |
| [delay](examples/delay/) | Demonstrates non-blocking `Delay(ms)` pauses that safely block the Web Worker thread without freezing the browser UI. |
| [enhanced_colours](examples/enhanced_colours/) | Explores rich text-mode palettes with zigzagging color ramps and repeating colored banners on the virtual console. |
| [gotoxy](examples/gotoxy/) | Cursor positioning with `GotoXY` and screen clearing with `ClrScr` to draw borders and banners on the 80×25 terminal grid. |
| [guess](examples/guess/) | Classic number-guessing game using `readln`/`writeln` and a repeat-until loop — 7 tries to find the secret number. |
| [looped_fibonacci](examples/looped_fibonacci/) | Computes and formats Fibonacci numbers iteratively on an extended 80×50 text-mode screen. |
| [read_demo](examples/read_demo/) | Demonstrates interactive `readln` input for integers and floats, routed through browser dialogs by the Web Worker runtime. |
| [screen40](examples/screen40/) | Compact 40×10 virtual console via the `{$Screen 40 10}` directive, with cursor placement and text wrapping. |
| [shapes](examples/shapes/) | Draws text-mode geometric patterns (triangles, diamonds, bordered rectangles) on an 80×40 console using only `write`/`writeln`. |

### 🏛️ Memory & Object-Oriented Programming

| Example | Description |
|---|---|
| [alloc](examples/alloc/) | Heap allocation with `New`/`Dispose` and `GetMem`/`FreeMem` by building, traversing, and freeing a singly linked list. |
| [classes_demo](examples/classes_demo/) | Delphi-style classes with fields, methods, `Create` constructors, single inheritance, overrides, and heap lifetime management. |
| [heap_demo](examples/heap_demo/) | Shows heap growth inside a `{$M 64K}` limit by allocating 10 blocks step by step, then freeing them all. |
| [objects_demo](examples/objects_demo/) | Turbo Pascal 7 `object` types with constructors, virtual methods, inheritance via `inherited`, and stack plus heap semantics. |

### 🧱 Language Syntax & Data Structures

| Example | Description |
|---|---|
| [case_ranges_demo](examples/case_ranges_demo/) | Range expressions (`lo..hi`) in `case` statements, compiling dense spans to `br_table` jump tables and sparse spans to branches. |
| [enums](examples/enums/) | Enumerations and subranges as array indices, loop bounds, and `case` targets, with ordinal conversions and set operations. |
| [fibonacci](examples/fibonacci/) | Classic recursion and iteration benchmark, also highlighting Delphi-style inline ternary expressions. |
| [hello](examples/hello/) | Minimal Pascal `library` exporting `add` and `wasm_init` to the JavaScript host while also writing to standard output. |
| [hello_write](examples/hello_write/) | `write`/`writeln` output for strings, integers, floats, and newline control through the WebAssembly host. |
| [math](examples/math/) | Exercises the built-in math functions (`Sin`, `Cos`, `ArcTan`, `Ln`, `Exp`, `Sqrt`, `Round`, `Trunc`, `Abs`) on WebAssembly. |
| [multidim](examples/multidim/) | Multi-dimensional arrays including enum-indexed matrices, 3D cubes, nested traversal, and memory layout. |
| [ordinals](examples/ordinals/) | Ordinal built-ins `Ord`, `Chr`, `Pred`, `Succ`, `Odd`, and `Halt` for characters and enums. |
| [pointers](examples/pointers/) | Typed pointers (`^T`), `nil`, `SizeOf`, and pointer arithmetic with `Inc`/`Dec` across array elements. |
| [set_demo](examples/set_demo/) | `set of` types: constructors, union, difference, intersection, `in` membership, and subset and equality comparisons. |
| [strings](examples/strings/) | String concatenation, `Length`, `Copy`, `Pos`, `Str`/`Val` conversions, and fixed-length `String[n]` buffers. |
| [ternary](examples/ternary/) | Delphi-style inline ternary expressions (`if cond then a else b`) in assignments and arguments, with type promotion. |
| [typed_const_demo](examples/typed_const_demo/) | Initialized typed constants for records and arrays, compiled into the WebAssembly data section. |
| [unicode](examples/unicode/) | Unicode handling with raw UTF-8 literals, `#nn` and `#$hh` character codes, and adjacent literal concatenation. |
| [var_params_demo](examples/var_params_demo/) | Pass-by-reference with `var` parameters for in-place mutation of variables, record fields, and array elements. |
| [variants](examples/variants/) | Variant records (`case tag of`) as memory-efficient tagged unions, such as shape definitions. |
| [with_demo](examples/with_demo/) | The `with` statement for simplifying record field access, including chained scopes and shadowed-field resolution. |

### ⚠️ Work in Progress

| Example | Description |
|---|---|
| [wasmtools](examples/wasmtools/) | ⚠️ *Compiler investigation ongoing.* A PC Tools / Turbo Vision tribute with pulldown menus, dialog boxes, a directory browser, and an 80×25 terminal UI. |

## Games

Beyond the single-folder examples, this repo carries complete games: each is a full Pascal source tree that ships with its own hand-written browser host page and a compiled `.wasm` binary, ready to serve as a finished project rather than paste into the IDE.

| Game | Description |
|---|---|
| [mypaddock](games/mypaddock/) | A complete sheep-farming game — buy sheep, keep them fed and watered, hire farm hands, sell wool, and pay an upkeep bill that never stops growing — with a live simulation economy, a pixel-buffer canvas renderer, synthesized sound, and saves that survive reloads. |

### Running a Game

A game is three static files in one folder — `index.html`, `host.js`, and the compiled `.wasm` — with no build step and no server-side code. Serve the folder over HTTP and open it:

```bash
cd games/mypaddock
python3 -m http.server 8931
# then open http://localhost:8931/
```

Keep the three files together (the page fetches the `.wasm` from its own folder), and serve over HTTP(S) rather than `file://` — browsers refuse to load `.wasm` binaries from the filesystem. Any static host will do. Each game's README documents the IDE build process, the host import surface it requires, and its save format.

## Blog Posts

Runnable code from the WasmPascal blog posts (full Pascal sources plus their HTML host pages).

| Post | Code | Description |
|---|---|---|
| [Your First WebAssembly Module in Pascal with WasmPascal](https://nofuss.co.za/blog/wasm_pascal_add_numbers/) | [blog_posts/wasm_pascal_add_numbers/](blog_posts/wasm_pascal_add_numbers/) | Minimal `library` exporting `Add` to JavaScript (`adder.pas` + `index.html`). |
| [Processing CSV Files in WebAssembly with Pascal](https://nofuss.co.za/blog/wasm_pascal_csv_processing/) | [blog_posts/wasm_pascal_csv_processing/](blog_posts/wasm_pascal_csv_processing/) | Sorts `Name,Age` CSV rows by age in Wasm (`csvsort.pas` + `index.html`). |
| [Processing Large CSV Files in WebAssembly with Pascal](https://nofuss.co.za/blog/wasm_pascal_large_csv/) | [blog_posts/wasm_pascal_large_csv/](blog_posts/wasm_pascal_large_csv/) | Large-file CSV sorter with `{$M 128M}` memory and quicksort (`namesort.pas` + `index.html`). |
| [And then there was Pascal, on the web!](https://nofuss.co.za/blog/pascal_on_the_web/) | [blog_posts/pascal_on_the_web/](blog_posts/pascal_on_the_web/) | `crt_demo` colour-palette program (`crt_demo.pas`; no HTML listing in post). |
| [wasmpascal v0.4.0: Ternaries, Xonix, and more](https://nofuss.co.za/blog/wasmpascal_v040/) | [blog_posts/wasmpascal_v040/](blog_posts/wasmpascal_v040/) | `FibRec` before/after fragments for the new inline ternary (no full program or HTML listing in post). |
| [Flight! We have Flight!](https://nofuss.co.za/blog/flight_we_have_flight/) | [blog_posts/flight_we_have_flight/](blog_posts/flight_we_have_flight/) | Flight Leader 3D space-combat sim; multi-unit source lives in [examples/flightleader/](examples/flightleader/) (no Pascal listing in post). |
| [Building a Game Like Floaty in Pascal: Step by Step](https://nofuss.co.za/blog/building_floaty_car/) | [blog_posts/building_floaty_car/](blog_posts/building_floaty_car/) | Full `floaty_car.pas` endless-driver game (no HTML listing in post). |
| [wasmpascal v1.1.3: The Compiler Learns to Complain](https://nofuss.co.za/blog/wasmpascal_v113/) | [blog_posts/wasmpascal_v113/](blog_posts/wasmpascal_v113/) | Compiler diagnostics release; post holds only intentionally-rejected fragments (no runnable program). |
