unit mp_game;

{ M1: initialisation seam + frame entry points. GameInit seeds the RNG and
  bakes the level-0 background; DrawFrame clears, blits, and titles.
  M3 fills in the sim; input handlers land in M2. }

interface

uses
  mp_defs,
  mp_rand,
  mp_world,
  mp_draw,
  mp_render;

procedure GameInit(seed: Cardinal);

procedure GameUpdate(dt: Double);

procedure DrawFrame;

procedure HandlePointerDown(x, y: Integer);

procedure HandlePointerMove(x, y: Integer);

procedure HandlePointerUp(x, y: Integer);

procedure HandleKeyDown;

implementation

procedure GameInit(seed: Cardinal);
begin
  SeedRand(seed);
  bg_level := -1;
  EnsureBackground(0);
end;

procedure GameUpdate(dt: Double);
begin
end;

procedure DrawFrame;
var
  tw: Integer;
begin
  CFillRect(0, 0, CANVAS_W, CANVAS_H, SKY_R, SKY_G, SKY_B);
  BlitWorld(0.0, 0.0);
  tw := TextWidthLarge('MY PADDOCK');
  DrawTextLarge((CANVAS_W - tw) div 2, 40, 'MY PADDOCK',
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
  tw := TextWidth('WASMPASCAL PORT - M1');
  DrawText((CANVAS_W - tw) div 2, 90, 'WASMPASCAL PORT - M1',
    HUD_TEXT_R, HUD_TEXT_G, HUD_TEXT_B);
end;

procedure HandlePointerDown(x, y: Integer);
begin
end;

procedure HandlePointerMove(x, y: Integer);
begin
end;

procedure HandlePointerUp(x, y: Integer);
begin
end;

procedure HandleKeyDown;
begin
end;

begin
end.
