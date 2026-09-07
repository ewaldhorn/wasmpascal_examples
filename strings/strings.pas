program strings;
// M3 string-system demo: constants, concat (+ and Concat), comparison,
// Length/Copy/Pos/Val/Str/StringOfChar, and fixed-length String[n] buffers.
var
  s, s2: string;
  n, code: Integer;
  fixed: string[10];
begin
  // string constants + concatenation
  s := 'Hello';
  writeln(s + ', ' + 'World!');
  writeln('ab' + 'cd' + 'ef');
  // comparison (= <> < > <= >=), incl. prefix ordering
  if 'abc' = 'abc' then writeln('eq') else writeln('ne');
  if 'abc' < 'abd' then writeln('lt') else writeln('ge');
  if 'ab' < 'abc' then writeln('prefix-lt') else writeln('prefix-ge');
  s := 'hello';
  s2 := 'world';
  if s = s2 then writeln('same') else writeln('diff');
  if s < s2 then writeln('s-lt') else writeln('s-ge');
  // Length / Concat / Copy / Pos
  writeln(Length(s));
  writeln(Concat('ab', 'cd', 'ef'));
  writeln(Copy('abcdef', 2, 3));
  writeln(Pos('cd', 'abcdef'));
  writeln(Pos('zz', 'abcdef'));
  // Val / Str
  Val(' -42 ', n, code);
  writeln(n, ' ', code);
  Val('12x', n, code);
  writeln(code);
  Str(12345, s);
  writeln(s);
  // StringOfChar
  writeln(StringOfChar('*', 8));
  // fixed-length String[n]: truncates on store
  fixed := 'too long for ten';
  writeln(fixed);
  writeln(Length(fixed));
end.
