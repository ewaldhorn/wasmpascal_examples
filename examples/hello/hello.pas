library hello;

procedure wasm_init;
begin
end;

function add(a, b: Integer): Integer;
begin
  add := a + b;
end;

exports
  wasm_init name 'wasm_init',
  add name 'add';

begin
  WriteLn("Howzit!");
end.
