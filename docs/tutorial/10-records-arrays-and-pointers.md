# Records, arrays, and pointers

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

A `record` groups fields; a static `array` has fixed bounds; pointers (`^T`) hold addresses you take with `@` and follow with `p^`. Records and arrays nest, and indexed fields work like `balls[i].x`.

```pascal
library recs;

type
  TPoint = record
    x: Integer;
    y: Integer;
  end;
  TGrid = array [0..9] of Integer;

var
  p: TPoint;
  g: TGrid;
  i: Integer;

begin
  p.x := 3;
  p.y := 4;
  writeln('point ', p.x, ',', p.y);
  for i := 0 to 9 do g[i] := i * i;
  writeln('g[4] = ', g[4]);
end.
```

Records use FPC natural alignment for layout — relevant only when you reach past a record's fields into raw memory. `SizeOf(T)` / `SizeOf(v)` is a compile-time constant (`SizeOf(Integer)` = 4, `SizeOf(String)` = 8 — the (addr,len) pair model). `nil` is the null pointer (assign and compare with `=`/`<>`; the TP idiom `p <> 0` also works), and `Inc(p)`/`Dec(p, n)` move a typed pointer by whole elements — ideal for walking record arrays. A record can also carry **variants**: a `case tag: T of` part whose arms share storage, with an `else` arm as the default. Multi-dim arrays use the TP sugar `array[1..3, 1..4] of T` with `a[i, j]` indexing (equivalent to nested arrays). Integer literals can be hex (`$FF`) or binary (`%1010`), floats use scientific notation (`1e10`), and `MaxInt` is 2147483647.

```pascal
library recs2;

type
  TPair = record
    a, b: Integer;
  end;
  PPair = ^TPair;
  TShape = record
    case tag: Byte of
      0: (r: Single);
      1: (w, h: Single);
  end;

var
  arr: array[0..1] of TPair;
  p: PPair;
  s: TShape;

begin
  p := @arr[0];
  Inc(p);              // +8: one whole record
  p.a := 11;
  writeln(arr[1].a);      // 11
  writeln(SizeOf(TPair));  // 8
  s.tag := 1;
  s.w := 2.0;
  s.h := 3.0;
  writeln(s.w);            // 2
  writeln(SizeOf(s));       // 12
end.
```

For building games, look at the `basic_canvas.pas` example: it mixes arrays of records, `Byte` pixel buffers, and an RNG.

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
