program pointers;
// M4: pointer ergonomics — nil, SizeOf, bare Pi, Inc/Dec on pointers.
type
  TPair = record
    a, b: Integer;
  end;
  PPair = ^TPair;
  PInt = ^Integer;
var
  arr: array[0..2] of TPair;
  nums: array[0..3] of Integer;
  p: PPair;
  q: PInt;
begin
  // nil: the null pointer constant
  p := nil;
  if p = nil then writeln('p is nil');
  if p <> 0 then writeln('not zero');  // p <> 0 is also a valid null check
  // SizeOf: compile-time constant (type or variable)
  writeln(SizeOf(TPair));              // 8
  writeln(SizeOf(p));                  // 4 (a pointer)
  writeln(SizeOf(arr));                // 24 (3 records)
  // bare Pi (a Double constant, no parens needed)
  writeln(Pi > 3.14);
  // Inc/Dec walk a record array: the step is element size, so +8 per record
  p := @arr[0];
  Inc(p);
  p.a := 11;
  Inc(p, 1);
  p.b := 22;
  Dec(p);
  p.b := 33;
  writeln(arr[1].a);                   // 11
  writeln(arr[2].b);                   // 22
  writeln(arr[1].b);                   // 33
  // Inc/Dec on an int pointer: +4 per element
  q := @nums[0];
  Inc(q);
  q^ := 99;
  Inc(q, 2);
  q^ := 55;
  writeln(nums[1]);                    // 99
  writeln(nums[3]);                    // 55
end.
