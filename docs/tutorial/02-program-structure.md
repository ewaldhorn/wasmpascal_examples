# Program structure

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

A program starts with a `program`/`library` header and ends with `end.` (the final dot). The `library` header is what the examples use; either works. The optional `uses` clause pulls in units registered with the host — more on that in lesson 12.

```pascal
library hello;

procedure Main;
begin
  writeln('Hello from wasmpascal!');
end;

begin
  Main;
end.
```

Statements live in `begin .. end` blocks. A `writeln(...)` prints a line of text, which is how this program talks to you — press Run and the output panel shows what it says.

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
