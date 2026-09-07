# Case Statement Ranges

Demonstrates [WasmPascal](https://wasmpascal.com/)'s support for range expressions (`lo..hi`) inside `case` statements.

In this demo:
- Dense value spans compile to optimized WebAssembly jump tables (`br_table`).
- Sparse or wide spans fall back cleanly to conditional branches.
- Brings classic Turbo Pascal and Free Pascal range syntax directly to WebAssembly.
