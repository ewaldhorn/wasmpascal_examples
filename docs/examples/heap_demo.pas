library heap_demo;

// Watch the heap climb in the status bar (RAM ... · heap ...).
// Allocates 10 blocks one at a time, pausing for ENTER after each so you can
// see the "heap" number grow, then frees them all.
// {$M 64K} keeps the whole app (including the heap) inside 64 KiB of memory.

{$M 64K}

const
  BLOCKS = 10;

var
  ptrs: array[0..BLOCKS - 1] of ^Byte;
  i: Integer;
  p: ^Byte;

procedure Demo;
begin
  writeln('Allocating 10 blocks of growing size, one at a time.');
  writeln('Watch "heap" in the status bar climb.');
  writeln('Press ENTER after each block to allocate the next.');
  writeln;

  for i := 0 to BLOCKS - 1 do
    begin
      GetMem(ptrs[i], (i + 1) * 1024);
      // Touch the block so the memory is actually committed.
      p := ptrs[i];
      p^ := 1;
      writeln('  allocated block ', i + 1, ': ', (i + 1) * 1024, ' bytes');
      if i < BLOCKS - 1 then
        readln;
    end;

  writeln;
  writeln('All blocks allocated. Press ENTER to free them all...');
  readln;

  for i := 0 to BLOCKS - 1 do
    FreeMem(ptrs[i]);

  writeln('Freed all blocks.');
  writeln;
  writeln('Done.');
end;

begin
  Demo;
end.
