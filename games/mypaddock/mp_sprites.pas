unit mp_sprites;

{ Entity sprites. Port of draw_trough/draw_sheep/draw_worker/draw_effect +
  person/dog silhouettes from renderer.odin. All positions are world-space;
  pass cam_x/cam_y to project. Shadows are dithered (see DitherCircle). }

interface

uses
  mp_defs,
  mp_draw,
  mp_sheep,
  mp_trough,
  mp_worker,
  mp_effect;

procedure DrawTroughSprite(var t: TTrough; cam_x, cam_y: Double);

procedure DrawSheepSprite(var s: TSheep; cam_x, cam_y: Double);

procedure DrawWorkerSprite(var w: TWorker; cam_x, cam_y: Double; has_dog: Boolean);

procedure DrawEffectSprite(var e: TEffect; cam_x, cam_y: Double);

implementation

function Culled(cx, cy: Integer): Boolean;
begin
  if (cx < -20) or (cx > VIEW_W + 20) or (cy < -20) or (cy > CANVAS_H + 20) then
    Culled := true
  else
    Culled := false;
end;

procedure DrawTroughSprite(var t: TTrough; cam_x, cam_y: Double);
var
  cx, cy, fill_w: Integer;
  frac: Double;
begin
  cx := Trunc(t.x - cam_x);
  cy := Trunc(t.y - cam_y);
  if Culled(cx, cy) then Exit;
  DitherCircle(cx, cy + 8, 10);
  CFillRect(cx - 12, cy - 4, 24, 10, FENCE_DARK_R, FENCE_DARK_G, FENCE_DARK_B);
  CFillRect(cx - 10, cy - 2, 20, 6, PANEL_BG_R, PANEL_BG_G, PANEL_BG_B);
  frac := t.amount / TROUGH_CAPACITY;
  if frac < 0.0 then frac := 0.0;
  if frac > 1.0 then frac := 1.0;
  fill_w := Trunc(18.0 * frac);
  if fill_w > 0 then
  begin
    if t.kind = TR_FOOD then
      CFillRect(cx - 9, cy - 1, fill_w, 4,
        TROUGH_FOOD_R, TROUGH_FOOD_G, TROUGH_FOOD_B)
    else
      CFillRect(cx - 9, cy - 1, fill_w, 4,
        TROUGH_WATER_R, TROUGH_WATER_G, TROUGH_WATER_B);
  end;
  if TroughNeedsRefill(t) then
    DrawText(cx - 2, cy - 20, StrAddr('!'), StrLen('!'),
      BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
end;

procedure DrawSheepSprite(var s: TSheep; cam_x, cam_y: Double);
var
  cx, cy, bob, radius, head_x, worst: Integer;
  frac: Double;
  br, bg2, bb: Integer;
begin
  cx := Trunc(s.x - cam_x);
  cy := Trunc(s.y - cam_y);
  if Culled(cx, cy) then Exit;
  bob := Trunc(mSin(s.bob_timer * 4.0) * 1.5);
  DitherCircle(cx, cy + 10, 7);
  CFillRect(cx - 7, cy + 4 + bob, 3, 7,
    SHEEP_LEG_R, SHEEP_LEG_G, SHEEP_LEG_B);
  CFillRect(cx + 4, cy + 4 + bob, 3, 7,
    SHEEP_LEG_R, SHEEP_LEG_G, SHEEP_LEG_B);
  frac := s.wool / 100.0;
  radius := 8 + Trunc(5.0 * frac);
  if s.wool < 15.0 then
  begin
    br := SHEEP_SKIN_R; bg2 := SHEEP_SKIN_G; bb := SHEEP_SKIN_B;
  end
  else
  begin
    br := WOOL_LO_R + Trunc((WOOL_HI_R - WOOL_LO_R) * frac);
    bg2 := WOOL_LO_G + Trunc((WOOL_HI_G - WOOL_LO_G) * frac);
    bb := WOOL_LO_B + Trunc((WOOL_HI_B - WOOL_LO_B) * frac);
  end;
  CFillCircle(cx, cy + bob, radius, br, bg2, bb);
  head_x := cx + Trunc(s.facing) * (radius + 2);
  CFillCircle(head_x, cy - 1 + bob, 5,
    SHEEP_FACE_R, SHEEP_FACE_G, SHEEP_FACE_B);
  if s.flash_timer > 0.0 then
  begin
    SetActive(255, 255, 255, 255);
    CircleOutline(cx, cy + bob, radius + 5);
    CircleOutline(cx, cy + bob, radius + 6);
    CircleOutline(cx, cy + bob, radius + 7);
  end;
  worst := Trunc(s.hunger);
  if Trunc(s.thirst) < worst then worst := Trunc(s.thirst);
  if worst < 25 then
    DrawText(cx - 2, cy - radius - 10, StrAddr('!'), StrLen('!'),
      BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
end;

procedure DrawPerson(cx, cy, bob, facing: Integer;
  shirt_r, shirt_g, shirt_b, skin_r, skin_g, skin_b,
  hat_r, hat_g, hat_b, pants_r, pants_g, pants_b: Integer);
begin
  DitherCircle(cx, cy + 14, 6);
  CFillRect(cx - 4, cy + 4, 3, 9 + bob, pants_r, pants_g, pants_b);
  CFillRect(cx + 2, cy + 4, 3, 9 - bob, pants_r, pants_g, pants_b);
  CFillRect(cx - 5, cy - 8, 10, 13, shirt_r, shirt_g, shirt_b);
  CFillCircle(cx, cy - 12, 5, skin_r, skin_g, skin_b);
  CFillRect(cx - 7, cy - 18, 14, 3, hat_r, hat_g, hat_b);
  CFillRect(cx - 4 + facing * 3, cy - 21, 8, 4, hat_r, hat_g, hat_b);
end;

procedure DrawDog(cx, cy, bob, dir: Integer);
var
  head_x: Integer;
begin
  DitherCircle(cx, cy + 8, 5);
  CFillRect(cx - 5, cy + 1 + bob, 2, 5, DOG_LEG_R, DOG_LEG_G, DOG_LEG_B);
  CFillRect(cx + 4, cy + 1 - bob, 2, 5, DOG_LEG_R, DOG_LEG_G, DOG_LEG_B);
  CFillRect(cx - 7, cy - 4, 14, 7, DOG_BODY_R, DOG_BODY_G, DOG_BODY_B);
  head_x := cx + dir * 9;
  CFillCircle(head_x, cy - 3, 4, DOG_BODY_R, DOG_BODY_G, DOG_BODY_B);
  CFillRect(head_x - 2, cy - 8, 2, 3, DOG_EAR_R, DOG_EAR_G, DOG_EAR_B);
  CFillRect(cx - dir * 9, cy - 6, 3, 3, DOG_BODY_R, DOG_BODY_G, DOG_BODY_B);
end;

procedure DrawWorkerSprite(var w: TWorker; cam_x, cam_y: Double; has_dog: Boolean);
var
  cx, cy, bob, dir, ta, tl: Integer;
begin
  cx := Trunc(w.x - cam_x);
  cy := Trunc(w.y - cam_y);
  if Culled(cx, cy) then Exit;
  bob := Trunc(mSin(w.walk_timer * 6.0) * 1.5);
  dir := Trunc(w.facing);
  if w.kind = WK_HAND then
    DrawPerson(cx, cy, bob, dir,
      HAND_SHIRT_R, HAND_SHIRT_G, HAND_SHIRT_B,
      FARMER_SKIN_R, FARMER_SKIN_G, FARMER_SKIN_B,
      HAND_HAT_R, HAND_HAT_G, HAND_HAT_B,
      FARMER_PANTS_R, FARMER_PANTS_G, FARMER_PANTS_B)
  else
  begin
    DrawPerson(cx, cy, bob, dir,
      FARMER_SHIRT_R, FARMER_SHIRT_G, FARMER_SHIRT_B,
      FARMER_SKIN_R, FARMER_SKIN_G, FARMER_SKIN_B,
      FARMER_HAT_R, FARMER_HAT_G, FARMER_HAT_B,
      FARMER_PANTS_R, FARMER_PANTS_G, FARMER_PANTS_B);
    if has_dog then
      DrawDog(cx - dir * 16, cy + 6, bob, dir);
  end;
  if w.state = WS_WORKING then
  begin
    if w.task = WT_REFILL_FOOD then
    begin ta := StrAddr('REFILLING FOOD'); tl := StrLen('REFILLING FOOD'); end
    else if w.task = WT_REFILL_WATER then
    begin ta := StrAddr('REFILLING WATER'); tl := StrLen('REFILLING WATER'); end
    else if w.task = WT_SHEAR then
    begin ta := StrAddr('SHEARING'); tl := StrLen('SHEARING'); end
    else begin ta := 0; tl := 0; end;
    if tl > 0 then
      DrawText(cx - (tl * 12) div 2, cy - 34, ta, tl,
        HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
  end;
end;

procedure DrawEffectSprite(var e: TEffect; cam_x, cam_y: Double);
var
  draw_x, draw_y, total, n: Integer;
begin
  draw_x := Trunc(e.x - cam_x);
  draw_y := Trunc(e.y - cam_y -
    EFFECT_FLOAT_RISE * (1.0 - e.timer / e.max_timer));
  if e.kind = EK_COIN_FLOAT then
  begin
    n := IntToBuf(e.value);
    total := (1 + n) * 12;
    DrawText(draw_x - total div 2, draw_y,
      StrAddr('+'), StrLen('+'), COIN_FLOAT_R, COIN_FLOAT_G, COIN_FLOAT_B);
    DrawDigits(draw_x - total div 2 + 12, draw_y, n,
      COIN_FLOAT_R, COIN_FLOAT_G, COIN_FLOAT_B);
  end
  else
    DrawText(draw_x - 2, draw_y, StrAddr('*'), StrLen('*'),
      255, 255, 255);
end;

begin
end.
