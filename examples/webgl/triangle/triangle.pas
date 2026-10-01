{
  WasmPascal and WebGL

  triangle.pas — the Pascal side of the classic WebGL 2 demo.

  THE SIDES

  JavaScript (host.js) is a generic WebGL 2 host: canvas, context, resize,
  shader compile/link, one VAO/VBO pair, uniforms, draw calls and the frame
  loop. It knows nothing about triangles — the same file drives any example
  that speaks the webgl ABI below.

  Pascal (triangle.pas) owns everything triangle-specific: the two shaders,
  the vertex layout, the clear colour, the draw mode, the geometry and the
  animation. Every frame it rewrites 15 floats and tells the host to draw.

  THE CONTRACT (the generic webgl ABI):

    Pascal exports      webgl_main            build the GL pipeline, once
                        webgl_frame(t_ms)     fill the vertices, draw, per frame

    Pascal imports      webgl_env.gl_program(vs, fs)
                        webgl_env.gl_attr(index, size, stride, offset)
                        webgl_env.gl_alloc(bytes)
                        webgl_env.gl_upload(ptr, bytes)
                        webgl_env.gl_clear(r, g, b, a)
                        webgl_env.gl_draw(mode, first, count)
                        webgl_env.gl_uniform_f(name, v)
                        webgl_env.gl_canvas_width / gl_canvas_height

    Implicit imports    odin_env.sin, odin_env.cos (Sin/Cos are compiler
                        builtins; the host also provides the rest of Math.*
                        so future examples just work)

  THE VERTEX LAYOUT, written down once, here:

      0 x   1 y   2 r   3 g   4 b     -- 5 floats = 20 bytes per vertex

  Compile it with the repo's CLI compiler:

      node wpcompile.mjs triangle.pas -o triangle.wasm
      ./build.sh        # does the above, then stages dist/}

library triangle;

const
  { The three corners of an equilateral triangle on the unit circle, pointing
    up: 90, 210 and 330 degrees. Rotating these drives the animation. }
  CORNER_X: array[0..2] of Single = (0.0, -0.8660254, 0.8660254);
  CORNER_Y: array[0..2] of Single = (1.0, -0.5, -0.5);

  { One colour per corner — red, green, blue — so it is obvious in the picture
    that the colour is interpolated across the face, not flat. }
  CORNER_R: array[0..2] of Single = (1.0, 0.0, 0.0);
  CORNER_G: array[0..2] of Single = (0.0, 1.0, 0.0);
  CORNER_B: array[0..2] of Single = (0.0, 0.0, 1.0);

  VERT_COUNT  = 3;
  VERT_FLOATS = 5;         { x, y, r, g, b }
  RADIUS      = 0.75;      { how much of the clip-space square the triangle fills }
  SPIN_RATE   = 1.0;       { radians per second }

  GL_TRIANGLES = 4;        { the draw mode, a GL enum passed straight through }

  CLEAR_R = 0.06;          { the page's dark backdrop }
  CLEAR_G = 0.07;
  CLEAR_B = 0.10;

  { The two shaders. The classic tutorial pair, minus the uniforms a tutorial
    usually has: Pascal sends final clip-space positions, so the only thing
    left to correct for is the window's aspect ratio — and Pascal sets that
    uniform itself every frame (see TriangleFrame), so the host never sees it.
    Newlines are #10; adjacent literals concatenate. }
  VS_SRC =
    '#version 300 es'#10 +
    'layout(location = 0) in vec2 a_pos;'#10 +
    'layout(location = 1) in vec3 a_color;'#10 +
    'uniform float u_aspect;'#10 +
    'out vec3 v_color;'#10 +
    'void main() {'#10 +
    '  gl_Position = vec4(a_pos.x / u_aspect, a_pos.y, 0.0, 1.0);'#10 +
    '  v_color = a_color;'#10 +
    '}'#10;

  FS_SRC =
    '#version 300 es'#10 +
    'precision highp float;'#10 +
    'in vec3 v_color;'#10 +
    'out vec4 frag;'#10 +
    'void main() { frag = vec4(v_color, 1.0); }'#10;

var
  { The vertex array itself. The host does not copy it — `ptr` below is the
    address of this array inside the wasm module's linear memory, so what gets
    uploaded to the GPU is this variable, as it stands at the end of
    TriangleFrame. Read-only from JS: the layout and the values are
    entirely Pascal's. }
  verts: array[0..VERT_COUNT * VERT_FLOATS - 1] of Single;

{ ---- the host side ---------------------------------------------------------
  `external 'module' name 'fn'` names both the import module and the function,
  exactly as they must appear in the host's importObject. A `string` parameter
  arrives in JS as a (ptr, len) pair into this module's memory; a Single
  arrives as a number. Nothing here is triangle-specific: these are generic
  GL primitives that happen to draw a triangle when driven this way. }
function  gl_program(vs, fs: string): Integer; external 'webgl_env' name 'gl_program';
procedure gl_attr(index, size, stride_floats, offset_floats: Integer); external 'webgl_env' name 'gl_attr';
procedure gl_alloc(byte_size: Integer); external 'webgl_env' name 'gl_alloc';
procedure gl_upload(ptr, byte_size: Integer); external 'webgl_env' name 'gl_upload';
procedure gl_clear(r, g, b, a: Single); external 'webgl_env' name 'gl_clear';
procedure gl_draw(mode, first, count: Integer); external 'webgl_env' name 'gl_draw';
procedure gl_uniform_f(name: string; v: Single); external 'webgl_env' name 'gl_uniform_f';
function  gl_canvas_width: Integer; external 'webgl_env' name 'gl_canvas_width';
function  gl_canvas_height: Integer; external 'webgl_env' name 'gl_canvas_height';

{ Called once by the host, after the canvas exists. The constant half of the
  vertex data (the colours) is written here; the positions are rewritten every
  frame. Returns 0 if the GL pipeline could not be built. }
function TriangleMain: Integer;
var
  i: Integer;
begin
  for i := 0 to VERT_COUNT - 1 do
  begin
    verts[i * VERT_FLOATS + 2] := CORNER_R[i];
    verts[i * VERT_FLOATS + 3] := CORNER_G[i];
    verts[i * VERT_FLOATS + 4] := CORNER_B[i];
  end;
  if gl_program(VS_SRC, FS_SRC) = 0 then
  begin
    TriangleMain := 0;
    Exit;
  end;
  gl_attr(0, 2, VERT_FLOATS, 0);   { a_pos: vec2 at float 0 }
  gl_attr(1, 3, VERT_FLOATS, 2);   { a_color: vec3 at float 2 }
  gl_alloc(VERT_COUNT * VERT_FLOATS * 4);
  TriangleMain := 1;
end;

{ Called by the host once per animation frame with the frame timestamp.

  `t_ms`, not a per-frame delta, on purpose: the angle is a function of the page
  clock, so the spin runs at the same speed on a 60 Hz and a 120 Hz display and
  a late frame does not slow it down. }
procedure TriangleFrame(t_ms: Double);
var
  i: Integer;
  angle: Double;
  c, s: Double;
  x, y: Double;
  w, h: Integer;
begin
  angle := t_ms / 1000.0 * SPIN_RATE;
  c := Cos(angle);                       { odin_env.cos on the host side }
  s := Sin(angle);                       { odin_env.sin on the host side }

  for i := 0 to VERT_COUNT - 1 do
  begin
    x := CORNER_X[i];
    y := CORNER_Y[i];
    verts[i * VERT_FLOATS + 0] := Single((x * c - y * s) * RADIUS);
    verts[i * VERT_FLOATS + 1] := Single((x * s + y * c) * RADIUS);
  end;

  { Aspect correction lives here now, not in the host's resize handler: the
    host owns the canvas size, Pascal owns what the shader does with it. }
  w := gl_canvas_width;
  h := gl_canvas_height;
  if h <= 0 then h := 1;
  gl_uniform_f('u_aspect', Single(w / h));

  gl_upload(Integer(@verts), VERT_COUNT * VERT_FLOATS * 4);
  gl_clear(CLEAR_R, CLEAR_G, CLEAR_B, 1.0);
  gl_draw(GL_TRIANGLES, 0, VERT_COUNT);
end;

exports
  TriangleMain  name 'webgl_main',
  TriangleFrame name 'webgl_frame';

begin
end.
