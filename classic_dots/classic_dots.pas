// classic_dots.pas — 4000 bouncing dots with ball-to-ball collision and a
// full-spectrum baked palette, ported to Pascal via wasmpascal. basic_canvas
// ABI (wasm_init / wasm_update / wasm_click / wasm_pointer_* /
// wasm_get_pixels): the host blits the RGBA pixel buffer with one
// putImageData per frame.
//
// Ported from screensavers/classic/src/dot.odin + main.odin: same 4000-dot
// count, same DOT_RADIUS/SPEED, same spatial-hash collisions every other
// frame, same click/touch-drag scatter (PUSH_BOOST, decaying back to 1).
//
// Dots start at the centre with random headings, bounce off the walls, and
// collide elastically via a uniform spatial hash grid (GRID_CELL = 16, the
// dot diameter, so dots only meet in adjacent cells). The collision sweep
// runs every other frame, as in the original. Zero per-frame allocation:
// all state is module-level arrays.
library classic_dots;

const
  WIDTH    = 800;
  HEIGHT   = 600;
  BUF_SIZE = LongInt(WIDTH) * LongInt(HEIGHT) * 4;

  TAU = 6.283185307179586;

  NUM_DOTS    = 4000;
  NUM_COLOURS = 64;
  DOT_RADIUS  = 5;
  DOT_SPEED   = 67.0;
  BG_R = 5;
  BG_G = 7;
  BG_B = 13;

  // Spatial hash grid: cell >= dot diameter, dots collide only in the 3x3
  // neighbourhood of their own cell.
  GRID_CELL = 16;
  GRID_COLS = 50;   // WIDTH div GRID_CELL
  GRID_ROWS = 38;   // (HEIGHT + GRID_CELL - 1) div GRID_CELL
  GRID_LEN  = 1900; // GRID_COLS * GRID_ROWS

  PUSH_R2     = 5625.0; // PUSH_RADIUS(75)^2 — compare against dist_sq
  PUSH_BOOST  = 4.0;
  BOOST_DECAY = 0.85;

  SPEC_A = 90; // specular highlight alpha (white at ~0.35 over the dot)

var
  dot_x, dot_y, dot_vx, dot_vy, dot_boost: array[0..NUM_DOTS - 1] of Single;
  dot_r, dot_g, dot_b: array[0..NUM_DOTS - 1] of Byte;
  pal_r, pal_g, pal_b: array[0..NUM_COLOURS - 1] of Byte;
  grid_head: array[0..GRID_LEN - 1] of Integer;
  grid_next: array[0..NUM_DOTS - 1] of Integer;
  frame_count: Integer = 0;
  rngState: Cardinal = $DEADBEEF;
  // True while a pointer (mouse button or touch) is held down on the canvas.
  dragging: Boolean = False;

procedure _haltproc(exitCode: Integer); external 'env' name '_haltproc';

// Trig comes from the host's odin_env Math.* imports (transforms.pas
// pattern); Sqrt stays a native wasm op via the Sqrt builtin.
function mSin(x: Double): Double; external 'odin_env' name 'sin';
function mCos(x: Double): Double; external 'odin_env' name 'cos';

// Pixel buffer base address — fixed offset past static data in WASM memory.
// $30000 (192 KB) is safely past all data segments (~116 KB here: five
// 4000xSingle arrays + grid + palette) with margin.
function PixelBase: PByte;
begin
  PixelBase := PByte($30000);
end;

function RngNext: Cardinal;
begin
  rngState := rngState xor (rngState shl 13);
  rngState := rngState xor (rngState shr 17);
  rngState := rngState xor (rngState shl 5);
  RngNext := rngState;
end;

function RngFloat: Single;
begin
  // Shift to 24 bits; divide by 2^24 for a uniform [0, 1) float.
  RngFloat := (RngNext shr 8) / 16777216.0;
end;

// HslToRgb converts HSL (hue 0..359, sat/light 0..1) to RGB 0..255.
// Standard algorithm, ported from hsl_to_rgb in dot.odin.
procedure HslToRgb(hue: Integer; sat, light: Single; var r, g, b: Integer);
var
  sec: Integer;
  frac, c, x, m: Single;
  rr, gg, bb: Single;
  n: Single;
begin
  sec := hue div 60;
  frac := (hue mod 60) / 60.0;
  if 2.0 * light - 1.0 < 0.0 then
    c := (1.0 - (1.0 - 2.0 * light)) * sat
  else
    c := (1.0 - (2.0 * light - 1.0)) * sat;
  if sec mod 2 = 0 then
    x := c * (1.0 - frac)
  else
    x := c * frac;
  m := light - c / 2.0;
  case sec of
    0: begin rr := c; gg := x; bb := 0.0; end;
    1: begin rr := x; gg := c; bb := 0.0; end;
    2: begin rr := 0.0; gg := c; bb := x; end;
    3: begin rr := 0.0; gg := x; bb := c; end;
    4: begin rr := x; gg := 0.0; bb := c; end;
    else begin rr := c; gg := 0.0; bb := x; end;
  end;
  n := (rr + m) * 255.0;
  if n < 0.0 then n := 0.0;
  if n > 255.0 then n := 255.0;
  r := Trunc(n);
  n := (gg + m) * 255.0;
  if n < 0.0 then n := 0.0;
  if n > 255.0 then n := 255.0;
  g := Trunc(n);
  n := (bb + m) * 255.0;
  if n < 0.0 then n := 0.0;
  if n > 255.0 then n := 255.0;
  b := Trunc(n);
end;

// BakePalette pre-computes the 64-entry RGBA palette from HSL, once at init.
// The frame loop never touches colour math — each dot writes its baked RGB.
procedure BakePalette;
var
  i, hue, r, g, b: Integer;
  sat, light: Single;
begin
  for i := 0 to NUM_COLOURS - 1 do
  begin
    hue := i * 360 div NUM_COLOURS;
    sat := 0.75 + (i mod 3) * 0.10;
    light := 0.45 + (i mod 5) * 0.06;
    HslToRgb(hue, sat, light, r, g, b);
    pal_r[i] := Byte(r);
    pal_g[i] := Byte(g);
    pal_b[i] := Byte(b);
  end;
end;

// InitDots places every dot at the centre with a random heading at
// DOT_SPEED and deals it a palette colour.
procedure InitDots;
var
  i: Integer;
  angle: Single;
begin
  BakePalette;
  for i := 0 to NUM_DOTS - 1 do
  begin
    dot_x[i] := WIDTH / 2.0;
    dot_y[i] := HEIGHT / 2.0;
    angle := RngFloat * TAU;
    dot_vx[i] := Single(mCos(angle)) * DOT_SPEED;
    dot_vy[i] := Single(mSin(angle)) * DOT_SPEED;
    dot_boost[i] := 1.0;
    dot_r[i] := pal_r[RngNext mod NUM_COLOURS];
    dot_g[i] := pal_g[RngNext mod NUM_COLOURS];
    dot_b[i] := pal_b[RngNext mod NUM_COLOURS];
  end;
end;

// GridCell returns the flat grid cell index for a position, clamped.
function GridCell(x, y: Integer): Integer;
var
  cx, cy: Integer;
begin
  cx := x div GRID_CELL;
  cy := y div GRID_CELL;
  if cx < 0 then cx := 0;
  if cx >= GRID_COLS then cx := GRID_COLS - 1;
  if cy < 0 then cy := 0;
  if cy >= GRID_ROWS then cy := GRID_ROWS - 1;
  GridCell := cy * GRID_COLS + cx;
end;

// MoveDots advances positions (with decaying click boost) and bounces off
// the walls.
procedure MoveDots(dt: Single);
var
  i: Integer;
begin
  for i := 0 to NUM_DOTS - 1 do
  begin
    dot_x[i] := dot_x[i] + dot_vx[i] * dot_boost[i] * dt;
    dot_y[i] := dot_y[i] + dot_vy[i] * dot_boost[i] * dt;
    dot_boost[i] := 1.0 + (dot_boost[i] - 1.0) * BOOST_DECAY;

    if dot_x[i] - DOT_RADIUS < 0 then
    begin dot_x[i] := DOT_RADIUS; dot_vx[i] := -dot_vx[i]; end
    else if dot_x[i] + DOT_RADIUS > WIDTH then
    begin dot_x[i] := WIDTH - DOT_RADIUS; dot_vx[i] := -dot_vx[i]; end;
    if dot_y[i] - DOT_RADIUS < 0 then
    begin dot_y[i] := DOT_RADIUS; dot_vy[i] := -dot_vy[i]; end
    else if dot_y[i] + DOT_RADIUS > HEIGHT then
    begin dot_y[i] := HEIGHT - DOT_RADIUS; dot_vy[i] := -dot_vy[i]; end;
  end;
end;

// CollideDots resolves elastic collisions between equal dots via the
// spatial grid: each dot checks only the 3x3 block around its own cell.
// Runs every other frame (frame_count gate in UpdateDots).
procedure CollideDots;
var
  i, c, ci, ri, dcx, dcy, nx, ny, nc, j: Integer;
  dx, dy, dist_sq, dist, nxp, nyp, dvn, overlap: Single;
begin
  for i := 0 to GRID_LEN - 1 do grid_head[i] := -1;
  for i := 0 to NUM_DOTS - 1 do
  begin
    c := GridCell(Trunc(dot_x[i]), Trunc(dot_y[i]));
    grid_next[i] := grid_head[c];
    grid_head[c] := i;
  end;
  for i := 0 to NUM_DOTS - 1 do
  begin
    c := GridCell(Trunc(dot_x[i]), Trunc(dot_y[i]));
    ci := c mod GRID_COLS;
    ri := c div GRID_COLS;
    for dcx := -1 to 1 do
      for dcy := -1 to 1 do
      begin
        nx := ci + dcx;
        ny := ri + dcy;
        if (nx < 0) or (nx >= GRID_COLS) or (ny < 0) or (ny >= GRID_ROWS) then
          Continue;
        nc := ny * GRID_COLS + nx;
        j := grid_head[nc];
        while j <> -1 do
        begin
          if j > i then
          begin
            dx := dot_x[j] - dot_x[i];
            dy := dot_y[j] - dot_y[i];
            dist_sq := dx * dx + dy * dy;
            if (dist_sq < (DOT_RADIUS * 2) * (DOT_RADIUS * 2)) and (dist_sq > 0.0001) then
            begin
              dist := Sqrt(dist_sq);
              nxp := dx / dist;
              nyp := dy / dist;
              dvn := (dot_vx[i] - dot_vx[j]) * nxp + (dot_vy[i] - dot_vy[j]) * nyp;
              if dvn > 0.0 then
              begin
                dot_vx[i] := dot_vx[i] - dvn * nxp;
                dot_vy[i] := dot_vy[i] - dvn * nyp;
                dot_vx[j] := dot_vx[j] + dvn * nxp;
                dot_vy[j] := dot_vy[j] + dvn * nyp;
              end;
              overlap := (DOT_RADIUS * 2) - dist;
              dot_x[i] := dot_x[i] - nxp * overlap * 0.5;
              dot_y[i] := dot_y[i] - nyp * overlap * 0.5;
              dot_x[j] := dot_x[j] + nxp * overlap * 0.5;
              dot_y[j] := dot_y[j] + nyp * overlap * 0.5;
            end;
          end;
          j := grid_next[j];
        end;
      end;
  end;
end;

procedure UpdateDots(dt: Single);
begin
  frame_count := (frame_count + 1) and 1;
  MoveDots(dt);
  if frame_count = 0 then
    CollideDots;
end;

// Fill the entire pixel buffer with a solid colour (32-bit word stores;
// WASM is little-endian so the byte order is R, G, B, A).
procedure ClearScreen(r, g, b: Byte);
var
  color: Cardinal;
  p: ^Cardinal;
  i: LongInt;
begin
  color := r or (Cardinal(g) shl 8) or (Cardinal(b) shl 16) or (255 shl 24);
  p := pointer(PixelBase);
  for i := 0 to BUF_SIZE div 4 - 1 do
    p[i] := color;
end;

// DrawDots rasterizes every dot as a filled RGBA stamp of its baked colour,
// with a soft white specular blend in the upper-left quadrant (the Bayer
// rim dither of the Odin original is skipped — at these sizes the stamp
// edge reads the same once CSS-upscaled).
procedure DrawDots;
var
  i, cx, cy, x0, y0, x1, y1, x, y, dx, dy, d2: Integer;
  base, row_off: Cardinal;
  p: PByte;
  r, g, b: Byte;
begin
  p := PixelBase;
  for i := 0 to NUM_DOTS - 1 do
  begin
    cx := Trunc(dot_x[i]);
    cy := Trunc(dot_y[i]);
    x0 := cx - DOT_RADIUS;
    y0 := cy - DOT_RADIUS;
    x1 := cx + DOT_RADIUS;
    y1 := cy + DOT_RADIUS;
    if x0 < 0 then x0 := 0;
    if y0 < 0 then y0 := 0;
    if x1 >= WIDTH then x1 := WIDTH - 1;
    if y1 >= HEIGHT then y1 := HEIGHT - 1;
    if (x0 > x1) or (y0 > y1) then
      Continue;
    base := (Cardinal(y0) * WIDTH + Cardinal(x0)) * 4;
    row_off := (Cardinal(WIDTH) - Cardinal(x1 - x0 + 1)) * 4;
    r := dot_r[i];
    g := dot_g[i];
    b := dot_b[i];
    for y := y0 to y1 do
    begin
      for x := x0 to x1 do
      begin
        dx := x - cx;
        dy := y - cy;
        d2 := dx * dx + dy * dy;
        if d2 <= DOT_RADIUS * DOT_RADIUS then
        begin
          p[base] := r;
          p[base + 1] := g;
          p[base + 2] := b;
          p[base + 3] := 255;
          if (dx < 0) and (dy < 0) then
          begin
            p[base] := Byte((255 * SPEC_A + Word(p[base]) * (255 - SPEC_A)) div 255);
            p[base + 1] := Byte((255 * SPEC_A + Word(p[base + 1]) * (255 - SPEC_A)) div 255);
            p[base + 2] := Byte((255 * SPEC_A + Word(p[base + 2]) * (255 - SPEC_A)) div 255);
          end;
        end;
        base := base + 4;
      end;
      base := base + row_off;
    end;
  end;
end;

procedure wasm_init;
var
  p: PByte;
begin
  p := PixelBase;
  FillChar(p^, BUF_SIZE, 0);
  frame_count := 0;
  InitDots;
end;

procedure wasm_update(dt: Single);
begin
  if dt > 0.1   then dt := 0.1;
  if dt < 0.001 then dt := 0.001;

  ClearScreen(BG_R, BG_G, BG_B);

  UpdateDots(dt);
  DrawDots;
end;

// RepelAt scatters dots within PUSH_RADIUS of (x, y): they are re-aimed
// directly away at DOT_SPEED with a boost that decays over the next frames.
procedure RepelAt(x, y: Integer);
var
  i: Integer;
  dx, dy, dist_sq, dist: Single;
begin
  for i := 0 to NUM_DOTS - 1 do
  begin
    dx := dot_x[i] - Single(x);
    dy := dot_y[i] - Single(y);
    dist_sq := dx * dx + dy * dy;
    if (dist_sq < PUSH_R2) and (dist_sq > 0.0001) then
    begin
      dist := Sqrt(dist_sq);
      dot_vx[i] := dx / dist * DOT_SPEED;
      dot_vy[i] := dy / dist * DOT_SPEED;
      dot_boost[i] := PUSH_BOOST;
    end;
  end;
end;

// Click (or tap) to scatter.
procedure wasm_click(x, y: Integer);
begin
  RepelAt(x, y);
end;

// Press-and-drag scatter (mouse or touch — the host forwards Pointer Events
// for both): repel on press and on every move while held, like the Odin
// original. Hover moves (no button held) do nothing.
procedure wasm_pointer_down(x, y: Integer);
begin
  dragging := True;
  RepelAt(x, y);
end;

procedure wasm_pointer_move(x, y: Integer);
begin
  if dragging then
    RepelAt(x, y);
end;

procedure wasm_pointer_up;
begin
  dragging := False;
end;

function wasm_get_pixels: PByte;
begin
  wasm_get_pixels := PixelBase;
end;

function wasm_get_width: Integer;
begin
  wasm_get_width := WIDTH;
end;

function wasm_get_height: Integer;
begin
  wasm_get_height := HEIGHT;
end;

exports
  wasm_init         name 'wasm_init',
  wasm_update       name 'wasm_update',
  wasm_click        name 'wasm_click',
  wasm_pointer_down name 'wasm_pointer_down',
  wasm_pointer_move name 'wasm_pointer_move',
  wasm_pointer_up   name 'wasm_pointer_up',
  wasm_get_pixels   name 'wasm_get_pixels',
  wasm_get_width    name 'wasm_get_width',
  wasm_get_height   name 'wasm_get_height';

begin
end.

