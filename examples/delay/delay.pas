library delay;

// Delay(ms) pauses the program. Console programs run in
// a worker, so the sleep blocks the worker thread without freezing the page.

procedure Demo;
begin
  writeln('before delay');
  Delay(500);
  writeln('after delay');
end;

begin
  Demo;
end.
