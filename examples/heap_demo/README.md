# Heap Monitor Demo

Demonstrates dynamic heap memory allocation and monitoring inside a constrained memory limit (`{$M 64K}`) in [WasmPascal](https://wasmpascal.com/).

The program sequentially allocates 10 memory blocks on the heap, pausing after each allocation so the live heap growth is visible in the status bar, then frees all allocated memory.
