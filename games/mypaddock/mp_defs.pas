unit mp_defs;

{ Shared constants, pixel buffers, scratch state, and host imports.
  Port of constants.odin + palette.odin (colour values only).
  Mirrors the sweepdefs.pas pattern: one unit owns every cross-unit name. }

interface

const
  VERSION = 'M1';
  CANVAS_W = 800;
  CANVAS_H = 600;
  PIXEL_COUNT = CANVAS_W * CANVAS_H * 4;

  VIEW_W = 580;
  VIEW_H = 600;
  RIGHT_PANEL_W = 220;

  WORLD_BASE_W = 580;
  WORLD_BASE_H = 600;
  WORLD_EXPAND_W = 240;
  WORLD_EXPAND_H = 160;
  PADDOCK_MARGIN = 22;
  MAX_PADDOCK_LEVEL = 4;

  { Largest world: (580+4*240) x (600+4*160) = 1540 x 1240. Needs {$M 32M}. }
  BG_MAX_W = 1540;
  BG_MAX_H = 1240;
  BG_MAX_COUNT = BG_MAX_W * BG_MAX_H * 4;

  { Entity caps: fixed arrays + counts (no dynamic arrays in wasmpascal).
    Gameplay flock cap stays 50 (paddock_level 4); 120 is array headroom. }
  MAX_SHEEP = 120;
  MAX_WORKERS = 8;
  MAX_TROUGHS = 20;
  MAX_EFFECTS = 64;

  { Panel / minimap / shop / dialog layout. Single source of truth: draw code
    and hit-testing both use these consts (mirrors renderer.odin's rect procs). }
  PANEL_X = 580;
  PANEL_PAD = 14;
  PANEL_BTN_W = 192;
  SHOPBTN_X = 594; SHOPBTN_Y = 116; SHOPBTN_W = 192; SHOPBTN_H = 32;
  MUTEBTN_X = 594; MUTEBTN_Y = 156; MUTEBTN_W = 192; MUTEBTN_H = 32;
  MM_X = 594; MM_Y = 220; MM_W = 192; MM_H = 150;
  RSTBTN_X = 594; RSTBTN_Y = 430; RSTBTN_W = 192; RSTBTN_H = 28;
  SHOP_PANEL_X = 170; SHOP_PANEL_Y = 12;
  SHOP_PANEL_W = 460; SHOP_PANEL_H = 576;
  SHOP_ROW_H = 58; SHOP_ROW_COUNT = 7; SHOP_ROWS_TOP = 118;
  SHOPROW_X = 194; SHOPROW_W = 412; SHOPROW_H = 48;
  RESET_W = 380; RESET_H = 150; RESET_X = 210; RESET_Y = 225;
  YESBTN_X = 240; YESBTN_Y = 315; YESBTN_W = 150; YESBTN_H = 36;
  NOBTN_X = 410; NOBTN_Y = 315; NOBTN_W = 150; NOBTN_H = 36;
  DRAG_THRESHOLD = 6;
  PAN_STEP = 48;
  START_COINS = 40;
  START_SHEEP = 3;

  { Sheep tuning (sheep.odin). }
  SHEEP_SPEED = 14.0;
  SHEEP_WANDER_MIN = 4.0;
  SHEEP_WANDER_MAX = 10.0;
  SHEEP_ARRIVE_DIST = 10.0;
  HUNGER_DECAY_PER_SEC = 100.0 / 300.0;
  THIRST_DECAY_PER_SEC = 100.0 / 240.0;
  WOOL_GROWTH_PER_SEC = 100.0 / 347.8;
  SHEAR_THRESHOLD = 80.0;
  WOOL_TO_COIN_DIV = 4;

  { Trough tuning (trough.odin / constants.odin). }
  TROUGH_SHEEP_CAPACITY = 5;
  TROUGH_CAPACITY = 15.0;
  TROUGH_CONSUME_PER_VISIT = 1.0;
  TROUGH_REFILL_THRESHOLD_FRAC = 0.3;
  SHEEP_SEEK_THRESHOLD = 40.0;
  TR_FOOD = 0;
  TR_WATER = 1;

  { Worker tuning (worker.odin). }
  FARMER_SPEED = 34.0;
  HAND_SPEED = 34.0;
  WORKER_WANDER_MIN = 3.0;
  WORKER_WANDER_MAX = 7.0;
  WORKER_ARRIVE_DIST = 14.0;
  WORKER_WORK_DURATION = 0.7;
  DOG_SPEED_MULT = 1.75;
  WK_FARMER = 0;
  WK_HAND = 1;
  WS_IDLE = 0;
  WS_WALKING = 1;
  WS_WORKING = 2;
  WT_NONE = 0;
  WT_REFILL_FOOD = 1;
  WT_REFILL_WATER = 2;
  WT_SHEAR = 3;

  { Economy tuning (shop.odin / constants.odin) — mutations land in M4. }
  TROUGH_COST = 50;
  DOG_REQUIRED_AT = 10;
  DOG_HIRE_COST = 150;
  DOG_SELL_VALUE = 75;
  HAND_REQUIRED_AT = 20;
  HAND_CAPACITY_STEP = 10;
  FARM_HAND_BASE_COST = 200;
  FARM_HAND_COST_STEP = 100;
  FARM_HAND_SELL_VALUE = 90;
  SHEEP_SELL_VALUE = 10;
  SHEEP_MIN_KEPT = 1;
  UPKEEP_INTERVAL = 60.0;
  UPKEEP_PER_SHEEP = 1;
  UPKEEP_PER_DOG = 4;
  UPKEEP_PER_HAND = 5;

  { Effect tuning (effect.odin). }
  EFFECT_FLOAT_DURATION = 0.9;
  EFFECT_FLOAT_RISE = 30.0;
  SPARKLE_DURATION = 0.5;
  EK_COIN_FLOAT = 0;
  EK_SPARKLE = 1;

  { Host callback ids (echoed back via pascaldom_invoke_callback). }
  CB_MOUSEDOWN = 0;
  CB_MOUSEMOVE = 1;
  CB_MOUSEUP = 2;
  CB_KEYDOWN = 3;
  CB_TICK = 4;
  CB_RESIZE = 5;

  { Palette (RGB; alpha is always 255 except where noted at use site). }
  SKY_R = 176; SKY_G = 224; SKY_B = 230;
  GRASS_R = 122; GRASS_G = 178; GRASS_B = 76;
  GRASS_DARK_R = 106; GRASS_DARK_G = 162; GRASS_DARK_B = 62;
  FENCE_R = 139; FENCE_G = 98; FENCE_B = 56;
  FENCE_DARK_R = 101; FENCE_DARK_G = 68; FENCE_DARK_B = 36;
  BARN_R = 178; BARN_G = 60; BARN_B = 50;
  BARN_ROOF_R = 90; BARN_ROOF_G = 50; BARN_ROOF_B = 40;
  BARN_DOOR_R = 70; BARN_DOOR_G = 38; BARN_DOOR_B = 30;
  FLOWER0_R = 255; FLOWER0_G = 255; FLOWER0_B = 255;
  FLOWER1_R = 255; FLOWER1_G = 220; FLOWER1_B = 60;
  FLOWER2_R = 255; FLOWER2_G = 140; FLOWER2_B = 180;
  FLOWER3_R = 190; FLOWER3_G = 120; FLOWER3_B = 220;
  WOOL_LO_R = 240; WOOL_LO_G = 236; WOOL_LO_B = 224;
  WOOL_HI_R = 255; WOOL_HI_G = 255; WOOL_HI_B = 250;
  SHEEP_FACE_R = 60; SHEEP_FACE_G = 55; SHEEP_FACE_B = 55;
  SHEEP_LEG_R = 50; SHEEP_LEG_G = 45; SHEEP_LEG_B = 45;
  SHEEP_SKIN_R = 232; SHEEP_SKIN_G = 190; SHEEP_SKIN_B = 172;
  FARMER_SHIRT_R = 60; FARMER_SHIRT_G = 110; FARMER_SHIRT_B = 160;
  FARMER_SKIN_R = 222; FARMER_SKIN_G = 172; FARMER_SKIN_B = 140;
  FARMER_HAT_R = 220; FARMER_HAT_G = 190; FARMER_HAT_B = 100;
  FARMER_PANTS_R = 90; FARMER_PANTS_G = 70; FARMER_PANTS_B = 50;
  HAND_SHIRT_R = 90; HAND_SHIRT_G = 140; HAND_SHIRT_B = 70;
  HAND_HAT_R = 200; HAND_HAT_G = 90; HAND_HAT_B = 70;
  DOG_BODY_R = 150; DOG_BODY_G = 108; DOG_BODY_B = 66;
  DOG_LEG_R = 90; DOG_LEG_G = 65; DOG_LEG_B = 40;
  DOG_EAR_R = 60; DOG_EAR_G = 42; DOG_EAR_B = 26;
  TROUGH_FOOD_R = 210; TROUGH_FOOD_G = 160; TROUGH_FOOD_B = 70;
  TROUGH_WATER_R = 90; TROUGH_WATER_G = 160; TROUGH_WATER_B = 220;
  HUD_BG_R = 60; HUD_BG_G = 45; HUD_BG_B = 30;
  HUD_TEXT_R = 255; HUD_TEXT_G = 240; HUD_TEXT_B = 200;
  HUD_COIN_R = 240; HUD_COIN_G = 200; HUD_COIN_B = 40;
  BTN_BG_R = 96; BTN_BG_G = 72; BTN_BG_B = 46;
  BTN_SEL_R = 210; BTN_SEL_G = 160; BTN_SEL_B = 60;
  BTN_DIS_R = 55; BTN_DIS_G = 45; BTN_DIS_B = 38;
  PANEL_BG_R = 45; PANEL_BG_G = 34; PANEL_BG_B = 24;
  PANEL_BD_R = 210; PANEL_BD_G = 160; PANEL_BD_B = 60;
  BAR_BAD_R = 200; BAR_BAD_G = 70; BAR_BAD_B = 60;
  COIN_FLOAT_R = 255; COIN_FLOAT_G = 215; COIN_FLOAT_B = 60;

type
  TSheep = record
    id: Integer;
    x, y: Double;
    target_x, target_y: Double;
    facing: Double;
    hunger, thirst, wool: Double;
    wander_timer, bob_timer, flash_timer: Double;
  end;
  TTrough = record
    kind: Integer;
    x, y: Double;
    amount: Double;
  end;
  TWorker = record
    kind: Integer;
    x, y: Double;
    target_x, target_y: Double;
    facing: Double;
    walk_timer, wander_timer: Double;
    state, task: Integer;
    target_sheep_id: Integer;
    target_trough: Integer;
    work_timer, speed_mult: Double;
  end;
  TEffect = record
    kind: Integer;
    x, y: Double;
    value: Integer;
    timer, max_timer: Double;
  end;

var
  pixels: array[0..PIXEL_COUNT - 1] of Byte;
  bg: array[0..BG_MAX_COUNT - 1] of Byte;
  bg_w: Integer = 0;
  bg_h: Integer = 0;
  bg_level: Integer = -1;
  act_r: Byte = 255;
  act_g: Byte = 255;
  act_b: Byte = 255;
  act_a: Byte = 255;
  scratch: array[0..79] of Byte;
  numbuf: array[0..15] of Byte;
  sheep: array[0..MAX_SHEEP - 1] of TSheep;
  sheep_n: Integer = 0;
  workers: array[0..MAX_WORKERS - 1] of TWorker;
  worker_n: Integer = 0;
  troughs: array[0..MAX_TROUGHS - 1] of TTrough;
  trough_n: Integer = 0;
  effects: array[0..MAX_EFFECTS - 1] of TEffect;
  effect_n: Integer = 0;
  next_sheep_id: Integer = 0;
  claimed_sheep: array[0..MAX_SHEEP - 1] of Integer;
  claimed_sheep_n: Integer = 0;
  claimed_troughs: array[0..MAX_TROUGHS - 1] of Integer;
  claimed_troughs_n: Integer = 0;
  rng_state: Cardinal = 1;
  rnd_x: Double = 0.0;
  rnd_y: Double = 0.0;
  cw_x: Integer = 0;
  cw_y: Integer = 0;

{ ---- environment externals (pascaldom_env / odin_env) ---- }
function  dom_get_global(nm: string): Integer; external 'pascaldom_env' name 'dom_get_global';
function  dom_get_property(h: Integer; k: string): Integer; external 'pascaldom_env' name 'dom_get_property';
function  dom_get_element_by_id(id: string): Integer; external 'pascaldom_env' name 'dom_get_element_by_id';
procedure dom_set_inner_text(h: Integer; text: string); external 'pascaldom_env' name 'dom_set_inner_text';
function  dom_get_property_str(h: Integer; k: string; buf: Integer; maxlen: Integer): Integer;
          external 'pascaldom_env' name 'dom_get_property_str';
procedure dom_call_method0(h: Integer; nm: string); external 'pascaldom_env' name 'dom_call_method0';
function  dom_call_method_ret(h: Integer; nm: string): Integer;
          external 'pascaldom_env' name 'dom_call_method_ret';
procedure dom_add_event_listener(h: Integer; event: string; cb: Integer);
          external 'pascaldom_env' name 'dom_add_event_listener';
function  dom_canvas_create(parent: Integer; w, h: Integer): Integer;
          external 'pascaldom_env' name 'dom_canvas_create';
function  dom_canvas_get_context(cv: Integer): Integer;
          external 'pascaldom_env' name 'dom_canvas_get_context';
procedure dom_canvas_render(cv, ctx, pp, pl, w, h: Integer);
          external 'pascaldom_env' name 'dom_canvas_render';
procedure dom_start_animation_loop(cb: Integer); external 'pascaldom_env' name 'dom_start_animation_loop';
function  dom_now: Double; external 'pascaldom_env' name 'dom_now';

{ math }
function  mSqrt(x: Double): Double; external 'odin_env' name 'sqrt';
function  mSin(x: Double): Double; external 'odin_env' name 'sin';

implementation

begin
end.
