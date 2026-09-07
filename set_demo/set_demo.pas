library set_demo;

// `set of` demo (2026-08-21): bitmask sets over ordinal domains. A
// `set of Byte` is 8 i32 words (256 bits); a `set of 0..6` fits a single
// i32. Covers constructors ([1,3..5], []), the set ops + - * (union,
// difference, intersection), `in` membership, = <> equality, <= >= subset,
// and runtime elements.
//
// Sets need an address, so set variables must be GLOBALS (like arrays —
// the compiler has no stack-slot addressing for multi-word values).

type
  TWeek = set of 0..6;   // single-word set (7 bits)

var
  letters: set of Char;  // 8-word set (256 bits)
  week: TWeek;
  s, t, u: set of Byte;  // globals (set vars need an address)

procedure Demo;
begin
  writeln('set demo');
  writeln('---------');

  s := [1, 3, 5];
  t := [3, 4, 5, 6];
  u := s + t;                       // union: {1,3,4,5,6}
  writeln('3 in s       = ', 3 in s);
  writeln('2 in s       = ', 2 in s);
  writeln('6 in (s + t) = ', 6 in u);
  writeln('3 in (s * t) = ', 3 in (s * t));   // intersection {3,5}
  writeln('6 in (t - s) = ', 6 in (t - s));   // difference {4,6}
  writeln('s <= u       = ', s <= u);         // subset
  writeln('s = t        = ', s = t);

  week := [0, 2, 4, 6];             // single-word set
  writeln('6 in week    = ', 6 in week);
  writeln('week = [0,2,4,6] = ', week = [0, 2, 4, 6]);

  letters := ['A', 'C', 'G'];
  writeln('A in letters = ', 'A' in letters);
  writeln('B in letters = ', 'B' in letters);

  writeln('[] = []       = ', [] = []);       // two empty set constants
end;

begin
  Demo;
end.
