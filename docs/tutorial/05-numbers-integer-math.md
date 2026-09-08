# Numbers: integer math

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

The integer operators are `+` `-` `*` `div` (division) and `mod` (remainder). `div` is the *integer* division: it truncates, so `7 div 2` is `3`. A single slash `/` is *real* division and gives a float even from two integers.

```pascal
library intmath;

var
  total, n: Integer;

begin
  total := 0;
  for n := 1 to 10 do
    total := total + n;
  writeln('sum 1..10 = ', total);
  writeln('7 div 2 = ', 7 div 2);
  writeln('7 mod 3 = ', 7 mod 3);
  writeln('7 / 2   = ', 7 / 2);
end.
```

**Watch out:** unsigned `div`/`mod` need *both* operands unsigned. `Cardinal mod 100` is signed and can silently go negative. Use a power-of-two mask (`x and (RANGE - 1)`) for wrapping, as the examples do.

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
