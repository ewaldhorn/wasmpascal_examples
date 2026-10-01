// host.js — a generic WebGL 2 host for WasmPascal examples.
//
// This file knows nothing about triangles, squares or whatever comes next: no
// shaders, no vertex layout, no colours, no draw mode. It owns the browser
// side — the canvas, the context, resize, the GL objects — and exposes a small
// set of primitives the Pascal side orchestrates. Copy it unchanged into the
// next example; only the wasm file (and the Pascal that builds it) changes.
//
// THE CONTRACT (the generic webgl ABI):
//
//   Pascal exports     webgl_main            build the GL pipeline, only needed once
//                      webgl_frame(t_ms)     draw one frame
//
//   webgl_env imports, in the order Pascal calls them:
//     gl_program(vs, fs)            compile + link + useProgram, 1 ok / 0 fail
//     gl_attr(index, size, stride, offset)
//                                   one vertex attrib (floats, not bytes)
//     gl_alloc(bytes)               size the single VBO (DYNAMIC_DRAW)
//     gl_upload(ptr, bytes)         copy wasm memory into the VBO
//     gl_clear(r, g, b, a)          clearColor + clear
//     gl_draw(mode, first, count)   drawArrays (mode is the GL enum, e.g. 4)
//     gl_uniform_f(name, v)         set a float uniform, no-op if missing
//     gl_canvas_width/height        drawing-buffer size, for aspect math
//
//   A `string` parameter arrives as a (ptr, len) pair into the wasm module's
//   memory; the host decodes it fresh on every call.
//
//   wasmpascal_env — the full Math.* set plus heap_report. Sin and Cos are
//              compiler BUILTINS and the compiler reaches for them as imports
//              from wasmpascal_env, so a module that does not provide them
//              fails to instantiate at all; the rest of Math.* is provided so
//              a future example using Tan, Exp or Power does not hit the same
//              wall. heap_report is emitted only if Pascal builds a dynamic
//              string — a no-op, kept so that adding one Str() call later does
//              not turn into a mysterious "module is not an object" error.
//
// Wiring: <script src="host.js" data-wasm="triangle.wasm"></script>
// The wasm URL is the ONLY per-example setting, and it lives in index.html.
'use strict';
(() => {
  const thisScript = document.currentScript;
  const canvas = document.getElementById('gl');
  const gl = canvas.getContext('webgl2', { antialias: true });

  const decoder = new TextDecoder('utf-8');

  let wasm = null;             // the wasm module's exports
  let program = null;
  let vao = null;
  let vbo = null;
  const uniformLocs = new Map();
  let frames = 0;
  let glErrors = 0;

  // Decode a Pascal string parameter: (ptr, len) into wasm memory. Read fresh
  // on every call, on purpose: if the module ever grows its memory the old
  // ArrayBuffer is detached, and a view captured at boot would then throw.
  function str(ptr, len) {
    return decoder.decode(new Uint8Array(wasm.memory.buffer, ptr, len));
  }

  // ---- WebGL 2 boilerplate --------------------------------------------------

  function compile(type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      console.error('webgl: shader did not compile\n' + gl.getShaderInfoLog(shader));
      return null;
    }
    return shader;
  }

  function link(vs, fs) {
    const p = gl.createProgram();
    gl.attachShader(p, vs);
    gl.attachShader(p, fs);
    gl.linkProgram(p);
    gl.deleteShader(vs);                  // the program keeps what it needs
    gl.deleteShader(fs);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
      console.error('webgl: program did not link\n' + gl.getProgramInfoLog(p));
      return null;
    }
    return p;
  }

  // WebGL fails silently: a mistyped attribute name draws nothing and reports
  // nothing. getError() is the only place that turns up, so setup calls and
  // every draw are followed by a drain, and the count is published for the check.
  function drainGlErrors() {
    for (let e = gl.getError(); e !== gl.NO_ERROR; e = gl.getError()) glErrors++;
    return glErrors;
  }

  // The host owns the viewport and nothing else about the picture: what the
  // shader does with the canvas size (aspect correction, usually) is Pascal's
  // business via gl_canvas_width/height and gl_uniform_f.
  function resize() {
    if (!gl) return;
    const dpr = window.devicePixelRatio || 1;
    const w = Math.max(1, Math.round(canvas.clientWidth * dpr));
    const h = Math.max(1, Math.round(canvas.clientHeight * dpr));
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }
    gl.viewport(0, 0, w, h);
  }

  // ---- the calls Pascal imports --------------------------------------------

  // Once, from webgl_main. Both shaders arrive from Pascal as strings; the
  // host compiles, links, uses and makes one VAO/VBO pair current.
  function glProgram(vsPtr, vsLen, fsPtr, fsLen) {
    if (!gl) return 0;
    const vs = compile(gl.VERTEX_SHADER, str(vsPtr, vsLen));
    const fs = compile(gl.FRAGMENT_SHADER, str(fsPtr, fsLen));
    if (!vs || !fs) return 0;
    const p = link(vs, fs);
    if (!p) return 0;
    if (program) gl.deleteProgram(program);
    if (vao) gl.deleteVertexArray(vao);
    if (vbo) gl.deleteBuffer(vbo);
    program = p;
    uniformLocs.clear();
    vao = gl.createVertexArray();
    gl.bindVertexArray(vao);
    vbo = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.useProgram(program);
    resize();
    drainGlErrors();
    return 1;
  }

  // Once per attribute, from webgl_main. Stride and offset are in floats, the
  // unit Pascal counts vertices in; the host multiplies by 4.
  function glAttr(index, size, strideFloats, offsetFloats) {
    if (!gl || !program) return;
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.enableVertexAttribArray(index);
    gl.vertexAttribPointer(index, size, gl.FLOAT, false, strideFloats * 4, offsetFloats * 4);
    drainGlErrors();
  }

  // Once, from webgl_main. Sizes the VBO; bufferSubData never grows it, so
  // this must cover the largest upload the example will ever do.
  function glAlloc(byteSize) {
    if (!gl || !vbo) return;
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, byteSize, gl.DYNAMIC_DRAW);
    drainGlErrors();
  }

  // Every frame. `ptr` is a byte offset into the wasm module's linear memory,
  // uploaded as it stands — no copy, no marshalling, no JSON. A byte view, not
  // a float view, so future vertex formats (shorts, bytes) pass through too.
  function glUpload(ptr, byteSize) {
    if (!gl || !vbo) return;
    const data = new Uint8Array(wasm.memory.buffer, ptr, byteSize);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferSubData(gl.ARRAY_BUFFER, 0, data);
  }

  function glClear(r, g, b, a) {
    if (!gl) return;
    gl.clearColor(r, g, b, a);
    gl.clear(gl.COLOR_BUFFER_BIT);
  }

  function glDraw(mode, first, count) {
    if (!gl || !program) return;
    gl.bindVertexArray(vao);
    gl.drawArrays(mode, first, count);
    frames++;
    drainGlErrors();
  }

  // Set a float uniform by name. Missing programs and missing names are a
  // silent no-op: an example that queries a uniform it never declared has a
  // Pascal bug, not a host bug, and should not take the frame down with it.
  // Locations are cached; a new program clears the cache.
  function glUniformF(namePtr, nameLen, v) {
    if (!gl || !program) return;
    const name = str(namePtr, nameLen);
    let loc;
    if (uniformLocs.has(name)) {
      loc = uniformLocs.get(name);
    } else {
      loc = gl.getUniformLocation(program, name);
      uniformLocs.set(name, loc);
    }
    if (loc) gl.uniform1f(loc, v);
  }

  // ---- boot ----------------------------------------------------------------

  const importObject = {
    webgl_env: {
      gl_program: glProgram,
      gl_attr: glAttr,
      gl_alloc: glAlloc,
      gl_upload: glUpload,
      gl_clear: glClear,
      gl_draw: glDraw,
      gl_uniform_f: glUniformF,
      gl_canvas_width: () => canvas.width,
      gl_canvas_height: () => canvas.height,
    },
    wasmpascal_env: {
      sin: Math.sin, cos: Math.cos, tan: Math.tan,
      asin: Math.asin, acos: Math.acos, atan: Math.atan, atan2: Math.atan2,
      sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh,
      exp: Math.exp, ln: Math.log, log10: Math.log10, log2: Math.log2,
      pow: Math.pow, sqrt: Math.sqrt, hypot: Math.hypot,
      heap_report: () => {},
    },
  };

  function fail(text) {
    const note = document.getElementById('note');
    if (note) note.textContent = text;
    console.error('webgl: ' + text);
  }

  window.addEventListener('resize', resize);

  async function boot() {
    if (!gl) {
      fail('This browser has no WebGL 2.');
      return;
    }
    const wasmName = (thisScript && thisScript.dataset.wasm) || 'app.wasm';
    const url = new URL(wasmName, document.baseURI);
    const buf = await (await fetch(url)).arrayBuffer();
    const { instance } = await WebAssembly.instantiate(buf, importObject);
    wasm = instance.exports;

    if (typeof wasm.webgl_main !== 'function' || typeof wasm.webgl_frame !== 'function') {
      fail('The wasm module does not export webgl_main/webgl_frame.');
      return;
    }
    if (!wasm.webgl_main()) {
      fail('The GL pipeline did not build — see the console.');
      return;
    }

    requestAnimationFrame(function frame(t) {
      requestAnimationFrame(frame);      // the host drives; Pascal draws
      wasm.webgl_frame(t);
    });
  }

  // A tiny probe surface, so a headless check (or devtools) can tell "it is
  // drawing" apart from "it is a still image" without reading pixels.
  window.__webgl = {
    frames: () => frames,
    errors: () => glErrors,
  };

  boot().catch((e) => fail('Could not start: ' + e.message));
})();
