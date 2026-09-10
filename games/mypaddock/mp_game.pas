unit mp_game;

{ M7: game orchestration (init, frame update, input, panel/dialogs, save
  glue, debug getters). Economy lives in mp_shop, sim glue in mp_sim;
  uses chain is game -> sim -> shop, never the reverse. }

interface

uses
  mp_defs,
  mp_rand,
  mp_world,
  mp_draw,
  mp_render,
  mp_sprites,
  mp_sheep,
  mp_sound,
  mp_trough,
  mp_worker,
  mp_store,
  mp_env,
  mp_shop,
  mp_sim;

var
  cam_x: Double = 0.0;
  cam_y: Double = 0.0;
  shop_open: Boolean = false;
  confirm_reset: Boolean = false;
  budget_open: Boolean = false;
  { Mute state lives in mp_sound as sfx_on (avoids a unit cycle). }
  dragging: Boolean = false;
  drag_moved: Boolean = false;
  drag_last_x: Integer = 0;
  drag_last_y: Integer = 0;
  mwr_x: Integer = 0;
  mwr_y: Integer = 0;
  mwr_w: Integer = 0;
  mwr_h: Integer = 0;
  mwr_scale: Double = 0.0;
  time_acc: Double = 0.0;
  wall_ms_origin: Double = 0.0;
  upkeep_timer: Double = 60.0;
  autosave_timer: Double = 0.0;
  welcome_timer: Double = 0.0;
  bill_notice_timer: Double = 0.0;
  offline_coins_earned: Integer = 0;
  bill_sheep_sold: Integer = 0;
  bill_hands_sold: Integer = 0;
  bill_dog_sold: Boolean = false;

procedure GameInit(seed: Cardinal; now_ms: Double);

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

function DbgS0Wool: Integer;

function DbgSheepCap: Integer;

function DbgTr0: Integer;

function DbgWelcome: Integer;

function DbgOfflineCoins: Integer;

function DbgStatShear: Integer;

function DbgStatSales: Integer;

function DbgStatUpkeep: Integer;

function DbgStatSpent: Integer;

function DbgBudgetOpen: Integer;

implementation

function InRect(x, y, rx, ry, rw, rh: Integer): Boolean;
begin
  InRect := (x >= rx) and (x < rx + rw) and (y >= ry) and (y < ry + rh);
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

function CurrentWallMs: Double;
begin
  CurrentWallMs := wall_ms_origin + time_acc * 1000.0;
end;

procedure SaveAll;
var
  dog_v: Integer;
begin
  SaveInt(StrAddr('mypaddockCoins'), StrLen('mypaddockCoins'), coins);
  SaveInt(StrAddr('mypaddockPaddockLevel'), StrLen('mypaddockPaddockLevel'), paddock_level);
  if has_dog then dog_v := 1 else dog_v := 0;
  SaveInt(StrAddr('mypaddockDog'), StrLen('mypaddockDog'), dog_v);
  SaveInt(StrAddr('mypaddockHands'), StrLen('mypaddockHands'), hand_count);
  SaveFlock;
  SaveTroughs;
  SaveLastSeen(CurrentWallMs);
  SaveSfx(sfx_on);
  SaveInt(StrAddr('mypaddockStatShear'), StrLen('mypaddockStatShear'), stat_shear);
  SaveInt(StrAddr('mypaddockStatSales'), StrLen('mypaddockStatSales'), stat_sales);
  SaveInt(StrAddr('mypaddockStatUpkeep'), StrLen('mypaddockStatUpkeep'), stat_upkeep);
  SaveInt(StrAddr('mypaddockStatSpent'), StrLen('mypaddockStatSpent'), stat_spent);
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

procedure HandleShopClick(x, y: Integer);
var
  i: Integer;
  ok: Boolean;
begin
  if (x < SHOP_PANEL_X) or (x >= SHOP_PANEL_X + SHOP_PANEL_W) or
     (y < SHOP_PANEL_Y) or (y >= SHOP_PANEL_Y + SHOP_PANEL_H) then
  begin
    shop_open := false;
    Exit;
  end;
  for i := 0 to SHOP_ROW_COUNT - 1 do
  begin
    ShopRowRect(i);
    if not InRect(x, y, rr_x, rr_y, rr_w, rr_h) then
      continue;
    if i = 0 then ok := TryBuySheep
    else if i = 1 then ok := TryExpandPaddock
    else if i = 2 then ok := TryHireDog
    else if i = 3 then ok := SellOneSheep
    else if i = 4 then ok := TryBuyTrough(TR_FOOD)
    else if i = 5 then ok := TryBuyTrough(TR_WATER)
    else ok := TryHireHand;
    if not ok then PlayDenied
    else if i = 3 then PlayCoin
    else PlayPurchase;
    Exit;
  end;
end;

procedure HandleTap(x, y: Integer);
var
  world_x, world_y: Double;
begin
  if confirm_reset then
  begin
    if InRect(x, y, YESBTN_X, YESBTN_Y, YESBTN_W, YESBTN_H) then
    begin
      ResetSave;
      mp_js_reload;
      Exit;
    end;
    confirm_reset := false;
    Exit;
  end;
  if shop_open then
  begin
    HandleShopClick(x, y);
    Exit;
  end;
  if budget_open then
  begin
    budget_open := false;
    Exit;
  end;
  if InRect(x, y, SHOPBTN_X, SHOPBTN_Y, SHOPBTN_W, SHOPBTN_H) then
  begin
    shop_open := true;
    budget_open := false;
    Exit;
  end;
  if InRect(x, y, MUTEBTN_X, MUTEBTN_Y, MUTEBTN_W, MUTEBTN_H) then
  begin
    sfx_on := not sfx_on;
    SaveSfx(sfx_on);
    Exit;
  end;
  if InRect(x, y, RSTBTN_X, RSTBTN_Y, RSTBTN_W, RSTBTN_H) then
  begin
    confirm_reset := true;
    Exit;
  end;
  if InRect(x, y, BUDGETBTN_X, BUDGETBTN_Y, BUDGETBTN_W, BUDGETBTN_H) then
  begin
    budget_open := true;
    shop_open := false;
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

procedure GameInit(seed: Cardinal; now_ms: Double);
var
  i, cycles, earned_before: Integer;
  last_seen, elapsed: Double;
begin
  SeedRand(seed);
  wall_ms_origin := now_ms;
  bg_level := -1;
  cam_x := 0.0;
  cam_y := 0.0;
  coins := LoadInt(StrAddr('mypaddockCoins'), StrLen('mypaddockCoins'), START_COINS);
  paddock_level := LoadInt(StrAddr('mypaddockPaddockLevel'), StrLen('mypaddockPaddockLevel'), 0);
  has_dog := LoadInt(StrAddr('mypaddockDog'), StrLen('mypaddockDog'), 0) <> 0;
  hand_count := LoadInt(StrAddr('mypaddockHands'), StrLen('mypaddockHands'), 0);
  stat_shear := LoadInt(StrAddr('mypaddockStatShear'), StrLen('mypaddockStatShear'), 0);
  stat_sales := LoadInt(StrAddr('mypaddockStatSales'), StrLen('mypaddockStatSales'), 0);
  stat_upkeep := LoadInt(StrAddr('mypaddockStatUpkeep'), StrLen('mypaddockStatUpkeep'), 0);
  stat_spent := LoadInt(StrAddr('mypaddockStatSpent'), StrLen('mypaddockStatSpent'), 0);
  sheep_n := 0;
  worker_n := 0;
  trough_n := 0;
  effect_n := 0;
  next_sheep_id := 0;
  time_acc := 0.0;
  upkeep_timer := UPKEEP_INTERVAL;
  autosave_timer := 0.0;
  welcome_timer := 0.0;
  bill_notice_timer := 0.0;
  offline_coins_earned := 0;
  shop_open := false;
  confirm_reset := false;
  dragging := false;
  drag_moved := false;
  BoundsFor(paddock_level);
  if not LoadTroughs then
  begin
    for i := 1 to 2 do
    begin
      BoundsRandomPoint;
      if i = 1 then
        NewTrough(troughs[trough_n], TR_FOOD, rnd_x, rnd_y)
      else
        NewTrough(troughs[trough_n], TR_WATER, rnd_x, rnd_y);
      trough_n := trough_n + 1;
    end;
  end;
  if not LoadFlock then
    for i := 1 to START_SHEEP do
    begin
      next_sheep_id := next_sheep_id + 1;
      NewSheep(sheep[sheep_n], next_sheep_id);
      sheep_n := sheep_n + 1;
    end;
  NewWorker(workers[worker_n], WK_FARMER);
  worker_n := worker_n + 1;
  for i := 1 to hand_count do
  begin
    { No Break-in-if (targets the if, not the loop); guard instead. }
    if worker_n < MAX_WORKERS then
    begin
      NewWorker(workers[worker_n], WK_HAND);
      worker_n := worker_n + 1;
    end;
  end;
  sfx_on := LoadSfx;
  EnsureBackground(paddock_level);
  last_seen := LoadLastSeen;
  if last_seen >= 0.0 then
  begin
    elapsed := (now_ms - last_seen) / 1000.0;
    if elapsed < 0.0 then elapsed := 0.0;
    if elapsed > OFFLINE_CAP_SECONDS then elapsed := OFFLINE_CAP_SECONDS;
    if elapsed > OFFLINE_MIN_SECONDS then
    begin
      earned_before := coins;
      { M6b: offline runs at 1/10th speed but full pay — scale the window,
        not the rates. Upkeep cycles below use the scaled elapsed too. }
      elapsed := elapsed / OFFLINE_TIME_DIV;
      ApplyOfflineProgress(elapsed);
      cycles := Trunc(elapsed / UPKEEP_INTERVAL);
      bill_sheep_sold := 0;
      bill_hands_sold := 0;
      bill_dog_sold := false;
      for i := 1 to cycles do
      begin
        ChargeUpkeep;
        bill_sheep_sold := bill_sheep_sold + cs_sheep;
        bill_hands_sold := bill_hands_sold + cs_hands;
        if cs_dog then bill_dog_sold := true;
      end;
      if (bill_sheep_sold > 0) or (bill_hands_sold > 0) or bill_dog_sold then
        bill_notice_timer := 6.0
      else if coins > earned_before then
      begin
        offline_coins_earned := coins - earned_before;
        welcome_timer := 6.0;
      end;
    end;
  end;
end;

procedure GameUpdate(dt: Double);
var
  sold_any: Boolean;
begin
  time_acc := time_acc + dt;
  if welcome_timer > 0.0 then
    welcome_timer := welcome_timer - dt;
  if bill_notice_timer > 0.0 then
    bill_notice_timer := bill_notice_timer - dt;
  BoundsFor(paddock_level);
  UpdateSheepNeeds(dt);
  UpdateWorkers(dt);
  UpdateEffects(dt);
  upkeep_timer := upkeep_timer - dt;
  if upkeep_timer <= 0.0 then
  begin
    upkeep_timer := upkeep_timer + UPKEEP_INTERVAL;
    ChargeUpkeep;
    sold_any := (cs_sheep > 0) or (cs_hands > 0) or cs_dog;
    if sold_any then
    begin
      bill_sheep_sold := cs_sheep;
      bill_hands_sold := cs_hands;
      bill_dog_sold := cs_dog;
      bill_notice_timer := 6.0;
      PlaySold;
    end;
  end;
  autosave_timer := autosave_timer + dt;
  if autosave_timer >= AUTOSAVE_INTERVAL then
  begin
    autosave_timer := 0.0;
    SaveAll;
  end;
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
  DrawText(x, 68, StrAddr('//'), 1,
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
  if sfx_on then begin la := StrAddr('SFX ON'); ll := 6; end
  else begin la := StrAddr('SFX OFF'); ll := 7; end;
  if sfx_on then
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
  if budget_open then
    DrawButton(BUDGETBTN_X, BUDGETBTN_Y, BUDGETBTN_W, BUDGETBTN_H,
      StrAddr('BUDGET'), StrLen('BUDGET'),
      BTN_SEL_R, BTN_SEL_G, BTN_SEL_B, HUD_BG_R, HUD_BG_G, HUD_BG_B)
  else
    DrawButton(BUDGETBTN_X, BUDGETBTN_Y, BUDGETBTN_W, BUDGETBTN_H,
      StrAddr('BUDGET'), StrLen('BUDGET'),
      BTN_BG_R, BTN_BG_G, BTN_BG_B,
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

{ Budget overlay (new feature, no Odin equivalent): lifetime income vs
  expenses. Sign chars use doubled literals (single-char StrAddr trap). }
procedure DrawSignedLine(x, y, la, ll, v: Integer; income: Boolean);
var
  n, dv, vx, sr, sg, sb: Integer;
  neg: Boolean;
begin
  DrawText(x, y, la, ll, HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  if income then
  begin sr := HUD_COIN_R; sg := HUD_COIN_G; sb := HUD_COIN_B; end
  else
  begin sr := BAR_BAD_R; sg := BAR_BAD_G; sb := BAR_BAD_B; end;
  { v is already signed (expense call sites pass negated counters);
    a zero expense still reads as -0. }
  dv := v;
  neg := (dv < 0) or ((dv = 0) and (not income));
  if dv < 0 then dv := -dv;
  n := IntToBuf(dv);
  vx := x + BUD_W - 40 - (1 + n) * 12;
  if neg then
    DrawText(vx, y, StrAddr('--'), 1, sr, sg, sb)
  else
    DrawText(vx, y, StrAddr('++'), 1, sr, sg, sb);
  DrawDigits(vx + 12, y, n, sr, sg, sb);
end;

procedure DrawBudget;
var
  y, net: Integer;
begin
  DimScreen;
  CFillRect(BUD_X, BUD_Y, BUD_W, BUD_H, PANEL_BG_R, PANEL_BG_G, PANEL_BG_B);
  CRectThick(BUD_X, BUD_Y, BUD_W, BUD_H, 2, PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
  DrawTextLarge(BUD_X + 24, BUD_Y + 16,
    StrAddr('BUDGET'), StrLen('BUDGET'), PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
  DrawText(BUD_X + 24, BUD_Y + 48,
    StrAddr('LIFETIME TOTALS'), StrLen('LIFETIME TOTALS'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  y := BUD_Y + 70;
  DrawSignedLine(BUD_X + 20, y, StrAddr('SHEARING'), StrLen('SHEARING'),
    stat_shear, true);
  y := y + 32;
  DrawSignedLine(BUD_X + 20, y, StrAddr('SALES'), StrLen('SALES'),
    stat_sales, true);
  y := y + 32;
  DrawSignedLine(BUD_X + 20, y, StrAddr('UPKEEP'), StrLen('UPKEEP'),
    -stat_upkeep, false);
  y := y + 32;
  DrawSignedLine(BUD_X + 20, y, StrAddr('PURCHASES'), StrLen('PURCHASES'),
    -stat_spent, false);
  y := y + 32;
  DrawSignedLine(BUD_X + 20, y, StrAddr('START'), StrLen('START'),
    START_COINS, true);
  y := y + 32;
  net := START_COINS + stat_shear + stat_sales - stat_upkeep - stat_spent;
  DrawSignedLine(BUD_X + 20, y, StrAddr('NET'), StrLen('NET'), net, net >= 0);
  DrawText(BUD_X + (BUD_W - 18 * 12) div 2, BUD_Y + BUD_H - 24,
    StrAddr('[E OR ESC TO CLOSE]'), StrLen('[E OR ESC TO CLOSE]'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
end;

procedure DrawWelcomeBanner;
var
  w, h, x, y, n, total, cx: Integer;
begin
  w := 420;
  h := 40;
  x := (VIEW_W - w) div 2;
  y := 16;
  CFillRect(x, y, w, h, PANEL_BG_R, PANEL_BG_G, PANEL_BG_B);
  CRectThick(x, y, w, h, 2, PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
  n := IntToBuf(offline_coins_earned);
  total := 22 + n + 6;
  cx := x + (w - total * 12) div 2;
  DrawText(cx, y + 13,
    StrAddr('WHILE YOU WERE AWAY: +'), StrLen('WHILE YOU WERE AWAY: +'),
    HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
  cx := cx + 22 * 12;
  DrawDigits(cx, y + 13, n, HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
  DrawText(cx + n * 12, y + 13,
    StrAddr(' COINS'), StrLen(' COINS'),
    HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
end;

procedure DrawBillNotice;
var
  w, h, x, y, n, total, cx: Integer;
  bankrupt: Boolean;
begin
  w := 460;
  h := 40;
  x := (VIEW_W - w) div 2;
  y := 16;
  CFillRect(x, y, w, h, PANEL_BG_R, PANEL_BG_G, PANEL_BG_B);
  CRectThick(x, y, w, h, 2, BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  bankrupt := (sheep_n <= SHEEP_MIN_KEPT) and (not has_dog) and
    (hand_count = 0) and (coins = 0);
  if bankrupt then
  begin
    DrawText(x + (w - 39 * 12) div 2, y + 13,
      StrAddr('BANKRUPT - SOLD DOWN TO YOUR LAST SHEEP'),
      StrLen('BANKRUPT - SOLD DOWN TO YOUR LAST SHEEP'),
      BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
    Exit;
  end;
  total := 29;
  if bill_sheep_sold > 0 then
  begin
    n := IntToBuf(bill_sheep_sold);
    total := total + 1 + n + 6;
  end;
  if bill_hands_sold > 0 then
  begin
    n := IntToBuf(bill_hands_sold);
    total := total + 3 + n + 10;
    if bill_hands_sold > 1 then total := total + 1;
  end;
  if bill_dog_sold then
  begin
    if (bill_sheep_sold > 0) or (bill_hands_sold > 0) then
      total := total + 10
    else
      total := total + 14;
  end;
  cx := x + (w - total * 12) div 2;
  DrawText(cx, y + 13,
    StrAddr('COULDN''T PAY THE BILLS - SOLD'),
    StrLen('COULDN''T PAY THE BILLS - SOLD'),
    BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  cx := cx + 29 * 12;
  if bill_sheep_sold > 0 then
  begin
    n := IntToBuf(bill_sheep_sold);
    DrawText(cx, y + 13, StrAddr('  '), 1,
      BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
    DrawDigits(cx + 12, y + 13, n, BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
    DrawText(cx + 12 + n * 12, y + 13,
      StrAddr(' SHEEP'), StrLen(' SHEEP'),
      BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
    cx := cx + (1 + n + 6) * 12;
  end;
  if bill_hands_sold > 0 then
  begin
    n := IntToBuf(bill_hands_sold);
    DrawText(cx, y + 13, StrAddr(' + '), StrLen(' + '),
      BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
    DrawDigits(cx + 3 * 12, y + 13, n, BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
    if bill_hands_sold > 1 then
    begin
      DrawText(cx + (3 + n) * 12, y + 13,
        StrAddr(' FARM HANDS'), StrLen(' FARM HANDS'),
        BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
      cx := cx + (3 + n + 11) * 12;
    end
    else
    begin
      DrawText(cx + (3 + n) * 12, y + 13,
        StrAddr(' FARM HAND'), StrLen(' FARM HAND'),
        BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
      cx := cx + (3 + n + 10) * 12;
    end;
  end;
  if bill_dog_sold then
  begin
    if (bill_sheep_sold > 0) or (bill_hands_sold > 0) then
      DrawText(cx, y + 13, StrAddr(' + THE DOG'), StrLen(' + THE DOG'),
        BAR_BAD_R, BAR_BAD_G, BAR_BAD_B)
    else
      DrawText(cx, y + 13, StrAddr(' THE SHEEP DOG'), StrLen(' THE SHEEP DOG'),
        BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  end;
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
  if budget_open then DrawBudget;
  if confirm_reset then DrawResetConfirm;
  if bill_notice_timer > 0.0 then DrawBillNotice
  else if welcome_timer > 0.0 then DrawWelcomeBanner;
end;

procedure HandlePointerDown(x, y: Integer);
begin
  if shop_open or confirm_reset or budget_open or (x >= VIEW_W) then Exit;
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

function DbgS0Wool: Integer;
begin
  DbgS0Wool := Trunc(sheep[0].wool * 10.0);
end;

function DbgSheepCap: Integer;
begin
  DbgSheepCap := SheepCap;
end;

function DbgTr0: Integer;
begin
  DbgTr0 := Trunc(troughs[0].amount * 100.0);
end;

function DbgWelcome: Integer;
begin
  if welcome_timer > 0.0 then DbgWelcome := 1
  else DbgWelcome := 0;
end;

function DbgOfflineCoins: Integer;
begin
  DbgOfflineCoins := offline_coins_earned;
end;

function DbgStatShear: Integer;
begin
  DbgStatShear := stat_shear;
end;

function DbgStatSales: Integer;
begin
  DbgStatSales := stat_sales;
end;

function DbgStatUpkeep: Integer;
begin
  DbgStatUpkeep := stat_upkeep;
end;

function DbgStatSpent: Integer;
begin
  DbgStatSpent := stat_spent;
end;

function DbgBudgetOpen: Integer;
begin
  if budget_open then DbgBudgetOpen := 1 else DbgBudgetOpen := 0;
end;

procedure HandleKeyDown(addr, len: Integer);
var
  c: Integer;
begin
  if len = 1 then
  begin
    c := BufByte(addr, 0);
    if (c >= 65) and (c <= 90) then c := c + 32;
    if c = 98 then
    begin
      shop_open := not shop_open;
      budget_open := false;
    end
    else if c = 101 then
    begin
      budget_open := not budget_open;
      shop_open := false;
    end
    else if c = 109 then
    begin
      sfx_on := not sfx_on;
      SaveSfx(sfx_on);
    end;
    Exit;
  end;
  if KeyEquals(addr, len, StrAddr('Escape'), StrLen('Escape')) then
  begin
    shop_open := false;
    confirm_reset := false;
    budget_open := false;
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
