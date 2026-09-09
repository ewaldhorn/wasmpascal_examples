# WasmPascal Examples

[![WasmPascal IDE](https://img.shields.io/badge/IDE-wasmpascal.com-2ea44f?style=flat&logo=webassembly&logoColor=white)](https://wasmpascal.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Pascal](https://img.shields.io/badge/Language-Pascal-blue)](https://wasmpascal.com/)
[![WebAssembly](https://img.shields.io/badge/Target-WebAssembly-654FF0?logo=webassembly&logoColor=white)](https://webassembly.org/)

[WasmPascal](https://wasmpascal.com/) is an online Pascal to Wasm compiler that runs entirely in your browser. The idea behind the project is that you just sometimes want to write some Wasm code, but getting the toolchain configured can be a real pain.

WasmPascal makes it possible to use the browser as the development platform for, well, the browser! Write Pascal code and compile it to a WebAssembly binary right in your browser. You can then download that binary from your browser to use as you please.

---

**Quick Navigation**:
[How to Run](#how-to-run-the-examples) • [Repository Structure](#repository-structure) • [Pascal Reference](#pascal-quick-reference) • [Learn Pascal Tutorial](#learn-pascal-tutorial) • [Examples](#examples) • [Blog Posts](#blog-posts)

---

## This Repo

I want to make the examples in WasmPascal more accessible, and I also don't want to update the compiler every time I add a new example. So my plan is to, over time, put all the example programs in this repo, possibly with more and/or better documentation. WasmPascal has grown a bit beyond the quick experiment I originally intended, so bear with me as I get the supporting documentation in place!

## Repository Structure

- **[`examples/`](examples/)**: 48 standalone Pascal programs, demos, and games showcasing language syntax, standard units (`Crt`, math, strings), memory management, and HTML5 Canvas graphics.
- **[`docs/`](docs/)**: Complete offline documentation ported directly from the WasmPascal web IDE:
  - **[`docs/reference/`](docs/reference/)**: 14 quick-reference guides covering types, control flow, host ABIs, directives, and compiler builtins.
  - **[`docs/tutorial/`](docs/tutorial/)**: 15-part "Learn Pascal" tutorial from your first `writeln` to multi-file OOP architectures.
- **[`blog_posts/`](blog_posts/)**: Runnable companion code and HTML test harnesses for articles published on [nofuss.co.za](https://nofuss.co.za/).

## How to Run the Examples

### 1. In the WasmPascal Web IDE

The fastest way to try any example is directly in your browser at **[wasmpascal.com](https://wasmpascal.com/)**:

- **Single-file examples** (e.g. `hello`, `basic_canvas`, `breakout`, `crt_demo`):
  1. Open [wasmpascal.com](https://wasmpascal.com/).
  2. Copy and paste the `.pas` code into the editor (or click **Upload files** on the toolbar).
  3. Click **Run** (or press `Ctrl+Enter` / `Cmd+Enter`).

- **Multi-unit projects** (`dugster`, `flightleader`, `sweep`):
  1. Open [wasmpascal.com](https://wasmpascal.com/).
  2. Click **Upload files** on the toolbar and select all `.pas` files in the example's folder at once.
  3. The editor automatically selects the `program` file as root and loads the accompanying units (`uses`).
  4. Click **Run**.

### 2. Running Blog Post Demos Locally

The [`blog_posts/`](blog_posts/) folder includes standalone HTML host pages that load WebAssembly modules. Because browsers restrict loading `.wasm` binaries over `file://`, start a local HTTP server:

```bash
# Run from repository root
python3 -m http.server 8080
```

Then visit `http://localhost:8080/blog_posts/wasm_pascal_add_numbers/` (or any other subfolder) in your browser.

## Caution

Not all of these examples are working. I am still fine-tuning the Pascal compiler and here and there some of the examples might not behave as expected. For example, wasmtools has some issue that I'm working on.

## Documentation

Quick-reference and tutorial docs ported from the WasmPascal web IDE help (`?`) and Learn overlays.

### Pascal quick reference

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

### Learn Pascal tutorial

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

Looking for something specific? Here are the 48 examples organized by focus area:

- 🕹️ **Arcade Games & Interactive Demos**:
  [`breakout`](examples/breakout/) • [`breakout_graphics`](examples/breakout_graphics/) • [`dugster`](examples/dugster/) • [`flightleader`](examples/flightleader/) • [`floaty_car`](examples/floaty_car/) • [`pascaloids`](examples/pascaloids/) • [`pong`](examples/pong/) • [`runner`](examples/runner/) • [`sweep`](examples/sweep/) • [`xonix`](examples/xonix/)
- 🎨 **HTML5 Canvas Graphics & Simulation**:
  [`basic_canvas`](examples/basic_canvas/) • [`classic_dots`](examples/classic_dots/) • [`colors`](examples/colors/) • [`growable`](examples/growable/) • [`pascaldom_probe`](examples/pascaldom_probe/) • [`sparks`](examples/sparks/) • [`transforms`](examples/transforms/)
- 🖥️ **Virtual Console & Turbo Pascal `Crt`**:
  [`crt_demo`](examples/crt_demo/) • [`delay`](examples/delay/) • [`enhanced_colours`](examples/enhanced_colours/) • [`gotoxy`](examples/gotoxy/) • [`guess`](examples/guess/) • [`looped_fibonacci`](examples/looped_fibonacci/) • [`read_demo`](examples/read_demo/) • [`screen40`](examples/screen40/) • [`shapes`](examples/shapes/)
- 🏛️ **Memory & Object-Oriented Programming**:
  [`alloc`](examples/alloc/) • [`classes_demo`](examples/classes_demo/) • [`heap_demo`](examples/heap_demo/) • [`objects_demo`](examples/objects_demo/)
- 🧱 **Language Syntax & Data Structures**:
  [`case_ranges_demo`](examples/case_ranges_demo/) • [`enums`](examples/enums/) • [`fibonacci`](examples/fibonacci/) • [`hello`](examples/hello/) • [`hello_write`](examples/hello_write/) • [`math`](examples/math/) • [`multidim`](examples/multidim/) • [`ordinals`](examples/ordinals/) • [`pointers`](examples/pointers/) • [`set_demo`](examples/set_demo/) • [`strings`](examples/strings/) • [`ternary`](examples/ternary/) • [`typed_const_demo`](examples/typed_const_demo/) • [`unicode`](examples/unicode/) • [`var_params_demo`](examples/var_params_demo/) • [`variants`](examples/variants/) • [`with_demo`](examples/with_demo/)
- ⚠️ **Work in Progress**:
  [`wasmtools`](examples/wasmtools/)

### All Examples

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
| [dugster](examples/dugster/) <br>*(multi-unit)* | A complete multi-unit Dig Dug / Boulder Dash style arcade game with procedural caverns, digging, rock gravity, and monster AI. |
| [enhanced_colours](examples/enhanced_colours/) | Explores rich text-mode palettes with zigzagging color ramps and repeating colored banners on the virtual console. |
| [enums](examples/enums/) | Demonstrates enumerations and subranges as array indices, loop bounds, and `case` targets, with ordinal conversions and set operations. |
| [fibonacci](examples/fibonacci/) | A classic recursion and iteration benchmark that also highlights Delphi-style inline ternary expressions. |
| [flightleader](examples/flightleader/) <br>*(multi-unit)* | A sophisticated 3D wireframe flight combat game built from modular units for vector math, batched rendering, particles, and flight physics. |
| [floaty_car](examples/floaty_car/) | A top-down arcade racing game with a scrolling road grid, keyboard and touch steering, boost mechanics, and synthesized engine sounds. |
| [gotoxy](examples/gotoxy/) | Demonstrates cursor positioning with `GotoXY` and screen clearing with `ClrScr` to draw borders and banners on the 80x25 terminal grid. |
| [growable](examples/growable/) | Demonstrates a swap-remove particle pool where mouse-held spawns drift upward and fade, with constant-time removal and no heap churn. |
| [guess](examples/guess/) | The classic number-guessing game using `readln`/`writeln` and a repeat-until loop, giving the player 7 tries to find the secret number. |
| [heap_demo](examples/heap_demo/) | Shows heap growth inside a constrained `{$M 64K}` limit by allocating 10 blocks step by step, then freeing them all. |
| [hello](examples/hello/) | A minimal Pascal `library` exporting `add` and `wasm_init` to the JavaScript host while also writing to standard output. |
| [hello_write](examples/hello_write/) | Demonstrates `write`/`writeln` output for strings, integers, floats, and newline control through the WebAssembly host. |
| [looped_fibonacci](examples/looped_fibonacci/) | Computes and formats Fibonacci numbers iteratively on an extended 80x50 text-mode screen. |
| [math](examples/math/) | Exercises the built-in math functions (`Sin`, `Cos`, `ArcTan`, `Ln`, `Exp`, `Sqrt`, `Round`, `Trunc`, `Abs`) on WebAssembly. |
| [multidim](examples/multidim/) | Demonstrates multi-dimensional arrays, including enum-indexed matrices, 3D cubes, nested traversal, and memory layout. |
| [objects_demo](examples/objects_demo/) | Demonstrates Turbo Pascal 7 `object` types with constructors, virtual methods, inheritance via `inherited`, and stack plus heap semantics. |
| [ordinals](examples/ordinals/) | Exercises the ordinal built-ins `Ord`, `Chr`, `Pred`, `Succ`, `Odd`, and `Halt` for characters and enums. |
| [pascaldom_probe](examples/pascaldom_probe/) | A minimal diagnostic for the `pascaldom` DOM layer that acquires a canvas, paints it, and exports `pascaldom_main`. |
| [pascaloids](examples/pascaloids/) | A full Asteroids-style shooter with inertial ship physics, fracturing asteroids, batched Canvas2D rendering, and synthesized audio. |
| [pointers](examples/pointers/) | Demonstrates typed pointers (`^T`), `nil`, `SizeOf`, and pointer arithmetic with `Inc`/`Dec` across array elements. |
| [pong](examples/pong/) | A complete real-time Pong game with a player paddle, tracking AI, angle-based deflection, Web Audio effects, and 60 fps canvas rendering. |
| [read_demo](examples/read_demo/) | Demonstrates interactive `readln` input for integers and floats, routed through browser dialogs by the Web Worker runtime. |
| [runner](examples/runner/) | An endless runner platformer with procedural platforms, variable jump physics, parallax backgrounds, day-night transitions, and synth sound effects. |
| [screen40](examples/screen40/) | Demonstrates a compact 40x10 virtual console via the `{$Screen 40 10}` directive, with cursor placement and text wrapping. |
| [set_demo](examples/set_demo/) | Explores `set of` types, covering constructors, union, difference, intersection, `in` membership, and subset and equality comparisons. |
| [shapes](examples/shapes/) | Draws text-mode geometric patterns like triangles, diamonds, and bordered rectangles on an 80x40 console using only `write`/`writeln`. |
| [sparks](examples/sparks/) | An interactive mouse-aimed particle fountain with gravity and a fixed free-list pool for zero per-frame heap allocation. |
| [strings](examples/strings/) | Demonstrates string concatenation, `Length`, `Copy`, `Pos`, `Str`/`Val` conversions, and fixed-length `String[n]` buffers. |
| [sweep](examples/sweep/) <br>*(multi-unit)* | A complete multi-unit Minesweeper engine and UI with seeded mine placement, flood-fill clearing, canvas rendering, and persistent high scores. |
| [ternary](examples/ternary/) | Demonstrates Delphi-style inline ternary expressions (`if cond then a else b`) in assignments and arguments, with type promotion. |
| [transforms](examples/transforms/) | Showcases the Canvas 2D transform stack (`save`, `restore`, `translate`, `rotate`, `scale`) with gears, orbits, and pulsating waves. |
| [typed_const_demo](examples/typed_const_demo/) | Demonstrates initialized typed constants for records and arrays, compiled into the WebAssembly data section. |
| [unicode](examples/unicode/) | Demonstrates Unicode handling with raw UTF-8 literals, `#nn` and `#$hh` character codes, and adjacent literal concatenation. |
| [var_params_demo](examples/var_params_demo/) | Demonstrates pass-by-reference with `var` parameters for in-place mutation of variables, record fields, and array elements. |
| [variants](examples/variants/) | Demonstrates variant records (`case tag of`) as memory-efficient tagged unions, such as shape definitions. |
| [wasmtools](examples/wasmtools/) <br>*(⚠️ WIP)* | ⚠️ *Work in progress (compiler investigation ongoing).* A PC Tools / Turbo Vision tribute with pulldown menus, dialog boxes, a directory browser, and an 80x25 terminal UI. |
| [with_demo](examples/with_demo/) | Demonstrates the `with` statement for simplifying record field access, including chained scopes and shadowed-field resolution. |
| [xonix](examples/xonix/) | A faithful Xonix territory-capture port with trail carving, flood-fill capture logic, multi-level difficulty, and batched canvas rendering. |

## Blog posts

Runnable code from the WasmPascal blog posts (full Pascal sources plus their HTML host pages).

| Post | Code | Description |
|---|---|---|
| [Your First WebAssembly Module in Pascal with WasmPascal](https://nofuss.co.za/blog/wasm_pascal_add_numbers/) | [blog_posts/wasm_pascal_add_numbers/](blog_posts/wasm_pascal_add_numbers/) | Minimal `library` exporting `Add` to JavaScript (`adder.pas` + `index.html`). |
| [Processing CSV Files in WebAssembly with Pascal](https://nofuss.co.za/blog/wasm_pascal_csv_processing/) | [blog_posts/wasm_pascal_csv_processing/](blog_posts/wasm_pascal_csv_processing/) | Sorts `Name,Age` CSV rows by age in Wasm (`csvsort.pas` + `index.html`). |
| [Processing Large CSV Files in WebAssembly with Pascal](https://nofuss.co.za/blog/wasm_pascal_large_csv/) | [blog_posts/wasm_pascal_large_csv/](blog_posts/wasm_pascal_large_csv/) | Large-file CSV sorter with `{$M 128M}` memory and quicksort (`namesort.pas` + `index.html`). |
| [And then there was Pascal, on the web!](https://nofuss.co.za/blog/pascal_on_the_web/) | [blog_posts/pascal_on_the_web/](blog_posts/pascal_on_the_web/) | `crt_demo` colour-palette program (`crt_demo.pas`; no HTML listing in post). |
| [wasmpascal v0.4.0: Ternaries, Xonix, and more](https://nofuss.co.za/blog/wasmpascal_v040/) | [blog_posts/wasmpascal_v040/](blog_posts/wasmpascal_v040/) | `FibRec` before/after fragments for the new inline ternary (no full program or HTML listing in post). |
