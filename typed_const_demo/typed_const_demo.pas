program typed_const_demo;
// Typed const demo — aggregate initializers for records and arrays.
// `const Name: Type = ( ... )` is an initialized global (not an inlined
// scalar): the compiler emits the bytes into static data and copies them
// on use. Also shows: string `+` with a Char variable, and `s[i]` indexing.

type
  TPoint = record
    x, y: Integer;
  end;
  TRec = record
    id: Integer;
    name: string[10];
  end;

const
  Origin: TPoint = (x: 10; y: 20);
  Scores: array[0..2] of Integer = (10, 20, 30);
  Names: array[0..1] of TPoint = ((x: 1; y: 2), (x: 3; y: 4));
  Info: TRec = (id: 42; name: 'hello');

var
  p: TPoint;
  c: Char;
  s: string;
  t: string[20];
  i: Integer;

begin
  writeln('--- typed const: record ---');
  writeln('Origin: ', Origin.x, ' ', Origin.y);
  p := Origin;
  writeln('p := Origin: ', p.x, ' ', p.y);

  writeln('--- typed const: arrays ---');
  writeln('Scores: ', Scores[0], ' ', Scores[1], ' ', Scores[2]);
  writeln('sum=', Scores[0] + Scores[1] + Scores[2]);
  writeln('Names[0]=', Names[0].x, ',', Names[0].y, ' Names[1]=', Names[1].x, ',', Names[1].y);

  writeln('--- typed const: record with string ---');
  writeln('Info.id=', Info.id, ' name=', Info.name, ' len=', Length(Info.name));

  writeln('--- string + Char variable ---');
  c := 'X';
  s := 'hello' + c;        // Char var coerced to 1-char string
  writeln('hello + X = ', s);
  s := c + ' world';
  writeln('X + world = ', s);
  s := s + c;
  writeln('again + X = ', s);

  writeln('--- string s[i] indexing ---');
  t := 'abcdef';
  writeln('t=', t, ' t[1]=', t[1], ' t[3]=', t[3]);
  writeln('Length(t)=', Length(t));

  writeln('--- typed const: whole-record copy ---');
  for i := 0 to 2 do writeln('Scores[', i, ']=', Scores[i]);
end.
