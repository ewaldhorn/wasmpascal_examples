library read_demo;

// readln demo: interactive console input via prompt() dialogs, routed through
// the wasmpascal_env console_read_int / console_read_f64 host imports.

var
  a, b: Integer;
  f: Single;

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
  writeln('f * 2 = ', f * 2.0);
  writeln('=== done ===');
end.
