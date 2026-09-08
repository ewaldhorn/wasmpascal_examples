library math;

// Math builtins demo: exercises the full set of math functions the compiler
// emits as odin_env imports (JS Math.*). Each line shows the function, its
// argument(s), and the computed result. Compare against a calculator.

function Fmt(x: Double): Double;
begin
  // Round to 4 decimals so the grid stays tidy.
  Fmt := Trunc(x * 10000 + 0.5);
  Fmt := Fmt / 10000.0;
end;

procedure Demo;
var
  a, b: Double;
begin
  writeln('wasmpascal math builtins');
  writeln('------------------------');

  // Basic arithmetic
  a := 2.0;
  writeln('abs(-3.5)   = ', Fmt(abs(-3.5)));
  writeln('sqr(4)      = ', Fmt(sqr(4)));
  writeln('sqrt(2)     = ', Fmt(sqrt(2)));

  // Trig (radians)
  writeln('sin(0)      = ', Fmt(sin(0)));
  writeln('cos(0)      = ', Fmt(cos(0)));
  writeln('tan(0)      = ', Fmt(tan(0)));
  writeln('arctan(1)   = ', Fmt(arctan(1)), '  (pi/4)');
  writeln('arcsin(0.5) = ', Fmt(arcsin(0.5)));
  writeln('arccos(0.5) = ', Fmt(arccos(0.5)));
  writeln('arctan2(1,1)= ', Fmt(arctan2(1, 1)));

  // Hyperbolic
  writeln('sinh(1)     = ', Fmt(sinh(1)));
  writeln('cosh(1)     = ', Fmt(cosh(1)));
  writeln('tanh(1)     = ', Fmt(tanh(1)));

  // Exponential / log
  writeln('ln(e)       = ', Fmt(ln(exp(1))));
  writeln('exp(1)      = ', Fmt(exp(1)));
  writeln('power(2,10) = ', Fmt(power(2, 10)));
  writeln('log10(1000) = ', Fmt(log10(1000)));
  writeln('log2(8)     = ', Fmt(log2(8)));

  // Geometry helper
  writeln('hypot(3,4)  = ', Fmt(hypot(3, 4)));

  writeln('Done.');
end;

begin
  Demo;
end.
