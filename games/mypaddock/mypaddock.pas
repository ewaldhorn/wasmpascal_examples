{$M 32M}
library mypaddock;

{ My Paddock — sheep-farming idle game, ported from Odin to WasmPascal.
  Pixel-buffer pascaldom ABI (see PLAN.md §1). M5: sim + chrome + save + sound.
  Dbg* getters are debug/test exports (sweep_state precedent); they live in
  mp_game and are re-exported here. }

uses
  mp_host,
  mp_game,
  mp_sound;

function mp_cam_x: Integer;
begin
  mp_cam_x := Trunc(cam_x);
end;

function mp_cam_y: Integer;
begin
  mp_cam_y := Trunc(cam_y);
end;

function mp_shop_open: Integer;
begin
  if shop_open then mp_shop_open := 1 else mp_shop_open := 0;
end;

function mp_sfx_on: Integer;
begin
  if sfx_on then mp_sfx_on := 1 else mp_sfx_on := 0;
end;

function mp_confirm: Integer;
begin
  if confirm_reset then mp_confirm := 1 else mp_confirm := 0;
end;

exports
  MpMain name 'pascaldom_main',
  InvokeCallback name 'pascaldom_invoke_callback',
  SetLastEvent name 'pascaldom_set_last_event',
  mp_cam_x name 'mp_cam_x',
  mp_cam_y name 'mp_cam_y',
  mp_shop_open name 'mp_shop_open',
  mp_sfx_on name 'mp_sfx_on',
  mp_confirm name 'mp_confirm',
  DbgSheepN name 'mp_sheep_n',
  DbgWorkerN name 'mp_worker_n',
  DbgCoins name 'mp_coins',
  DbgS0x name 'mp_s0x',
  DbgS0y name 'mp_s0y',
  DbgS0Hunger name 'mp_s0hunger',
  DbgTr0 name 'mp_tr0',
  DbgWelcome name 'mp_welcome',
  DbgOfflineCoins name 'mp_offline_coins';

begin
end.
