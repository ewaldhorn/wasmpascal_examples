unit sweepstore;

interface

uses
  sweepdefs,
  sweeprand;

function LoadDifficulty: Integer;

procedure SaveDifficulty(d: Integer);

procedure LoadBestTimes;

procedure SaveBestTime(d, secs: Integer);

implementation


function LoadDifficulty: Integer;
var
  n: Integer;
begin
  n := ls_get_item(StrAddr('sweepDifficulty'), StrLen('sweepDifficulty'), Integer(@scratch), 80);
  if n < 0 then LoadDifficulty := 0
  else LoadDifficulty := ParseInt(Integer(@scratch), n);
end;

procedure SaveDifficulty(d: Integer);
var
  n: Integer;
begin
  n := IntToBuf(d, Integer(@text_buf));
  ls_set_item(StrAddr('sweepDifficulty'), StrLen('sweepDifficulty'), Integer(@text_buf), n);
end;

procedure LoadBestTimes;
var
  n: Integer;
begin
  n := ls_get_item(StrAddr('sweepBestEasy'), StrLen('sweepBestEasy'), Integer(@scratch), 80);
  if n >= 0 then best_times[0] := ParseInt(Integer(@scratch), n);
  n := ls_get_item(StrAddr('sweepBestMedium'), StrLen('sweepBestMedium'), Integer(@scratch), 80);
  if n >= 0 then best_times[1] := ParseInt(Integer(@scratch), n);
  n := ls_get_item(StrAddr('sweepBestHard'), StrLen('sweepBestHard'), Integer(@scratch), 80);
  if n >= 0 then best_times[2] := ParseInt(Integer(@scratch), n);
end;

procedure SaveBestTime(d, secs: Integer);
var
  n: Integer;
begin
  n := IntToBuf(secs, Integer(@text_buf));
  if d = 0 then
    ls_set_item(StrAddr('sweepBestEasy'), StrLen('sweepBestEasy'), Integer(@text_buf), n)
  else if d = 1 then
    ls_set_item(StrAddr('sweepBestMedium'), StrLen('sweepBestMedium'), Integer(@text_buf), n)
  else
    ls_set_item(StrAddr('sweepBestHard'), StrLen('sweepBestHard'), Integer(@text_buf), n);
end;

begin
end.
