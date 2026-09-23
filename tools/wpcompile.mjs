#!/usr/bin/env node
// wpcompile — offline CLI compiler for WasmPascal.
//
// We use the `wasmpascal.wasm` compiler, just like the online IDE does. Well, with just like,
// I mean we create a suitable host environment.
//
// You need a version of Node that handles Web Assembly properly, so anything from 18 onwards
// seem to have all the right functionality.
//
// The compiler module declares two required host imports:
//   odin_env.write(fd, ptr, len)   -> diagnostics
//   odin_env.rand_bytes(ptr, len)  -> randomness (I'm not sure this is used, it is planned though)
//
// It also exports the required touch points:
//  source buffer, compile, output, diag, add_unit
//
// It's just as used by the web IDE and needed to create the right runtime environment.

import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { dirname, resolve, basename, extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomFillSync } from 'node:crypto';

// ------------------------------------------------------------------------------------------------
const HERE = dirname(fileURLToPath(import.meta.url));
const DEFAULT_COMPILER = resolve(HERE, '..', 'docs', 'wasmpascal.wasm');

// Units the compiler provides itself; they are not files on disk, so skip them
const BUILTIN_UNITS = new Set(['crt', 'web', 'math', 'strings', 'sysutils', 'system', 'dos']);

const decoder = new TextDecoder('utf-8');
const encoder = new TextEncoder();

// ------------------------------------------------------------------------------------------------
function usage() {
  return `wpcompile — compile WasmPascal source to WebAssembly.

Usage:
  node tools/wpcompile.mjs <main.pas> [options]
  node tools/wpcompile.mjs - [options] < main.pas

Options:
  -o, --out <file>      Write the .wasm here (default: <main>.wasm; "-" = stdout)
  -I, --units-dir <dir> Extra directory to search for units (repeatable)
      --compiler <path> Compiler wasm (default: docs/wasmpascal.wasm)
      --no-units        Do not auto-resolve "uses" clauses
  -v, --verbose         Show resolved units, handy for debugging
  -h, --help            Help

Units named in a "uses" clause are resolved automatically: a matching <unit>.pas
is searched for next to the main file and in each --units-dir, recursively.
Compiler builtins are supposed to be skipped.

Exit status: 0 on success, 1 on compile error, 2 on usage/IO error.`;
}

// ------------------------------------------------------------------------------------------------
function parseArgs(argv) {
  const opts = { main: null, out: null, dirs: [], compiler: DEFAULT_COMPILER, units: true, verbose: false };

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '-h' || a === '--help') { console.log(usage()); process.exit(0); }
    else if (a === '-o' || a === '--out') opts.out = argv[++i];
    else if (a === '-I' || a === '--units-dir') opts.dirs.push(resolve(argv[++i]));
    else if (a === '--compiler') opts.compiler = resolve(argv[++i]);
    else if (a === '--no-units') opts.units = false;
    else if (a === '-v' || a === '--verbose') opts.verbose = true;
    else if (a.startsWith('-') && a !== '-') { console.error(`wpcompile: unknown option ${a}\n`); console.error(usage()); process.exit(2); }
    else if (opts.main === null) opts.main = a;
    else { console.error(`wpcompile: unexpected argument ${a}\n`); console.error(usage()); process.exit(2); }
  }

  if (opts.main === null) { console.error(usage()); process.exit(2); }

  return opts;
}

// ------------------------------------------------------------------------------------------------
/** Load a Pascal source file, or stdin when the argument is "-". */
function readSource(arg) {
  if (arg === '-') {
    try { return readFileSync(0, 'utf8'); }
    catch (err) { console.error(`wpcompile: cannot read source from stdin: ${err.message}`); process.exit(2); }
  }
  const p = resolve(arg);
  if (!existsSync(p)) { console.error(`wpcompile: no such file: ${arg}`); process.exit(2); }
  if (statSync(p).isDirectory()) { console.error(`wpcompile: ${arg} is a directory`); process.exit(2); }
  return readFileSync(p, 'utf8');
}

// ------------------------------------------------------------------------------------------------
/**
 * Comments that start a line with the word "uses" breaks my primitive parser.
 * So I strip comments out now by blanking them. That broke line numbers so now I also keep
 * the newlines so the line numbering doesn't break.
 *
 * TODO: I need to fix this upstream but my todo list is a km long already, this works for now.
 */
function stripComments(source) {
  const blank = (text) => text.replace(/[^\n]/g, ' ');
  let out = '';
  let i = 0;

  while (i < source.length) {
    const c = source[i];
    if (c === '{') {
      const end = source.indexOf('}', i);
      const stop = end === -1 ? source.length : end + 1;
      out += blank(source.slice(i, stop));
      i = stop;
    } else if (c === '(' && source[i + 1] === '*') {
      const end = source.indexOf('*)', i + 2);
      const stop = end === -1 ? source.length : end + 2;
      out += blank(source.slice(i, stop));
      i = stop;
    } else if (c === '/' && source[i + 1] === '/') {
      const end = source.indexOf('\n', i);
      const stop = end === -1 ? source.length : end;
      out += blank(source.slice(i, stop));
      i = stop;
    } else if (c === "'") {
      let j = i + 1; // Pascal escapes a quote by doubling it
      while (j < source.length) {
        if (source[j] === "'") {
          if (source[j + 1] === "'") { j += 2; continue; }
          j++;
          break;
        }
        j++;
      }
      out += source.slice(i, j);
      i = j;
    } else {
      out += c;
      i++;
    }
  }

  return out;
}

// ------------------------------------------------------------------------------------------------
/** Need to create a list of all the units this file uses */
function usesNames(source) {
  const names = [];
  const re = /^[ \t]*uses\b([\s\S]*?);/gim;
  let m;

  while ((m = re.exec(stripComments(source))) !== null) {
    for (const raw of m[1].split(',')) {
      const name = raw.replace(/\s+/g, '');
      if (name) names.push(name);
    }
  }

  return names;
}

// ------------------------------------------------------------------------------------------------
/** The name a file declares itself to be, when it is a unit rather than a root file. */
function unitName(source) {
  const m = /^[ \t]*unit[ \t]+([A-Za-z_][\w]*)[ \t]*;/im.exec(stripComments(source));
  return m ? m[1] : null;
}

// ------------------------------------------------------------------------------------------------
/**
 * Resolve the transitive closure of units needed by `source`, depth-first.
 * Returns { files: [{name, path, source}], builtins: [...], missing: [...] }.
 */
function resolveUnits(rootSource, searchDirs, verbose) {
  const files = [];
  const builtins = new Set();
  const missing = new Set();
  const seen = new Set();
  const dirs = [...searchDirs];

  // TODO: This is not ideal, need to harden this up a bit.
  // Case-insensitive lookup, so `uses Foo` finds `foo.pas` or `Foo.pas`. Bit brittle still.
  const cache = new Map();
  const findUnit = (name) => {
    for (const dir of dirs) {
      let listing = cache.get(dir);
      if (!listing) {
        try { listing = readdirSync(dir); } catch { continue; }
        cache.set(dir, listing);
      }
      const hit = listing.find((f) => f.toLowerCase() === `${name.toLowerCase()}.pas`);
      if (hit) return join(dir, hit);
    }
    return null;
  };

  const visit = (source, fromDir) => {
    if (dirs[dirs.length - 1] !== fromDir) dirs.unshift(fromDir);
    for (const name of usesNames(source)) {
      const key = name.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      if (BUILTIN_UNITS.has(key)) { builtins.add(name); continue; }
      const path = findUnit(name);
      if (!path) {
        // Not a file and not a known builtin: the compiler will error if it is
        // actually needed, so note it as missing and keep parsing. You can "use" units and then
        // never actually call anything from them. I've done it...
        missing.add(name);
        continue;
      }
      const text = readFileSync(path, 'utf8');
      files.push({ name: basename(path, extname(path)), path, source: text });
      if (verbose) console.error(`  unit: ${basename(path)}`);
      visit(text, dirname(path));
    }
  };

  visit(rootSource, searchDirs[0]);
  return { files, builtins: [...builtins], missing: [...missing] };
}

// ------------------------------------------------------------------------------------------------
/** Loads the compiler wasm binary and returns our wrapper. */
async function loadCompiler(compilerPath, verbose) {
  if (!existsSync(compilerPath)) {
    console.error(`wpcompile: compiler not found at ${compilerPath}`);
    console.error('  (expected docs/wasmpascal.wasm in this repo; use --compiler to override)');
    process.exit(2);
  }
  let memory = null;
  const importObject = {
    odin_env: {
      write: (fd, ptr, len) => {
        const text = decoder.decode(new Uint8Array(memory.buffer, ptr, len));
        (fd === 2 ? process.stderr : process.stdout).write(text);
      },
      rand_bytes: (ptr, len) => randomFillSync(new Uint8Array(memory.buffer, ptr, len)),
    },
  };
  const bytes = readFileSync(compilerPath);
  const { instance } = await WebAssembly.instantiate(bytes, importObject);
  memory = instance.exports.memory;
  const e = instance.exports;
  if (verbose) console.error(`compiler: ${basename(compilerPath)} (${bytes.length} bytes loaded)`);
  return {
    exports: e,
    clearUnits: () => { if (typeof e.wasmpascal_clear_units === 'function') e.wasmpascal_clear_units(); },
    addUnit: (name, source) => {
      const nameBytes = encoder.encode(name);
      const srcBytes = encoder.encode(source);
      // Both halves live in the shared source scratch buffer; the compiler copies
      // them out before returning, so the next call may reuse the same address.
      const at = e.wasmpascal_source_ptr();
      const view = new Uint8Array(e.memory.buffer);
      view.set(nameBytes, at);
      view.set(srcBytes, at + nameBytes.length);
      const rc = e.wasmpascal_add_unit(at, nameBytes.length, at + nameBytes.length, srcBytes.length);
      if (rc < 0) throw new Error(`add_unit(${name}) failed with ${rc}`);
    },
    compile: (source) => {
      const srcBytes = encoder.encode(source);
      const at = e.wasmpascal_source_ptr();
      new Uint8Array(e.memory.buffer, at, srcBytes.length).set(srcBytes);
      const n = e.wasmpascal_compile(at, srcBytes.length);
      const diagPtr = e.wasmpascal_diag_ptr();
      const diag = decoder.decode(new Uint8Array(e.memory.buffer, diagPtr, e.wasmpascal_diag_len()));
      if (n < 0) return { ok: false, diag };
      const out = new Uint8Array(n);
      out.set(new Uint8Array(e.memory.buffer, e.wasmpascal_output_ptr(), n));
      return {
        ok: true,
        diag,
        bytes: out,
        dataSize: e.wasmpascal_data_size(),
        heapBase: e.wasmpascal_heap_base(),
        screenCols: typeof e.wasmpascal_screen_cols === 'function' ? e.wasmpascal_screen_cols() : 0,
        screenRows: typeof e.wasmpascal_screen_rows === 'function' ? e.wasmpascal_screen_rows() : 0,
      };
    },
  };
}

// ------------------------------------------------------------------------------------------------
async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const source = readSource(opts.main);
  const fromStdin = opts.main === '-';
  const mainDir = fromStdin ? process.cwd() : dirname(resolve(opts.main));
  const searchDirs = [mainDir, ...opts.dirs.filter((d) => d !== mainDir)];

  if (opts.verbose) console.error(`compiling: ${fromStdin ? '<stdin>' : opts.main}`);

  const t0 = performance.now();
  const compiler = await loadCompiler(opts.compiler, opts.verbose);
  const tLoad = performance.now();

  const units = opts.units
    ? resolveUnits(source, searchDirs, opts.verbose)
    : { files: [], builtins: [], missing: [] };

  if (units.missing.length > 0) {
    console.error(`wpcompile: note — no file found for unit(s): ${units.missing.join(', ')}`);
    console.error('  (assumed to be compiler builtins; pass -I <dir> if they live elsewhere)');
  }
  if (opts.verbose && units.builtins.length > 0) {
    console.error(`  builtin units skipped: ${units.builtins.join(', ')}`);
  }

  compiler.clearUnits();
  // Units first: add_unit stages through the same scratch buffer that holds the
  // main source, so writing the main program last keeps it intact.
  for (const u of units.files) compiler.addUnit(u.name, u.source);

  const result = compiler.compile(source);
  const tDone = performance.now();

  if (!result.ok) {
    if (result.diag.trim()) process.stderr.write(result.diag.endsWith('\n') ? result.diag : result.diag + '\n');
    else console.error('wpcompile: compilation failed (no diagnostic produced)');
    // The overwhelmingly common cause is pointing the tool at a unit file
    // rather than the program that uses it.
    const unit = unitName(source);
    if (unit && opts.main !== '-') {
      console.error(`wpcompile: hint — ${basename(opts.main)} declares \`unit ${unit};\``);
      console.error('wpcompile: units are not root programs; compile the file that `uses` it instead.');
    }
    process.exit(1);
  }
  if (result.diag.trim()) process.stderr.write(result.diag);

  const outPath = opts.out === '-' ? null : (opts.out ?? (fromStdin ? 'out.wasm' : resolve(mainDir, basename(opts.main, extname(opts.main)) + '.wasm')));
  if (outPath === null) process.stdout.write(Buffer.from(result.bytes));
  else writeFileSync(outPath, result.bytes);

  if (outPath !== null || opts.verbose) {
    const target = outPath === null ? '<stdout>' : outPath;
    const ms = (tDone - t0).toFixed(0);
    const loadMs = (tLoad - t0).toFixed(0);
    const compileMs = (tDone - tLoad).toFixed(0);
    console.error(
      `wpcompile: ${basename(opts.main)} -> ${target} (${result.bytes.length} bytes` +
        `, ${units.files.length} unit(s), data=${result.dataSize}B, heapBase=${result.heapBase}` +
        (result.screenCols ? `, screen=${result.screenCols}x${result.screenRows}` : '') +
        `, ${ms}ms total / ${loadMs}ms load / ${compileMs}ms compile)`
    );
  }
}

// ------------------------------------------------------------------------------------------------
// I think this is how you catch really bad errors in Node?
// TODO: Check that I'm not missing errors or warnings somehow.
main().catch((err) => {
  console.error(`wpcompile: ${err && err.message ? err.message : err}`);
  process.exit(2);
});
