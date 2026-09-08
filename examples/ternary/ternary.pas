library ternary;

// Ternary expressions (Delphi 13 style, 2026-08-26):
//   `if cond then a else b` used where an expression is expected.
// The condition must be Boolean; the two branches must be the same type.
// Numeric kinds promote (so `if c then 1 else 2.5` is Real) and STRINGS
// work too (`if c then 'yes' else 'no'` picks one string — a String[n] and
// dynamic String mix resolves to dynamic). Sets, records and arrays are NOT
// allowed. Only the taken branch runs (short-circuit), so a divide-by-zero
// or nil-deref in the untaken branch never executes.

function Max(a, b: Integer): Integer;
begin
  Max := if a > b then a else b;
end;

procedure Demo;
var
  n, score, grade: Integer;
  d: Double;
  label_text, mood: String;
begin
  writeln('ternary expression demo');
  writeln('-----------------------');

  // Basic form: assign the result of `if cond then a else b`.
  for n := 1 to 5 do
    writeln('n = ', n, ' -> ', if n mod 2 = 0 then 1 else 0, ' (1 = even, 0 = odd)');

  // Ternary inside a larger expression.
  score := 0;
  writeln('score starts at ', score, ', adds ', if score = 0 then 10 else 5);
  score := score + (if score = 0 then 10 else 5);
  writeln('score is now ', score);

  // Nested ternary: the inner `if` binds its own `else` (dangling-else safe).
  n := 7;
  grade := if n > 0 then 1 else if n < 0 then -1 else 0;
  writeln('sign of ', n, ' is ', grade, ' (1 = positive, -1 = negative, 0 = zero)');

  // Numeric promotion: an Integer branch and a Real branch promote to Real.
  d := if n > 0 then 1 else 2.5;
  writeln('d = ', d);

  // Ternary as a function argument.
  writeln('Max(3, 9) = ', Max(3, 9));

  // Char and Boolean branches work too.
  writeln('grade letter: ', if score >= 10 then 'A' else 'B');
  writeln('is score >= 10? ', if score >= 10 then 1 else 0);

  // STRING ternaries: pick one of two strings. Useful for building messages.
  label_text := if score >= 10 then 'pass' else 'fail';
  writeln('you ', label_text);
  mood := if n > 0 then 'positive' else 'negative';
  writeln('mood: ', mood);
  writeln('direct: ', if n > 0 then 'up' else 'down');
  writeln('concat: ', if n > 0 then 'super' else 'sub', '-string');

  // Short-circuit: the untaken branch is never evaluated, so this
  // divide-by-zero in the untaken branch is harmless.
  n := 0;
  writeln('safe: ', if 1 > 0 then 42 else 10 div n);
end;

begin
  Demo;
end.
