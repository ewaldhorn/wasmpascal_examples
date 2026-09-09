# Processing CSV Files in WebAssembly with Pascal

Code from the blog post [Processing CSV Files in WebAssembly with Pascal](https://nofuss.co.za/blog/wasm_pascal_csv_processing/).

Sorts `Name,Age` CSV rows by age inside WebAssembly: JavaScript deposits raw bytes in the module's input buffer, Pascal parses, insertion-sorts (up to 512 records), and emits sorted CSV from the output buffer.

| File | Description |
|---|---|
| [csvsort.pas](csvsort.pas) | Full Pascal source. Paste into [WasmPascal](https://wasmpascal.com/), compile, and save as `csvsort.wasm`. |
| [index.html](index.html) | Host page with file picker, sample data, and download link. Place next to `csvsort.wasm` and serve with `python3 -m http.server`. |
