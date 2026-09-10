{$M 32M}
library mypaddock;

{ My Paddock — sheep-farming idle game, ported from Odin to WasmPascal.
  Pixel-buffer pascaldom ABI (see PLAN.md §1). M1: baked background + title. }

uses
  mp_host;

exports
  MpMain name 'pascaldom_main',
  InvokeCallback name 'pascaldom_invoke_callback',
  SetLastEvent name 'pascaldom_set_last_event';

begin
end.
