// M5 harness: boots mypaddock.wasm under stub pascaldom_env/odin_env/mp_env
// plus stub app_env.play_sound (captured per boot), with a stub localStorage.
// Supports multiple instances sharing one store (persistence/offline tests).
// Usage: node tests/mp_test.js [/tmp/....wasm]
'use strict';
const fs = require('fs');
const t = setTimeout(() => { console.error('TIMEOUT'); process.exit(2); }, 300000);
const wasmPath = process.argv[2] || '/tmp/mypaddock_m6.wasm';
const wasmBytes = fs.readFileSync(wasmPath);

let failures = 0;
function check(name, got, want) {
  const pass = got.length === want.length && got.every((v, i) => v === want[i]);
  console.log((pass ? 'PASS' : 'FAIL') + ' ' + name + ' got [' + got + '] want [' + want + ']');
  if (!pass) failures++;
}

async function boot(store, clock) {
  let mem = null;
  let render = null;
  const sounds = [];
  let ptrX = 0, ptrY = 0;
  let keyValue = 'a';
  const u8 = () => new Uint8Array(mem.buffer);
  const readStr = (a, l) => Buffer.from(u8().slice(a, a + l)).toString('latin1');
  function writeStr(a, s, m) {
    const n = Math.min(s.length, m);
    for (let i = 0; i < n; i++) u8()[a + i] = s.charCodeAt(i);
    return n;
  }
  const importObject = {
    pascaldom_env: {
      dom_get_global: () => 1,
      dom_get_property: () => 0,
      dom_get_element_by_id: () => 2,
      dom_set_inner_text: () => {},
      dom_get_property_str: (h, ka, kl, buf, maxlen) => {
        const k = readStr(ka, kl);
        const vals = { left: '0', top: '0', width: '800', height: '600', clientX: String(ptrX), clientY: String(ptrY), button: '0', key: keyValue };
        return writeStr(buf, vals[k] || '0', maxlen);
      },
      dom_call_method0: () => {},
      dom_call_method_ret: () => 100,
      dom_add_event_listener: () => {},
      dom_canvas_create: () => 4,
      dom_canvas_get_context: () => 5,
      dom_canvas_render: (cv, ctx, pp, pl, w, h) => { render = { pp, pl, w, h }; },
      dom_start_animation_loop: () => {},
      dom_now: () => { clock.now += 16.7; return clock.now; },
      dom_local_storage_get_item: (ka, kl, buf, maxlen) => {
        const k = readStr(ka, kl);
        if (!store.map.has(k)) return -1;
        return writeStr(buf, store.map.get(k), maxlen);
      },
      dom_local_storage_set_item: (ka, kl, va, vl) => {
        const k = readStr(ka, kl);
        if (vl === 0) store.map.delete(k);
        else store.map.set(k, readStr(va, vl));
      },
    },
    odin_env: { sqrt: (x) => Math.sqrt(x), sin: (x) => Math.sin(x) },
    app_env: { play_sound: (id) => { sounds.push(id); } },
    mp_env: {
      date_now: () => clock.wall,
      js_reload: () => { store.reloaded = true; },
    },
  };
  const result = await WebAssembly.instantiate(wasmBytes, importObject);
  const e = result.instance.exports;
  mem = e.memory;
  e.pascaldom_main();
  const g = {
    e,
    sounds,
    dims: () => [render.w, render.h, render.pl],
    tick: () => e.pascaldom_invoke_callback(4),
    down: (x, y) => { ptrX = x; ptrY = y; e.pascaldom_invoke_callback(0); },
    move: (x, y) => { ptrX = x; ptrY = y; e.pascaldom_invoke_callback(1); },
    up: (x, y) => { ptrX = x; ptrY = y; e.pascaldom_invoke_callback(2); },
    tap: (x, y) => { ptrX = x; ptrY = y; e.pascaldom_invoke_callback(0); ptrX = x; ptrY = y; e.pascaldom_invoke_callback(2); },
    key: (k) => { keyValue = k; e.pascaldom_invoke_callback(3); },
    px: (x, y) => {
      const o = render.pp + (y * 800 + x) * 4;
      const b = u8();
      return [b[o], b[o + 1], b[o + 2], b[o + 3]];
    },
    band: (x0, x1, y0, y1, r, gg, bb) => {
      let n = 0;
      const b = u8();
      for (let y = y0; y < y1; y++)
        for (let x = x0; x < x1; x++) {
          const o = render.pp + (y * 800 + x) * 4;
          if (b[o] === r && b[o + 1] === gg && b[o + 2] === bb) n++;
        }
      return n;
    },
  };
  return g;
}

(async () => {
  // ---- M2/M3 on fresh store A ----
  const storeA = { map: new Map(), reloaded: false };
  const clockA = { now: 1000000.0, wall: 1700000000000.0 };
  const g = await boot(storeA, clockA);
  const e = g.e, tick = g.tick, tap = g.tap, key = g.key, px = g.px;
  const ticked = (fn, n) => { for (let i = 0; i < n; i++) fn(); };
  const tapTick = (x, y) => { tap(x, y); tick(); };
  const keyTick = (k) => { key(k); tick(); };
  tick();

  check('render dims', g.dims(), [800, 600, 800 * 600 * 4]);
  check('panel bg (700,10)', px(700, 10), [60, 45, 30, 255]);
  check('shop btn fill (600,120)', px(600, 120), [96, 72, 46, 255]);
  check('shop btn text (670,125)', px(670, 125), [255, 240, 200, 255]);
  check('minimap frame (594,220)', px(594, 220), [210, 160, 60, 255]);
  check('viewport box (761,295)', px(761, 295), [240, 200, 40, 255]);
  const titlePx = g.band(594, 786, 14, 43, 210, 160, 60);
  console.log('PADDOCK title pixels:', titlePx);
  if (titlePx < 200) { console.log('FAIL title pixels'); failures++; }
  else console.log('PASS title pixels');

  // drag pans then clamps at level 0 (world == viewport); release is a drag
  g.down(100, 100); g.move(200, 150); tick(); g.up(200, 150); tick();
  check('cam clamped after drag', [e.mp_cam_x(), e.mp_cam_y()], [0, 0]);
  check('drag is not a tap', [e.mp_shop_open()], [0]);

  tapTick(690, 132);
  check('shop opens on tap', [e.mp_shop_open()], [1]);
  check('shop row0 disabled at boot (3 sheep cost 80 > 40)', px(200, 150), [55, 45, 38, 255]);
  check('dim dither (50,500)', px(50, 500), [0, 0, 0, 255]);
  tapTick(100, 100);
  check('outside tap closes shop', [e.mp_shop_open()], [0]);
  keyTick('b');
  check('shop opens on b', [e.mp_shop_open()], [1]);
  keyTick('b');
  check('shop closes on b', [e.mp_shop_open()], [0]);
  keyTick('Escape');
  check('escape closes', [e.mp_shop_open(), e.mp_confirm()], [0, 0]);
  tapTick(675, 172);
  check('mute tap toggles off', [e.mp_sfx_on()], [0]);
  tapTick(675, 172);
  check('mute tap toggles on', [e.mp_sfx_on()], [1]);
  keyTick('m');
  check('m toggles off', [e.mp_sfx_on()], [0]);
  keyTick('m');
  check('m toggles on', [e.mp_sfx_on()], [1]);
  tapTick(675, 444);
  check('reset opens dialog', [e.mp_confirm()], [1]);
  tapTick(485, 333);
  check('cancel closes dialog', [e.mp_confirm()], [0]);
  tapTick(675, 444);
  tapTick(315, 333);
  // Odin parity: reset clears progress keys but keeps the SFX preference
  // (a device setting); the earlier mute taps saved it, so one key remains.
  check('yes reloads + clears progress', [e.mp_confirm(), storeA.reloaded ? 1 : 0, storeA.map.size], [1, 1, 1]);
  if (!storeA.map.has('mypaddockSFX')) { console.log('FAIL sfx key lost on reset'); failures++; }
  else console.log('PASS sfx survives reset');
  tapTick(650, 295);
  check('minimap tap clamps', [e.mp_cam_x(), e.mp_cam_y()], [0, 0]);
  keyTick('ArrowUp'); keyTick('ArrowLeft'); keyTick('ArrowDown'); keyTick('ArrowRight');
  check('arrows clamp', [e.mp_cam_x(), e.mp_cam_y()], [0, 0]);

  // ---- Minimap drag: a press-drag on the map scrubs the camera (the
  // viewport box tracks the cursor in minimap pixels) instead of the old
  // teleport-to-the-release-point; a press-release that barely moves is
  // still a jump-to-here tap. Needs a world wider than the viewport, so
  // this boots its own level-2 save (world 1060x920 vs view 580x600).
  const storeM = { map: new Map(), reloaded: false };
  const clockM = { now: 9500000.0, wall: 1700000000000.0 };
  storeM.map.set('mypaddockPaddockLevel', '2');
  const mq = await boot(storeM, clockM);
  mq.tick();
  // Minimap box: world letterboxed into 192x150 at (594,220) -> scale is the
  // smaller ratio 150/920, drawing 172x150 at (604,220); so one minimap px
  // is 920/150 world px.
  const wmpx = 920 / 150;
  const mapX = 594 + Math.trunc((192 - 172) / 2);
  const mapY = 220;
  mq.down(100, 100); mq.move(60, 60); mq.up(60, 60); mq.tick();
  check('paddock drag pans 1:1', [mq.e.mp_cam_x(), mq.e.mp_cam_y()], [40, 40]);
  mq.down(650, 295); mq.move(670, 295); mq.up(670, 295); mq.tick();
  // +20 map px pans +20*wmpx world px. The old code ignored the press (x was
  // in the panel) and jumped to the release point instead: [114,160].
  check('minimap drag scrubs the camera',
    [mq.e.mp_cam_x(), mq.e.mp_cam_y()],
    [Math.trunc(40 + 20 * wmpx), 40]);
  mq.down(650, 300); mq.move(653, 300); mq.up(653, 300); mq.tick();
  check('sub-threshold minimap press still jumps',
    [mq.e.mp_cam_x(), mq.e.mp_cam_y()],
    [Math.trunc((653 - mapX) / (1 / wmpx) - 580 / 2),
     Math.trunc((300 - mapY) / (1 / wmpx) - 600 / 2)]);

  // ---- M3 sim ----
  check('flock spawned', [e.mp_sheep_n(), e.mp_worker_n()], [3, 1]);
  const x0a = e.mp_s0x(), y0a = e.mp_s0y();
  ticked(tick, 600);
  const moved = (e.mp_s0x() !== x0a) || (e.mp_s0y() !== y0a);
  console.log((moved ? 'PASS' : 'FAIL') + ' sheep wander');
  if (!moved) failures++;
  const woolDots = g.band(594, 786, 220, 370, 255, 255, 250);
  const shirtDots = g.band(594, 786, 220, 370, 60, 110, 160);
  console.log('minimap wool dots:', woolDots, 'shirt dots:', shirtDots);
  if (woolDots === 0) { console.log('FAIL no sheep dots'); failures++; }
  else console.log('PASS sheep dots');
  if (shirtDots === 0) { console.log('FAIL no worker dots'); failures++; }
  else console.log('PASS worker dots');
  ticked(tick, 12000);
  console.log('after 200s sim: coins=' + e.mp_coins() + ' hunger0=' + e.mp_s0hunger() + ' trough0=' + e.mp_tr0());
  if (e.mp_coins() <= 40) { console.log('FAIL no shearing income'); failures++; }
  else console.log('PASS shearing income');
  if (e.mp_s0hunger() <= 0) { console.log('FAIL sheep never ate'); failures++; }
  else console.log('PASS sheep ate');
  if (e.mp_tr0() < 0 || e.mp_tr0() > 1500) { console.log('FAIL trough out of range'); failures++; }
  else console.log('PASS trough in range');
  // ---- M5: shear sound (2) fires during the 200s run; feed/water need a
  // trough refill (~11 visits each) and are covered by the long run below ----
  console.log('sim sounds:', JSON.stringify(g.sounds));
  if (!g.sounds.includes(2)) { console.log('FAIL sim sound missing: 2'); failures++; }
  else console.log('PASS sim sound: 2');

  // ---- M4: sell + autosave reload ----
  const storeB = { map: new Map(), reloaded: false };
  const clockB = { now: 2000000.0, wall: 1700000000000.0 };
  const h = await boot(storeB, clockB);
  h.tick();
  h.key('b'); h.tick();
  h.tap(400, 328); h.tick(); // SELL SHEEP row
  check('sell sheep', [h.e.mp_sheep_n(), h.e.mp_coins()], [2, 50]);
  for (let i = 0; i < 400; i++) { h.tick(); clockB.wall += 16.7; }
  const h2 = await boot(storeB, clockB);
  h2.tick();
  check('reload restores save', [h2.e.mp_coins(), h2.e.mp_sheep_n(), h2.e.mp_welcome()], [50, 2, 0]);

  // ---- M4: upkeep bill at 60s, no shear before it ----
  const storeC = { map: new Map(), reloaded: false };
  const clockC = { now: 3000000.0, wall: 1700000000000.0 };
  const u = await boot(storeC, clockC);
  for (let i = 0; i < 3700; i++) { u.tick(); clockC.wall += 16.7; }
  check('upkeep bills 3 coins at 60s', [u.e.mp_coins(), u.e.mp_sheep_n()], [37, 3]);

  // ---- M4: offline progress after 1h away ----
  const storeD = { map: new Map(), reloaded: false };
  const clockD = { now: 4000000.0, wall: 1700000000000.0 };
  const o = await boot(storeD, clockD);
  for (let i = 0; i < 400; i++) { o.tick(); clockD.wall += 16.7; }
  clockD.wall += 3600 * 1000;
  const o2 = await boot(storeD, clockD);
  o2.tick();
  // M6b: offline simulates 1/10th of the window at full rates — 1h away is
  // ~6 live minutes: 60 gross, 18 billed over 6 cycles, flock intact.
  check('offline 1/10th time, full pay, welcome',
    [o2.e.mp_stat_shear(), o2.e.mp_stat_upkeep(), o2.e.mp_stat_sales(), o2.e.mp_sheep_n(), o2.e.mp_coins(), o2.e.mp_welcome(), o2.e.mp_offline_coins()],
    [60, 18, 0, 3, 82, 1, 42]);

  // ---- M4: long-run bounds, no debt or wipeout ----
  const storeF = { map: new Map(), reloaded: false };
  const clockF = { now: 5000000.0, wall: 1700000000000.0 };
  const f = await boot(storeF, clockF);
  for (let i = 0; i < 15000; i++) { f.tick(); clockF.wall += 16.7; }
  const fok = (f.e.mp_coins() >= 0) && (f.e.mp_sheep_n() >= 1);
  console.log((fok ? 'PASS' : 'FAIL') + ' no-ruin (coins=' + f.e.mp_coins() + ' sheep=' + f.e.mp_sheep_n() + ')');
  if (!fok) failures++;

  // ---- M5: UI-driven sounds on a fresh store ----
  // denied=5 (row0 too dear) coin=3 (sell row3) purchase=4 (trough row4)
  // sold=6 (upkeep with 0 coins forces a sale). Mute suppresses all.
  const storeE = { map: new Map(), reloaded: false };
  const clockE = { now: 6000000.0, wall: 1700000000000.0 };
  const s = await boot(storeE, clockE);
  s.tick();
  s.key('b'); s.tick();
  s.tap(400, 159); s.tick(); // row0: buy sheep, 80 > 40
  check('denied on dear row', s.sounds, [5]);
  s.tap(400, 333); s.tick(); // row3: sell sheep 40 -> 50
  check('coin on sell', s.sounds, [5, 3]);
  // single-char StrAddr trap (parser makes them Char): these glyphs were
  // silently missing before the doubled-literal fix; exact pixel counts.
  check('sell plus glyph', [s.band(488, 500, 321, 335, 240, 200, 40)], [36]);
  check('trough paren glyph', [s.band(372, 384, 379, 393, 255, 240, 200)], [28]);
  s.tap(400, 391); s.tick(); // row4: food trough 50 -> 0
  check('purchase on trough', s.sounds, [5, 3, 4]);
  check('broke after trough', [s.e.mp_coins()], [0]);
  s.key('m'); s.tick();      // mute off
  s.tap(400, 159); s.tick(); // denied suppressed
  check('mute suppresses sound', s.sounds, [5, 3, 4]);
  s.key('m'); s.tick();      // mute back on
  for (let i = 0; i < 3700; i++) { s.tick(); clockE.wall += 16.7; }
  check('upkeep fires sold', s.sounds, [5, 3, 4, 6]);

  // ---- M5: worker refills fire feed(0)/water(1); troughs need ~11 visits
  // each to hit the 0.3 refill threshold, so run up to 800s in 1k chunks ----
  const storeG = { map: new Map(), reloaded: false };
  const clockG = { now: 7000000.0, wall: 1700000000000.0 };
  const r = await boot(storeG, clockG);
  r.tick();
  let refillTicks = 0;
  for (let i = 0; i < 48; i++) {
    for (let j = 0; j < 1000; j++) { r.tick(); clockG.wall += 16.7; }
    refillTicks += 1000;
    if (r.sounds.includes(0) && r.sounds.includes(1)) break;
  }
  console.log('refill run: ticks=' + refillTicks + ' sounds=' + JSON.stringify(r.sounds));
  for (const id of [0, 1]) {
    if (!r.sounds.includes(id)) { console.log('FAIL refill sound missing: ' + id); failures++; }
    else console.log('PASS refill sound: ' + id);
  }

  // ---- Budget: lifetime income vs expenses, persisted ----
  const storeH = { map: new Map(), reloaded: false };
  const clockH = { now: 8000000.0, wall: 1700000000000.0 };
  const bq = await boot(storeH, clockH);
  bq.tick();
  check('budget starts closed, stats zero',
    [bq.e.mp_budget_open(), bq.e.mp_stat_shear(), bq.e.mp_stat_sales(), bq.e.mp_stat_upkeep(), bq.e.mp_stat_spent()],
    [0, 0, 0, 0, 0]);
  bq.key('e'); bq.tick();
  check('e opens budget', [bq.e.mp_budget_open()], [1]);
  const budTitle = bq.band(244, 388, 156, 184, 210, 160, 60);
  console.log('BUDGET title pixels:', budTitle);
  if (budTitle < 150) { console.log('FAIL budget title'); failures++; }
  else console.log('PASS budget title');
  bq.tap(100, 100); bq.tick();
  check('tap closes budget', [bq.e.mp_budget_open()], [0]);
  bq.tap(690, 486); bq.tick();
  check('button opens budget', [bq.e.mp_budget_open()], [1]);
  bq.tap(690, 486); bq.tick();
  check('button tap closes budget', [bq.e.mp_budget_open()], [0]);
  bq.key('b'); bq.tick();
  bq.tap(400, 333); bq.tick(); // sell: +10 sales, coins 50
  bq.tap(400, 391); bq.tick(); // trough: +50 spent, coins 0
  check('sales+spent tracked', [bq.e.mp_stat_sales(), bq.e.mp_stat_spent(), bq.e.mp_coins()], [10, 50, 0]);
  bq.key('b'); bq.tick(); // close shop
  for (let i = 0; i < 3700; i++) { bq.tick(); clockH.wall += 16.7; }
  // upkeep bills 2 (2 sheep), forces a +10 sale; coins 0-2+10 = 8
  check('upkeep bill+forced sale tracked',
    [bq.e.mp_stat_upkeep(), bq.e.mp_stat_sales(), bq.e.mp_coins()], [2, 20, 8]);
  const ident = 40 + bq.e.mp_stat_shear() + bq.e.mp_stat_sales()
    - bq.e.mp_stat_upkeep() - bq.e.mp_stat_spent();
  check('budget identity: coins = 40 + in - out', [ident], [bq.e.mp_coins()]);
  const bq2 = await boot(storeH, clockH);
  bq2.tick();
  check('stats persist across reload',
    [bq2.e.mp_stat_shear(), bq2.e.mp_stat_sales(), bq2.e.mp_stat_upkeep(), bq2.e.mp_stat_spent()],
    [bq.e.mp_stat_shear(), 20, 2, 50]);
  for (let i = 0; i < 3700; i++) { bq2.tick(); clockH.wall += 16.7; }
  // second bill (1 sheep, affordable): upkeep 3, no new sale, identity holds
  check('second bill accumulates', [bq2.e.mp_stat_upkeep(), bq2.e.mp_stat_sales()], [3, 20]);
  const ident2 = 40 + bq2.e.mp_stat_shear() + bq2.e.mp_stat_sales()
    - bq2.e.mp_stat_upkeep() - bq2.e.mp_stat_spent();
  check('identity holds in later session', [ident2], [bq2.e.mp_coins()]);
  bq2.tap(675, 444); bq2.tick();
  bq2.tap(315, 333); bq2.tick();
  const statKeys = ['mypaddockStatShear', 'mypaddockStatSales', 'mypaddockStatUpkeep', 'mypaddockStatSpent'];
  check('reset wipes stats too',
    [storeH.reloaded ? 1 : 0, statKeys.every((k) => !storeH.map.has(k)) ? 1 : 0], [1, 1]);

  // ---- Wool readiness colors: grey bands while growing, white at >=80 ----
  const storeW = { map: new Map(), reloaded: false };
  const clockW = { now: 9000000.0, wall: 1700000000000.0 };
  const wq = await boot(storeW, clockW);
  wq.tick();
  const s0px = () => wq.px(Math.floor(wq.e.mp_s0x() / 100), Math.floor(wq.e.mp_s0y() / 100)).slice(0, 3);
  // spawn wool 35 -> band L1 (20<=35<40) -> grey 138; body center is solid
  check('spawn wool grey L1', [wq.e.mp_s0wool(), ...s0px()], [350, 138, 138, 138]);
  const woolColor = (w10) => {
    const w = w10 / 10;
    if (w < 15) return [232, 190, 172];
    if (w >= 80) return [255, 255, 250];
    const lvl = w < 20 ? 0 : w < 40 ? 1 : w < 60 ? 2 : 3;
    const g = 100 + lvl * 38;
    return [g, g, g];
  };
  for (let i = 0; i < 20000; i++) { wq.tick(); clockW.wall += 16.7; }
  let woolOk = false;
  for (let t = 0; t < 6 && !woolOk; t++) {
    const exp = woolColor(wq.e.mp_s0wool());
    const got = s0px();
    woolOk = exp.every((v, k) => v === got[k]);
    if (!woolOk) { wq.tick(); clockW.wall += 16.7; }
  }
  if (!woolOk) { console.log('FAIL wool band color'); failures++; }
  else console.log('PASS wool band color (wool=' + (wq.e.mp_s0wool() / 10) + ')');

  // ---- M8: level-10 paradigm — seeded save with 22 food + 22 water troughs
  // must cap at 110 sheep and still trade; minimap/camera render implicitly
  const storeL = { map: new Map(), reloaded: false };
  const clockL = { now: 9500000.0, wall: 1700000000000.0 };
  storeL.map.set('mypaddockPaddockLevel', '10');
  storeL.map.set('mypaddockCoins', '9999');
  storeL.map.set('mypaddockTroughs',
    Array(22).fill('0,15').concat(Array(22).fill('1,15')).join(';'));
  const lq = await boot(storeL, clockL);
  lq.tick();
  check('L10 cap fits paradigm', [lq.e.mp_sheep_cap()], [110]);
  lq.key('b'); lq.tick();
  lq.tap(400, 159); lq.tick(); // row0: buy sheep, gates pass at n=3
  check('L10 trading works', [lq.e.mp_sheep_n(), lq.e.mp_coins()], [4, 9919]);

  console.log(failures === 0 ? 'SUCCESS' : 'FAILURE');
  clearTimeout(t);
  process.exit(failures === 0 ? 0 : 1);
})().catch((err) => { clearTimeout(t); console.error('FAIL', err); process.exit(1); });
