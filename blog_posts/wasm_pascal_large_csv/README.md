# Processing Large CSV Files in WebAssembly with Pascal

Code from the blog post [Processing Large CSV Files in WebAssembly with Pascal](https://nofuss.co.za/blog/wasm_pascal_large_csv/).

Scales the CSV sorter to large files (e.g. 10 MB / 300k+ rows): 128 MB of linear memory via `{$M 128M}`, zero-copy 12-byte index records over the input buffer, and in-place quicksort.

| File | Description |
|---|---|
| [namesort.pas](namesort.pas) | Full Pascal source. Paste into [WasmPascal](https://wasmpascal.com/), compile, and save as `namesort.wasm`. |
| [index.html](index.html) | Host page with drag-and-drop upload and sorted-CSV download. Place next to `namesort.wasm` and serve with `python3 -m http.server`. |
