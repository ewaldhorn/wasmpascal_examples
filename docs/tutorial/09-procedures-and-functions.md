# Procedures and functions

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

Routines are declared before the `begin..end.` of the program (typically above the main block). A `function` declares its result type and assigns the result to its own name; a `procedure` returns nothing.

```pascal
library fns;

function Factorial(n: Integer): Integer;
var
  i, r: Integer;
begin
  r := 1;
  for i := 2 to n do r := r * i;
  Factorial := r;
end;

procedure Announce(n: Integer);
begin
  writeln('value is ', n);
end;

begin
  Announce(42);
  writeln('5! = ', Factorial(5));
end.
```

`var` parameters (declared `procedure P(var x: Integer)`) are passed by address and can be modified by the routine. The argument can be a global, an indexed element, a record field, a pointer deref, or a **local** — locals live in a per-call stack frame in linear memory, so they have a real address. Args must be type-identical lvalues (no `P(1+2)`). `exit` returns early from either kind of routine (optionally with a value: `exit(42)`). Strings work Pascal-side too: `string` vars/params are (addr,len) pairs — assign with `s := 'lit'`, print with `writeln(s)`, concatenate with `+`, pass by value or `var`; foreign functions get the pair as two `i32`s. Numeric `label`/`goto` (`label 10;` … `goto 10;`) work within a routine.

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
