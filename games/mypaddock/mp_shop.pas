unit mp_shop;

{ Economy + shop UI. Costs, caps, gates, buy/sell/upkeep mutations (Odin's
  shop.odin + charge_upkeep), progression state (coins, flock staffing,
  lifetime stats), shop row geometry, and shop drawing. Split out of
  mp_game (M7); mp_game and mp_sim use this unit, never the reverse. }

interface

uses
  mp_defs,
  mp_world,
  mp_sheep,
  mp_trough,
  mp_worker,
  mp_draw;

var
  paddock_level: Integer = 0;
  coins: Integer = 40;
  has_dog: Boolean = false;
  hand_count: Integer = 0;
  { Lifetime money stats (persisted): income from shearing and all livestock
    sales, upkeep bills charged, and all shop purchases. }
  stat_shear: Integer = 0;
  stat_sales: Integer = 0;
  stat_upkeep: Integer = 0;
  stat_spent: Integer = 0;
  cs_sheep: Integer = 0;
  cs_hands: Integer = 0;
  cs_dog: Boolean = false;
  rr_x: Integer = 0;
  rr_y: Integer = 0;
  rr_w: Integer = 0;
  rr_h: Integer = 0;

function CountTroughs(kind: Integer): Integer;

function SheepCap: Integer;

function UpkeepCost: Integer;

function HandsRequiredFor(count: Integer): Integer;

function SellOneSheep: Boolean;

function SellOneHand: Boolean;

procedure ChargeUpkeep;

function BuySheepCost(count: Integer): Integer;

function ExpandCost(level: Integer): Integer;

function HandCost(count: Integer): Integer;

function TryExpandPaddock: Boolean;

function TryBuySheep: Boolean;

function TryHireDog: Boolean;

function TryHireHand: Boolean;

function TryBuyTrough(kind: Integer): Boolean;

procedure ShopRowRect(i: Integer);

procedure DrawShopRowText(i, na, nl, ca, cl: Integer; avail: Boolean);

procedure DrawShopRowCoins(i, na, nl, v: Integer; plus: Boolean; avail: Boolean);

procedure DrawCountRow(i, na, nl, count, v: Integer; avail: Boolean);

procedure DrawShop;

implementation

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
  if has_dog then
    UpkeepCost := UpkeepCost + UPKEEP_PER_DOG;
end;

function HandsRequiredFor(count: Integer): Integer;
begin
  if count < HAND_REQUIRED_AT then HandsRequiredFor := 0
  else HandsRequiredFor := 1 + (count - HAND_REQUIRED_AT) div HAND_CAPACITY_STEP;
end;

function SellOneSheep: Boolean;
begin
  SellOneSheep := false;
  if sheep_n <= SHEEP_MIN_KEPT then Exit;
  sheep_n := sheep_n - 1;
  coins := coins + SHEEP_SELL_VALUE;
  stat_sales := stat_sales + SHEEP_SELL_VALUE;
  SellOneSheep := true;
end;

function SellOneHand: Boolean;
var
  i: Integer;
begin
  SellOneHand := false;
  i := worker_n - 1;
  while i >= 0 do
  begin
    if workers[i].kind = WK_HAND then
    begin
      workers[i] := workers[worker_n - 1];
      worker_n := worker_n - 1;
      hand_count := hand_count - 1;
      coins := coins + FARM_HAND_SELL_VALUE;
      stat_sales := stat_sales + FARM_HAND_SELL_VALUE;
      SellOneHand := true;
      Exit;
    end;
    i := i - 1;
  end;
end;

procedure ChargeUpkeep;
var
  done: Boolean;
  bill: Integer;
begin
  bill := UpkeepCost;
  stat_upkeep := stat_upkeep + bill;
  coins := coins - bill;
  cs_sheep := 0;
  cs_hands := 0;
  cs_dog := false;
  done := false;
  while (coins < 0) and (not done) do
  begin
    if SellOneSheep then
      cs_sheep := cs_sheep + 1
    else
      done := true;
  end;
  done := false;
  while (coins < 0) and (not done) do
  begin
    if SellOneHand then
      cs_hands := cs_hands + 1
    else
      done := true;
  end;
  if (coins < 0) and has_dog then
  begin
    has_dog := false;
    coins := coins + DOG_SELL_VALUE;
    stat_sales := stat_sales + DOG_SELL_VALUE;
    cs_dog := true;
  end;
  if coins < 0 then
    coins := 0;
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

function TryExpandPaddock: Boolean;
var
  cost: Integer;
begin
  TryExpandPaddock := false;
  if paddock_level >= MAX_PADDOCK_LEVEL then Exit;
  cost := ExpandCost(paddock_level);
  if coins < cost then Exit;
  coins := coins - cost;
  stat_spent := stat_spent + cost;
  paddock_level := paddock_level + 1;
  TryExpandPaddock := true;
end;

function TryBuySheep: Boolean;
var
  cost: Integer;
begin
  TryBuySheep := false;
  if sheep_n >= SheepCap then Exit;
  if sheep_n >= PaddockCap(paddock_level) then Exit;
  if (sheep_n >= DOG_REQUIRED_AT) and (not has_dog) then Exit;
  if hand_count < HandsRequiredFor(sheep_n + 1) then Exit;
  cost := BuySheepCost(sheep_n);
  if coins < cost then Exit;
  if sheep_n >= MAX_SHEEP then Exit;
  coins := coins - cost;
  stat_spent := stat_spent + cost;
  next_sheep_id := next_sheep_id + 1;
  NewSheep(sheep[sheep_n], next_sheep_id);
  sheep_n := sheep_n + 1;
  TryBuySheep := true;
end;

function TryHireDog: Boolean;
begin
  TryHireDog := false;
  if has_dog then Exit;
  if coins < DOG_HIRE_COST then Exit;
  coins := coins - DOG_HIRE_COST;
  stat_spent := stat_spent + DOG_HIRE_COST;
  has_dog := true;
  TryHireDog := true;
end;

function TryHireHand: Boolean;
var
  cost: Integer;
begin
  TryHireHand := false;
  cost := HandCost(hand_count);
  if coins < cost then Exit;
  if worker_n >= MAX_WORKERS then Exit;
  coins := coins - cost;
  stat_spent := stat_spent + cost;
  hand_count := hand_count + 1;
  NewWorker(workers[worker_n], WK_HAND);
  worker_n := worker_n + 1;
  TryHireHand := true;
end;

function TryBuyTrough(kind: Integer): Boolean;
begin
  TryBuyTrough := false;
  if coins < TROUGH_COST then Exit;
  if trough_n >= MAX_TROUGHS then Exit;
  coins := coins - TROUGH_COST;
  stat_spent := stat_spent + TROUGH_COST;
  BoundsRandomPoint;
  NewTrough(troughs[trough_n], kind, rnd_x, rnd_y);
  trough_n := trough_n + 1;
  TryBuyTrough := true;
end;

procedure ShopRowRect(i: Integer);
begin
  rr_x := SHOPROW_X;
  rr_y := SHOP_PANEL_Y + SHOP_ROWS_TOP + i * SHOP_ROW_H;
  rr_w := SHOPROW_W;
  rr_h := SHOPROW_H;
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
      StrAddr('++'), 1, cr, cg, cb);
    cost_x := cost_x + 12;
  end;
  DrawDigits(cost_x, rr_y + (rr_h - 14) div 2, n, cr, cg, cb);
  DrawText(cost_x + n * 12, rr_y + (rr_h - 14) div 2,
    StrAddr(' COINS'), StrLen(' COINS'), cr, cg, cb);
end;

procedure DrawCountRow(i, na, nl, count, v: Integer; avail: Boolean);
var
  n, nx: Integer;
begin
  ShopRowRect(i);
  if avail then
    CFillRect(rr_x, rr_y, rr_w, rr_h, BTN_BG_R, BTN_BG_G, BTN_BG_B)
  else
    CFillRect(rr_x, rr_y, rr_w, rr_h, BTN_DIS_R, BTN_DIS_G, BTN_DIS_B);
  DrawText(rr_x + 10, rr_y + (rr_h - 14) div 2, na, nl,
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  nx := rr_x + 10 + nl * 12;
  n := IntToBuf(count);
  DrawDigits(nx, rr_y + (rr_h - 14) div 2, n,
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  DrawText(nx + n * 12, rr_y + (rr_h - 14) div 2,
    StrAddr('))'), 1, HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  n := IntToBuf(v);
  if avail then
  begin
    DrawDigits(rr_x + rr_w - (n + 6) * 12 - 10, rr_y + (rr_h - 14) div 2, n,
      HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
    DrawText(rr_x + rr_w - 6 * 12 - 10, rr_y + (rr_h - 14) div 2,
      StrAddr(' COINS'), StrLen(' COINS'),
      HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
  end
  else
  begin
    DrawDigits(rr_x + rr_w - (n + 6) * 12 - 10, rr_y + (rr_h - 14) div 2, n,
      HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
    DrawText(rr_x + rr_w - 6 * 12 - 10, rr_y + (rr_h - 14) div 2,
      StrAddr(' COINS'), StrLen(' COINS'),
      HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  end;
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
  DrawCountRow(4, StrAddr('FOOD TROUGH ('), StrLen('FOOD TROUGH ('),
    CountTroughs(TR_FOOD), TROUGH_COST, coins >= TROUGH_COST);
  DrawCountRow(5, StrAddr('WATER TROUGH ('), StrLen('WATER TROUGH ('),
    CountTroughs(TR_WATER), TROUGH_COST, coins >= TROUGH_COST);
  DrawCountRow(6, StrAddr('HIRE FARM HAND ('), StrLen('HIRE FARM HAND ('),
    hand_count, HandCost(hand_count), coins >= HandCost(hand_count));
  DrawText(SHOP_PANEL_X + 20, SHOP_PANEL_Y + SHOP_PANEL_H - 24,
    StrAddr('[ESC OR B TO CLOSE]'), StrLen('[ESC OR B TO CLOSE]'),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
end;

begin
end.
