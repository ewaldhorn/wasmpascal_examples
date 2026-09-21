unit sweepdefs;

{$mode fpc}

interface

const
  CELL_SIZE = 24;
  MAX_W = 30;
  MAX_H = 16;
  CANVAS_W = 748;
  CANVAS_H = 458;
  PIXEL_COUNT = CANVAS_W * CANVAS_H * 4;
  CS_INITIAL = 0; CS_OPENED = 1; CS_FLAGGED = 2; CS_UNCERTAIN = 3;
  ST_UNDEFINED = 0; ST_PLAYING = 1; ST_LOST = 2; ST_WON = 3;
  FS_NORMAL = 0; FS_WORRIED = 1; FS_WON = 2; FS_LOST = 3;
  MB_NONE = 0; MB_LEFT = 1; MB_RIGHT = 2;
  CB_CLICK = 0; CB_CONTEXTMENU = 1; CB_MOUSEMOVE = 2; CB_MOUSEDOWN = 3;
  CB_MOUSEUP = 4; CB_TICK = 5; CB_RESIZE = 6; CB_KEYDOWN = 7;
  SEVEN_SEG_0 = $3F; SEVEN_SEG_1 = $06; SEVEN_SEG_2 = $5B; SEVEN_SEG_3 = $4F;
  SEVEN_SEG_4 = $66; SEVEN_SEG_5 = $6D; SEVEN_SEG_6 = $7D; SEVEN_SEG_7 = $07;
  SEVEN_SEG_8 = $7F; SEVEN_SEG_9 = $6F;


var
  pixels: array[0..PIXEL_COUNT - 1] of Byte;
  act_r: Byte = 255;
  act_g: Byte = 255;
  act_b: Byte = 255;
  act_a: Byte = 255;
  scratch: array[0..79] of Byte;
  text_buf: array[0..31] of Byte;
  tmp16: array[0..15] of Byte;

  // var-param output scratch (wasmpascal has no local-address; var args = globals)
  bix, biy, biw, bih: Integer;
  win_w, win_h: Integer;
  win_ox, win_oy: Integer;
  field_x, field_y, field_w, field_h: Integer;
  face_x, face_y, face_w, face_h: Integer;
  cell_i, cell_j: Integer;
  num_r, num_g, num_b: Integer;
  cw_x, cw_y: Integer;
  top_x, top_y, top_w, top_h: Integer;


// ---- the bridge ------------------------------------------------------------
//
// `uses WEB` (DOMPLAN.md D1/D2) brings the whole pascaldom bridge in from the
// compiler binary: the `dom_*` entry points below used to be declared here as
// `external 'odindom_env'` and are now the embedded unit's, under the same
// names and with the same signatures — that is what makes the migration a
// deletion rather than a rewrite. The unit also owns the callback entry points
// (`pascaldom_invoke_callback` / `pascaldom_set_last_event`) and the dispatch
// table, so the game no longer picks callback ids or writes a `case id of`
// dispatcher (see sweephost.pas).
//
// The module name follows the unit: `pascaldom_env`, not `odindom_env` — the
// host is `pascaldom.js` (see README.md § ABI and index.html).
uses
  WEB;

// math
function  mSqrt(x: Double): Double; external 'odin_env' name 'sqrt';


implementation


begin
end.
