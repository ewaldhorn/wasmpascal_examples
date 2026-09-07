library unicode;

// Unicode in string literals — three ways:
//   1. Raw UTF-8: type the characters directly (works because the lexer is
//      byte-based and passes UTF-8 through untouched).
//   2. Character codes: #nn (decimal) or #$hh (hex) append a single byte;
//      a lone #nn element is a Char (TP7).
//   3. Adjacent elements concatenate into one string: 'Hello'#13#10'World'.
// Backslash is a LITERAL character (no C-style \n escapes); doubled quotes
// ('' or "") are an escaped quote.

procedure Demo;
begin
  writeln('=== Unicode strings ===');
  writeln;
  writeln('Raw UTF-8:');
  writeln('  Hello, wörld! 日本語 🎉');
  writeln;
  writeln('Character codes (#nn decimal, #$hh hex):');
  writeln('  '#65#66#67' decimal, '#$41#$42#$43' hex');
  writeln('  quote it''s, backslash \ is literal');
  writeln;
  writeln('Adjacent elements concatenate:');
  writeln('  Hello'#13#10'World');
  writeln;
  writeln('Field width with unicode:');
  writeln('  日本語':10);
  writeln('  done.');
end;

begin
  Demo;
end.