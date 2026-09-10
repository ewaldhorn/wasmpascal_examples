unit mp_trough;

{ Port of trough.odin: food/water trough data. }

interface

uses
  mp_defs;

procedure NewTrough(var t: TTrough; kind: Integer; x, y: Double);

function TroughNeedsRefill(var t: TTrough): Boolean;

implementation

procedure NewTrough(var t: TTrough; kind: Integer; x, y: Double);
begin
  t.kind := kind;
  t.x := x;
  t.y := y;
  t.amount := TROUGH_CAPACITY;
end;

function TroughNeedsRefill(var t: TTrough): Boolean;
begin
  TroughNeedsRefill := t.amount < TROUGH_CAPACITY * TROUGH_REFILL_THRESHOLD_FRAC;
end;

begin
end.
