library with_demo;

// `with` statement demo (2026-08-21): opens a record-member scope so bare
// field names resolve to the record's fields without writing `r.` every time.
// Covers: bare field reads/writes through `with`, `Inc`, comma chains
// (`with a, b do` — the INNERMOST record wins for overlapping names), and
// nested records (`with r do` where `a`/`b` are record fields).

type
  TPoint = record
    x: Integer;
    y: Integer;
  end;
  TRect = record
    a: TPoint;
    b: TPoint;
  end;

var
  rect: TRect;
  a: TPoint;
  b: TPoint;

procedure Demo;
var
  p: TPoint;
  s: Integer;
begin
  writeln('with statement demo');
  writeln('-------------------');

  // plain record field access via `with`
  p.x := 10;
  p.y := 20;
  with p do
  begin
    s := x + y;          // 30 — bare x/y resolve to p.x/p.y
    x := 11;             // write through the with-scope
    Inc(y);              // 21
  end;
  writeln('p: x=', p.x, ' y=', p.y, '  s=', s);

  // nested records: `with rect do` then dig into a and b
  with rect do
  begin
    a.x := 3;
    a.y := 4;
    b.x := 5;
    b.y := 6;
  end;
  writeln('rect.a= (', rect.a.x, ',', rect.a.y, ') rect.b= (', rect.b.x, ',', rect.b.y, ')');

  // comma chain: innermost (b) wins for x/y
  a.x := 100;
  a.y := 200;
  b.x := 7;
  b.y := 8;
  with a, b do
    s := x + y;          // 7 + 8 = 15 (both from b)
  writeln('comma chain x+y = ', s, '  (innermost record wins)');

  writeln('Done.');
end;

begin
  Demo;
end.
