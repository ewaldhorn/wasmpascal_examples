# WebGL Triangle using WasmPascal

In the world of WebGL, one demo stands out to me: The classic colour triangle that is slowly
spinning around.  So naturally, when I wanted to create a WasmPascal and WebGL demo, this
is what I built!

Being Web Assembly, there's more needed than just the Pascal-based binary, we also need some
JavaScript magic to tie things together. I ended up splitting things up like this:

- **JavaScript** (`host.js`): A *generic* WebGL 2 host. It handles the browser side of things,
  like the canvas, the WebGL 2 context, resize, shader compile/link, one VAO/VBO pair, uniforms
  and the draw call — but it knows nothing about triangles. No shaders, no layout, no colours,
  no draw mode live here, so the same file can drive future WebGL examples unchanged.
- **Pascal** (`triangle.pas`): Owns everything triangle-specific: the two shaders, the vertex
  layout, the clear colour, the draw mode, the geometry and the animation. It writes three vertices
  of (`x, y, r, g, b`) each and drives the host's primitives, because wasm doesn't have direct
  access to the DOM or browser API's.


## How to run

```sh
./serve.sh       # builds, then serves dist/ on :8080
                 # open http://localhost:8080/
```

`./build.sh` compiles `triangle.pas` to `dist/triangle.wasm` and populates `dist/` with `index.html`
and `host.js`. Since a `.wasm` binary cannot be fetched over `file://`, it needs a static server.
`serve.sh` uses `python3 -m http.server`, but just about any static server should do. I just
happen to use Python quite a lot!

While WasmPascal will compile this binary, it won't be able to run it. This is one of the examples that
is best served using the CLI WasmPascal compiler. I used the online one to compile the binary and
just downloaded it, added the needed HTML and JavaScript and it worked perfectly. So you absolutely
don't _need_ to install the CLI tools. There's a tutorial in the README at [WasmPascal Examples](https://github.com/ewaldhorn/wasmpascal_examples)
if you wanted to get the CLI compiler going. My current setup is using the CLI and the Zed editor, and it
works pretty well.

## So how does it work

The Pascal binary exports two functions for the host script to call. Every WebGL example uses
these same names, which is what keeps the host generic:

- **`webgl_main()`**: Called once, after the canvas has been created. First it writes the constants used for colours,
  then it hands the shaders to the host, describes the vertex layout and sizes the buffer.
  A return of 0 indicates it was unable to create the pipeline.

- **`webgl_frame(t_ms)`**: Called per animation frame, with the frame timestamp as an argument.
  It writes the rotated positions to the memory buffer, sets the aspect uniform, uploads the
  vertices and draws — one host call per step.

The JavaScript host provides generic GL primitives for the Pascal binary to drive:

- **`webgl_env.gl_program(vs, fs)`**: Compiles and links the two shader strings Pascal passes,
  makes one VAO/VBO pair current. Returns 1, or 0 with the info log on the console.
- **`webgl_env.gl_attr(index, size, stride, offset)`**: One vertex attribute (floats, not bytes).
- **`webgl_env.gl_alloc(bytes)`**: Sizes the VBO.
- **`webgl_env.gl_upload(ptr, bytes)`**: Copies `bytes` from `ptr` — a byte offset into the wasm
  module's linear memory — into the VBO. This way, JavaScript reads whatever Wasm writes.
- **`webgl_env.gl_clear(r, g, b, a)`**, **`webgl_env.gl_draw(mode, first, count)`**: The clear
  colour and the draw call, with the GL enum (`TRIANGLES` = 4) coming from Pascal.
- **`webgl_env.gl_uniform_f(name, v)`**: Sets a float uniform by name (a no-op if the shader
  doesn't declare it). **`webgl_env.gl_canvas_width/height`**: The drawing-buffer size, so Pascal
  can do its own aspect math.

- **`wasmpascal_env.sin` / `wasmpascal_env.cos` / ...**: `Sin` and `Cos` are compiler *builtins*,
  and the compiler reaches for them as imports from `wasmpascal_env`. The host provides the full
  `Math.*` set, so a future example using `Tan`, `Exp` or `Power` doesn't trip over a missing import.

```js
const importObject = {
  webgl_env: { gl_program, gl_attr, gl_alloc, gl_upload, gl_clear, gl_draw, gl_uniform_f, ... },
  wasmpascal_env: { sin: Math.sin, cos: Math.cos, tan: Math.tan, /* ... */ },
};
```

The only per-example wiring is which `.wasm` to load, and it lives in `index.html`:

```html
<script src="host.js" data-wasm="triangle.wasm"></script>
```

## The vertex layout

```
0 x   1 y   2 r   3 g   4 b      -- 5 floats, 20 bytes per vertex
```

The vertex layout is defined in `triangle.pas` as `VERT_FLOATS` and handed to the host one
attribute at a time via `gl_attr`. The host never sees it as a constant of its own.

## Reusing the host for the next example

Copy `host.js` and `index.html` unchanged, point `data-wasm` at the new binary, and have the new
`.pas` file export `webgl_main` / `webgl_frame` while importing the `webgl_env` primitives above.
Shaders, layout, colours and draw mode all live on the Pascal side, so nothing in the host needs
to change — if the new example needs a second VBO or indexed drawing, that's when the host grows
a new primitive rather than a new special case.

## Troubleshootin

During development of this example, I made quite a few mistakes. Here's where I messed up and how
to fix it.

- **A missing `wasmpascal_env` entry.** Adding `Sin`, `Cos`, `Tan`, `ArcTan`,
  `ArcSin`, `ArcCos`, `ArcTan2`, `Sinh`/`Cosh`/`Tanh`, `Exp`, `Ln` or `Power`
  to the Pascal side adds an import to the host's side, named after the JS
  function (`atan`, `pow`). Instantiation then fails with "module is not an
  object", which reads like a loader bug and is not one. The host now provides
  the whole set up front, so this one is retired — but a hand-written host for a
  new ABI will hit it again. (`Sqrt`, `Abs`, `Trunc`, `Round`, `Frac` and `Int`
  are native instructions and import nothing.)
- **CSS size versus drawing buffer.** `canvas.clientWidth` is the CSS size;
  `canvas.width` is the drawing buffer. Set the buffer to the CSS size times
  `devicePixelRatio` (as `resize()` does) or every edge is soft on a retina
  screen.
- **`bufferSubData` past the end of the buffer.** `gl_alloc` sizes the buffer,
  and `bufferSubData` never grows it. Pascal allocates `count * stride` bytes
  up front.
- **WebGL's silence.** A mistyped attribute or a failed link draws nothing and
  reports nothing. `drainGlErrors()` runs `gl.getError()` after every setup call
  and every draw, and the count is published on `window.__webgl.errors()`.
- **`#10` goes outside the quotes.** A shader line is `'...'#10`, not `'...#10'` —
  inside the quotes it's the literal text "#10". Multi-line constants need `+`
  between the lines.

The host publishes a small number of useful probe functions:

```js
window.__webgl.frames()    // how many frames have been drawn
window.__webgl.errors()    // GL errors seen so far, we hope for 0
```
