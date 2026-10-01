// host.js — the JavaScript half of the triangle demo: all of the WebGL 2.
//
// The split, in one sentence: JavaScript owns the canvas, the context, the two
// shaders and the draw call; Pascal owns the vertices. Every frame Pascal writes
// 15 floats into its own memory and calls one function in here to draw them.
//
// This file supplies exactly one import module to the wasm module:
//
//   webgl_env  — gl_create and gl_frame, the two calls triangle.pas declares.
//   odin_env   — sin and cos. Sin and Cos in Pascal are compiler BUILTINS and
//                the compiler reaches for them as imports from odin_env, so a
//                module that does not provide them fails to instantiate at all.
//   wasmpascal_env — heap_report, emitted only if Pascal builds a dynamic
//                string. A no-op, kept so that adding one Str() call later does
//                not turn into a mysterious "module is not an object" error.
//
// There are no other boundaries. The host knows the vertex count, the layout and
// nothing else about the geometry, and it learns those from Pascal's arguments.
'use strict';
(() => {
  const canvas = document.getElementById('gl');
  const gl = canvas.getContext('webgl2', { antialias: true });

  // The two shaders. They are the classic tutorial pair, minus the uniforms a
  // tutorial usually has: Pascal sends final clip-space positions, so the only
  // thing left to correct for is the window's aspect ratio.
  const VERTEX_SHADER = `#version 300 es
  layout(location = 0) in vec2 a_pos;      // clip space, computed in Pascal
  layout(location = 1) in vec3 a_color;    // per-vertex colour, from Pascal
  uniform float u_aspect;                  // canvas width / height
  out vec3 v_color;
  void main() {
    // Squeeze x so a triangle drawn on the unit circle stays equilateral in a
    // window that is not square.
    gl_Position = vec4(a_pos.x / u_aspect, a_pos.y, 0.0, 1.0);
    v_color = a_color;
  }`;

  const FRAGMENT_SHADER = `#version 300 es
  precision highp float;
  in vec3 v_color;
  out vec4 frag;
  void main() { frag = vec4(v_color, 1.0); }`;

  let wasm = null;             // the wasm module's exports
  let program = null;
  let vao = null;
  let vbo = null;
  let uAspect = null;
  let floatsPerVertex = 0;     // told to us by tri_main; we invent no constants
  let vertexCount = 0;
  let frames = 0;
  let glErrors = 0;

  // ---- WebGL 2 boilerplate --------------------------------------------------

  function compile(type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      console.error('triangle: shader did not compile\n' + gl.getShaderInfoLog(shader));
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
      console.error('triangle: program did not link\n' + gl.getProgramInfoLog(p));
      return null;
    }
    return p;
  }

  // WebGL fails silently: a mistyped attribute name draws nothing and reports
  // nothing. getError() is the only place that turns up, so every GL call this
  // file makes is followed by a drain, and the count is published for the check.
  function drainGlErrors() {
    for (let e = gl.getError(); e !== gl.NO_ERROR; e = gl.getError()) glErrors++;
    return glErrors;
  }

  function resize() {
    if (!gl) return;
    const dpr = window.devicePixelRatio || 1;
    const w = Math.max(1, Math.round(canvas.clientWidth * dpr));
    const h = Math.max(1, Math.round(canvas.clientHeight * dpr));
    canvas.width = w;
    canvas.height = h;
    gl.viewport(0, 0, w, h);
    if (uAspect) gl.uniform1f(uAspect, w / h);
  }

  // ---- the two calls Pascal imports ----------------------------------------

  // Once, from tri_main. Everything the host needs to know about the vertex
  // data arrives as arguments here — the count and the layout are Pascal's, and
  // the host does not repeat them as constants of its own.
  function glCreate(count, floatsPerVertexArg) {
    if (!gl) return 0;
    const vs = compile(gl.VERTEX_SHADER, VERTEX_SHADER);
    const fs = compile(gl.FRAGMENT_SHADER, FRAGMENT_SHADER);
    if (!vs || !fs) return 0;
    program = link(vs, fs);
    if (!program) return 0;

    uAspect = gl.getUniformLocation(program, 'u_aspect');
    floatsPerVertex = floatsPerVertexArg;
    vertexCount = count;

    const stride = floatsPerVertex * 4;            // bytes per vertex
    vao = gl.createVertexArray();
    gl.bindVertexArray(vao);
    vbo = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, count * stride, gl.DYNAMIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, stride, 0);   // x, y
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, false, stride, 8);   // r, g, b

    gl.useProgram(program);
    gl.clearColor(0.06, 0.07, 0.10, 1.0);          // the page's dark backdrop
    resize();
    drainGlErrors();
    return 1;
  }

  // Every frame, from tri_frame. `ptr` is a byte offset into the wasm module's
  // linear memory: the vertex array IS Pascal's global, uploaded as it stands
  // at the end of the frame — no copy, no marshalling, no JSON.
  function glFrame(ptr, count) {
    if (!gl || !program) return;
    // The ArrayBuffer is read fresh every frame, on purpose: if the module ever
    // grows its memory the old ArrayBuffer is detached, and a view captured at
    // boot would then throw instead of drawing.
    const verts = new Float32Array(wasm.memory.buffer, ptr, count * floatsPerVertex);
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferSubData(gl.ARRAY_BUFFER, 0, verts);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, count);
    frames++;
    drainGlErrors();
  }

  // ---- boot ----------------------------------------------------------------

  const importObject = {
    webgl_env: { gl_create: glCreate, gl_frame: glFrame },
    odin_env: { sin: Math.sin, cos: Math.cos },
    wasmpascal_env: { heap_report: () => {} },
  };

  function fail(text) {
    const note = document.getElementById('note');
    if (note) note.textContent = text;
    console.error('triangle: ' + text);
  }

  window.addEventListener('resize', resize);

  async function boot() {
    if (!gl) {
      fail('This browser has no WebGL 2.');
      return;
    }
    const url = new URL('triangle.wasm', document.baseURI);
    const buf = await (await fetch(url)).arrayBuffer();
    const { instance } = await WebAssembly.instantiate(buf, importObject);
    wasm = instance.exports;

    if (!wasm.triangle_main()) {
      fail('The GL pipeline did not build — see the console.');
      return;
    }

    requestAnimationFrame(function frame(t) {
      requestAnimationFrame(frame);      // the host drives; Pascal draws
      wasm.triangle_frame(t);
    });
  }

  // A tiny probe surface, so a headless check (or devtools) can tell "it is
  // drawing" apart from "it is a still image" without reading pixels.
  window.__triangle = {
    frames: () => frames,
    errors: () => glErrors,
    vertices: () => vertexCount,
  };

  boot().catch((e) => fail('Could not start: ' + e.message));
})();
