# Heap Allocation

Demonstrates dynamic memory allocation and pointer handling on the heap using standard Pascal `New` / `Dispose` and `GetMem` / `FreeMem`.

The program constructs a dynamic singly linked list of records on the heap, traverses the nodes, and systematically frees each one. This showcases the heap management and pointer ergonomics built into [WasmPascal](https://wasmpascal.com/), operating directly within a WebAssembly linear memory buffer.
