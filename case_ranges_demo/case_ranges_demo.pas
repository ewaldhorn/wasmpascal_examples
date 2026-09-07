library case_ranges_demo;

// `case` with lo..hi RANGE arms (2026-08-21): each arm can list single
// values and ranges. Dense spans dispatch via br_table; very wide or sparse
// spans fall back to an if-chain. Use to group contiguous values:

function Rank(x: Integer): Integer;
begin
  case x of
    0..4:        Rank := 1;   // tiny
    5..10:       Rank := 2;   // small
    11, 15..20:  Rank := 3;   // medium — mixed singles + ranges
    21..99:      Rank := 4;   // large
    else         Rank := 9;
  end;
end;

procedure Show(x: Integer);
var
  r: Integer;
begin
  r := Rank(x);
  write(x:3, ' -> ');
  case r of
    1: writeln('tiny');
    2: writeln('small');
    3: writeln('medium');
    4: writeln('large');
    else writeln('?');
  end;
end;

procedure Demo;
var
  i: Integer;
begin
  writeln('case range demo');
  writeln('---------------');
  for i := 0 to 12 do
    Show(i);
  Show(17);
  Show(18);
  Show(50);
  Show(150);
end;

begin
  Demo;
end.
