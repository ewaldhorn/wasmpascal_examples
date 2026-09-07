// fldefs.pas — FLIGHT LEADER shared definitions: constants, record types,
// global game state, and the host import surface (batch_env + app_env).
//
// One unit owns every cross-unit name so nothing is re-declared (unit merge
// dedups by name and keeps the FIRST declaration — re-declaring a constant
// or global here would silently win over a later one). Functions/procedures
// are prefixed by their unit (fx*, sim*, rd*, cb*) for the same reason.
unit fldefs;

interface

// ---------------------------------------------------------------------------
// Canvas + world tuning
// ---------------------------------------------------------------------------
const
  CW = 800;                 // canvas width
  CH = 600;                 // canvas height
  FOCAL = 430.0;            // perspective focal length (pixels)
  NEARZ = 0.8;              // near plane; objects behind it are culled

  MAX_STARS = 320;          // 3-layer starfield
  MAX_ENEMIES = 10;
  MAX_PBOLTS = 24;          // player laser bolts
  MAX_EBOLTS = 40;          // enemy laser bolts
  MAX_MISSILES = 6;
  MAX_PARTICLES = 420;      // 2D screen-space explosion particles
  MAX_DEBRIS = 90;
  MAX_SHOCKWAVES = 10;
  CMD_CAPACITY = 262144;    // batch command buffer (bytes)

  // flight tuning
  TURN_RATE = 1.9;          // rad/s at full stick deflection
  CRUISE_SPEED = 300.0;     // u/s at 100% throttle
  AFTERBURN_SPEED = 560.0;  // u/s with afterburner
  THROTTLE_RATE = 45.0;     // %/s
  PLAYER_RADIUS = 15.0;     // collision radius
  SHIELD_REGEN = 7.0;       // shields/s after SHIELD_DELAY
  SHIELD_DELAY = 2.2;       // s without damage before regen
  PLAYER_MAX_SHIELDS = 100.0;
  PLAYER_MAX_HULL = 100.0;

  // weapons
  LASER_COOLDOWN = 0.16;
  LASER_SPEED = 1800.0;
  LASER_DAMAGE = 14.0;
  LASER_LIFE = 2.2;
  BOLT_RADIUS = 16.0;       // laser-vs-ship proximity
  MISSILE_SPEED = 850.0;
  MISSILE_TURN = 2.6;       // rad/s homing turn limit
  MISSILE_LIFE = 7.0;
  MISSILE_DAMAGE = 70.0;
  MISSILE_FUSE = 34.0;
  LOCK_TIME = 0.55;         // s of tracking to acquire a lock
  LOCK_CONE = 0.62;         // min dot(fwd, toTarget) for a lock
  LOCK_RANGE = 3200.0;
  MISSILE_START = 3;        // missiles per mission

  // enemy tuning
  ENEMY_SPAWN_Z = 1100.0;
  ENEMY_SPAWN_SPREAD = 520.0;
  ENEMY_MAX_SPEED = 390.0;   // faster than cruise (300) so they can catch up;
                             // slower than afterburn (560) so you can escape
  ENEMY_TURN = 2.2;         // rad/s AI turn limit (tight enough to hold an orbit)
  ENEMY_FIRE_RANGE = 980.0;
  ENEMY_FIRE_ALIGN = 0.86;  // min dot(vel, toPlayer) to shoot
  ENEMY_LASER_SPEED = 900.0;
  ENEMY_LASER_DAMAGE = 7.0;
  ENEMY_COOLDOWN = 1.6;
  EVADE_TIME = 2.0;
  RETREAT_HP = 0.32;        // fraction of hp that triggers retreat (gunboat)
  CAPITAL_SPEED = 70.0;

  // scoring
  SCORE_FIGHTER = 100;
  SCORE_GUNBOAT = 300;
  SCORE_CAPITAL = 1000;

  // batch opcodes (batch.odin wire format)
  OP_SET_FILL = $01;
  OP_SET_STROKE = $02;
  OP_SET_LINE_WIDTH = $03;
  OP_SET_FONT = $04;
  OP_SET_TEXT_ALIGN = $05;
  OP_SET_TEXT_BASELINE = $06;
  OP_SET_GLOBAL_ALPHA = $07;
  OP_SET_LINE_CAP = $08;
  OP_FILL_RECT = $10;
  OP_STROKE_RECT = $11;
  OP_CLEAR_RECT = $12;
  OP_BEGIN_PATH = $20;
  OP_MOVE_TO = $21;
  OP_LINE_TO = $22;
  OP_CLOSE_PATH = $23;
  OP_ARC = $24;
  OP_ELLIPSE = $25;
  OP_RECT = $26;
  OP_FILL = $28;
  OP_STROKE = $29;
  OP_CLIP = $2A;
  OP_FILL_TEXT = $30;
  OP_STROKE_TEXT = $31;
  OP_BEZIER_CURVE_TO = $27;
  OP_SAVE = $40;
  OP_RESTORE = $41;
  OP_TRANSLATE = $42;
  OP_SCALE = $43;
  OP_ROTATE = $44;
  OP_SET_TRANSFORM = $45;
  OP_RESET_TRANSFORM = $46;
  OP_LINEAR_GRADIENT = $50;
  OP_RADIAL_GRADIENT = $51;
  OP_ADD_COLOR_STOP = $52;
  OP_USE_GRADIENT_FILL = $53;
  OP_USE_GRADIENT_STROKE = $54;
  OP_DRAW_SPRITE = $60;
  OP_DRAW_SPRITE_SCALED = $61;
  OP_DRAW_SPRITE_SUB = $62;
  OP_SET_SHADOW = $70;
  OP_CLEAR_SHADOW = $71;
  OP_SET_FILTER = $72;
  OP_CLEAR_FILTER = $73;
  OP_BAKE_BEGIN = $80;
  OP_BAKE_END = $81;

  // callback ids
  CB_TICK = 0;
  CB_KEYDOWN = 1;
  CB_KEYUP = 2;

  // key slots (filled by wcmain from evt.key strings)
  KEY_W = 0;        // throttle up
  KEY_S = 1;        // throttle down
  KEY_UP = 2;       // ArrowUp: pitch up
  KEY_DOWN = 3;     // ArrowDown: pitch down
  KEY_SPACE = 4;    // fire lasers
  KEY_SHIFT = 5;    // afterburner
  KEY_TAB = 6;      // missile lock / fire
  KEY_ENTER = 7;    // advance overlays
  KEY_P = 8;        // pause
  KEY_LEFT = 9;     // ArrowLeft: yaw left
  KEY_RIGHT = 10;   // ArrowRight: yaw right
  KEY_COUNT = 11;

  // sound slots (app_env.play_sound; host mini-synth in app.js + standalone)
  SND_FIRE = 0;
  SND_BANG_LARGE = 1;
  SND_BANG_MED = 2;
  SND_BANG_SMALL = 3;
  SND_SHIP_DEATH = 4;
  SND_WAVE = 5;
  SND_HYPER = 6;
  SND_THUD = 7;
  SND_LOCK = 8;        // missile lock tone
  SND_LAUNCH = 9;      // missile launch
  SND_SHIELD = 10;     // shield hit

  // game state
  GS_TITLE = 0;
  GS_BRIEFING = 1;
  GS_FLIGHT = 2;
  GS_WAVECLEAR = 3;
  GS_DEAD = 4;
  GS_DEBRIEF = 5;

  // enemy AI states
  ES_INBOUND = 0;
  ES_ATTACK = 1;
  ES_EVADE = 2;
  ES_RETREAT = 3;
  ES_CAPITAL = 4;

  // enemy classes
  EC_FIGHTER = 0;
  EC_GUNBOAT = 1;
  EC_CAPITAL = 2;

  WAVE_COUNT = 3;

// ---------------------------------------------------------------------------
// Record types
// ---------------------------------------------------------------------------
type
  TVec3 = record
    x, y, z: Single;
  end;

  TStar = record
    wx, wy, wz, tw: Single;   // world pos + twinkle phase
    layer: Integer;           // 0 far .. 2 near (parallax speed)
  end;

  TPlayer = record
    px, py, pz: Single;       // world position
    yaw, pitch, bank: Single; // orientation + visual bank (rad)
    throttle: Single;         // 0..100
    speed: Single;            // current u/s
    afterburn: Boolean;
    shields, hull: Single;
    missile_count: Integer;
    laser_cd: Single;
    shield_cd: Single;
    lock_target: Integer;     // enemy index or -1
    lock_timer: Single;
    locked: Boolean;
  end;

  TEnemy = record
    px, py, pz: Single;
    vx, vy, vz: Single;
    hp, max_hp: Single;
    cls: Integer;             // EC_*
    state: Integer;           // ES_*
    cooldown: Single;
    jink_phase: Single;       // weave phase (rad)
    evade_timer: Single;
    radius: Single;
    score: Integer;
    alive: Boolean;
    hit_flash: Single;        // white flash after being hit
  end;

  TBolt = record
    px, py, pz: Single;
    vx, vy, vz: Single;
    life: Single;
    active: Boolean;
  end;

  TMissile = record
    px, py, pz: Single;
    vx, vy, vz: Single;
    life: Single;
    target: Integer;
    active: Boolean;
  end;

  TParticle = record          // 2D screen-space
    x, y, vx, vy, life, max_life: Single;
    active: Boolean;
  end;

  TDebris = record            // 2D screen-space line shards
    x, y, vx, vy, ang, spin, len, life, max_life: Single;
    active: Boolean;
  end;

  TShock = record             // 2D expanding ring
    x, y, r, max_r, life, max_life: Single;
    active: Boolean;
  end;

// ---------------------------------------------------------------------------
// Shared game state
// ---------------------------------------------------------------------------
var
  // starfield + entities
  stars: array[0..MAX_STARS - 1] of TStar;
  player: TPlayer;
  enemies: array[0..MAX_ENEMIES - 1] of TEnemy;
  pbolts: array[0..MAX_PBOLTS - 1] of TBolt;
  ebolts: array[0..MAX_EBOLTS - 1] of TBolt;
  missiles: array[0..MAX_MISSILES - 1] of TMissile;

  // 2D effect pools (screen space)
  particles: array[0..MAX_PARTICLES - 1] of TParticle;
  debris: array[0..MAX_DEBRIS - 1] of TDebris;
  shocks: array[0..MAX_SHOCKWAVES - 1] of TShock;
  shake_mag: Single;
  shake_x: Single;
  shake_y: Single;

  // input (filled by wcmain key handlers)
  keys: array[0..KEY_COUNT - 1] of Boolean;
  just_pressed: array[0..KEY_COUNT - 1] of Boolean;

  // game flow
  game_state: Integer;
  wave: Integer;              // 1-based
  score: Integer;
  kills: Integer;
  shots_fired: Integer;
  shots_hit: Integer;
  state_timer: Single;        // overlay pause timers
  paused: Boolean;
  thrust_on: Boolean;         // engine-hum state (avoids duplicate set_thrust)
  lock_beeped: Boolean;       // missile-lock sound edge
  anim_time: Single;
  msg_timer: Single;
  msg_len: Integer;           // 0 = no message
  msg_buf: array[0..63] of Byte;

  // host handles
  cv_h: Integer = 0;          // canvas handle
  ctx_h: Integer = 0;         // context handle
  doc_h: Integer = 0;         // document handle
  last_event: Integer = 0;

  // scratch buffers for HUD text / property reads
  text_buf: array[0..63] of Byte;
  tmp16: array[0..15] of Byte;

  // batch command buffer (flbatch)
  cb_cmd: array[0..CMD_CAPACITY - 1] of Byte;
  cb_len: Integer = 0;

  rng_state: Cardinal = $9E3779B9;

// ---------------------------------------------------------------------------
// Host imports (batch_env + app_env; math builtins come from the compiler)
// ---------------------------------------------------------------------------
procedure bBatchFlush(c, buf, len: Integer); external 'batch_env' name 'batch_cmd_flush';
function  bNow: Double; external 'batch_env' name 'batch_now';
function  bCanvasCreate(parent, w, h: Integer): Integer; external 'batch_env' name 'batch_canvas_create';
function  bGetElement(p: Integer; n: Integer): Integer; external 'batch_env' name 'batch_get_element_by_id';
function  bGetGlobal(nm: Integer; n: Integer): Integer; external 'batch_env' name 'batch_get_global';
function  bGetContext(canvas: Integer): Integer; external 'batch_env' name 'batch_canvas_get_context';
procedure bStartLoop(cbId: Integer); external 'batch_env' name 'batch_start_animation_loop';
procedure bAddListener(elem: Integer; ev: Integer; n: Integer; cb: Integer);
          external 'batch_env' name 'batch_add_event_listener';
function  bGetPropStr(h: Integer; k: Integer; kn: Integer; buf: Integer; maxlen: Integer): Integer;
          external 'batch_env' name 'batch_get_property_str';
function  bCallMethodRet(h: Integer; m: Integer; mn: Integer): Integer;
          external 'batch_env' name 'batch_call_method_ret';

procedure aSetFps(f: Single); external 'app_env' name 'set_fps';
procedure aPlaySound(id: Integer); external 'app_env' name 'play_sound';
procedure aSetThrust(on: Integer); external 'app_env' name 'set_thrust';

// Math imports (Double signature). NOTE: the compiler's math BUILTINS
// (Sin/Cos/...) promote only Integer args to f64 — a Single arg is passed
// as f32 and produces invalid wasm — so the game routes all float math
// through these Double externals with explicit casts (pascaloids pattern).
function mSin(x: Double): Double; external 'odin_env' name 'sin';
function mCos(x: Double): Double; external 'odin_env' name 'cos';
function mAtan2(y, x: Double): Double; external 'odin_env' name 'atan2';
function mPow(b, e: Double): Double; external 'odin_env' name 'pow';

implementation

begin
end.
