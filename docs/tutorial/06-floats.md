# Floats

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

Floats get the usual arithmetic, plus the math builtins: `Sqrt`, `Sqr`, `Abs`, `Trunc`, `Round`, `Frac`, `Pi` (a bare `Pi` is a pre-defined `Double` constant; `Pi()` works too), trigonometry (`Sin`/`Cos`/`Tan`/ `ArcTan`…), and logs (`Ln`/`Exp`/`Log10`/ `Power`/`Hypot`). The trig/log ones are implemented by the host's `Math.*`, so they work everywhere.

```pascal
library floats;

var
  r, area: Double;

begin
  r := 2.5;
  area := 3.14159 * Sqr(r);   // Sqr is squares; Pi() is a builtin
  writeln('area of circle r=2.5 is ', area);
  writeln('sqrt(2) = ', Sqrt(2.0));
  writeln('trunc(3.7) = ', Trunc(3.7));
  writeln('round(3.7) = ', Round(3.7));
end.
```

Field widths pad the output — `write(x:5)` right-aligns `x` in 5 columns (lesson 7 covers it in more depth). Prefer `Double`/`Real` for floats you print: `Single` values print fine too, but mixing a `Single` into a `writeln` with other values is a codegen edge case, so keep printed floats `Double`. Floats print in the host's default format; very large or very small values use exponent notation.

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
