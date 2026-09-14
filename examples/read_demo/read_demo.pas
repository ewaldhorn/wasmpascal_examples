library read_demo;

// readln demo: interactive console input through the wasmpascal_env
// console_read_int / console_read_f64 / console_read_str host imports. A
// console program runs in the run worker and blocks on Atomics.wait, so the
// IDE shows an inline input line at the cursor (the answer is echoed into the
// grid, TP7 style); only the no-SharedArrayBuffer fallback (a host without
// COOP/COEP) uses prompt() dialogs on the main thread.
//
// ALL THREE READ FORMS are here on purpose: Integer, Single and String go
// through three different imports, and the string one is the one that had no
// host implementation for as long as the feature existed — every shipping host
// (IDE main thread, IDE worker, both standalone runtimes) was missing
// `console_read_str`, so `readln(name)` compiled and then failed to start.
// Nothing caught it because no example read a string (docs/features.md
// §10.54); this file does now, and standalone_test.js drives it on both the
// worker and the prompt paths.

var
  a, b: Integer;
  f: Single;
  name: String;

begin
  writeln('=== readln demo ===');
  write('Enter an integer for a: ');
  readln(a);
  write('Enter an integer for b: ');
  readln(b);
  writeln('a + b = ', a + b);
  writeln('a * b = ', a * b);
  write('Enter a float: ');
  readln(f);
  // f * 2.0:0:2 is the TP7 write form — width 0 means "no padding", 2 means
  // two decimals — and it is the one import every host was missing too
  // (`console_float`, docs/features.md §10.54). One line, three hosts, all of
  // them silent.
  writeln('f * 2 = ', f * 2.0:0:2);
  write('Enter your name: ');
  readln(name);
  writeln('Hello, ', name, '!');
  writeln('=== done ===');
end.
