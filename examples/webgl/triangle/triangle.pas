{
  WasmPascal and WebGL

  triangle.pas — the Pascal side of the classic WebGL 2 demo.

  THE SIDES

  JavaScript (host.js) owns the browser side of things, like the canvas, WebGL 2 context, shaders,
  vertex buffer and the draw call.

  Pascal (triangle.pas) owns the geometry and writes 15 floats, three vertices of (x, y, r, g, b),
  into its own memory every frame and asks the host to draw them.

  PUTTING IT TOGETHER:

    Pascal exports      tri_main            create the GL pipeline, only needed once
                        tri_frame(t_ms)     fill the vertex array, draw, per frame

    Pascal imports      webgl_env.gl_create(count, floats_per_vertex)
                        webgl_env.gl_frame(ptr, count)

    Implicit imports    odin_env.sin, odin_env.cos

  THE VERTEX LAYOUT, written down once, here, and handed to the host by
  gl_create rather than repeated on the other side:

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

var
  { The vertex array itself. The host does not copy it — `ptr` below is the
    address of this array inside the wasm module's linear memory, so what gets
    uploaded to the GPU is this variable, as it stands at the end of TriFrame.
    Read-only from JS: the layout and the values are entirely Pascal's. }
  verts: array[0..VERT_COUNT * VERT_FLOATS - 1] of Single;

{ ---- the host side ---------------------------------------------------------
  `external 'module' name 'fn'` names both the import module and the function,
  exactly as they must appear in the host's importObject. Nothing here is
  WebGL-specific: these are just calls into JavaScript that happen to create GL
  objects on this side of the boundary. }
function  gl_create(count, floats_per_vertex: Integer): Integer; external 'webgl_env' name 'gl_create';
procedure gl_frame(ptr, count: Integer); external 'webgl_env' name 'gl_frame';

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
  TriangleMain := gl_create(VERT_COUNT, VERT_FLOATS);
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

  gl_frame(Integer(@verts), VERT_COUNT);
end;

exports
  TriangleMain  name 'triangle_main',
  TriangleFrame name 'triangle_frame';

begin
end.
