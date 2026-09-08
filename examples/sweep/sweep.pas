library sweep;

uses
  sweephost;

function sweep_state: Integer;
begin
  sweep_state := state;
end;
function sweep_flags: Integer;
begin
  sweep_flags := FlagCount;
end;
function sweep_get_cell(i, j: Integer): Integer;
begin
  sweep_get_cell := cells[i * MAX_H + j];
end;
function sweep_bomb(i, j: Integer): Integer;
begin
  if bombs[i * MAX_H + j] then sweep_bomb := 1 else sweep_bomb := 0;
end;
function sweep_num(i, j: Integer): Integer;
begin
  sweep_num := Integer(nums[i * MAX_H + j]);
end;
function sweep_difficulty: Integer;
begin
  sweep_difficulty := difficulty;
end;
function sweep_best(d: Integer): Integer;
begin
  sweep_best := best_times[d];
end;
function sweep_pixels: Integer;
begin
  sweep_pixels := Integer(@pixels);
end;
function sweep_timer: Integer;
begin
  if state = ST_UNDEFINED then sweep_timer := 0
  else sweep_timer := Integer(last_time - start_time);
end;


exports
  SweepMain name 'pascaldom_main',
  InvokeCallback name 'pascaldom_invoke_callback',
  SetLastEvent name 'pascaldom_set_last_event',
  sweep_state name 'sweep_state',
  sweep_flags name 'sweep_flags',
  sweep_get_cell name 'sweep_get_cell',
  sweep_bomb name 'sweep_bomb',
  sweep_num name 'sweep_num',
  sweep_difficulty name 'sweep_difficulty',
  sweep_best name 'sweep_best',
  sweep_pixels name 'sweep_pixels',
  sweep_timer name 'sweep_timer';

begin
end.
