// duglevel.pas — DUGSTER level state: the dirt/emerald grids, level
// generation, and tile queries. All level state lives here; the sim moves
// the actors, the renderer draws the grids.
unit duglevel;

interface

uses
  dugdefs;

const
  BAG_NONE = 0;
  BAG_REST = 1;
  BAG_FALL = 2;
  // Authentic map count: levels cycle (dgLevel-1) mod LV_COUNT.
  LV_COUNT = 8;

var
  lvDug: array[0..ROWS1, 0..COLS1] of Boolean;
  lvEm: array[0..ROWS1, 0..COLS1] of Boolean;
  // Gold bags: BAG_NONE / BAG_REST / BAG_FALL.
  // lvBagT: elapsed seconds while resting (wobble timer); integer-truncated
  // cells fallen while falling (Trunc(lvBagT) = fall depth).
  lvBag: array[0..ROWS1, 0..COLS1] of Integer;
  lvBagT: array[0..ROWS1, 0..COLS1] of Single;
  // Spilled gold (A5): one 500-pt pile per shattered bag. lvGoldT ages
  // in simStepBags; lifetime is (150-10*level) ticks like the original.
  lvGold: array[0..ROWS1, 0..COLS1] of Boolean;
  lvGoldT: array[0..ROWS1, 0..COLS1] of Single;

// Build a fresh board: solid dirt, a starter pocket for the monster,
// scattered emeralds. Sets dgEmLeft. Caller positions the actors.
procedure lvNewLevel;

// Pocket dugsters (starter tunnels).
procedure lvDig(x, y: Integer);

// Queries.
function lvInBounds(x, y: Integer): Integer;
function lvIsDug(x, y: Integer): Integer;
function lvHasEmerald(x, y: Integer): Integer;

// Collect the emerald at (x, y). Returns 1 if one was there.
function lvTakeEmerald(x, y: Integer): Integer;

// Bag queries.
function lvBagAt(x, y: Integer): Integer;
procedure lvSetBag(x, y, st: Integer);
procedure lvClearBag(x, y: Integer);

// Gold queries (A5).
function lvHasGold(x, y: Integer): Integer;
procedure lvSetGold(x, y: Integer);
procedure lvClearGold(x, y: Integer);

implementation

var
  // Authentic map rows for the current level: 10 rows of up to 15 cells,
  // 1-based strings (see lvLoadRows). Stored WITHOUT trailing spaces; a
  // short row means trailing untouched dirt (handled in lvNewLevel).
  lvRows: array[0..ROWS1] of string[15];

// Load one authentic map's 10 rows into lvRows. Transcribed verbatim from
// the classic level data (P3 research): ' ' = untouched dirt, V/H/S =
// tunnel (S = both dirs), C = emerald, B = gold bag. Levels cycle every
// 8 (classic levof10 restarts at a higher difficulty; difficulty ramp is
// reserved for a future pass).
procedure lvLoadRows(lv: Integer);
begin
  case lv of
    0: begin
      lvRows[0] := 'S   B     HHHHS';
      lvRows[1] := 'V  CC  C  V B';
      lvRows[2] := 'V C  C CV   V';
      lvRows[3] := 'VVC C CCCCC VV';
      lvRows[4] := 'V C C V   V  V';
      lvRows[5] := 'V C C V CCCCCCV';
      lvRows[6] := 'V CC  V V   V';
      lvRows[7] := 'V C C V V C V';
      lvRows[8] := 'V C  CV V C V';
      lvRows[9] := 'C V    V   V C';
    end;
    1: begin
      lvRows[0] := 'SHHHHH  B B  HS';
      lvRows[1] := ' CC  V       V';
      lvRows[2] := ' CB  VC CCCC V';
      lvRows[3] := 'CCB  VCCCCCCCV';
      lvRows[4] := '  B  V  C   V';
      lvRows[5] := ' CB  V C C V V';
      lvRows[6] := ' CC  V CCC V';
      lvRows[7] := ' CB  V C C V';
      lvRows[8] := 'HCC  V C C V';
      lvRows[9] := 'SHHHHHC C C V';
    end;
    2: begin
      lvRows[0] := 'SHHHHB B BHHHHS';
      lvRows[1] := 'CC  V C C V BB';
      lvRows[2] := 'C C V C C V  B';
      lvRows[3] := '  C V C C V B';
      lvRows[4] := ' CC V C C V   H';
      lvRows[5] := ' C  V C C V  HS';
      lvRows[6] := 'CC  V C C V  V';
      lvRows[7] := 'CBC V C C V  V';
      lvRows[8] := 'CC  V C C V C V';
      lvRows[9] := 'S   V   V V C V';
    end;
    3: begin
      lvRows[0] := 'S   B B B   H S';
      lvRows[1] := 'V C C C C C V';
      lvRows[2] := 'V CCCCC CCCC V';
      lvRows[3] := 'V C C C C C V';
      lvRows[4] := 'VVC C C C C V';
      lvRows[5] := 'V C C C C C V';
      lvRows[6] := 'V CCCCC CCCC V';
      lvRows[7] := 'V C C C C C V';
      lvRows[8] := 'V CVCVCVCVCV V';
      lvRows[9] := 'C C C C C C  C';
    end;
    4: begin
      lvRows[0] := 'SHHHHBBB  HHHS';
      lvRows[1] := 'V         V';
      lvRows[2] := 'V CCCCCCC V';
      lvRows[3] := 'V C     C V';
      lvRows[4] := 'V C CBC C V';
      lvRows[5] := 'V C CBC C V';
      lvRows[6] := 'V C CBC C V';
      lvRows[7] := 'V C     C V';
      lvRows[8] := 'V CCCCCCC V';
      lvRows[9] := 'V         V C';
    end;
    5: begin
      lvRows[0] := 'S  B B B B  H S';
      lvRows[1] := 'V C C C C C  V';
      lvRows[2] := 'V CVCVCVCVCV V';
      lvRows[3] := 'V C C C C C  V';
      lvRows[4] := 'V CCCCCCCCCC V';
      lvRows[5] := 'V C C C C C  V';
      lvRows[6] := 'V CVCVCVCVCV V';
      lvRows[7] := 'V C C C C C  V';
      lvRows[8] := 'V CVCVCVCVCV V';
      lvRows[9] := 'C C C C C C  C';
    end;
    6: begin
      lvRows[0] := 'SSSSSSSSSSSSSSS';
      lvRows[1] := '   CC   CC  V';
      lvRows[2] := '  CCB CCB C V C';
      lvRows[3] := '  C  C  C  V';
      lvRows[4] := ' CC  CC  C V C';
      lvRows[5] := ' C BC C BC V C';
      lvRows[6] := ' CC  C   C V C';
      lvRows[7] := ' C BC C BC V C';
      lvRows[8] := ' CC  CC  C V C';
      lvRows[9] := ' C CBC C B V C';
    end;
    7: begin
      lvRows[0] := 'SHHHHBBB  HHHS';
      lvRows[1] := 'V         V';
      lvRows[2] := 'V CCCCCCC V';
      lvRows[3] := 'V C     C V';
      lvRows[4] := 'V C CBC C V H';
      lvRows[5] := 'V C CBC C V  S';
      lvRows[6] := 'V C CBC C V H';
      lvRows[7] := 'V C     C V';
      lvRows[8] := 'V CCCCCCC V';
      lvRows[9] := 'V         V C';
    end;
  end;
end;

function lvInBounds(x, y: Integer): Integer;
begin
  if (x < 0) or (x > COLS1) or (y < 0) or (y > ROWS1) then
    lvInBounds := 0
  else
    lvInBounds := 1;
end;

function lvIsDug(x, y: Integer): Integer;
begin
  if lvInBounds(x, y) = 0 then
    lvIsDug := 0
  else if lvDug[y, x] then
    lvIsDug := 1
  else
    lvIsDug := 0;
end;

function lvHasEmerald(x, y: Integer): Integer;
begin
  if lvInBounds(x, y) = 0 then
    lvHasEmerald := 0
  else if lvEm[y, x] then
    lvHasEmerald := 1
  else
    lvHasEmerald := 0;
end;

procedure lvDig(x, y: Integer);
begin
  if lvInBounds(x, y) = 0 then Exit;
  lvDug[y, x] := true;
end;

function lvTakeEmerald(x, y: Integer): Integer;
begin
  lvTakeEmerald := 0;
  if lvInBounds(x, y) = 0 then Exit;
  if lvEm[y, x] then
  begin
    lvEm[y, x] := false;
    dgEmLeft := dgEmLeft - 1;
    lvTakeEmerald := 1;
  end;
end;

function lvBagAt(x, y: Integer): Integer;
begin
  lvBagAt := 0;
  if lvInBounds(x, y) = 0 then Exit;
  lvBagAt := lvBag[y, x];
end;

procedure lvSetBag(x, y, st: Integer);
begin
  if lvInBounds(x, y) = 0 then Exit;
  lvBag[y, x] := st;
  lvBagT[y, x] := 0.0;
end;

procedure lvClearBag(x, y: Integer);
begin
  if lvInBounds(x, y) = 0 then Exit;
  lvBag[y, x] := BAG_NONE;
  lvBagT[y, x] := 0.0;
end;

function lvHasGold(x, y: Integer): Integer;
begin
  lvHasGold := 0;
  if lvInBounds(x, y) = 0 then Exit;
  if lvGold[y, x] then lvHasGold := 1;
end;

procedure lvSetGold(x, y: Integer);
begin
  if lvInBounds(x, y) = 0 then Exit;
  lvGold[y, x] := true;
  lvGoldT[y, x] := 0.0;
end;

procedure lvClearGold(x, y: Integer);
begin
  if lvInBounds(x, y) = 0 then Exit;
  lvGold[y, x] := false;
  lvGoldT[y, x] := 0.0;
end;

procedure lvNewLevel;
var
  x, y: Integer;
  ch: Char;
begin
  // Solid dirt, no emeralds, no bags, no gold.
  for y := 0 to ROWS1 do
    for x := 0 to COLS1 do
    begin
      lvDug[y, x] := false;
      lvEm[y, x] := false;
      lvBag[y, x] := BAG_NONE;
      lvBagT[y, x] := 0.0;
      lvGold[y, x] := false;
      lvGoldT[y, x] := 0.0;
    end;

  // Authentic map for this level (cycles every 8).
  lvLoadRows((dgLevel - 1) mod LV_COUNT);
  dgEmLeft := 0;
  for y := 0 to ROWS1 do
    for x := 0 to COLS1 do
    begin
      // Short rows drop trailing spaces; a short row means trailing dirt.
      if x + 1 > Length(lvRows[y]) then continue;
      ch := lvRows[y][x + 1];  // map strings are 1-based
      // S digs like H/V — direction is implied by adjacency; the cell is
      // simply clear (pre-dug in at least one axis).
      if (ch = 'S') or (ch = 'H') or (ch = 'V') then lvDig(x, y)
      else if ch = 'C' then
      begin
        lvEm[y, x] := true;
        dgEmLeft := dgEmLeft + 1;
      end
      else if ch = 'B' then lvSetBag(x, y, BAG_REST);
    end;

  // Today's spawns predate the A4 dispenser: the player starts at (0,9)
  // and the pocket pair top-right, so those exact cells are dug explicitly
  // to keep every actor mobile on all 8 maps.
  lvDig(0, ROWS1);             // player start (col 0, bottom row)
  lvDig(COLS1, 0);             // monster pocket: top-right corner
  lvDig(COLS1 - 1, 0);        // pocket: one cell left on row 0
  lvDig(COLS1, 1);             // pocket: one cell down on col 14
  lvDig(COLS1 - 1, 1);        // pocket: inner cell (2×2 clear zone)
end;

end.
