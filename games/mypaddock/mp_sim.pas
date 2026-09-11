unit mp_sim;

{ Sim glue: cross-entity task assignment (sheep needs, worker state machine,
  effect upkeep) and offline catch-up. Split out of mp_game (M7); uses
  mp_shop for economy state, never the reverse. }

interface

uses
  mp_defs,
  mp_sheep,
  mp_trough,
  mp_worker,
  mp_effect,
  mp_sound,
  mp_shop;

var
  wft_task: Integer = 0;
  wft_sheep: Integer = 0;
  wft_trough: Integer = 0;
  wft_ok: Boolean = false;
  { Round-robin cursor for handing new jobs to idle workers. Without it the
    worker loop below always scans from index 0, so the farmer (always [0])
    wins every tie when only one job is up — the norm in a small flock — and
    hired hands visibly never work. The cursor advances only when a job is
    actually assigned, so consecutive lone jobs strictly alternate takers. }
  rr_next: Integer = 0;
  off_next: array[0..MAX_SHEEP - 1] of Double;
  off_last: array[0..MAX_SHEEP - 1] of Double;
  off_free: array[0..31] of Double;
  off_cycle: array[0..31] of Double;

procedure ApplyOfflineProgress(elapsed: Double);

function NearestTrough(kind: Integer; x, y: Double): Integer;

function FindSheepIndex(id: Integer): Integer;

function SheepClaimed(id: Integer): Boolean;

function TroughClaimed(idx: Integer): Boolean;

procedure WorkerFindTask;

procedure AddCoinEffect(x, y: Double; amount: Integer);

procedure AddSparkle(x, y: Double);

procedure UpdateSheepNeeds(dt: Double);

procedure UpdateWorkers(dt: Double);

procedure UpdateEffects(dt: Double);

implementation

procedure ApplyOfflineProgress(elapsed: Double);
var
  i, n, lanes, w, w_best, s_best: Integer;
  coins_each: Integer;
  regrow, t, assign: Double;
  done: Boolean;
begin
  for i := 0 to sheep_n - 1 do
  begin
    sheep[i].hunger := 100.0;
    sheep[i].thirst := 100.0;
  end;
  n := sheep_n;
  if n = 0 then Exit;
  regrow := SHEAR_THRESHOLD / WOOL_GROWTH_PER_SEC;
  coins_each := Trunc(SHEAR_THRESHOLD) div WOOL_TO_COIN_DIV;
  for i := 0 to n - 1 do
  begin
    t := (SHEAR_THRESHOLD - sheep[i].wool) / WOOL_GROWTH_PER_SEC;
    if t < 0.0 then t := 0.0;
    off_next[i] := t;
    off_last[i] := -1.0;
  end;
  lanes := 1 + hand_count;
  if lanes > 32 then lanes := 32;
  for w := 0 to lanes - 1 do
  begin
    off_free[w] := 0.0;
    off_cycle[w] := OFFLINE_WORKER_CYCLE_SEC;
  end;
  if has_dog then
    off_cycle[0] := OFFLINE_WORKER_CYCLE_SEC / DOG_SPEED_MULT;
  { NOTE: do not use Break inside the if below — the compiler resolves it
    to the if-block, not the loop (infinite loop). Done-flag instead. }
  done := false;
  while not done do
  begin
    w_best := 0;
    for w := 1 to lanes - 1 do
      if off_free[w] < off_free[w_best] then
        w_best := w;
    s_best := 0;
    for i := 1 to n - 1 do
      if off_next[i] < off_next[s_best] then
        s_best := i;
    assign := off_free[w_best];
    if off_next[s_best] > assign then
      assign := off_next[s_best];
    if assign > elapsed then
      done := true
    else
    begin
      coins := coins + coins_each;
      stat_shear := stat_shear + coins_each;
      off_last[s_best] := assign;
      off_next[s_best] := assign + regrow;
      off_free[w_best] := assign + off_cycle[w_best];
    end;
  end;
  for i := 0 to n - 1 do
  begin
    if off_last[i] < 0.0 then
      sheep[i].wool := sheep[i].wool + WOOL_GROWTH_PER_SEC * elapsed
    else
      sheep[i].wool := (elapsed - off_last[i]) * WOOL_GROWTH_PER_SEC;
    if sheep[i].wool < 0.0 then sheep[i].wool := 0.0;
    if sheep[i].wool > 100.0 then sheep[i].wool := 100.0;
  end;
end;

function NearestTrough(kind: Integer; x, y: Double): Integer;
var
  i, best: Integer;
  best_d, dx, dy, d: Double;
begin
  best := -1;
  best_d := 1e18;
  for i := 0 to trough_n - 1 do
  begin
    if troughs[i].kind <> kind then continue;
    if troughs[i].amount <= 0.0 then continue;
    dx := troughs[i].x - x;
    dy := troughs[i].y - y;
    d := dx * dx + dy * dy;
    if d < best_d then
    begin
      best_d := d;
      best := i;
    end;
  end;
  NearestTrough := best;
end;

function FindSheepIndex(id: Integer): Integer;
var
  i: Integer;
begin
  FindSheepIndex := -1;
  for i := 0 to sheep_n - 1 do
    if sheep[i].id = id then
    begin
      FindSheepIndex := i;
      Exit;
    end;
end;

function SheepClaimed(id: Integer): Boolean;
var
  i: Integer;
begin
  SheepClaimed := false;
  for i := 0 to claimed_sheep_n - 1 do
    if claimed_sheep[i] = id then
    begin
      SheepClaimed := true;
      Exit;
    end;
end;

function TroughClaimed(idx: Integer): Boolean;
var
  i: Integer;
begin
  TroughClaimed := false;
  for i := 0 to claimed_troughs_n - 1 do
    if claimed_troughs[i] = idx then
    begin
      TroughClaimed := true;
      Exit;
    end;
end;

procedure WorkerFindTask;
var
  i: Integer;
  best_wool: Double;
  best_i: Integer;
begin
  wft_task := WT_NONE;
  wft_sheep := -1;
  wft_trough := -1;
  wft_ok := false;
  for i := 0 to trough_n - 1 do
    if (troughs[i].kind = TR_FOOD) and TroughNeedsRefill(troughs[i]) and
       (not TroughClaimed(i)) then
    begin
      wft_task := WT_REFILL_FOOD;
      wft_trough := i;
      wft_ok := true;
      Exit;
    end;
  for i := 0 to trough_n - 1 do
    if (troughs[i].kind = TR_WATER) and TroughNeedsRefill(troughs[i]) and
       (not TroughClaimed(i)) then
    begin
      wft_task := WT_REFILL_WATER;
      wft_trough := i;
      wft_ok := true;
      Exit;
    end;
  best_wool := SHEAR_THRESHOLD;
  best_i := -1;
  for i := 0 to sheep_n - 1 do
  begin
    if SheepClaimed(sheep[i].id) then continue;
    if sheep[i].wool >= best_wool then
    begin
      best_wool := sheep[i].wool;
      best_i := i;
    end;
  end;
  if best_i >= 0 then
  begin
    wft_task := WT_SHEAR;
    wft_sheep := best_i;
    wft_ok := true;
  end;
end;

procedure AddCoinEffect(x, y: Double; amount: Integer);
begin
  if effect_n >= MAX_EFFECTS then Exit;
  NewCoinEffect(effects[effect_n], x, y, amount);
  effect_n := effect_n + 1;
end;

procedure AddSparkle(x, y: Double);
begin
  if effect_n >= MAX_EFFECTS then Exit;
  NewSparkleEffect(effects[effect_n], x, y);
  effect_n := effect_n + 1;
end;

procedure UpdateSheepNeeds(dt: Double);
var
  i, ti: Integer;
  sought: Boolean;
begin
  for i := 0 to sheep_n - 1 do
  begin
    SheepTickNeeds(sheep[i], dt);
    sought := false;
    if sheep[i].hunger < SHEEP_SEEK_THRESHOLD then
    begin
      ti := NearestTrough(TR_FOOD, sheep[i].x, sheep[i].y);
      if ti >= 0 then
      begin
        sought := true;
        if SheepStepToward(sheep[i], troughs[ti].x, troughs[ti].y, dt) then
        begin
          SheepFeed(sheep[i]);
          troughs[ti].amount := troughs[ti].amount - TROUGH_CONSUME_PER_VISIT;
          AddSparkle(sheep[i].x, sheep[i].y - 20.0);
        end;
      end;
    end;
    if (not sought) and (sheep[i].thirst < SHEEP_SEEK_THRESHOLD) then
    begin
      ti := NearestTrough(TR_WATER, sheep[i].x, sheep[i].y);
      if ti >= 0 then
      begin
        sought := true;
        if SheepStepToward(sheep[i], troughs[ti].x, troughs[ti].y, dt) then
        begin
          SheepWater(sheep[i]);
          troughs[ti].amount := troughs[ti].amount - TROUGH_CONSUME_PER_VISIT;
          AddSparkle(sheep[i].x, sheep[i].y - 20.0);
        end;
      end;
    end;
    if not sought then
      SheepWander(sheep[i], dt);
  end;
end;

procedure UpdateWorkers(dt: Double);
var
  i, j, k, idx, earned, n_idle: Integer;
  tx, ty: Double;
  valid: Boolean;
  idle: array[0..MAX_WORKERS - 1] of Integer;
begin
  claimed_sheep_n := 0;
  claimed_troughs_n := 0;
  for i := 0 to worker_n - 1 do
  begin
    if workers[i].state = WS_IDLE then continue;
    if workers[i].task = WT_SHEAR then
    begin
      claimed_sheep[claimed_sheep_n] := workers[i].target_sheep_id;
      claimed_sheep_n := claimed_sheep_n + 1;
    end
    else if (workers[i].task = WT_REFILL_FOOD) or
            (workers[i].task = WT_REFILL_WATER) then
    begin
      claimed_troughs[claimed_troughs_n] := workers[i].target_trough;
      claimed_troughs_n := claimed_troughs_n + 1;
    end;
  end;
  { Advance workers that already have jobs. Idle workers are assigned below in
    round-robin order (see rr_next): scanning from index 0 every frame let the
    farmer take every lone job, leaving hired hands permanently wandering. }
  for i := 0 to worker_n - 1 do
  begin
    if (workers[i].kind = WK_FARMER) and has_dog then
      workers[i].speed_mult := DOG_SPEED_MULT
    else
      workers[i].speed_mult := 1.0;
    if workers[i].state = WS_IDLE then continue
    else if workers[i].state = WS_WALKING then
    begin
      valid := true;
      if workers[i].task = WT_SHEAR then
      begin
        idx := FindSheepIndex(workers[i].target_sheep_id);
        if idx < 0 then valid := false
        else
        begin
          tx := sheep[idx].x;
          ty := sheep[idx].y;
        end;
      end
      else if (workers[i].task = WT_REFILL_FOOD) or
              (workers[i].task = WT_REFILL_WATER) then
      begin
        tx := troughs[workers[i].target_trough].x;
        ty := troughs[workers[i].target_trough].y;
      end
      else
        valid := false;
      if not valid then
        workers[i].state := WS_IDLE
      else if WorkerStepToward(workers[i], tx, ty, dt) then
      begin
        workers[i].state := WS_WORKING;
        workers[i].work_timer := WORKER_WORK_DURATION;
      end;
    end
    else if workers[i].state = WS_WORKING then
    begin
      workers[i].walk_timer := workers[i].walk_timer + dt;
      workers[i].work_timer := workers[i].work_timer - dt;
      if workers[i].work_timer <= 0.0 then
      begin
        if workers[i].task = WT_SHEAR then
        begin
          idx := FindSheepIndex(workers[i].target_sheep_id);
          if idx >= 0 then
            if SheepCanShear(sheep[idx]) then
            begin
              earned := SheepShear(sheep[idx]);
              coins := coins + earned;
              stat_shear := stat_shear + earned;
              AddCoinEffect(sheep[idx].x, sheep[idx].y - 20.0, earned);
              PlayShear;
            end;
        end
        else if workers[i].task = WT_REFILL_FOOD then
        begin
          troughs[workers[i].target_trough].amount := TROUGH_CAPACITY;
          AddSparkle(troughs[workers[i].target_trough].x,
            troughs[workers[i].target_trough].y - 16.0);
          PlayFeed;
        end
        else if workers[i].task = WT_REFILL_WATER then
        begin
          troughs[workers[i].target_trough].amount := TROUGH_CAPACITY;
          AddSparkle(troughs[workers[i].target_trough].x,
            troughs[workers[i].target_trough].y - 16.0);
          PlayWater;
        end;
        workers[i].state := WS_IDLE;
        workers[i].task := WT_NONE;
      end;
    end;
  end;
  { Hand new jobs to idle workers in round-robin order starting after the last
    assignee, so lone jobs alternate takers instead of always going to the
    farmer. Claims are appended on each assignment exactly as before, so later
    takers in the same frame still see earlier ones. }
  if worker_n > 0 then
  begin
    rr_next := rr_next mod worker_n;
    n_idle := 0;
    for k := 0 to worker_n - 1 do
    begin
      i := (rr_next + k) mod worker_n;
      if workers[i].state = WS_IDLE then
      begin
        idle[n_idle] := i;
        n_idle := n_idle + 1;
      end;
    end;
    for j := 0 to n_idle - 1 do
    begin
      i := idle[j];
      WorkerFindTask;
      if not wft_ok then
        WorkerWander(workers[i], dt)
      else
      begin
        workers[i].task := wft_task;
        workers[i].state := WS_WALKING;
        if wft_task = WT_SHEAR then
        begin
          workers[i].target_sheep_id := sheep[wft_sheep].id;
          claimed_sheep[claimed_sheep_n] := workers[i].target_sheep_id;
          claimed_sheep_n := claimed_sheep_n + 1;
        end
        else
        begin
          workers[i].target_trough := wft_trough;
          claimed_troughs[claimed_troughs_n] := wft_trough;
          claimed_troughs_n := claimed_troughs_n + 1;
        end;
        rr_next := (i + 1) mod worker_n;
      end;
    end;
  end;
end;

procedure UpdateEffects(dt: Double);
var
  i, j: Integer;
begin
  j := 0;
  for i := 0 to effect_n - 1 do
    if EffectUpdate(effects[i], dt) then
    begin
      effects[j] := effects[i];
      j := j + 1;
    end;
  effect_n := j;
end;

begin
end.
