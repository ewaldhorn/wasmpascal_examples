{ 48M: bg bake of the level-10 world is 2980*2200*4 = 26.2 MB, plus the
  1.9 MB frame and program data. Raised from 32M in M8. }
{$M 48M}
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

function mp_stat_shear: Integer;
begin
  mp_stat_shear := DbgStatShear;
end;

function mp_stat_sales: Integer;
begin
  mp_stat_sales := DbgStatSales;
end;

function mp_stat_upkeep: Integer;
begin
  mp_stat_upkeep := DbgStatUpkeep;
end;

function mp_stat_spent: Integer;
begin
  mp_stat_spent := DbgStatSpent;
end;

function mp_budget_open: Integer;
begin
  if budget_open then mp_budget_open := 1 else mp_budget_open := 0;
end;

function mp_w1task: Integer;
begin
  mp_w1task := DbgW1Task;
end;

function mp_wbubble(idx: Integer): Integer;
begin
  mp_wbubble := DbgWBubble(idx);
end;

function mp_help_open: Integer;
begin
  if help_open then mp_help_open := 1 else mp_help_open := 0;
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
  DbgS0Wool name 'mp_s0wool',
  DbgSheepCap name 'mp_sheep_cap',
  DbgTr0 name 'mp_tr0',
  DbgTrN name 'mp_tr_n',
  DbgTrSel name 'mp_tr_sel',
  DbgTr0x name 'mp_tr0x',
  DbgTr0y name 'mp_tr0y',
  DbgTr1x name 'mp_tr1x',
  DbgTr1y name 'mp_tr1y',
  DbgWelcome name 'mp_welcome',
  DbgOfflineCoins name 'mp_offline_coins',
  mp_stat_shear name 'mp_stat_shear',
  mp_stat_sales name 'mp_stat_sales',
  mp_stat_upkeep name 'mp_stat_upkeep',
  mp_stat_spent name 'mp_stat_spent',
  mp_budget_open name 'mp_budget_open',
  mp_help_open name 'mp_help_open',
  mp_w1task name 'mp_w1task',
  mp_wbubble name 'mp_wbubble';

begin
end.
