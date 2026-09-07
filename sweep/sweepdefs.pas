unit sweepdefs;

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


// ---- environment externals (pascaldom_env / odin_env) ----
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

// localStorage (raw ptr/len signatures; pass StrAddr('...')/StrLen('...') literals)
function  ls_get_item(kp: Integer; kl: Integer; buf: Integer; maxlen: Integer): Integer;
          external 'pascaldom_env' name 'dom_local_storage_get_item';
procedure ls_set_item(kp, kl, vp, vl: Integer);
          external 'pascaldom_env' name 'dom_local_storage_set_item';

// math
function  mSqrt(x: Double): Double; external 'odin_env' name 'sqrt';


implementation


begin
end.
