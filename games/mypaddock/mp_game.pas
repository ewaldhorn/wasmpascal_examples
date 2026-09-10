unit mp_game;

{ M3: sheep/worker/trough/effect sim + live panel/shop text. Economy
  mutations (row purchases) and sound arrive in M4/M5. Port of game.odin's
  update procs + renderer.odin's panel/shop draw (draw parts). }

interface

uses
  mp_defs,
  mp_rand,
  mp_world,
  mp_draw,
  mp_render,
  mp_sprites,
  mp_sheep,
  mp_trough,
  mp_worker,
  mp_effect;

var
  cam_x: Double = 0.0;
  cam_y: Double = 0.0;
  paddock_level: Integer = 0;
  coins: Integer = 40;
  has_dog: Boolean = false;
  hand_count: Integer = 0;
  shop_open: Boolean = false;
  confirm_reset: Boolean = false;
  sfx_enabled: Boolean = true;
  dragging: Boolean = false;
  drag_moved: Boolean = false;
  drag_last_x: Integer = 0;
  drag_last_y: Integer = 0;
  mwr_x: Integer = 0;
  mwr_y: Integer = 0;
  mwr_w: Integer = 0;
  mwr_h: Integer = 0;
  mwr_scale: Double = 0.0;
  rr_x: Integer = 0;
  rr_y: Integer = 0;
  rr_w: Integer = 0;
  rr_h: Integer = 0;
  time_acc: Double = 0.0;
  wft_task: Integer = 0;
  wft_sheep: Integer = 0;
  wft_trough: Integer = 0;
  wft_ok: Boolean = false;

procedure GameInit(seed: Cardinal);

procedure GameUpdate(dt: Double);

procedure DrawFrame;

procedure HandlePointerDown(x, y: Integer);

procedure HandlePointerMove(x, y: Integer);

procedure HandlePointerUp(x, y: Integer);

procedure HandleKeyDown(addr, len: Integer);

function DbgSheepN: Integer;

function DbgWorkerN: Integer;

function DbgCoins: Integer;

function DbgS0x: Integer;

function DbgS0y: Integer;

function DbgS0Hunger: Integer;

function DbgTr0: Integer;

implementation

function InRect(x, y, rx, ry, rw, rh: Integer): Boolean;
begin
  if (x >= rx) and (x < rx + rw) and (y >= ry) and (y < ry + rh) then
    InRect := true
  else
    InRect := false;
end;

procedure ClampCamera;
var
  max_x, max_y: Double;
begin
  max_x := Double(WorldW(paddock_level) - VIEW_W);
  if max_x < 0.0 then max_x := 0.0;
  max_y := Double(WorldH(paddock_level) - VIEW_H);
  if max_y < 0.0 then max_y := 0.0;
  if cam_x < 0.0 then cam_x := 0.0;
  if cam_x > max_x then cam_x := max_x;
  if cam_y < 0.0 then cam_y := 0.0;
  if cam_y > max_y then cam_y := max_y;
end;

function CountTroughs(kind: Integer): Integer;
var
  i, n: Integer;
begin
  n := 0;
  for i := 0 to trough_n - 1 do
    if troughs[i].kind = kind then n := n + 1;
  CountTroughs := n;
end;

function SheepCap: Integer;
var
  food, water, trough_cap, pad_cap: Integer;
begin
  food := CountTroughs(TR_FOOD);
  water := CountTroughs(TR_WATER);
  if food < water then trough_cap := food * TROUGH_SHEEP_CAPACITY
  else trough_cap := water * TROUGH_SHEEP_CAPACITY;
  pad_cap := PaddockCap(paddock_level);
  if trough_cap < pad_cap then SheepCap := trough_cap
  else SheepCap := pad_cap;
end;

function UpkeepCost: Integer;
begin
  UpkeepCost := sheep_n * UPKEEP_PER_SHEEP + hand_count * UPKEEP_PER_HAND;
end;

function HandsRequiredFor(count: Integer): Integer;
begin
  if count < HAND_REQUIRED_AT then HandsRequiredFor := 0
  else HandsRequiredFor := 1 + (count - HAND_REQUIRED_AT) div HAND_CAPACITY_STEP;
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
  i, idx, earned: Integer;
  tx, ty: Double;
  valid: Boolean;
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
  for i := 0 to worker_n - 1 do
  begin
    if (workers[i].kind = WK_FARMER) and has_dog then
      workers[i].speed_mult := DOG_SPEED_MULT
    else
      workers[i].speed_mult := 1.0;
    if workers[i].state = WS_IDLE then
    begin
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
      end;
    end
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
              AddCoinEffect(sheep[idx].x, sheep[idx].y - 20.0, earned);
            end;
        end
        else if workers[i].task = WT_REFILL_FOOD then
        begin
          troughs[workers[i].target_trough].amount := TROUGH_CAPACITY;
          AddSparkle(troughs[workers[i].target_trough].x,
            troughs[workers[i].target_trough].y - 16.0);
        end
        else if workers[i].task = WT_REFILL_WATER then
        begin
          troughs[workers[i].target_trough].amount := TROUGH_CAPACITY;
          AddSparkle(troughs[workers[i].target_trough].x,
            troughs[workers[i].target_trough].y - 16.0);
        end;
        workers[i].state := WS_IDLE;
        workers[i].task := WT_NONE;
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

procedure MinimapWorld;
var
  s1, s2: Double;
begin
  s1 := Double(MM_W) / Double(WorldW(paddock_level));
  s2 := Double(MM_H) / Double(WorldH(paddock_level));
  if s1 < s2 then mwr_scale := s1 else mwr_scale := s2;
  mwr_w := Trunc(Double(WorldW(paddock_level)) * mwr_scale);
  mwr_h := Trunc(Double(WorldH(paddock_level)) * mwr_scale);
  mwr_x := MM_X + (MM_W - mwr_w) div 2;
  mwr_y := MM_Y + (MM_H - mwr_h) div 2;
end;

procedure ShopRowRect(i: Integer);
begin
  rr_x := SHOPROW_X;
  rr_y := SHOP_PANEL_Y + SHOP_ROWS_TOP + i * SHOP_ROW_H;
  rr_w := SHOPROW_W;
  rr_h := SHOPROW_H;
end;

function KeyEquals(addr, len, lit, litlen: Integer): Boolean;
var
  i: Integer;
begin
  KeyEquals := false;
  if len <> litlen then Exit;
  for i := 0 to len - 1 do
    if BufByte(addr, i) <> BufByte(lit, i) then Exit;
  KeyEquals := true;
end;

procedure HandleTap(x, y: Integer);
var
  world_x, world_y: Double;
begin
  if confirm_reset then
  begin
    if InRect(x, y, YESBTN_X, YESBTN_Y, YESBTN_W, YESBTN_H) then
    begin
      { M4 wires the real wipe+reload; M3 just closes. }
      confirm_reset := false;
      Exit;
    end;
    confirm_reset := false;
    Exit;
  end;
  if shop_open then
  begin
    if (x < SHOP_PANEL_X) or (x >= SHOP_PANEL_X + SHOP_PANEL_W) or
       (y < SHOP_PANEL_Y) or (y >= SHOP_PANEL_Y + SHOP_PANEL_H) then
      shop_open := false;
    { Row purchases land in M4; M3 only opens/closes the overlay. }
    Exit;
  end;
  if InRect(x, y, SHOPBTN_X, SHOPBTN_Y, SHOPBTN_W, SHOPBTN_H) then
  begin
    shop_open := true;
    Exit;
  end;
  if InRect(x, y, MUTEBTN_X, MUTEBTN_Y, MUTEBTN_W, MUTEBTN_H) then
  begin
    sfx_enabled := not sfx_enabled;
    Exit;
  end;
  if InRect(x, y, RSTBTN_X, RSTBTN_Y, RSTBTN_W, RSTBTN_H) then
  begin
    confirm_reset := true;
    Exit;
  end;
  MinimapWorld;
  if InRect(x, y, mwr_x, mwr_y, mwr_w, mwr_h) then
  begin
    world_x := Double(x - mwr_x) / mwr_scale;
    world_y := Double(y - mwr_y) / mwr_scale;
    cam_x := world_x - Double(VIEW_W) / 2.0;
    cam_y := world_y - Double(VIEW_H) / 2.0;
    ClampCamera;
  end;
end;

procedure GameInit(seed: Cardinal);
var
  i: Integer;
begin
  SeedRand(seed);
  bg_level := -1;
  cam_x := 0.0;
  cam_y := 0.0;
  paddock_level := 0;
  coins := START_COINS;
  has_dog := false;
  hand_count := 0;
  sheep_n := 0;
  worker_n := 0;
  trough_n := 0;
  effect_n := 0;
  next_sheep_id := 0;
  time_acc := 0.0;
  shop_open := false;
  confirm_reset := false;
  dragging := false;
  drag_moved := false;
  BoundsFor(0);
  for i := 1 to 2 do
  begin
    BoundsRandomPoint;
    if i = 1 then
      NewTrough(troughs[trough_n], TR_FOOD, rnd_x, rnd_y)
    else
      NewTrough(troughs[trough_n], TR_WATER, rnd_x, rnd_y);
    trough_n := trough_n + 1;
  end;
  for i := 1 to START_SHEEP do
  begin
    next_sheep_id := next_sheep_id + 1;
    NewSheep(sheep[sheep_n], next_sheep_id);
    sheep_n := sheep_n + 1;
  end;
  NewWorker(workers[worker_n], WK_FARMER);
  worker_n := worker_n + 1;
  EnsureBackground(0);
end;

procedure GameUpdate(dt: Double);
begin
  time_acc := time_acc + dt;
  BoundsFor(paddock_level);
  UpdateSheepNeeds(dt);
  UpdateWorkers(dt);
  UpdateEffects(dt);
end;

procedure DrawMinimap;
var
  vx, vy, vw, vh, i: Integer;
begin
  CFillRect(MM_X, MM_Y, MM_W, MM_H, PANEL_BG_R, PANEL_BG_G, PANEL_BG_B);
  CRectOutline(MM_X, MM_Y, MM_W, MM_H, PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
  MinimapWorld;
  CRectOutline(mwr_x, mwr_y, mwr_w, mwr_h, FENCE_R, FENCE_G, FENCE_B);
  for i := 0 to sheep_n - 1 do
    CFillCircle(mwr_x + Trunc(sheep[i].x * mwr_scale),
      mwr_y + Trunc(sheep[i].y * mwr_scale), 1,
      WOOL_HI_R, WOOL_HI_G, WOOL_HI_B);
  for i := 0 to worker_n - 1 do
  begin
    if workers[i].kind = WK_HAND then
      CFillCircle(mwr_x + Trunc(workers[i].x * mwr_scale),
        mwr_y + Trunc(workers[i].y * mwr_scale), 2,
        HAND_SHIRT_R, HAND_SHIRT_G, HAND_SHIRT_B)
    else
      CFillCircle(mwr_x + Trunc(workers[i].x * mwr_scale),
        mwr_y + Trunc(workers[i].y * mwr_scale), 2,
        FARMER_SHIRT_R, FARMER_SHIRT_G, FARMER_SHIRT_B);
  end;
  vx := mwr_x + Trunc(cam_x * mwr_scale);
  vy := mwr_y + Trunc(cam_y * mwr_scale);
  vw := Trunc(Double(VIEW_W) * mwr_scale);
  vh := Trunc(Double(VIEW_H) * mwr_scale);
  CRectOutline(vx, vy, vw, vh, HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
end;

procedure DrawButton(x, y, w, h, la, ll: Integer; fill_r, fill_g, fill_b,
  text_r, text_g, text_b: Integer);
begin
  CFillRect(x, y, w, h, fill_r, fill_g, fill_b);
  DrawText(x + (w - ll * 12) div 2, y + 9, la, ll, text_r, text_g, text_b);
end;

procedure DrawPanel;
var
  la, ll, n1, x: Integer;
begin
  CFillRect(PANEL_X, 0, RIGHT_PANEL_W, CANVAS_H, HUD_BG_R, HUD_BG_G, HUD_BG_B);
  DrawTextLarge(PANEL_X + PANEL_PAD, 14,
    StrAddr('PADDOCK'), StrLen('PADDOCK'),
    PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
  DrawLabelInt(PANEL_X + PANEL_PAD, 48,
    StrAddr('COINS: '), StrLen('COINS: '), coins,
    HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
  x := PANEL_X + PANEL_PAD;
  DrawText(x, 68, StrAddr('SHEEP: '), StrLen('SHEEP: '),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  x := x + 7 * 12;
  n1 := IntToBuf(sheep_n);
  DrawDigits(x, 68, n1, HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  x := x + n1 * 12;
  DrawText(x, 68, StrAddr('/'), StrLen('/'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  x := x + 12;
  DrawDigits(x, 68, IntToBuf(SheepCap),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  DrawLabelInt(PANEL_X + PANEL_PAD, 88,
    StrAddr('UPKEEP: -'), StrLen('UPKEEP: -'), UpkeepCost,
    BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  if shop_open then
    DrawButton(SHOPBTN_X, SHOPBTN_Y, SHOPBTN_W, SHOPBTN_H,
      StrAddr('SHOP'), StrLen('SHOP'),
      BTN_SEL_R, BTN_SEL_G, BTN_SEL_B, HUD_BG_R, HUD_BG_G, HUD_BG_B)
  else
    DrawButton(SHOPBTN_X, SHOPBTN_Y, SHOPBTN_W, SHOPBTN_H,
      StrAddr('SHOP'), StrLen('SHOP'),
      BTN_BG_R, BTN_BG_G, BTN_BG_B,
      HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  if sfx_enabled then begin la := StrAddr('SFX ON'); ll := 6; end
  else begin la := StrAddr('SFX OFF'); ll := 7; end;
  if sfx_enabled then
    DrawButton(MUTEBTN_X, MUTEBTN_Y, MUTEBTN_W, MUTEBTN_H, la, ll,
      BTN_BG_R, BTN_BG_G, BTN_BG_B,
      HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B)
  else
    DrawButton(MUTEBTN_X, MUTEBTN_Y, MUTEBTN_W, MUTEBTN_H, la, ll,
      BTN_DIS_R, BTN_DIS_G, BTN_DIS_B,
      HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  DrawMinimap;
  DrawText(PANEL_X + PANEL_PAD, MM_Y + MM_H + 14,
    StrAddr('DRAG/ARROWS: SCROLL'), StrLen('DRAG/ARROWS: SCROLL'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  DrawText(PANEL_X + PANEL_PAD, MM_Y + MM_H + 32,
    StrAddr('CLICK MAP: JUMP'), StrLen('CLICK MAP: JUMP'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  CFillRect(RSTBTN_X, RSTBTN_Y, RSTBTN_W, RSTBTN_H,
    BTN_BG_R, BTN_BG_G, BTN_BG_B);
  CRectOutline(RSTBTN_X, RSTBTN_Y, RSTBTN_W, RSTBTN_H,
    BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  DrawText(RSTBTN_X + (RSTBTN_W - 5 * 12) div 2, RSTBTN_Y + 7,
    StrAddr('RESET'), StrLen('RESET'), BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
end;

procedure DrawShopRowText(i, na, nl, ca, cl: Integer; avail: Boolean);
begin
  ShopRowRect(i);
  if avail then
    CFillRect(rr_x, rr_y, rr_w, rr_h, BTN_BG_R, BTN_BG_G, BTN_BG_B)
  else
    CFillRect(rr_x, rr_y, rr_w, rr_h, BTN_DIS_R, BTN_DIS_G, BTN_DIS_B);
  DrawText(rr_x + 10, rr_y + (rr_h - 14) div 2, na, nl,
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  if avail then
    DrawText(rr_x + rr_w - cl * 12 - 10, rr_y + (rr_h - 14) div 2, ca, cl,
      HUD_COIN_R, HUD_COIN_G, HUD_COIN_B)
  else
    DrawText(rr_x + rr_w - cl * 12 - 10, rr_y + (rr_h - 14) div 2, ca, cl,
      HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
end;

procedure DrawShopRowCoins(i, na, nl, v: Integer; plus: Boolean; avail: Boolean);
var
  n, total, cost_x, cr, cg, cb: Integer;
begin
  ShopRowRect(i);
  if avail then
    CFillRect(rr_x, rr_y, rr_w, rr_h, BTN_BG_R, BTN_BG_G, BTN_BG_B)
  else
    CFillRect(rr_x, rr_y, rr_w, rr_h, BTN_DIS_R, BTN_DIS_G, BTN_DIS_B);
  DrawText(rr_x + 10, rr_y + (rr_h - 14) div 2, na, nl,
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  n := IntToBuf(v);
  total := n + 6;
  if plus then total := total + 1;
  cost_x := rr_x + rr_w - total * 12 - 10;
  if avail then begin cr := HUD_COIN_R; cg := HUD_COIN_G; cb := HUD_COIN_B; end
  else begin cr := HUD_TEXT_R; cg := HUD_TEXT_G; cb := HUD_TEXT_B; end;
  if plus then
  begin
    DrawText(cost_x, rr_y + (rr_h - 14) div 2,
      StrAddr('+'), StrLen('+'), cr, cg, cb);
    cost_x := cost_x + 12;
  end;
  DrawDigits(cost_x, rr_y + (rr_h - 14) div 2, n, cr, cg, cb);
  DrawText(cost_x + n * 12, rr_y + (rr_h - 14) div 2,
    StrAddr(' COINS'), StrLen(' COINS'), cr, cg, cb);
end;

function BuySheepCost(count: Integer): Integer;
begin
  BuySheepCost := 20 + count * 20;
end;

function ExpandCost(level: Integer): Integer;
begin
  ExpandCost := 80 + level * 120;
end;

function HandCost(count: Integer): Integer;
begin
  HandCost := FARM_HAND_BASE_COST + count * FARM_HAND_COST_STEP;
end;

procedure DrawShop;
var
  ok0: Boolean;
  cost0: Integer;
begin
  DimScreen;
  CFillRect(SHOP_PANEL_X, SHOP_PANEL_Y, SHOP_PANEL_W, SHOP_PANEL_H,
    PANEL_BG_R, PANEL_BG_G, PANEL_BG_B);
  CRectThick(SHOP_PANEL_X, SHOP_PANEL_Y, SHOP_PANEL_W, SHOP_PANEL_H, 2,
    PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
  DrawTextLarge(SHOP_PANEL_X + 24, SHOP_PANEL_Y + 16,
    StrAddr('SHOP'), StrLen('SHOP'), PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
  DrawLabelInt(SHOP_PANEL_X + 24, SHOP_PANEL_Y + 56,
    StrAddr('COINS: '), StrLen('COINS: '), coins,
    HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
  DrawLabelInt(SHOP_PANEL_X + 24, SHOP_PANEL_Y + 76,
    StrAddr('UPKEEP: -'), StrLen('UPKEEP: -'), UpkeepCost,
    BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  ok0 := (sheep_n < SheepCap) and
    ((sheep_n < DOG_REQUIRED_AT) or has_dog) and
    (hand_count >= HandsRequiredFor(sheep_n + 1));
  cost0 := BuySheepCost(sheep_n);
  if sheep_n >= PaddockCap(paddock_level) then
    DrawShopRowText(0, StrAddr('BUY SHEEP'), StrLen('BUY SHEEP'),
      StrAddr('NEED PADDOCK'), StrLen('NEED PADDOCK'), false)
  else if sheep_n >= SheepCap then
    DrawShopRowText(0, StrAddr('BUY SHEEP'), StrLen('BUY SHEEP'),
      StrAddr('NEED TROUGH'), StrLen('NEED TROUGH'), false)
  else if (sheep_n >= DOG_REQUIRED_AT) and (not has_dog) then
    DrawShopRowText(0, StrAddr('BUY SHEEP'), StrLen('BUY SHEEP'),
      StrAddr('NEED SHEEP DOG'), StrLen('NEED SHEEP DOG'), false)
  else if hand_count < HandsRequiredFor(sheep_n + 1) then
    DrawShopRowText(0, StrAddr('BUY SHEEP'), StrLen('BUY SHEEP'),
      StrAddr('NEED FARM HAND'), StrLen('NEED FARM HAND'), false)
  else
    DrawShopRowCoins(0, StrAddr('BUY SHEEP'), StrLen('BUY SHEEP'),
      cost0, false, ok0 and (coins >= cost0));
  if paddock_level >= MAX_PADDOCK_LEVEL then
    DrawShopRowText(1, StrAddr('EXPAND PADDOCK'), StrLen('EXPAND PADDOCK'),
      StrAddr('MAXED'), StrLen('MAXED'), false)
  else
    DrawShopRowCoins(1, StrAddr('EXPAND PADDOCK'), StrLen('EXPAND PADDOCK'),
      ExpandCost(paddock_level), false, coins >= ExpandCost(paddock_level));
  if has_dog then
    DrawShopRowText(2, StrAddr('HIRE SHEEP DOG'), StrLen('HIRE SHEEP DOG'),
      StrAddr('OWNED'), StrLen('OWNED'), false)
  else
    DrawShopRowCoins(2, StrAddr('HIRE SHEEP DOG'), StrLen('HIRE SHEEP DOG'),
      DOG_HIRE_COST, false, coins >= DOG_HIRE_COST);
  if sheep_n > SHEEP_MIN_KEPT then
    DrawShopRowCoins(3, StrAddr('SELL SHEEP'), StrLen('SELL SHEEP'),
      SHEEP_SELL_VALUE, true, true)
  else
    DrawShopRowText(3, StrAddr('SELL SHEEP'), StrLen('SELL SHEEP'),
      StrAddr('MIN 1 SHEEP'), StrLen('MIN 1 SHEEP'), false);
  DrawShopRowCoins(4, StrAddr('FOOD TROUGH (1)'), StrLen('FOOD TROUGH (1)'),
    TROUGH_COST, false, coins >= TROUGH_COST);
  DrawShopRowCoins(5, StrAddr('WATER TROUGH (1)'), StrLen('WATER TROUGH (1)'),
    TROUGH_COST, false, coins >= TROUGH_COST);
  DrawShopRowCoins(6, StrAddr('HIRE FARM HAND (0)'), StrLen('HIRE FARM HAND (0)'),
    HandCost(hand_count), false, coins >= HandCost(hand_count));
  DrawText(SHOP_PANEL_X + 20, SHOP_PANEL_Y + SHOP_PANEL_H - 24,
    StrAddr('[ESC OR B TO CLOSE]'), StrLen('[ESC OR B TO CLOSE]'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
end;

procedure DrawResetConfirm;
begin
  DimScreen;
  CFillRect(RESET_X, RESET_Y, RESET_W, RESET_H,
    PANEL_BG_R, PANEL_BG_G, PANEL_BG_B);
  CRectThick(RESET_X, RESET_Y, RESET_W, RESET_H, 2,
    BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  DrawTextLarge(RESET_X + (RESET_W - 11 * 24) div 2, RESET_Y + 18,
    StrAddr('RESET GAME?'), StrLen('RESET GAME?'),
    BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  DrawText(RESET_X + (RESET_W - 31 * 12) div 2, RESET_Y + 54,
    StrAddr('THIS DELETES YOUR SAVE FOR GOOD'),
    StrLen('THIS DELETES YOUR SAVE FOR GOOD'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  CFillRect(YESBTN_X, YESBTN_Y, YESBTN_W, YESBTN_H,
    BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  DrawText(YESBTN_X + (YESBTN_W - 10 * 12) div 2, YESBTN_Y + 11,
    StrAddr('YES, RESET'), StrLen('YES, RESET'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  CFillRect(NOBTN_X, NOBTN_Y, NOBTN_W, NOBTN_H,
    BTN_BG_R, BTN_BG_G, BTN_BG_B);
  DrawText(NOBTN_X + (NOBTN_W - 6 * 12) div 2, NOBTN_Y + 11,
    StrAddr('CANCEL'), StrLen('CANCEL'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
end;

procedure DrawFrame;
var
  i: Integer;
begin
  EnsureBackground(paddock_level);
  CFillRect(0, 0, CANVAS_W, CANVAS_H, SKY_R, SKY_G, SKY_B);
  BlitWorld(cam_x, cam_y);
  for i := 0 to trough_n - 1 do
    DrawTroughSprite(troughs[i], cam_x, cam_y);
  for i := 0 to worker_n - 1 do
    DrawWorkerSprite(workers[i], cam_x, cam_y, has_dog);
  for i := 0 to sheep_n - 1 do
    DrawSheepSprite(sheep[i], cam_x, cam_y);
  for i := 0 to effect_n - 1 do
    DrawEffectSprite(effects[i], cam_x, cam_y);
  DrawPanel;
  if shop_open then DrawShop;
  if confirm_reset then DrawResetConfirm;
end;

procedure HandlePointerDown(x, y: Integer);
begin
  if shop_open or confirm_reset or (x >= VIEW_W) then Exit;
  dragging := true;
  drag_moved := false;
  drag_last_x := x;
  drag_last_y := y;
end;

procedure HandlePointerMove(x, y: Integer);
var
  dx, dy: Integer;
begin
  if not dragging then Exit;
  dx := x - drag_last_x;
  dy := y - drag_last_y;
  if (dx > DRAG_THRESHOLD) or (dx < -DRAG_THRESHOLD) or
     (dy > DRAG_THRESHOLD) or (dy < -DRAG_THRESHOLD) then
    drag_moved := true;
  cam_x := cam_x - Double(dx);
  cam_y := cam_y - Double(dy);
  ClampCamera;
  drag_last_x := x;
  drag_last_y := y;
end;

procedure HandlePointerUp(x, y: Integer);
var
  was_drag: Boolean;
begin
  was_drag := dragging and drag_moved;
  dragging := false;
  drag_moved := false;
  if not was_drag then HandleTap(x, y);
end;

function DbgSheepN: Integer;
begin
  DbgSheepN := sheep_n;
end;

function DbgWorkerN: Integer;
begin
  DbgWorkerN := worker_n;
end;

function DbgCoins: Integer;
begin
  DbgCoins := coins;
end;

function DbgS0x: Integer;
begin
  DbgS0x := Trunc(sheep[0].x * 100.0);
end;

function DbgS0y: Integer;
begin
  DbgS0y := Trunc(sheep[0].y * 100.0);
end;

function DbgS0Hunger: Integer;
begin
  DbgS0Hunger := Trunc(sheep[0].hunger);
end;

function DbgTr0: Integer;
begin
  DbgTr0 := Trunc(troughs[0].amount * 100.0);
end;

procedure HandleKeyDown(addr, len: Integer);
var
  c: Integer;
begin
  if len = 1 then
  begin
    c := BufByte(addr, 0);
    if (c >= 65) and (c <= 90) then c := c + 32;
    if c = 98 then shop_open := not shop_open
    else if c = 109 then sfx_enabled := not sfx_enabled;
    Exit;
  end;
  if KeyEquals(addr, len, StrAddr('Escape'), StrLen('Escape')) then
  begin
    shop_open := false;
    confirm_reset := false;
  end
  else if KeyEquals(addr, len, StrAddr('ArrowUp'), StrLen('ArrowUp')) then
  begin
    cam_y := cam_y - PAN_STEP;
    ClampCamera;
  end
  else if KeyEquals(addr, len, StrAddr('ArrowDown'), StrLen('ArrowDown')) then
  begin
    cam_y := cam_y + PAN_STEP;
    ClampCamera;
  end
  else if KeyEquals(addr, len, StrAddr('ArrowLeft'), StrLen('ArrowLeft')) then
  begin
    cam_x := cam_x - PAN_STEP;
    ClampCamera;
  end
  else if KeyEquals(addr, len, StrAddr('ArrowRight'), StrLen('ArrowRight')) then
  begin
    cam_x := cam_x + PAN_STEP;
    ClampCamera;
  end;
end;

begin
end.
