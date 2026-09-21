# with and set of

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

`with <record> do` lets you address a record's fields by their bare names for the duration of one statement (or a `begin..end` block) — handy when a record has many fields. Comma chains (`with a, b do`) nest, with the *innermost* record winning for overlapping names; a `with` scope also shadows a same-named global. Locals and parameters always shadow `with` fields.

```pascal
library withset;

type
  TPoint = record
    x, y: Integer;
  end;

var
  p: TPoint;
  flags: set of 0..7;

begin
  with p do
  begin
    x := 3;          // p.x := 3
    y := 4;          // p.y := 4
  end;
  writeln('p = (', p.x, ',', p.y, ')');

  flags := [1, 3, 5];
  writeln('3 in flags   = ', 3 in flags);
  writeln('2 in flags   = ', 2 in flags);
  flags := flags + [2];             // union
  flags := flags - [1];             // difference
  writeln('2 in flags   = ', 2 in flags);
  writeln('1 in flags   = ', 1 in flags);
end.
```

A `set of <ordinal>` is a bitmask: a domain that fits in 32 bits (`0..6`, `0..31`) is a single integer; `set of Byte` uses 8 words. Operators: `+` union, `-` difference, `*` intersection, `in` membership, `=` / `<>` equality, `<=` / `>=` subset/superset. Constructors look like `[1, 3..5]` or `[]` (empty). Set variables must be **globals** — like arrays, they need an address, and the compiler rejects local sets. See `../../examples/set_demo.pas`.

`case` arms can also use lo..hi **ranges**: `case x of 0..4: ...; else ... end;` groups contiguous values in one arm (dense ranges use `br_table`, wide or sparse ones degrade to an if-chain — same behavior). See `../../examples/case_ranges_demo.pas`.

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
