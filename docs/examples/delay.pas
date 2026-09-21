library delay;

// Delay(ms) pauses the program. Console programs run in a worker, so the sleep
// blocks the worker thread (Atomics.wait on its own SAB slot) without freezing
// the page. On the no-SharedArrayBuffer fallback they run on the main thread
// instead, where Delay is a no-op — blocking there would freeze the page.

procedure Demo;
begin
  writeln('before delay');
  Delay(500);
  writeln('after delay');
end;

begin
  Demo;
end.
