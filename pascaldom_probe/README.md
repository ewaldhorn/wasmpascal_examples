# PascalDOM Probe

A minimal diagnostic test harness for the `pascaldom` WebAssembly-to-DOM integration layer in [WasmPascal](https://wasmpascal.com/).

The program acquires a canvas element, creates a 2D rendering context, paints a solid color, and exports `pascaldom_main` to verify end-to-end host communication.
