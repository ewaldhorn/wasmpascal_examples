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

procedure DrawTroughSprite(var t: TTrough; cam_x, cam_y: Double; selected: Boolean);

procedure DrawTroughGhost(gx, gy, kind: Integer);

procedure DrawSheepSprite(var s: TSheep; cam_x, cam_y: Double);

procedure DrawWorkerSprite(var w: TWorker; cam_x, cam_y: Double; has_dog: Boolean);

procedure DrawEffectSprite(var e: TEffect; cam_x, cam_y: Double);

implementation

function Culled(cx, cy: Integer): Boolean;
begin
  Culled := (cx < -20) or (cx > VIEW_W + 20) or (cy < -20) or (cy > CANVAS_H + 20);
end;

procedure DrawTroughSprite(var t: TTrough; cam_x, cam_y: Double; selected: Boolean);
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
    DrawText(cx - 2, cy - 20, StrAddr('!!'), 1,
      BAR_BAD_R, BAR_BAD_G, BAR_BAD_B);
  if selected then
  begin
    { Held trough: a coin-yellow ring (with a dark outer edge so it reads on
      grass and over the watermark of its own shadow). }
    CRectOutline(cx - 15, cy - 7, 30, 16,
      PANEL_BD_R, PANEL_BD_G, PANEL_BD_B);
    CRectOutline(cx - 14, cy - 6, 28, 14,
      HUD_COIN_R, HUD_COIN_G, HUD_COIN_B);
  end;
end;

{ Drop preview for a held trough: the body outline in the trough's own colour,
  so feed and water stay told apart. Drawn where the drop will land (already
  clamped to the fence), not wherever the cursor happens to be. }
procedure DrawTroughGhost(gx, gy, kind: Integer);
begin
  CRectOutline(gx - 13, gy - 5, 26, 12, WOOL_HI_R, WOOL_HI_G, WOOL_HI_B);
  if kind = TR_FOOD then
    CRectOutline(gx - 12, gy - 4, 24, 10,
      TROUGH_FOOD_R, TROUGH_FOOD_G, TROUGH_FOOD_B)
  else
    CRectOutline(gx - 12, gy - 4, 24, 10,
      TROUGH_WATER_R, TROUGH_WATER_G, TROUGH_WATER_B);
end;

procedure DrawSheepSprite(var s: TSheep; cam_x, cam_y: Double);
var
  cx, cy, bob, radius, head_x, worst, lvl, grey: Integer;
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
  else if s.wool >= SHEAR_THRESHOLD then
  begin
    br := WOOL_HI_R; bg2 := WOOL_HI_G; bb := WOOL_HI_B;
  end
  else
  begin
    if s.wool < SHEAR_THRESHOLD * 0.25 then lvl := 0
    else if s.wool < SHEAR_THRESHOLD * 0.5 then lvl := 1
    else if s.wool < SHEAR_THRESHOLD * 0.75 then lvl := 2
    else lvl := 3;
    grey := WOOL_GREY_BASE + lvl * WOOL_GREY_STEP;
    br := grey; bg2 := grey; bb := grey;
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
    DrawText(cx - 2, cy - radius - 10, StrAddr('!!'), 1,
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

{ Speech bubble: pale card with a dark outline and a stepped tail pointing
  down at the worker's hat, label centred. Clamped to the viewport so a
  worker near an edge still gets a fully visible bubble; the tail chases the
  worker's head, so it stays attached even when the card is nudged sideways.
  head_y is the top of the hat, so the card clears the head. }
procedure DrawSpeechBubble(cx, head_y, addr, len: Integer);
var
  pad_x, pad_y, box_w, box_h, bx, by, tail_x: Integer;
begin
  pad_x := 6;
  pad_y := 4;
  box_w := len * 12 + pad_x * 2;
  box_h := 14 + pad_y * 2;
  bx := cx - box_w div 2;
  by := head_y - 6 - box_h;
  if bx < 2 then bx := 2;
  if bx + box_w > VIEW_W - 2 then bx := VIEW_W - 2 - box_w;
  if by < 2 then by := 2;
  CFillRect(bx, by, box_w, box_h, BUBBLE_BG_R, BUBBLE_BG_G, BUBBLE_BG_B);
  CRectOutline(bx, by, box_w, box_h, BUBBLE_BD_R, BUBBLE_BD_G, BUBBLE_BD_B);
  { Tail drawn after the card, so its outline covers the card's bottom edge
    where they meet and the two read as one shape. }
  tail_x := cx;
  if tail_x < bx + 9 then tail_x := bx + 9;
  if tail_x > bx + box_w - 9 then tail_x := bx + box_w - 9;
  CFillRect(tail_x - 4, by + box_h - 1, 9, 5, BUBBLE_BD_R, BUBBLE_BD_G, BUBBLE_BD_B);
  CFillRect(tail_x - 3, by + box_h - 1, 7, 3, BUBBLE_BG_R, BUBBLE_BG_G, BUBBLE_BG_B);
  CFillRect(tail_x - 2, by + box_h + 3, 5, 4, BUBBLE_BD_R, BUBBLE_BD_G, BUBBLE_BD_B);
  CFillRect(tail_x - 1, by + box_h + 3, 3, 2, BUBBLE_BG_R, BUBBLE_BG_G, BUBBLE_BG_B);
  DrawText(bx + pad_x, by + pad_y, addr, len,
    BUBBLE_TEXT_R, BUBBLE_TEXT_G, BUBBLE_TEXT_B);
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
  { A worker with a job announces it, walking or working alike; an idle
    worker (WT_NONE) stays quiet and gets no bubble at all. }
  if w.state <> WS_IDLE then
  begin
    WorkerTaskLabel(w.task, ta, tl);
    DrawSpeechBubble(cx, cy - 21, ta, tl);
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
      StrAddr('++'), 1, COIN_FLOAT_R, COIN_FLOAT_G, COIN_FLOAT_B);
    DrawDigits(draw_x - total div 2 + 12, draw_y, n,
      COIN_FLOAT_R, COIN_FLOAT_G, COIN_FLOAT_B);
  end
  else
    DrawText(draw_x - 2, draw_y, StrAddr('**'), 1,
      255, 255, 255);
end;

begin
end.
