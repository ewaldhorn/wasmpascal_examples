# WebGL Triangle using WasmPascal

In the world of WebGL, one demo stands out to me: The classic colour triangle that is slowly
spinning around.  So naturally, when I wanted to create a WasmPascal and WebGL demo, this
is what I built!

Being Web Assembly, there's more needed than just the Pascal-based binary, we also need some
JavaScript magic to tie things together. I ended up splitting things up like this:

- **JavaScript** (`host.js`): Handles the browser side of things, like the canvas, the WebGL 2 
context, the shaders, vertex buffer and the draw call.
- **Pascal** (`triangle.pas`): Handles the calculations for every frame. It writes three vertices 
of (`x, y, r, g, b`) each and asks the host to draw them, because wasm doesn't have direct access to the DOM or browser API's.


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

The Pascal binary exports some functions for the host script to call:

- **`triangle_main()`**: Called once, after the canvas has been created. First it writes the constants used for colours,
  and then it asks the host to build the GL pipeline. A return of 0 indicates it was unable to create the pipeline.

- **`triangle_frame(t_ms)`**: Called per animation frame, with the frame timestamp as an argument.
  It writes the rotated positions to the memory buffer and then does a `gl_frame` call to render the new frame.

The JavaScript host provides interaction points for the Pascal binary:

- **`webgl_env.gl_create(count, floats_per_vertex)`**: Builds the GL pipeline and environment.

- **`webgl_env.gl_frame(ptr, count)`**: Loads `count` vertices from `ptr` and draws them. `ptr` is 
a byte offset into the wasm module's linear memory. This way, JavaScript reads whatever Wasm writes.

- **`odin_env.sin` / `odin_env.cos`**: `Sin` and `Cos` are compiler *builtins*, and the compiler
  reaches for them as imports from `odin_env`. The host environment is responsible for providing them.

```js
const importObject = {
  webgl_env: { gl_create: glCreate, gl_frame: glFrame },
  odin_env: { sin: Math.sin, cos: Math.cos },
};
```

## The vertex layout

```
0 x   1 y   2 r   3 g   4 b      -- 5 floats, 20 bytes per vertex
```

The vertex layout is defined `triangle.pas` as `VERT_FLOATS` and then gets handed to the host by the
`gl_create` call. This is a good example of a constant that is shared between the two halves of the 
program.

## Troubleshootin

During development of this example, I made quite a few mistakes. Here's where I messed up and how
to fix it.

- **A missing `odin_env` entry.** Adding `Sin`, `Cos`, `Tan`, `ArcTan`,
  `ArcSin`, `ArcCos`, `ArcTan2`, `Sinh`/`Cosh`/`Tanh`, `Exp`, `Ln` or `Power`
  to the Pascal side adds an import to the host's side, named after the JS
  function (`atan`, `pow`). Instantiation then fails with "module is not an
  object", which reads like a loader bug and is not one. `Sqrt`, `Abs`,
  `Trunc`, `Round`, `Frac` and `Int` are native instructions and import
  nothing.
- **CSS size versus drawing buffer.** `canvas.clientWidth` is the CSS size;
  `canvas.width` is the drawing buffer. Set the buffer to the CSS size times
  `devicePixelRatio` (as `resize()` does) or every edge is soft on a retina
  screen.
- **`bufferSubData` past the end of the buffer.** `gl.bufferData` at creation
  sizes the buffer, and `bufferSubData` never grows it. The host allocates
  `count * stride` bytes from the numbers `gl_create` received.
- **WebGL's silence.** A mistyped attribute or a failed link draws nothing and
  reports nothing. `drainGlErrors()` runs `gl.getError()` after every setup and
  every frame, and the count is published on `window.__triangle.errors()`.

The host publishes a small number of useful probe functions:

```js
window.__triangle.frames()    // how many frames have been drawn
window.__triangle.errors()    // GL errors seen so far, we hope for 0 
window.__triangle.vertices()  // the count Pascal handed to gl_create, useful for debugging
```
