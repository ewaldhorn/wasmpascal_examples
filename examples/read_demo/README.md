# Readln Demo

Demonstrates interactive console input using standard Pascal `readln` in [WasmPascal](https://wasmpascal.com/).

The program reads all three forms — `Integer`, `Single`, and `String` — through the `wasmpascal_env` `console_read_int` / `console_read_f64` / `console_read_str` host imports. A console program runs in the run worker and blocks on `Atomics.wait`, so the IDE shows an inline input line at the cursor and echoes the answer into the console grid, TP7 style; only the no-SharedArrayBuffer fallback (a host without COOP/COEP) uses `prompt()` dialogs on the main thread.

It also shows the TP7 write form: `f * 2.0:0:2` prints the value with two decimals and no padding.
