library hello_write;

// write/writeln demo: console output through the wasmpascal_env sink into the
// output panel. Exercises string / integer / float output and write vs
// writeln newline semantics.

procedure Demo;
var
  i: Integer;
begin
  writeln('Hello from wasmpascal!');
  writeln('Compiled and running entirely in the browser.');
  write('The answer is ');
  writeln(42);
  writeln('Counting:');
  for i := 1 to 5 do
    writeln('  ', i, ' squared is ', i * i);
  write('pi is ');
  writeln(3.14159);
  writeln('Done.');
end;

begin
  Demo;
end.
