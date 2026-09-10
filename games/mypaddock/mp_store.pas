unit mp_store;

{ Persistence: flat localStorage keys + composite flock/trough codecs.
  Port of storage.odin (minus reload_page, which lives in mp_env).
  Tash explicit params / mp_defs shared arrays — never imports mp_game,
  so there is no import cycle. Key names match the Odin build exactly. }

interface

uses
  mp_defs,
  mp_rand,
  mp_world;

function ls_get_item(kp, kl, buf, maxlen: Integer): Integer;
  external 'pascaldom_env' name 'dom_local_storage_get_item';
procedure ls_set_item(kp, kl, vp, vl: Integer);
  external 'pascaldom_env' name 'dom_local_storage_set_item';

var
  savepos: Integer = 0;

procedure SaveInt(ka, kl, v: Integer);

function LoadInt(ka, kl, def: Integer): Integer;

procedure SaveFlock;

function LoadFlock: Boolean;

procedure SaveTroughs;

function LoadTroughs: Boolean;

procedure SaveLastSeen(ms: Double);

function LoadLastSeen: Double;

procedure SaveSfx(enabled: Boolean);

function LoadSfx: Boolean;

procedure ResetSave;

implementation

procedure AppendChar(c: Integer);
begin
  if savepos < 2048 then
  begin
    savebuf[savepos] := Byte(c);
    savepos := savepos + 1;
  end;
end;

procedure AppendInt(v: Integer);
var
  n, i: Integer;
begin
  n := IntToBuf(v);
  for i := 0 to n - 1 do
    AppendChar(numbuf[i]);
end;

function SaveAddr: Integer;
begin
  SaveAddr := Integer(@savebuf);
end;

procedure SaveInt(ka, kl, v: Integer);
var
  n: Integer;
begin
  n := IntToBuf(v);
  ls_set_item(ka, kl, Integer(@numbuf), n);
end;

function LoadInt(ka, kl, def: Integer): Integer;
var
  n: Integer;
begin
  n := ls_get_item(ka, kl, Integer(@scratch), 80);
  if n <= 0 then LoadInt := def
  else LoadInt := ParseInt(Integer(@scratch), n);
end;

procedure SaveFlock;
var
  i: Integer;
begin
  savepos := 0;
  for i := 0 to sheep_n - 1 do
  begin
    if i > 0 then AppendChar(59);
    AppendInt(Trunc(sheep[i].hunger));
    AppendChar(44);
    AppendInt(Trunc(sheep[i].thirst));
    AppendChar(44);
    AppendInt(Trunc(sheep[i].wool));
  end;
  ls_set_item(StrAddr('mypaddockFlock'), StrLen('mypaddockFlock'),
    SaveAddr, savepos);
end;

function IsDigit(c: Integer): Boolean;
begin
  if (c >= 48) and (c <= 57) then IsDigit := true
  else IsDigit := false;
end;

procedure SkipEntry(base: Integer; n: Integer; var i: Integer);
begin
  while (i < n) and (BufByte(base, i) <> 59) do
    i := i + 1;
  if (i < n) and (BufByte(base, i) = 59) then
    i := i + 1;
end;

function ClampNeed(v: Integer): Double;
begin
  if v < 0 then ClampNeed := 0.0
  else if v > 100 then ClampNeed := 100.0
  else ClampNeed := Double(v);
end;

function LoadFlock: Boolean;
var
  base, n, i, v1, v2, v3: Integer;
  ok: Boolean;
begin
  base := SaveAddr;
  n := ls_get_item(StrAddr('mypaddockFlock'), StrLen('mypaddockFlock'),
    base, 2048);
  sheep_n := 0;
  if n <= 0 then
  begin
    LoadFlock := false;
    Exit;
  end;
  i := 0;
  while (i < n) and (sheep_n < MAX_SHEEP) do
  begin
    if BufByte(base, i) = 59 then
      i := i + 1
    else
    begin
      ok := true;
      v1 := 0;
      while (i < n) and IsDigit(BufByte(base, i)) do
      begin
        v1 := v1 * 10 + (BufByte(base, i) - 48);
        i := i + 1;
      end;
      if (i >= n) or (BufByte(base, i) <> 44) then ok := false
      else i := i + 1;
      v2 := 0;
      if ok then
      begin
        while (i < n) and IsDigit(BufByte(base, i)) do
        begin
          v2 := v2 * 10 + (BufByte(base, i) - 48);
          i := i + 1;
        end;
        if (i >= n) or (BufByte(base, i) <> 44) then ok := false
        else i := i + 1;
      end;
      v3 := 0;
      if ok then
      begin
        while (i < n) and IsDigit(BufByte(base, i)) do
        begin
          v3 := v3 * 10 + (BufByte(base, i) - 48);
          i := i + 1;
        end;
        if (i < n) and (BufByte(base, i) <> 59) then ok := false;
      end;
      if not ok then
        SkipEntry(base, n, i)
      else
      begin
        if (i < n) and (BufByte(base, i) = 59) then
          i := i + 1;
        next_sheep_id := next_sheep_id + 1;
        BoundsRandomPoint;
        sheep[sheep_n].id := next_sheep_id;
        sheep[sheep_n].x := rnd_x;
        sheep[sheep_n].y := rnd_y;
        sheep[sheep_n].target_x := rnd_x;
        sheep[sheep_n].target_y := rnd_y;
        sheep[sheep_n].facing := 1.0;
        sheep[sheep_n].hunger := ClampNeed(v1);
        sheep[sheep_n].thirst := ClampNeed(v2);
        sheep[sheep_n].wool := ClampNeed(v3);
        sheep[sheep_n].wander_timer := RngFloat * SHEEP_WANDER_MAX;
        sheep[sheep_n].bob_timer := RngFloat * 6.283185307179586;
        sheep[sheep_n].flash_timer := 0.0;
        sheep_n := sheep_n + 1;
      end;
    end;
  end;
  LoadFlock := sheep_n > 0;
end;

procedure SaveTroughs;
var
  i: Integer;
begin
  savepos := 0;
  for i := 0 to trough_n - 1 do
  begin
    if i > 0 then AppendChar(59);
    AppendInt(troughs[i].kind);
    AppendChar(44);
    AppendInt(Trunc(troughs[i].amount));
  end;
  ls_set_item(StrAddr('mypaddockTroughs'), StrLen('mypaddockTroughs'),
    SaveAddr, savepos);
end;

function LoadTroughs: Boolean;
var
  base, n, i, kind, amount: Integer;
  ok: Boolean;
begin
  base := SaveAddr;
  n := ls_get_item(StrAddr('mypaddockTroughs'), StrLen('mypaddockTroughs'),
    base, 2048);
  trough_n := 0;
  if n <= 0 then
  begin
    LoadTroughs := false;
    Exit;
  end;
  i := 0;
  while (i < n) and (trough_n < MAX_TROUGHS) do
  begin
    if BufByte(base, i) = 59 then
      i := i + 1
    else
    begin
      ok := true;
      kind := 0;
      while (i < n) and IsDigit(BufByte(base, i)) do
      begin
        kind := kind * 10 + (BufByte(base, i) - 48);
        i := i + 1;
      end;
      if (i >= n) or (BufByte(base, i) <> 44) then ok := false
      else i := i + 1;
      amount := 0;
      if ok then
      begin
        while (i < n) and IsDigit(BufByte(base, i)) do
        begin
          amount := amount * 10 + (BufByte(base, i) - 48);
          i := i + 1;
        end;
        if (i < n) and (BufByte(base, i) <> 59) then ok := false;
      end;
      if (not ok) or (kind < 0) or (kind > 1) then
        SkipEntry(base, n, i)
      else
      begin
        if (i < n) and (BufByte(base, i) = 59) then
          i := i + 1;
        BoundsRandomPoint;
        troughs[trough_n].kind := kind;
        troughs[trough_n].x := rnd_x;
        troughs[trough_n].y := rnd_y;
        troughs[trough_n].amount := Double(amount);
        trough_n := trough_n + 1;
      end;
    end;
  end;
  LoadTroughs := trough_n > 0;
end;

procedure SaveLastSeen(ms: Double);
var
  hi: Integer;
  lo: Double;
begin
  savepos := 0;
  hi := Trunc(ms / 1000000000.0);
  lo := ms - Double(hi) * 1000000000.0;
  AppendInt(hi);
  AppendChar(44);
  AppendInt(Trunc(lo));
  ls_set_item(StrAddr('mypaddockLastSeen'), StrLen('mypaddockLastSeen'),
    SaveAddr, savepos);
end;

function LoadLastSeen: Double;
var
  base, n, i, hi, lo: Integer;
begin
  base := SaveAddr;
  n := ls_get_item(StrAddr('mypaddockLastSeen'), StrLen('mypaddockLastSeen'),
    base, 80);
  if n <= 0 then
  begin
    LoadLastSeen := -1.0;
    Exit;
  end;
  hi := 0;
  i := 0;
  while (i < n) and IsDigit(BufByte(base, i)) do
  begin
    hi := hi * 10 + (BufByte(base, i) - 48);
    i := i + 1;
  end;
  if (i >= n) or (BufByte(base, i) <> 44) then
  begin
    LoadLastSeen := -1.0;
    Exit;
  end;
  i := i + 1;
  lo := 0;
  while (i < n) and IsDigit(BufByte(base, i)) do
  begin
    lo := lo * 10 + (BufByte(base, i) - 48);
    i := i + 1;
  end;
  LoadLastSeen := Double(hi) * 1000000000.0 + Double(lo);
end;

procedure SaveSfx(enabled: Boolean);
begin
  if enabled then savebuf[0] := 49
  else savebuf[0] := 48;
  ls_set_item(StrAddr('mypaddockSFX'), StrLen('mypaddockSFX'),
    SaveAddr, 1);
end;

function LoadSfx: Boolean;
var
  n: Integer;
begin
  n := ls_get_item(StrAddr('mypaddockSFX'), StrLen('mypaddockSFX'),
    SaveAddr, 8);
  if n <= 0 then LoadSfx := true
  else if BufByte(SaveAddr, 0) = 48 then LoadSfx := false
  else LoadSfx := true;
end;

procedure ResetSave;
begin
  ls_set_item(StrAddr('mypaddockCoins'), StrLen('mypaddockCoins'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockPaddockLevel'), StrLen('mypaddockPaddockLevel'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockDog'), StrLen('mypaddockDog'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockHands'), StrLen('mypaddockHands'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockFlock'), StrLen('mypaddockFlock'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockTroughs'), StrLen('mypaddockTroughs'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockLastSeen'), StrLen('mypaddockLastSeen'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockStatShear'), StrLen('mypaddockStatShear'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockStatSales'), StrLen('mypaddockStatSales'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockStatUpkeep'), StrLen('mypaddockStatUpkeep'), SaveAddr, 0);
  ls_set_item(StrAddr('mypaddockStatSpent'), StrLen('mypaddockStatSpent'), SaveAddr, 0);
end;

begin
end.
