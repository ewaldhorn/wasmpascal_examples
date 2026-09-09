# Your First WebAssembly Module in Pascal

Code from the blog post [Your First WebAssembly Module in Pascal with WasmPascal](https://nofuss.co.za/blog/wasm_pascal_add_numbers/).

A minimal WasmPascal `library` exporting a single `Add(a, b: Integer)` function to JavaScript.

| File | Description |
|---|---|
| [adder.pas](adder.pas) | Full Pascal source. Paste into [WasmPascal](https://wasmpascal.com/), compile, and save as `adder.wasm`. |
| [index.html](index.html) | Host page that loads `adder.wasm` and calls `Add(3, 4)`. Place next to `adder.wasm` and serve with `python3 -m http.server`. |
