library alloc;

// Heap allocation demo: New/Dispose + GetMem/FreeMem.
// Builds a linked list of records on the heap, walks it, then frees it.

type
  PNode = ^TNode;
  TNode = record
    value: Integer;
    next: PNode;
  end;

var
  head, p: PNode;
  n: Integer;
  buf: ^Byte;

procedure Demo;
begin
  writeln('Linked list via New/Dispose:');
  head := 0;
  for n := 1 to 5 do
    begin
      New(p);
      p^.value := n * 10;
      p^.next := head;
      head := p;
    end;
  p := head;
  while p <> 0 do
    begin
      write(p^.value);
      write(' ');
      p := p^.next;
    end;
  writeln;
  writeln;

  writeln('Raw buffer via GetMem/FreeMem:');
  GetMem(buf, 64);
  buf^ := 42;
  writeln('buf^ = ', buf^);
  FreeMem(buf);
  writeln('freed.');
end;

begin
  Demo;
end.
