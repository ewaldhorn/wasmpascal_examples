unit mp_render;

{ Background bake + viewport blit. Port of ensure_background,
  bake_background, bake_grass_texture, bake_fence_perimeter, bake_barn,
  and blit_world from renderer.odin. }

interface

uses
  mp_defs,
  mp_rand,
  mp_world,
  mp_draw;

procedure EnsureBackground(level: Integer);

procedure BlitWorld(cam_x, cam_y: Double);

implementation

procedure BakeGrassTexture;
var
  i, tufts, flowers, fx: Integer;
begin
  tufts := Trunc((bnd_r - bnd_l) * (bnd_b - bnd_t) / 700.0);
  for i := 1 to tufts do
  begin
    BoundsRandomPoint;
    SetActive(GRASS_DARK_R, GRASS_DARK_G, GRASS_DARK_B, 255);
    BgFillRect(Trunc(rnd_x), Trunc(rnd_y), 2, 2);
  end;
  flowers := Trunc((bnd_r - bnd_l) * (bnd_b - bnd_t) / 3200.0);
  for i := 1 to flowers do
  begin
    BoundsRandomPoint;
    fx := RngInt(4);
    if fx = 0 then SetActive(FLOWER0_R, FLOWER0_G, FLOWER0_B, 255)
    else if fx = 1 then SetActive(FLOWER1_R, FLOWER1_G, FLOWER1_B, 255)
    else if fx = 2 then SetActive(FLOWER2_R, FLOWER2_G, FLOWER2_B, 255)
    else SetActive(FLOWER3_R, FLOWER3_G, FLOWER3_B, 255);
    BgFillCircle(Trunc(rnd_x), Trunc(rnd_y), 2);
  end;
end;

procedure BakeFencePerimeter(x, y, w, h: Integer);
var
  rail, gap, px, py: Integer;
begin
  rail := 4;
  SetActive(FENCE_R, FENCE_G, FENCE_B, 255);
  BgFillRect(x, y, w, rail);
  BgFillRect(x, y + h - rail, w, rail);
  BgFillRect(x, y, rail, h);
  BgFillRect(x + w - rail, y, rail, h);
  SetActive(FENCE_DARK_R, FENCE_DARK_G, FENCE_DARK_B, 255);
  gap := 44;
  px := x;
  while px <= x + w do
  begin
    BgFillRect(px, y - 5, 3, rail + 8);
    BgFillRect(px, y + h - rail - 3, 3, rail + 8);
    px := px + gap;
  end;
  py := y;
  while py <= y + h do
  begin
    BgFillRect(x - 5, py, rail + 8, 3);
    BgFillRect(x + w - rail - 3, py, rail + 8, 3);
    py := py + gap;
  end;
end;

procedure BakeBarn;
var
  bx, by: Integer;
begin
  bx := Trunc(bnd_r) - 90;
  by := Trunc(bnd_t) + 4;
  SetActive(BARN_R, BARN_G, BARN_B, 255);
  BgFillRect(bx, by, 70, 46);
  SetActive(BARN_ROOF_R, BARN_ROOF_G, BARN_ROOF_B, 255);
  BgFillRect(bx - 6, by - 22, 82, 24);
  SetActive(BARN_DOOR_R, BARN_DOOR_G, BARN_DOOR_B, 255);
  BgFillRect(bx + 26, by + 16, 18, 30);
  SetActive(SKY_R, SKY_G, SKY_B, 255);
  BgFillRect(bx + 8, by + 8, 12, 12);
  BgFillRect(bx + 50, by + 8, 12, 12);
end;

procedure BakeBackground(level: Integer);
var
  seed_save: Cardinal;
begin
  { Stable-looking decor per level, independent of game RNG: reseed, bake,
    restore. Mirrors rand.create_u64(level * 7919 + 42) in renderer.odin. }
  seed_save := rng_state;
  SeedRand(Cardinal(level * 7919 + 42));
  SetActive(GRASS_R, GRASS_G, GRASS_B, 255);
  BgFillRect(0, 0, bg_w, bg_h);
  BakeGrassTexture;
  BakeFencePerimeter(Trunc(bnd_l) - 12, Trunc(bnd_t) - 12,
    Trunc(bnd_r - bnd_l) + 24, Trunc(bnd_b - bnd_t) + 24);
  BakeBarn;
  SeedRand(seed_save);
end;

procedure EnsureBackground(level: Integer);
begin
  if bg_level = level then Exit;
  bg_w := WorldW(level);
  bg_h := WorldH(level);
  BoundsFor(level);
  BakeBackground(level);
  bg_level := level;
end;

procedure BlitWorld(cam_x, cam_y: Double);
var
  cx, cy, row, width_px, src_y, src_off, dst_off: Integer;
begin
  cx := Trunc(cam_x);
  cy := Trunc(cam_y);
  if cx < 0 then cx := 0;
  if cy < 0 then cy := 0;
  width_px := VIEW_W;
  if bg_w - cx < width_px then width_px := bg_w - cx;
  if width_px <= 0 then Exit;
  for row := 0 to VIEW_H - 1 do
  begin
    src_y := cy + row;
    if (src_y >= 0) and (src_y < bg_h) then
    begin
      src_off := (src_y * bg_w + cx) * 4;
      dst_off := row * CANVAS_W * 4;
      Move(bg[src_off], pixels[dst_off], width_px * 4);
    end;
  end;
end;

begin
end.
