unit mp_game;

{ M2: camera + input routing + panel/minimap/shop-shell/reset chrome.
  No sim yet: coins/sheep/trough counts are placeholder state that M3/M4
  make live. Port of game.odin's input section + renderer.odin's panel,
  minimap, shop overlay, and reset dialog (draw parts only). }

interface

uses
  mp_defs,
  mp_rand,
  mp_world,
  mp_draw,
  mp_render;

var
  cam_x: Double = 0.0;
  cam_y: Double = 0.0;
  paddock_level: Integer = 0;
  coins: Integer = 40;
  sheep_shown: Integer = 0;
  food_troughs: Integer = 1;
  water_troughs: Integer = 1;
  has_dog_shown: Boolean = false;
  hand_shown: Integer = 0;
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

procedure GameInit(seed: Cardinal);

procedure GameUpdate(dt: Double);

procedure DrawFrame;

procedure HandlePointerDown(x, y: Integer);

procedure HandlePointerMove(x, y: Integer);

procedure HandlePointerUp(x, y: Integer);

procedure HandleKeyDown(addr, len: Integer);

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

function SheepCap: Integer;
var
  trough_cap, pad_cap: Integer;
begin
  trough_cap := food_troughs;
  if water_troughs < trough_cap then trough_cap := water_troughs;
  trough_cap := trough_cap * 5;
  pad_cap := PaddockCap(paddock_level);
  if trough_cap < pad_cap then SheepCap := trough_cap
  else SheepCap := pad_cap;
end;

function UpkeepCost: Integer;
begin
  UpkeepCost := sheep_shown;
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
      { M4 wires the real wipe+reload; M2 just closes. }
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
    { Row purchases land in M4; M2 only opens/closes the overlay. }
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
begin
  SeedRand(seed);
  bg_level := -1;
  cam_x := 0.0;
  cam_y := 0.0;
  paddock_level := 0;
  coins := START_COINS;
  shop_open := false;
  confirm_reset := false;
  dragging := false;
  drag_moved := false;
  EnsureBackground(0);
end;

procedure GameUpdate(dt: Double);
begin
end;

procedure DrawMinimap;
var
  vx, vy, vw, vh: Integer;
begin
  CFillRect(MM_X, MM_Y, MM_W, MM_H, PANEL_BG_R, PANEL_BG_G, PANEL_BG_B);
  CRectOutline(MM_X, MM_Y, MM_W, MM_H, PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
  MinimapWorld;
  CRectOutline(mwr_x, mwr_y, mwr_w, mwr_h, FENCE_R, FENCE_G, FENCE_B);
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
  la, ll: Integer;
begin
  CFillRect(PANEL_X, 0, RIGHT_PANEL_W, CANVAS_H, HUD_BG_R, HUD_BG_G, HUD_BG_B);
  DrawTextLarge(PANEL_X + PANEL_PAD, 14,
    StrAddr('PADDOCK'), StrLen('PADDOCK'),
    PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
  DrawLabelInt(PANEL_X + PANEL_PAD, 48,
    StrAddr('COINS: '), StrLen('COINS: '), coins,
    HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
  DrawText(PANEL_X + PANEL_PAD, 68,
    StrAddr('SHEEP: '), StrLen('SHEEP: '),
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  DrawDigits(PANEL_X + PANEL_PAD + 7 * 12, 68,
    IntToBuf(sheep_shown), HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  DrawText(PANEL_X + PANEL_PAD + 8 * 12, 68,
    StrAddr('/'), StrLen('/'), HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  DrawDigits(PANEL_X + PANEL_PAD + 9 * 12, 68,
    IntToBuf(SheepCap), HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
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

procedure DrawShopRow(i, na, nl, ca, cl: Integer; avail: Boolean);
var
  cost_col_r, cost_col_g, cost_col_b: Integer;
begin
  ShopRowRect(i);
  if avail then
    CFillRect(rr_x, rr_y, rr_w, rr_h, BTN_BG_R, BTN_BG_G, BTN_BG_B)
  else
    CFillRect(rr_x, rr_y, rr_w, rr_h, BTN_DIS_R, BTN_DIS_G, BTN_DIS_B);
  DrawText(rr_x + 10, rr_y + (rr_h - 14) div 2, na, nl,
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  if avail then
  begin
    cost_col_r := HUD_COIN_R; cost_col_g := HUD_COIN_G; cost_col_b := HUD_COIN_B;
  end
  else
  begin
    cost_col_r := HUD_TEXT_R; cost_col_g := HUD_TEXT_G; cost_col_b := HUD_TEXT_B;
  end;
  DrawText(rr_x + rr_w - cl * 12 - 10, rr_y + (rr_h - 14) div 2, ca, cl,
    cost_col_r, cost_col_g, cost_col_b);
end;

procedure DrawShop;
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
  DrawShopRow(0, StrAddr('BUY SHEEP'), StrLen('BUY SHEEP'),
    StrAddr('20 COINS'), StrLen('20 COINS'), true);
  DrawShopRow(1, StrAddr('EXPAND PADDOCK'), StrLen('EXPAND PADDOCK'),
    StrAddr('80 COINS'), StrLen('80 COINS'), true);
  DrawShopRow(2, StrAddr('HIRE SHEEP DOG'), StrLen('HIRE SHEEP DOG'),
    StrAddr('150 COINS'), StrLen('150 COINS'), true);
  DrawShopRow(3, StrAddr('SELL SHEEP'), StrLen('SELL SHEEP'),
    StrAddr('MIN 1 SHEEP'), StrLen('MIN 1 SHEEP'), false);
  DrawShopRow(4, StrAddr('FOOD TROUGH (1)'), StrLen('FOOD TROUGH (1)'),
    StrAddr('50 COINS'), StrLen('50 COINS'), true);
  DrawShopRow(5, StrAddr('WATER TROUGH (1)'), StrLen('WATER TROUGH (1)'),
    StrAddr('50 COINS'), StrLen('50 COINS'), true);
  DrawShopRow(6, StrAddr('HIRE FARM HAND (0)'), StrLen('HIRE FARM HAND (0)'),
    StrAddr('200 COINS'), StrLen('200 COINS'), true);
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
begin
  EnsureBackground(paddock_level);
  CFillRect(0, 0, CANVAS_W, CANVAS_H, SKY_R, SKY_G, SKY_B);
  BlitWorld(cam_x, cam_y);
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
