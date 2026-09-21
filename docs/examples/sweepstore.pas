unit sweepstore;

{$mode fpc}

interface

uses
  sweepdefs,
  sweeprand;

function LoadDifficulty: Integer;

procedure SaveDifficulty(d: Integer);

procedure LoadBestTimes;

procedure SaveBestTime(d, secs: Integer);

implementation


// The storage calls take STRINGS now: the WEB unit marshals a string argument
// itself, so the (ptr, len) pairs this file used to build by hand are gone —
// `Str(v, s)` formats the value and the compiler does the rest.

function LoadDifficulty: Integer;
var
  n: Integer;
begin
  n := dom_local_storage_get_item('sweepDifficulty', Integer(@scratch), 80);
  if n < 0 then LoadDifficulty := 0
  else LoadDifficulty := ParseInt(Integer(@scratch), n);
end;

procedure SaveDifficulty(d: Integer);
var
  s: string;
begin
  Str(d, s);
  dom_local_storage_set_item('sweepDifficulty', s);
end;

procedure LoadBestTimes;
var
  n: Integer;
begin
  n := dom_local_storage_get_item('sweepBestEasy', Integer(@scratch), 80);
  if n >= 0 then best_times[0] := ParseInt(Integer(@scratch), n);
  n := dom_local_storage_get_item('sweepBestMedium', Integer(@scratch), 80);
  if n >= 0 then best_times[1] := ParseInt(Integer(@scratch), n);
  n := dom_local_storage_get_item('sweepBestHard', Integer(@scratch), 80);
  if n >= 0 then best_times[2] := ParseInt(Integer(@scratch), n);
end;

procedure SaveBestTime(d, secs: Integer);
var
  s: string;
begin
  Str(secs, s);
  if d = 0 then
    dom_local_storage_set_item('sweepBestEasy', s)
  else if d = 1 then
    dom_local_storage_set_item('sweepBestMedium', s)
  else
    dom_local_storage_set_item('sweepBestHard', s);
end;

begin
end.
