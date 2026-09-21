{$Screen 80 50}
program looped_fibonacci;
uses Crt;

var i: longint;

function Fibonacci(n: longint): longint;
var a, b, t, j: longint;
begin
  if n = 0 then Fibonacci := 0
  else if n = 1 then Fibonacci := 1
  else
  begin
    a := 0; b := 1;
    for j := 2 to n do
    begin
      t := a + b;
      a := b;
      b := t;
    end;
    Fibonacci := b;
  end;
end;

begin
  Writeln("*** Calculating Fibonacci numbers, press ESC to abort ***");
  
  i := 0;
  repeat
    Write(i:4," : ");
    Writeln(Fibonacci(i):5);
    Delay(500);
    i := i + 1;
  until KeyPressed or (i > 40);

  Writeln;
  Writeln("Done!");
end.
