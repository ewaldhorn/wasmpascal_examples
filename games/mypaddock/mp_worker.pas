unit mp_worker;

{ Port of worker.odin: generic worker entity + movement. Task decisions live
  in mp_game (mirrors the Odin split). Kind/state/task are Integer consts
  (WK_*, WS_*, WT_* in mp_defs). }

interface

uses
  mp_defs,
  mp_rand,
  mp_world;

function WorkerSpeed(kind: Integer): Double;

procedure NewWorker(var w: TWorker; kind: Integer);

function WorkerStepToward(var w: TWorker; tx, ty, dt: Double): Boolean;

procedure WorkerWander(var w: TWorker; dt: Double);

{ What the worker is about to do, as the (addr, len) pair the speech bubble
  draws. WT_NONE is "...": an idle worker has nothing to do. Lives here, not
  in the sprite code, so the debug export reports exactly what is drawn. }
procedure WorkerTaskLabel(task: Integer; var addr, len: Integer);

implementation

function WorkerSpeed(kind: Integer): Double;
begin
  if kind = WK_HAND then WorkerSpeed := HAND_SPEED
  else WorkerSpeed := FARMER_SPEED;
end;

procedure NewWorker(var w: TWorker; kind: Integer);
begin
  BoundsRandomPoint;
  w.kind := kind;
  w.x := rnd_x;
  w.y := rnd_y;
  w.target_x := rnd_x;
  w.target_y := rnd_y;
  w.facing := 1.0;
  w.walk_timer := 0.0;
  w.wander_timer := 0.0;
  w.state := WS_IDLE;
  w.task := WT_NONE;
  w.target_sheep_id := 0;
  w.target_trough := 0;
  w.work_timer := 0.0;
  w.speed_mult := 1.0;
end;

function WorkerStepToward(var w: TWorker; tx, ty, dt: Double): Boolean;
var
  dx, dy, dist, step: Double;
begin
  w.walk_timer := w.walk_timer + dt;
  dx := tx - w.x;
  dy := ty - w.y;
  dist := mSqrt(dx * dx + dy * dy);
  if dist <= WORKER_ARRIVE_DIST then
  begin
    WorkerStepToward := true;
    Exit;
  end;
  step := WorkerSpeed(w.kind) * w.speed_mult * dt;
  if step > dist then step := dist;
  w.x := w.x + (dx / dist) * step;
  w.y := w.y + (dy / dist) * step;
  if dx > 0.5 then w.facing := 1.0
  else if dx < -0.5 then w.facing := -1.0;
  WorkerStepToward := false;
end;

procedure WorkerTaskLabel(task: Integer; var addr, len: Integer);
begin
  if task = WT_SHEAR then
  begin addr := StrAddr('SHEAR'); len := StrLen('SHEAR'); end
  else if task = WT_REFILL_FOOD then
  begin addr := StrAddr('REFILL FOOD'); len := StrLen('REFILL FOOD'); end
  else if task = WT_REFILL_WATER then
  begin addr := StrAddr('REFILL WATER'); len := StrLen('REFILL WATER'); end
  else
  begin addr := StrAddr('...'); len := StrLen('...'); end;
end;

procedure WorkerWander(var w: TWorker; dt: Double);
begin
  w.wander_timer := w.wander_timer - dt;
  if w.wander_timer <= 0.0 then
  begin
    BoundsRandomPoint;
    w.target_x := rnd_x;
    w.target_y := rnd_y;
    w.wander_timer := WORKER_WANDER_MIN +
      RngFloat * (WORKER_WANDER_MAX - WORKER_WANDER_MIN);
  end;
  WorkerStepToward(w, w.target_x, w.target_y, dt);
end;

begin
end.
