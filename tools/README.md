# tools/

Command-line front ends for the WasmPascal compiler that ships in [`docs/`](../docs/).

The compiler is a single WebAssembly module (`docs/wasmpascal.wasm`) with a very small
host surface, so it can be driven outside the browser. These scripts do that with plain
Node — no network, no dependencies, no toolchain.

| Script | Purpose |
|---|---|
| [`wpcompile.mjs`](wpcompile.mjs) | Compile Pascal source to a `.wasm` binary |
| [`wprun.mjs`](wprun.mjs) | Run a compiled console program in a terminal |

Requires **Node 18 or newer** (`node --version`). Everything runs offline.

## Why this is possible

The compiler module declares exactly two imports:

- `odin_env.write(fd, ptr, len)` — diagnostics (used only when something fails)
- `odin_env.rand_bytes(ptr, len)` — randomness

No WASI. No start section. It exports its memory and a small C-style API:
`wasmpascal_source_ptr`, `wasmpascal_compile`, `wasmpascal_output_ptr/len`,
`wasmpascal_diag_ptr/len`, `wasmpascal_add_unit`, `wasmpascal_clear_units`, plus
metadata (`wasmpascal_data_size`, `wasmpascal_heap_base`, `wasmpascal_screen_cols/rows`).

Supplying those two imports is the entire job of the host. For reference, the browser IDE
does the same thing in [`docs/worker.js`](../docs/worker.js).

## wpcompile

```bash
node tools/wpcompile.mjs <main.pas> [options]
```

Options:

- `-o, --out <file>` — output path (default `<main>.wasm` next to the source; `-` writes to stdout)
- `-I, --units-dir <dir>` — extra directory to search for units (repeatable)
- `--compiler <path>` — compiler module (default `docs/wasmpascal.wasm`)
- `--no-units` — do not follow `uses` clauses
- `-v, --verbose` — list resolved units and report timings
- `-h, --help`

Examples:

```bash
node tools/wpcompile.mjs examples/hello/hello.pas -o hello.wasm
node tools/wpcompile.mjs examples/dugster/dugster.pas -o dugster.wasm -v
cat hello.pas | node tools/wpcompile.mjs - -o - > hello.wasm
```

### Unit resolution

`uses` clauses are followed automatically. For each unit name, a matching `<unit>.pas` is
looked for next to the main file and in any `-I` directory, then that unit's own `uses`
clauses are followed in turn.

Names with no file on disk — `Crt`, `WEB`, `Math` — are compiler builtins and are skipped.
If a name is neither a file nor a known builtin, `wpcompile` says so and leaves it to the
compiler to accept or reject.

> **Compile the program, not its units.** A `unit foo;` file is not a root program: units in
> this compiler share one build scope, so a unit that calls into a sibling — even one its own
> `uses` clause does not name, and even with every sibling registered — cannot be compiled on
> its own. Point `wpcompile` at the file that declares `program`/`library` and uses it. When a
> compile fails on a file that declares `unit`, the tool says so explicitly.

> **Ordering matters inside the compiler**: units are staged through the same scratch
> buffer that holds the main source, so `wpcompile` adds every unit *before* writing the
> main program. Writing the main source first lets a unit silently overwrite it.

Diagnostics are printed verbatim to stderr, the exit status is non-zero on failure, and no
output file is written unless the compile succeeds.

## wprun

```bash
node tools/wprun.mjs <program.wasm> [options]
```

Options:

- `--allow-unimplemented` — stub browser-only imports instead of refusing to run
- `--no-color` — ignore `TextColor`/`TextBackground`/`TextColorRGB`
- `-h, --help`

Examples:

```bash
node tools/wprun.mjs hello.wasm
printf '64\n96\n112\n104\n108\n110\n109\n' | node tools/wprun.mjs guess.wasm
node tools/wprun.mjs breakout.wasm          # Escape or Ctrl-C to stop
```

### What it implements

The console half of the host ABI: `write`/`writeln`, `read`/`readln` (stdin),
`ReadKey`/`KeyPressed`, `ClrScr`, `GotoXY`, `TextColor`/`TextBackground` and the RGB
variants, `Delay`, `Randomize`, `Halt`, and the math imports.

- Colour and cursor movement become ANSI escapes, so the CRT-emulation examples look right
  in any modern terminal.
- Arrow keys are decoded into Turbo Pascal's extended `#0` + scan-code pairs (left 75,
  right 77, up 72, down 80) — the encoding `breakout.pas` and friends expect.
- **Escape stops the program**, matching the IDE, where Escape is the host's Stop button.
- `KeyPressed` is a genuine non-blocking poll.

### What it refuses

Programs that draw to a canvas or the DOM. The runner identifies the ABI from the compiled
program's exports, exactly as the IDE does (`pascaldom_main`, then `batchiness_main`, then
the `wasm_init`/`wasm_update`/`wasm_get_pixels` trio, else console). The pascaldom,
batchiness and basic_canvas ABIs are JS runtimes that need a real DOM — see
[`docs/standalone/`](../docs/standalone/) and
[the host ABI reference](../documentation/reference/12-host-abis-wasmpascal-specific.md).
Console programs are unaffected, and `--allow-unimplemented` will still run them (with no
visible graphics).

### Notes

- Piped input is read up front, which is what makes `KeyPressed` non-blocking and lets a
  scripted key sequence drive an interactive program. A terminal is driven byte by byte.
- Programs with unbounded loops (`breakout`, `wasmpascal`) run until you press Escape or
  Ctrl-C.
- A console program that ends in `Halt` stops on an `unreachable` trap — that is what the
  compiler emits for `Halt`, and the runner reports it as normal termination.

## Using another host

Nothing here is Node-specific. Any host that can define the two `odin_env` imports works:
the `wasmtime` crate, `wasmtime-py`, Wasmer, a Rust or Go embedder.

The bare **`wasmtime` CLI cannot** do it, because it has no way to define custom imports:

```
$ wasmtime run docs/wasmpascal.wasm
Error: failed to instantiate
    1: unknown import: `odin_env::rand_bytes` has not been defined
```

The `wasmtime` *library* is fine. Driving the compiler through `wasmtime-py` produces
output byte-identical to the Node host, because the compiler is deterministic — and
`rand_bytes` turns out never to be called during compilation at all.
