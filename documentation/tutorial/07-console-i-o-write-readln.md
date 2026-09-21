# Console I/O: write, readln

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

`write` prints text without a newline; `writeln` adds one. Both take any number of arguments. A field width `x:N` right-aligns the value in `N` columns (negative `N` left-aligns), handy for tables. `read`/`readln` read integers or floats, prompting once per argument.

```pascal
library console;

var
  n: Integer;
  f: Double;

begin
  write('Enter an integer: ');
  readln(n);
  write('Enter a float: ');
  readln(f);
  writeln('n + f = ', n + f);
  writeln('table:');
  writeln(1, n:6, f:8);
  writeln(2, n * 2:6, f * 2:8);
end.
```

Console output renders as a fixed character screen (Turbo Pascal style, 80×25 by default) in the output panel. When text reaches the last row the screen scrolls up; there is no scrollback. `readln` prompts via the browser's inline input (or a dialog in fallback mode) — this program blocks until you answer.

**Strings** behave like Turbo Pascal: string constants (`const G = 'Hi'`), `+` concatenation, full comparison (`= <> < >`, with prefix ordering), and the builtins `Length`, `Concat`, `Copy`, `Pos`, `Val`, `Str`, `StrToInt`, and `StringOfChar`. `UpCase(ch)` uppercases an ASCII char; `Flush(output)` is a no-op. A single-char literal is a `Char`, so string literals need two or more characters. Functions can return strings, including via `Exit('x')`.

```pascal
library strings2;

function greet: string;
begin
  greet := 'Hello';
end;

var
  s: string;

begin
  s := greet() + ', ' + 'World';
  writeln(s);                // Hello, World
  writeln(Length(s));          // 12
  writeln(Copy(s, 1, 5));    // Hello
  writeln(Pos('World', s));    // 8
  if 'abc' < 'abd' then writeln('lt');
  s := StringOfChar('*', 5);
  writeln(s);                // *****
end.
```

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
