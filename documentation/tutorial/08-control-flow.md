# Control flow

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

Conditions go in parentheses; the statement after a condition or loop is the body (use `begin..end` to group several). `break`/`continue` work in the innermost loop; `exit` leaves the current routine (optionally with a value, `exit(42)`).

```pascal
library control;

var
  i: Integer;

begin
  for i := 1 to 10 do
  begin
    if i mod 3 = 0 then continue;   // skip multiples of 3
    if i > 7 then break;             // stop at 8
    write(i, ' ');
  end;
  writeln;
  case 42 of
    1, 2, 3: writeln('small');
    41, 42, 43: writeln('medium');
  else writeln('large');
  end;
  repeat
    writeln('Looping under repeat...until');
    i := i - 1;
  until i < 0;
end.
```

`case` takes `case expr of` with `;`-separated arms, each a comma-separated list of values **or lo..hi ranges** (`0..4`) followed by `:` and a statement, then `end`. An `else` arm catches everything else. Dense ranges dispatch via `br_table`; very wide or sparse spans fall back to an if-chain, so both styles behave the same. A `for` loop's counter runs *from* to *to* inclusive; the step runs at the top, so `continue` inside always advances it.

**Ternary expressions** (Delphi 13 style): `if cond then a else b` used where an expression is expected — an assignment, a call argument, or inside a larger expression. The condition must be Boolean and the two branches must be the same type (numeric kinds promote, so `if c then 1 else 2.5` is Real); **strings work too** — the picked string becomes the result; sets, records and arrays are not allowed. Only the taken branch runs (short-circuit), so a divide-by-zero or nil-deref in the untaken branch never executes. Nested ternaries are dangling-else safe: the inner `if` binds its own `else`.

```pascal
library ternary;

function Min(a, b: Integer): Integer;
begin
  Min := if a < b then a else b;
end;

procedure Demo;
var
  n, score: Integer;
  d: Double;
  label_text: String;
begin
  for n := 1 to 4 do
  begin
    score := if n mod 2 = 0 then 1 else 0;  // 1 = even
    writeln('n = ', n, ' parity = ', score);
  end;
  score := 0;
  score := score + (if score = 0 then 10 else 5);
  writeln('score = ', score);
  d := if score > 5 then 1 else 2.5;   // int + Real -> Real
  writeln('d = ', d);
  writeln('Min(3, 9) = ', Min(3, 9));
  label_text := if score = 10 then 'ten' else 'other';  // string ternary
  writeln('word = ', label_text);
  writeln(if score > 5 then 'big' else 'small');
end;

begin
  Demo;
end.
```

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
