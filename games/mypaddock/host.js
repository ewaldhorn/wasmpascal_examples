// My Paddock — browser host for mypaddock.wasm (v1.0.7).
// Implements the full wasm import surface:
//   pascaldom_env.* (pixel-buffer canvas bridge, events, localStorage),
//   odin_env.sqrt/sin, mp_env.date_now/js_reload, app_env.play_sound.
// Sound patches mirror src/game/sound.odin exactly (Web Audio synth).
'use strict';
(() => {
  const T = new TextDecoder('utf-8');
  const E = new TextEncoder('utf-8');
  let mem = null;      // wasm memory, set after instantiate
  let inst = null;     // wasm instance exports
  const handles = [null]; // js-object handle table; 0 = null
  const freeList = [];
  let lastEvent = 0;

  function store(v) {
    if (v === null || v === undefined) return 0;
    const h = freeList.length > 0 ? freeList.pop() : handles.length;
    handles[h] = v;
    return h;
  }
  function readStr(ptr, len) {
    return T.decode(new Uint8Array(mem.buffer, ptr, len));
  }
  function writeStr(ptr, s, maxlen) {
    const bytes = E.encode(s);
    const n = Math.min(bytes.length, maxlen);
    new Uint8Array(mem.buffer, ptr, n).set(bytes.subarray(0, n));
    return n;
  }
  function fire(cbId, ev) {
    if (inst === null) return;
    lastEvent = store(ev);
    inst.pascaldom_set_last_event(lastEvent);
    inst.pascaldom_invoke_callback(cbId);
  }

  // ---- sound: 7 patches, same params as Odin sound.odin ----
  let actx = null, master = null;
  function audio() {
    if (actx !== null) {
      if (actx.state === 'suspended') actx.resume();
      return actx;
    }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    actx = new AC();
    master = actx.createGain();
    master.gain.value = 0.6;
    master.connect(actx.destination);
    return actx;
  }
  function tone(freq, delay, dur, type, gain) {
    const t = actx.currentTime + delay;
    const osc = actx.createOscillator();
    const g = actx.createGain();
    osc.connect(g); g.connect(master);
    osc.type = type;
    osc.frequency.value = freq;
    g.gain.setValueAtTime(0.0, t);
    g.gain.linearRampToValueAtTime(gain, t + 0.008);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    osc.start(t); osc.stop(t + dur + 0.05);
  }
  function sweep(f0, f1, delay, dur, type, gain) {
    const t = actx.currentTime + delay;
    const osc = actx.createOscillator();
    const g = actx.createGain();
    osc.connect(g); g.connect(master);
    osc.type = type;
    osc.frequency.setValueAtTime(f0, t);
    osc.frequency.exponentialRampToValueAtTime(f1, t + dur);
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    osc.start(t); osc.stop(t + dur + 0.05);
  }
  function playSound(id) {
    if (audio() === null) return;
    switch (id) {
      case 0: // feed
        tone(520, 0, 0.1, 'triangle', 0.1);
        tone(660, 0.06, 0.12, 'triangle', 0.09);
        break;
      case 1: // water
        sweep(900, 400, 0, 0.2, 'sine', 0.08);
        break;
      case 2: // shear
        sweep(2200, 1400, 0, 0.18, 'sawtooth', 0.06);
        sweep(2000, 1200, 0.1, 0.18, 'sawtooth', 0.06);
        break;
      case 3: // coin
        tone(880, 0, 0.08, 'square', 0.07);
        tone(1318.51, 0.06, 0.14, 'square', 0.08);
        break;
      case 4: // purchase
        tone(440, 0, 0.12, 'triangle', 0.1);
        tone(660, 0.08, 0.12, 'triangle', 0.1);
        break;
      case 5: // denied
        tone(160, 0, 0.15, 'square', 0.06);
        break;
      case 6: // sold
        sweep(260, 90, 0, 0.5, 'sawtooth', 0.1);
        break;
    }
  }

  // ---- image cache for putImageData ----
  let img = null;
  function render(ctx, pp, pl, w, h) {
    // The game renders into the same pixel buffer every frame, so one
    // cached ImageData view suffices; putImageData re-uploads it as-is.
    if (!img || img.pp !== pp || img.w !== w || img.h !== h ||
        img.buf !== mem.buffer) {
      const arr = new Uint8ClampedArray(mem.buffer, pp, w * h * 4);
      img = { pp, w, h, buf: mem.buffer, data: new ImageData(arr, w, h) };
    }
    ctx.putImageData(img.data, 0, 0);
  }

  const importObject = {
    pascaldom_env: {
      dom_get_global: (p, l) => store(globalThis[readStr(p, l)]),
      dom_get_property: () => 0,
      dom_get_element_by_id: (p, l) =>
        store(document.getElementById(readStr(p, l))),
      dom_set_inner_text: (h, p, l) => { handles[h].innerText = readStr(p, l); },
      dom_get_property_str: (h, kp, kl, buf, maxlen) =>
        writeStr(buf, String(handles[h][readStr(kp, kl)]), maxlen),
      dom_call_method0: () => {},
      dom_call_method_ret: (h, np, nl) =>
        store(handles[h][readStr(np, nl)]()),
      dom_add_event_listener: (h, ep, el, cb) => {
        handles[h].addEventListener(readStr(ep, el), (ev) => fire(cb, ev));
      },
      dom_canvas_create: (h, w, hh) => {
        const cv = document.createElement('canvas');
        cv.width = w; cv.height = hh;
        handles[h].appendChild(cv);
        return store(cv);
      },
      dom_canvas_get_context: (h) => store(handles[h].getContext('2d')),
      dom_canvas_render: (cv, ctx, pp, pl, w, h) =>
        render(handles[ctx], pp, pl, w, h),
      dom_start_animation_loop: (cb) => {
        const step = () => {
          inst.pascaldom_invoke_callback(cb);
          requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
      },
      dom_now: () => performance.now(),
      dom_local_storage_get_item: (kp, kl, buf, maxlen) => {
        const v = localStorage.getItem(readStr(kp, kl));
        if (v === null) return -1;
        return writeStr(buf, v, maxlen);
      },
      dom_local_storage_set_item: (kp, kl, vp, vl) => {
        const k = readStr(kp, kl);
        if (vl === 0) localStorage.removeItem(k);
        else localStorage.setItem(k, readStr(vp, vl));
      },
    },
    odin_env: { sqrt: (x) => Math.sqrt(x), sin: (x) => Math.sin(x) },
    mp_env: {
      date_now: () => Date.now(),
      js_reload: () => location.reload(),
    },
    app_env: { play_sound: (id) => playSound(id) },
  };

  async function boot() {
    const url = new URL('mypaddock.wasm', document.baseURI);
    let wasm;
    if (typeof WebAssembly.instantiateStreaming === 'function') {
      try {
        wasm = await WebAssembly.instantiateStreaming(fetch(url),
          importObject);
      } catch (e) {
        const buf = await (await fetch(url)).arrayBuffer();
        wasm = await WebAssembly.instantiate(buf, importObject);
      }
    } else {
      const buf = await (await fetch(url)).arrayBuffer();
      wasm = await WebAssembly.instantiate(buf, importObject);
    }
    inst = wasm.instance.exports;
    mem = inst.memory;

    // Touch relays as synthetic mouse events: the game has one input path.
    const touch = (type) => (ev) => {
      if (inst === null || !handles[1]) return;
      for (const t of ev.changedTouches) {
        handles[1].dispatchEvent(new MouseEvent(type, {
          clientX: t.clientX, clientY: t.clientY, button: 0,
          bubbles: true, cancelable: true,
        }));
      }
      ev.preventDefault();
    };
    document.addEventListener('touchstart', touch('mousedown'),
      { passive: false });
    document.addEventListener('touchmove', touch('mousemove'),
      { passive: false });
    document.addEventListener('touchend', touch('mouseup'),
      { passive: false });

    // Audio unlock: browsers require a user gesture before sound.
    const unlock = () => audio();
    document.addEventListener('pointerdown', unlock, { once: true });
    document.addEventListener('keydown', unlock, { once: true });

    inst.pascaldom_main();
  }
  boot().catch((e) => {
    console.error(e);
    document.getElementById('version').innerText = 'load failed: ' + e;
  });
})();
