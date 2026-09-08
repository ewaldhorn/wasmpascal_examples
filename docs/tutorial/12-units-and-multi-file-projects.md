# Units and multi-file projects

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

A **project** is a named set of Pascal files with one **root** (the file that gets compiled). Every other file is a `uses` **unit** — a file with a `unit Name;` header and `interface` / `implementation` sections. The root pulls them in with `uses`.

```pascal
library use_math;

uses u_math;

begin
  writeln('21 doubled is ', Twice(21));
end.
```

```pascal
unit u_math;

interface

function Twice(x: Integer): Integer;

implementation

function Twice(x: Integer): Integer;
begin
  Twice := x * 2;
end;

end.
```

The example above is a two-file project: the root `use_math.pas` `uses u_math;` and calls `Twice(21)`, and `u_math.pas` is the unit file that provides it — both are loaded into the project so the file dropdown shows them. (Note: avoid naming your own routines `Double` — the compiler treats that as the 64-bit float type.) The `+ File` button inserts a starter skeleton automatically. Units register with the host at run time and are deduped depth-first, so transitive `uses` just work. The `sweep.pas` example (minesweeper, 7 units) shows a real multi-file game.

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
