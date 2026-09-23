#!/usr/bin/env node
// wprun — offline CLI runner for WasmPascal *console* programs.
//
// Once a wasm binary's been compiled, we need a way to run it. CRT-based programs are actually
// console programs, so they should, in theory, work in most terminals. There's some challenges
// around ANSI escape codes etc. I try to provide a suitable runtime environment with this file
// for CRT programs, like good old DOS used to.
//
// Graphics programs (pascaldom / batchiness / game ABIs) should fail with a message.

import { readFileSync, readSync, writeSync } from 'node:fs';
import { basename } from 'node:path';
import { randomFillSync, randomInt } from 'node:crypto';

const decoder = new TextDecoder('utf-8');

// Synchronous writes: process.stdout may be an async pipe, and process.exit()
// would truncate buffered output. Writing to fd 1 directly avoids that entirely.
let outBytes = 0;
const out = (text) => { outBytes += Buffer.byteLength(text); writeSync(1, text); };
const err = (text) => writeSync(2, text);

// Modules that only exist as browser JS runtimes (see docs/standalone/).
const BROWSER_MODULES = new Map([
  ['pascaldom_env', 'DOM / canvas (pascaldom ABI)'],
  ['batch_env', 'canvas batch commands (batchiness ABI)'],
  ['app_env', 'game glue, user defined (scores, sound, thrust etc.)'],
]);

// ------------------------------------------------------------------------------------------------
// The IDE picks a runtime from the module's exports, not its imports. Same probe
// as docs/app.js, so `breakout` (console ABI) and `basic_canvas` (which imports
// nothing at all and is detected only by these exports) classify identically.
function detectAbi(module) {
  const names = WebAssembly.Module.exports(module).map((e) => e.name);
  if (names.includes('pascaldom_main')) return 'pascaldom';
  if (names.includes('batchiness_main')) return 'batchiness';
  if (names.includes('wasm_get_pixels') && names.includes('wasm_init') && names.includes('wasm_update')) return 'basic_canvas';
  return 'console';
}

// Console (CRT) support
// pascaldom_env.dom_now is just a clock and is safe to serve from the CLI.
const CONSOLE_SAFE_DOM = new Set(['dom_now']);

const CONSOLE_IMPORTS = new Set([
  'console_str', 'console_int', 'console_char', 'console_f64', 'console_float', 'console_nl',
  'console_color', 'console_color_rgba_fg', 'console_color_rgba_bg', 'console_gotoxy',
  'console_clrscr', 'console_key_pressed', 'console_read_key', 'console_read_int',
  'console_read_f64', 'console_read_str', 'random_seed', 'heap_report', 'delay',
]);

// Math support, notice the Odin roots?
// TODO: Clean up this ODIN_MATH thing to be decoupled
const ODIN_MATH = new Set([
  'sqrt', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'atan2', 'sinh', 'cosh', 'tanh',
  'ln', 'exp', 'log10', 'log2', 'hypot', 'pow',
]);

// ------------------------------------------------------------------------------------------------
function usage() {
  return `wprun — run a compiled WasmPascal console program on the command line.

Usage:
  node tools/wprun.mjs <program.wasm> [options]

Options:
      --allow-unimplemented  Stub browser-only imports instead of refusing (brittle!!!)
      --no-color             Ignore TextColor/TextBackground and RGB colour (for debugging)
  -h, --help                 This message

Implements the console host ABI: write/writeln, readln (stdin), ReadKey,
KeyPressed, ClrScr, GotoXY, TextColor/TextBackground, TextColorRGB, Delay,
Random/Randomize, and the Odin math imports.

Programs that need a DOM will fail, because those ABIs are JS runtimes that require a browser.

Exit status: 0 on success, 2 on usage/ABI error.`;
}

// ------------------------------------------------------------------------------------------------
function parseArgs(argv) {
  const opts = { program: null, allowUnimplemented: false, color: true };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '-h' || a === '--help') { writeSync(1, usage() + '\n'); process.exit(0); }
    else if (a === '--allow-unimplemented') opts.allowUnimplemented = true;
    else if (a === '--no-color') opts.color = false;
    else if (a.startsWith('-')) { err(`wprun: unknown option ${a}\n\n${usage()}\n`); process.exit(2); }
    else if (opts.program === null) opts.program = a;
    else { err(`wprun: unexpected argument ${a}\n\n${usage()}\n`); process.exit(2); }
  }
  if (opts.program === null) { err(usage() + '\n'); process.exit(2); }
  return opts;
}

// ------------------------------------------------------------------------------------------------
/**
  * TOTALLY A HACK
  * We remove the start section so the body does not run before we hold memory.
  *
  * Why?
  *
  * Because wasm binaries need to wait to be instantiated and all of that before their "main" can
  * run, and they could fire before everything is loaded, which breaks the whole chain.
  *
  * TODO: This feels like something I should be able to do upstream already.
  */
function stripStartSection(raw) {
  const out = [raw.subarray(0, 8)];
  let i = 8;
  let removed = false;
  while (i < raw.length) {
    const section = raw[i];
    let j = i + 1;
    let len = 0;
    let shift = 0;
    for (;;) {
      const b = raw[j++];
      len |= (b & 0x7f) << shift;
      shift += 7;
      if ((b & 0x80) === 0) break;
    }
    const end = j + len;
    if (section === 8) removed = true;
    else out.push(raw.subarray(i, end));
    i = end;
  }
  return removed ? Buffer.concat(out.map(Buffer.from)) : raw;
}

// ------------------------------------------------------------------------------------------------
// Terminal Support Section
const isTTY = Boolean(process.stdin.isTTY);
let rawMode = false;
let held = null;
const pending = []; // decoded Turbo Pascal key codes waiting for ReadKey, another hackity hack

// Piped input is slurped up front. That makes KeyPressed genuinely
// non-blocking and lets a scripted key sequence drive an interactive program.
const slurped = isTTY ? null : (() => { try { return readFileSync(0); } catch { return Buffer.alloc(0); } })();
let slurpPos = 0;

// ------------------------------------------------------------------------------------------------
function setRaw(on) {
  if (!isTTY || rawMode === on) return;
  try { process.stdin.setRawMode(on); } catch { /* unavailable */ }
  rawMode = on;
}

// Without this, a TTY read would block until a key arrives and KeyPressed
// could never answer "no key yet".
if (isTTY) { try { process.stdin._handle?.setBlocking(false); } catch { /* best effort */ } }

// ------------------------------------------------------------------------------------------------
function sleep(ms) {
  if (ms > 0) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

// ------------------------------------------------------------------------------------------------
/** byte, or null at EOF, or undefined when nothing is ready yet. */
function tryReadByte() {
  if (pending.length > 0) return pending.shift();
  if (held !== null) { const b = held; held = null; return b; }
  if (slurped !== null) return slurpPos < slurped.length ? slurped[slurpPos++] : null;
  const buf = Buffer.alloc(1);
  try {
    const n = readSync(0, buf, 0, 1, null);
    return n === 0 ? null : buf[0];
  } catch (e) {
    if (e.code === 'EAGAIN') return undefined;
    if (e.code === 'EOF') return null;
    throw e;
  }
}

// ------------------------------------------------------------------------------------------------
/** Blocking read; null at EOF. */
function readByte() {
  for (let i = 0; i < 200; i++) {
    const b = tryReadByte();
    if (b !== undefined) return b;
    sleep(5);
  }
  return null;
}

// ------------------------------------------------------------------------------------------------
/** Look one byte ahead, giving a TTY a short window to deliver it. */
function peekByte(waitMs) {
  const deadline = performance.now() + waitMs;
  for (;;) {
    const b = tryReadByte();
    if (b !== undefined) { held = b; return b; }
    if (performance.now() >= deadline) return undefined;
    sleep(5);
  }
}

// ------------------------------------------------------------------------------------------------
function keyAvailable() {
  if (pending.length > 0 || held !== null) return true;
  if (slurped !== null) return slurpPos < slurped.length;
  const b = tryReadByte();
  if (b === undefined || b === null) return false;
  held = b;
  return true;
}

// ------------------------------------------------------------------------------------------------
// ANSI final byte -> Turbo Pascal scan code for the extended #0 pair.
const ARROW_SCAN = { A: 72, B: 80, C: 77, D: 75, H: 71, F: 79 };

// ------------------------------------------------------------------------------------------------
/** Pops one key, decoding escape sequences into TP's #0 + scan-code pairs. */
function takeKey() {
  const b = readByte();
  if (b === null) return 0;
  if (b === 3) { err('\nwprun: stopped (Ctrl-C)\n'); throw EXIT; }
  if (b !== 0x1b) return b;
  // Escape is the host's Stop button; only a CSI/SS3 sequence means an arrow key.
  const next = peekByte(isTTY ? 40 : 0);
  if (next === 0x5b || next === 0x4f) {   // '[' or 'O'
    readByte();
    const code = readByte();
    const scan = code === null ? undefined : ARROW_SCAN[String.fromCharCode(code)];
    if (scan === undefined) return 0;
    pending.push(scan);                    // next ReadKey returns the scan code
    return 0;                              // this ReadKey returns #0
  }
  err('\nwprun: stopped (Escape)\n');
  throw EXIT;
}

// ------------------------------------------------------------------------------------------------
/**
 * One line of input, readln style. In canonical mode the terminal already
 * echoes what the user types; in raw mode nothing is echoed, matching ReadKey.
 */
function readLine() {
  setRaw(false);
  let line = '';
  for (;;) {
    const b = readByte();
    if (b === null || b === 0x0a || b === 0x0d) return line;
    line += String.fromCharCode(b);
  }
}

// ---- console formatting ---------------------------------------------------

// Character-cell widths, matching the IDE runtime (docs/worker.js displayWidth).
function displayWidth(cp) {
  if (cp >= 768 && cp <= 879) return 0; // combining marks
  if (
    (cp >= 4352 && cp <= 4447) || (cp >= 11904 && cp <= 42191) ||
    (cp >= 44032 && cp <= 55203) || (cp >= 63744 && cp <= 64255) ||
    (cp >= 65072 && cp <= 65103) || (cp >= 65281 && cp <= 65376) ||
    (cp >= 65504 && cp <= 65510) || (cp >= 127744 && cp <= 129791)
  ) return 2;
  return 1;
}

// ------------------------------------------------------------------------------------------------
function strWidth(s) {
  let w = 0;
  for (const ch of s) w += displayWidth(ch.codePointAt(0));
  return w;
}

// ------------------------------------------------------------------------------------------------
/** width > 0 right-aligns in `width` cells; width < 0 left-aligns (IDE semantics). */
function padField(text, width) {
  if (!width) return text;
  const w = strWidth(text);
  if (width > 0) return w >= width ? text : ' '.repeat(width - w) + text;
  return w >= -width ? text : text + ' '.repeat(-width - w);
}

// Turbo Pascal colour index -> ANSI SGR foreground.
const TP_COLORS = { 0: 30, 1: 34, 2: 32, 3: 36, 4: 31, 5: 35, 6: 33, 7: 37, 8: 90, 9: 94, 10: 92, 11: 96, 12: 91, 13: 95, 14: 93, 15: 97 };

// ------------------------------------------------------------------------------------------------
function rgbSgr(argb, code) {
  const v = argb >>> 0;
  return `\x1b[${code};2;${(v >>> 16) & 255};${(v >>> 8) & 255};${v & 255}m`;
}

// ---- run ------------------------------------------------------------------

const EXIT = Symbol('exit');

// ------------------------------------------------------------------------------------------------
async function main() {
  const opts = parseArgs(process.argv.slice(2));
  let bytes;
  try { bytes = readFileSync(opts.program); }
  catch (e) { err(`wprun: cannot read ${opts.program}: ${e.message}\n`); process.exit(2); }

  const module = await WebAssembly.compile(bytes);
  if (!WebAssembly.Module.exports(module).some((e) => e.kind === 'memory')) {
    err('wprun: this module does not export a memory; it is not a WasmPascal program\n');
    process.exit(2);
  }
  const abi = detectAbi(module);

  // Classify every import before instantiating anything.
  const neededBrowser = new Map();
  const unknownConsole = [];
  for (const imp of WebAssembly.Module.imports(module)) {
    if (BROWSER_MODULES.has(imp.module)) {
      if (imp.module === 'pascaldom_env' && CONSOLE_SAFE_DOM.has(imp.name)) continue;
      neededBrowser.set(imp.module, BROWSER_MODULES.get(imp.module));
    } else if (imp.module === 'wasmpascal_env' && !CONSOLE_IMPORTS.has(imp.name)) {
      unknownConsole.push(imp.name);
    } else if (imp.module === 'odin_env' && !(imp.name === 'write' || ODIN_MATH.has(imp.name))) {
      unknownConsole.push(`odin_env::${imp.name}`);
    }
  }

  if (abi !== 'console' && !opts.allowUnimplemented) {
    const what = {
      pascaldom: 'a DOM program (pascaldom ABI)',
      batchiness: 'a canvas program (batchiness ABI)',
      basic_canvas: 'a raw pixel-buffer program (basic_canvas ABI)',
    }[abi];
    err(`wprun: ${basename(opts.program)} is ${what}, not a console program.\n`);
    err('wprun: it draws to a canvas or DOM, so it needs a browser host — see docs/standalone/.\n');
    err('wprun: run it in the Web IDE or as an exported standalone app instead.\n');
    process.exit(2);
  }
  if (abi !== 'console') {
    err(`wprun: warning — ${abi} ABI detected; stubbing browser imports, so graphics will not render\n`);
  }

  if (neededBrowser.size > 0 && !opts.allowUnimplemented) {
    err(`wprun: ${basename(opts.program)} needs a browser host — it imports:\n`);
    for (const [mod, why] of neededBrowser) err(`  ${mod} — ${why}\n`);
    err('\nThese ABIs are supplied by the JS runtimes in docs/standalone/ and need a real DOM.\n');
    err('Run the program in the Web IDE or as an exported standalone app instead.\n');
    err('Console-only programs are unaffected by this restriction.\n');
    process.exit(2);
  }
  if (unknownConsole.length > 0 && !opts.allowUnimplemented) {
    err(`wprun: ${basename(opts.program)} needs host imports this runner does not implement:\n`);
    for (const n of unknownConsole) err(`  wasmpascal_env::${n}\n`);
    err('\nPass --allow-unimplemented to stub them (they will return 0).\n');
    process.exit(2);
  }
  for (const [mod] of neededBrowser) err(`wprun: warning — stubbing ${mod} imports (--allow-unimplemented)\n`);

  let memory = null;
  const mem = () => new Uint8Array(memory.buffer);
  const fallback = () => 0;

  const wasmpascalEnv = {
    console_str: (ptr, len, width) => out(padField(decoder.decode(mem().subarray(ptr, ptr + len)), width | 0)),
    console_int: (value, width) => out(padField(String(value | 0), width | 0)),
    console_char: (value, width) => out(padField(String.fromCharCode(value & 255), width | 0)),
    console_f64: (value, width) => out(padField(String(value), width | 0)),
    console_float: (value, prec, width) => {
      const p = Math.max(0, Math.min(100, prec | 0));
      out(padField(value.toFixed(p), width | 0));
    },
    console_nl: () => out('\n'),
    console_color: (value) => {
      if (!opts.color) return;
      const code = TP_COLORS[value & 15] ?? 0;
      out(`\x1b[${(value & 256) !== 0 ? code + 10 : code}m`);
    },
    console_color_rgba_fg: (argb) => { if (opts.color) out(rgbSgr(argb, 38)); },
    console_color_rgba_bg: (argb) => { if (opts.color) out(rgbSgr(argb, 48)); },
    console_gotoxy: (x, y) => out(`\x1b[${Math.max(1, y | 0)};${Math.max(1, x | 0)}H`),
    console_clrscr: () => out('\x1b[2J\x1b[H'),
    console_key_pressed: () => (keyAvailable() ? 1 : 0),
    console_read_key: () => {
      setRaw(true);
      const code = takeKey();
      setRaw(false);
      return code;
    },
    console_read_int: () => {
      const n = parseInt(readLine().trim(), 10);
      return Number.isFinite(n) ? n | 0 : 0;
    },
    console_read_f64: () => {
      const n = parseFloat(readLine().trim());
      return Number.isFinite(n) ? n : 0;
    },
    console_read_str: (ptr, max) => {
      const cap = max | 0;
      if (cap <= 0) return 0;
      const data = Buffer.from(readLine(), 'utf8').subarray(0, cap);
      mem().set(data, ptr);
      return data.length;
    },
    random_seed: () => randomInt(-0x80000000, 0x7fffffff) | 0,
    heap_report: () => {},
    delay: (ms) => sleep(ms | 0),
  };
  for (const name of unknownConsole) {
    if (!name.includes('::')) wasmpascalEnv[name] = fallback;
  }

  const odinEnv = {
    write: (fd, ptr, len) => (fd === 2 ? err : out)(decoder.decode(mem().subarray(ptr, ptr + len))),
    rand_bytes: (ptr, len) => randomFillSync(mem().subarray(ptr, ptr + len)),
    sqrt: Math.sqrt, sin: Math.sin, cos: Math.cos, tan: Math.tan,
    asin: Math.asin, acos: Math.acos, atan: Math.atan, atan2: Math.atan2,
    sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh,
    ln: Math.log, exp: Math.exp, log10: Math.log10, log2: Math.log2,
    hypot: Math.hypot, pow: Math.pow,
  };

  const importObject = {
    odin_env: odinEnv,
    wasmpascal_env: wasmpascalEnv,
    // dom_now is a page-relative clock (performance.now()); returning epoch
    // milliseconds overflows the program's f64->i32 seed cast and traps.
    pascaldom_env: new Proxy({ dom_now: () => performance.now() }, { get: (t, p) => (p in t ? t[p] : fallback) }),
    batch_env: new Proxy({}, { get: () => fallback }),
    app_env: new Proxy({}, { get: () => fallback }),
    env: { _haltproc: () => { throw EXIT; }, proc_exit: () => { throw EXIT; } },
  };

  // Programs put their body in a start section *and* in wasmpascal_init; the IDE
  // strips the former and calls the latter, so that memory is reachable first.
  const hasInit = WebAssembly.Module.exports(module).some((e) => e.name === 'wasmpascal_init');
  try {
    const { instance } = await WebAssembly.instantiate(hasInit ? stripStartSection(bytes) : bytes, importObject);
    memory = instance.exports.memory;
    if (hasInit) {
      instance.exports.wasmpascal_init();
    } else {
      err('wprun: note — no wasmpascal_init export; ran the module start section instead\n');
    }
  } catch (e) {
    // `Halt` compiles to `unreachable` (the IDE supplies env._haltproc, but an
    // unused external is dropped at link time). Treat it as normal termination.
    if (!(e instanceof WebAssembly.RuntimeError) || !/unreachable/i.test(e.message)) throw e;
    err('wprun: program stopped on an `unreachable` trap — this is what `Halt` compiles to.\n');
  }

  if (outBytes === 0) {
    err('wprun: note — the program wrote nothing to stdout. If this is a graphics\n');
    err('wprun: example, it belongs in a browser; console programs should print.\n');
  }
}

// ------------------------------------------------------------------------------------------------
main().then(
  () => { setRaw(false); process.exit(0); },
  (e) => {
    setRaw(false);
    if (e === EXIT) process.exit(0);
    err(`wprun: ${e && e.message ? e.message : e}\n`);
    process.exit(2);
  }
);
