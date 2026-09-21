# Variables and constants

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

A `var` is a name you can reassign; a `const` is a compile-time value you cannot. Declarations go in `var` and `const` sections (`type` sections come later).

```pascal
library vars;

const
  MAX = 100;

var
  score: Integer;
  ratio: Double;

begin
  score := 42;
  ratio := 3.5;
  writeln('Hi', ' score ', score);
  writeln('ratio ', ratio);
  writeln('MAX is ', MAX);
end.
```

`:=` is the assignment operator (a plain `=` is only for comparison). A `const` given a value at its declaration is inlined at compile time — you can use it in array bounds, `case` labels, and `{$IF}` preprocessor expressions. String *literals* work in `writeln` — single-quoted (`'text'`) or double-quoted (`"text"`, added 2026-08-19) — and are stored statically at compile time.

`writeln` accepts as many arguments as you like, separated by commas, and prints them one after another followed by a newline.

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
