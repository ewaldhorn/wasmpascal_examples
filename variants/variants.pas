program variants;
// M5: record variants — case tag of inside a record (TP7 form + else arm).
type
  TShape = record
    kind: Integer;
    case tag: Byte of
      0: (r: Single);          // circle: radius
      1: (w, h: Single);       // rect: width, height
  end;
  TThing = record
    case tag: Byte of
      0: (b: Byte);
      1: (w: Word);
      else (x: Integer);       // default arm
  end;
var
  s: TShape;
  t: TThing;
begin
  // write through the circle arm
  s.kind := 0;
  s.tag := 0;
  s.r := 2.5;
  writeln(s.kind);
  writeln(s.r);
  // write through the rect arm — the union reuses the same storage
  s.tag := 1;
  s.w := 3.0;
  s.h := 4.0;
  writeln(s.w);
  writeln(s.h);
  // SizeOf is base + the largest arm
  writeln(SizeOf(s));                  // 16
  // byte/word union (union alignment 2)
  t.tag := 1;
  t.w := 300;
  writeln(t.w);
  writeln(SizeOf(t));                  // 4
  // else arm
  t.tag := 2;
  t.x := 7;
  writeln(t.x);
end.
