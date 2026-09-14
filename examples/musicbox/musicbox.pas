// musicbox.pas — MUSIC BOX: a music player whose visualiser is made of DOM
// elements and nothing else.
//
// Where paint.pas uses the DOM to build an *interface*, this one uses it to
// render *motion*: there is no canvas, no framebuffer, no putImageData and no
// pixel buffer anywhere in this program. The scope is a grid of <span>s whose
// classes change every step, the meters are rows of segments that light up,
// the playhead is a class on a column, and the record spins because CSS says
// so. A step costs at most ~32 classList operations, and fifteen steps in
// sixteen allocate nothing at all (the sixteenth is the bar wrap, which
// rebuilds the one-line bar counter).
//
// The music is synthesised live through the Web Audio API reached from Pascal
// (web.NewAudioContext plus the facade's generic call-method / get-set-property
// methods): one oscillator + gain per note, wired
// osc -> gain -> master -> destination, with a short exponential release so
// notes do not click. The tunes are four short scores in the SCORE table —
// this player has no audio files, because the bridge cannot fetch one and the
// example corpus ships no assets.
//
// The clock is an animation-frame callback comparing web.NowMs against the
// next step deadline, deliberately not tied to audio-callback timing: the
// visualiser must keep running (silently) when the browser refuses to start
// an AudioContext before a user gesture. Note that web.NowMs and the audio
// clock are TWO DIFFERENT TIMELINES — see AudioClock below.
//
// Written against the host contract in docs/porting_odin_to_pascal.md.
//   - a `+` chain on strings used to be clamped at 255 bytes; that cap is gone
//     (docs/features.md §10.41), and the stylesheet stays plain literals only
//     because that reads better
// (Three entries this list used to carry are gone: `Break` inside an `if` and
//  indexing a by-value `string` param were compiler defects, now fixed — and
//  the StrAddr/StrLen rule stopped applying when this file moved to `uses WEB`,
//  because web.EventKey hands back a real Pascal string.)
//
// ABI: pascaldom — `uses WEB` makes the BODY of this library pascaldom_main,
// and the web unit owns pascaldom_invoke_callback / pascaldom_set_last_event
// and the dispatch table behind them (the same three exports sweep.pas has).

{$M 16M}
library musicbox;

uses
  WEB;

const
  STEPS = 16;              // sixteenth notes in a pattern (one bar of 4/4)
  VOICES = 3;
  TRACK_COUNT = 4;
  SEGMENTS = 8;            // VU segments per voice
  SCORE_LEN = TRACK_COUNT * VOICES * STEPS;

  NO_NOTE = -1;

  VOX_LEAD = 0;
  VOX_BASS = 1;
  VOX_CLICK = 2;

  // No callback ids here: `web.On` / `web.OnTick` HAND ONE BACK, and the
  // track rows and volume buttons keep theirs in track_cb / vol_cb and match
  // on the id the handler receives.

  BPM_MIN = 40;
  BPM_MAX = 240;
  BPM_STEP = 8;

  // Single-character key codes, named: a one-character string literal is a
  // Char in this dialect and StrAddr/StrLen miscompile on it, so key matching
  // never spells one.
  CH_SPACE = 32;
  CH_LOWER_S = 115;

  // The score: TRACK_COUNT x VOICES x STEPS, row-major, NO_NOTE (-1) = rest.
  // Each row is one voice of one track — 16 sixteenth notes, grouped
  // 4 | 4 | 4 | 4. MIDI note numbers, because the synth needs Hz, not names.
  // (Named SCORE rather than anything shorter: identifiers are
  // case-insensitive, so a const and a variable that differ only in case are
  // the same name — and a silent collision compiles to garbage.)
  SCORE: array[0..SCORE_LEN - 1] of Integer = (
    // ---- track 0 · "Aurora" · 96 BPM · square lead ----
    60, -1, 64, 67,   -1, 64, -1, 69,   67, -1, 64, -1,   62, -1, 60, -1,   // lead
    36, -1, -1, -1,   45, -1, -1, -1,   41, -1, -1, -1,   43, -1, -1, -1,   // bass
    36, -1, -1, -1,   84, -1, -1, -1,   36, -1, -1, -1,   84, -1, -1, -1,   // click
    // ---- track 1 · "Circuit" · 132 BPM · sawtooth lead ----
    69, -1, 72, 76,   74, -1, 71, -1,   69, -1, 67, 71,   74, -1, 72, -1,   // lead
    45, -1, -1, 45,   43, -1, -1, 43,   41, -1, -1, 41,   40, -1, -1, 40,   // bass
    36, -1, 84, -1,   36, -1, 84, 36,   36, -1, 84, -1,   36, -1, 84, 84,   // click
    // ---- track 2 · "Deep Water" · 72 BPM · sine lead ----
    57, -1, -1, -1,   60, -1, -1, -1,   62, -1, -1, -1,   64, -1, -1, -1,   // lead
    33, -1, -1, -1,   -1, -1, -1, -1,   29, -1, -1, -1,   31, -1, -1, -1,   // bass
    -1, -1, -1, -1,   84, -1, -1, -1,   -1, -1, -1, -1,   84, -1, -1, -1,   // click
    // ---- track 3 · "Arcade" · 168 BPM · square lead ----
    72, 72, 67, 72,   76, -1, 74, 72,   67, 67, 64, 67,   72, -1, 71, -1,   // lead
    36, 36, -1, 36,   43, -1, 43, -1,   41, 41, -1, 41,   48, -1, 48, -1,   // bass
    36, -1, 84, 84,   36, -1, 84, 84,   36, -1, 84, 84,   36, -1, 84, 84);  // click

// ---------------------------------------------------------------------------
// The bridge: `uses WEB`, no declarations of its own
// ---------------------------------------------------------------------------
// The unit declares the whole pascaldom bridge and gives it a `TWeb` facade —
// elements, classes, the injected stylesheet, the generic call-method /
// property bridge (which is how the audio graph is built), the audio context,
// the animation loop and events. Nothing here names an import, so the module
// imports exactly the bridge entries the unit's live code reaches. Math goes
// through the compiler's own builtins (`Power` below), which is what the old
// `external 'odin_env' name 'pow'` was.

var
  // --- transport and score position ---
  playing: Boolean = false;
  paused: Boolean = false;           // paused mid-bar: Play resumes, Stop rewinds
  step: Integer = 0;                 // step to play next (0 .. STEPS-1)
  marked_col: Integer = -1;          // column currently wearing .now
  loop_count: Integer = 0;
  next_time: Double = 0.0;           // web.NowMs deadline for the next step
  step_sec: Double = 0.15625;        // seconds per sixteenth note
  track_idx: Integer = 0;
  bpm: Integer = 96;
  vol_idx: Integer = 2;
  levels: array[0..VOICES - 1] of Integer;

  // --- audio ---
  audio_h: Integer = 0;              // AudioContext; 0 when unavailable
  master_node: Integer = 0;          // the master GainNode
  master_gain: Integer = 0;          // ...and its .gain AudioParam
  audio_now: Double = 0.0;           // AudioContext.currentTime for this step

  // --- DOM handles ---
  stage_h: Integer = 0;
  root_h: Integer = 0;
  disc_h: Integer = 0;
  title_h: Integer = 0;
  sub_h: Integer = 0;
  audio_lbl_h: Integer = 0;
  bpm_lbl_h: Integer = 0;
  play_h: Integer = 0;
  steps_row_h: Integer = 0;
  web: TWeb;
  cell_h: array[0..VOICES * STEPS - 1] of Integer;
  seg_h: array[0..VOICES * SEGMENTS - 1] of Integer;
  dot_h: array[0..STEPS - 1] of Integer;
  track_h: array[0..TRACK_COUNT - 1] of Integer;
  vol_h: array[0..3] of Integer;
  track_cb: array[0..TRACK_COUNT - 1] of Integer;   // ids web.On handed back
  vol_cb: array[0..3] of Integer;

  // --- text ---
  num_str: string;
  text_str: string;

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

// Equal temperament: A4 (MIDI 69) = 440 Hz. Power is the compiler's own
// builtin (it compiles to the odin_env `pow` import), so this is one call,
// not a hand-rolled series.
function MidiHz(midi: Integer): Double;
begin
  MidiHz := 440.0 * Power(2.0, (Double(midi) - 69.0) / 12.0);
end;

// There is no byte-compare and no float parser here any more. Both existed
// because a property read came back as RAW BYTES in a caller-owned buffer:
// web.GetPropertyF64 parses the audio clock with the compiler's own `Val`
// (taking the value's leading numeric run, docs/features.md §10.49), and a
// string-valued property compares as a string — `= 'running'`, never
// GetPropertyInt, which would read 'running' as 0.

// NoteAt, not Score: a `Score` function would collide with the SCORE const,
// and identifiers here are case-insensitive.
function NoteAt(t, v, s: Integer): Integer;
begin
  NoteAt := SCORE[(t * VOICES + v) * STEPS + s];
end;

function TrackBpm(t: Integer): Integer;
begin
  if t = 1 then TrackBpm := 132
  else if t = 2 then TrackBpm := 72
  else if t = 3 then TrackBpm := 168
  else TrackBpm := 96;
end;

// Master gain per volume preset — kept well below 1.0, because a square-wave
// chord at full scale clips hard.
function VolGain(i: Integer): Double;
begin
  if i = 0 then VolGain := 0.06
  else if i = 1 then VolGain := 0.12
  else if i = 2 then VolGain := 0.20
  else VolGain := 0.30;
end;

// ---------------------------------------------------------------------------
// The synth
// ---------------------------------------------------------------------------

// The audio timeline, in seconds since the context was created. This is NOT
// web.NowMs: that is performance.now(), milliseconds since the page loaded,
// and a completely different epoch. Scheduling an AudioParam event against the
// wrong epoch does not throw — it just puts every event `gap` seconds into the
// future, where `gap` is however long the page was open before the context
// started, and never advances while the context is suspended. Every note then
// sustains for that whole idle time, and the piece turns into a drone.
// Read once per step so a chord's notes share one onset.
function AudioClock: Double;
begin
  if audio_h = 0 then
  begin
    AudioClock := 0.0;
    exit;
  end;
  AudioClock := web.GetPropertyF64(audio_h, 'currentTime');
end;

// One note = one oscillator + one gain, wired into the master bus and then
// forgotten: Web Audio oscillators are single-use, so there is no voice pool
// to keep or steal. The four transient handles are released immediately — the
// audio graph holds its own reference once a node is connected and started,
// and the bridge's handle table would otherwise grow a slot per note for as
// long as the page is open.
procedure EmitOsc(midi: Integer; wave: string; amp, dur: Double);
var
  osc, gn, freq_p, gain_p: Integer;
  t: Double;
begin
  if audio_h = 0 then exit;
  t := audio_now;                           // the context's own clock
  osc := web.CallMethodRet(audio_h, 'createOscillator');
  gn := web.CallMethodRet(audio_h, 'createGain');
  web.SetPropertyStr(osc, 'type', wave);
  freq_p := web.GetProperty(osc, 'frequency');
  web.SetPropertyF64(freq_p, 'value', MidiHz(midi));
  gain_p := web.GetProperty(gn, 'gain');
  web.SetPropertyF64(gain_p, 'value', amp);
  web.CallMethod1h(osc, 'connect', gn);
  web.CallMethod1h(gn, 'connect', master_node);
  web.CallMethod2f(gain_p, 'exponentialRampToValueAtTime', 0.0001, t + dur);
  web.CallMethod0(osc, 'start');
  web.CallMethod1f(osc, 'stop', t + dur + 0.03);
  // The gain is deliberately left connected rather than disconnected here:
  // disconnect() takes effect immediately, so calling it now would cut the
  // note off before its scheduled stop, and there is no way to schedule one.
  // The oscillator's own stop() bounds the sound; a 60-second soak with the
  // render graph tapped keeps the envelope stable throughout (quiet fraction
  // 0.65 at 10 s, 0.67 at 60 s), so nothing accumulates audibly. See
  // "Synthesising audio from Pascal" in docs/host-abis.md.
  web.ReleaseHandle(freq_p);
  web.ReleaseHandle(gain_p);
  web.ReleaseHandle(osc);
  web.ReleaseHandle(gn);
end;

// Voice envelope + waveform. The lead's waveform is the track's character
// ('square' / 'sawtooth' / 'sine'); the bass is always a triangle; the click
// is a very short square — a hat when it is high, a thump when it is low.
procedure PlayVoice(v, midi: Integer);
begin
  if v = VOX_LEAD then
  begin
    if track_idx = 1 then EmitOsc(midi, 'sawtooth', 0.15, step_sec * 1.7)
    else if track_idx = 2 then EmitOsc(midi, 'sine', 0.22, step_sec * 3.0)
    else EmitOsc(midi, 'square', 0.15, step_sec * 1.7);
  end
  else if v = VOX_BASS then
  begin
    EmitOsc(midi, 'triangle', 0.28, step_sec * 1.9);
  end
  else
  begin
    EmitOsc(midi, 'square', 0.13, step_sec * 0.3);
  end;
end;

// The master bus: gain -> destination, created once and kept for the life of
// the page (the two handles stay valid, so nothing about it is released).
//
// The context also reports its own state changes, which is the only reliable
// way to keep the header honest: resume() is asynchronous, so reading `state`
// right after calling it returns the pre-resume value. Subscribing means the
// badge settles on its own, whenever the browser actually gets there.
procedure BuildAudio;
var
  dest: Integer;
begin
  audio_h := web.NewAudioContext;
  if audio_h = 0 then exit;
  master_node := web.CallMethodRet(audio_h, 'createGain');
  master_gain := web.GetProperty(master_node, 'gain');
  web.SetPropertyF64(master_gain, 'value', VolGain(vol_idx));
  dest := web.GetProperty(audio_h, 'destination');
  web.CallMethod1h(master_node, 'connect', dest);
  web.ReleaseHandle(dest);
  web.On(audio_h, 'statechange', OnAudioState);
end;

// ---------------------------------------------------------------------------
// The visualiser: classes only. Nothing here touches a pixel or builds a
// string, because this is the code that runs eight times a second.
// ---------------------------------------------------------------------------

procedure RepaintVu;
var
  v, i: Integer;
begin
  for v := 0 to VOICES - 1 do
  begin
    for i := 0 to SEGMENTS - 1 do
    begin
      if i < levels[v] then web.ClassListAdd(seg_h[v * SEGMENTS + i], 'lit')
      else web.ClassListRemove(seg_h[v * SEGMENTS + i], 'lit');
    end;
  end;
end;

procedure MarkColumn(col: Integer);
var
  v: Integer;
begin
  for v := 0 to VOICES - 1 do
  begin
    web.ClassListAdd(cell_h[v * STEPS + col], 'now');
  end;
  web.ClassListAdd(dot_h[col], 'now');
  marked_col := col;
end;

procedure ClearColumn(col: Integer);
var
  v: Integer;
begin
  if col < 0 then exit;
  for v := 0 to VOICES - 1 do
  begin
    web.ClassListRemove(cell_h[v * STEPS + col], 'now');
  end;
  web.ClassListRemove(dot_h[col], 'now');
  marked_col := -1;
end;

// Text updates are for the slow path only: a track change, a transport
// action, one per bar. The per-step position is shown by the playhead.
procedure UpdateLoopText;
begin
  Str(loop_count, num_str);
  text_str := num_str + ' loops played';
  web.SetInnerText(sub_h, text_str);
end;

// Sound and show the CURRENT step: mark the column, fire its notes, decay the
// meters. Split out from Advance because starting playback sounds step 0
// directly — routing a fresh start through Advance's wrap would count the
// forced jump to column 0 as a played bar.
procedure FireStep;
var
  v, n: Integer;
begin
  audio_now := AudioClock;      // one clock read per step, shared by the chord
  MarkColumn(step);
  for v := 0 to VOICES - 1 do
  begin
    n := NoteAt(track_idx, v, step);
    if n <> NO_NOTE then
    begin
      PlayVoice(v, n);
      levels[v] := SEGMENTS;
    end
    else if levels[v] > 0 then
    begin
      levels[v] := levels[v] - 1;
    end;
  end;
  RepaintVu;
end;

// One step forward: move the playhead, then sound it.
procedure Advance;
begin
  ClearColumn(marked_col);
  step := step + 1;
  if step >= STEPS then
  begin
    step := 0;
    loop_count := loop_count + 1;
    UpdateLoopText;
  end;
  FireStep;
end;

procedure Tick;
var
  t: Double;
begin
  if not playing then exit;
  t := web.NowMs;
  if t < next_time then exit;
  // A backgrounded tab throttles animation frames; without this resync the
  // sequencer would try to catch up on every missed step at once, which
  // sounds like a burst and looks like a stutter.
  if t > next_time + step_sec * 4000.0 then next_time := t;
  Advance;
  next_time := next_time + step_sec * 1000.0;
end;

// ---------------------------------------------------------------------------
// Transport
// ---------------------------------------------------------------------------

// Read the context's state and mirror it into the header. Called at boot and
// from the context's own 'statechange' event, so it is never a hand-taken
// snapshot of an async transition.
procedure UpdateAudioLabel;
begin
  if audio_h = 0 then
  begin
    web.SetInnerText(audio_lbl_h, 'audio unavailable');
    web.SetClassName(audio_lbl_h, 'mb-audio off');
    exit;
  end;
  if web.GetPropertyStr(audio_h, 'state') = 'running' then
  begin
    web.SetInnerText(audio_lbl_h, 'audio running');
    web.SetClassName(audio_lbl_h, 'mb-audio on');
  end
  else
  begin
    web.SetInnerText(audio_lbl_h, 'audio suspended');
    web.SetClassName(audio_lbl_h, 'mb-audio off');
  end;
end;

procedure SetTransportClasses;
begin
  if playing then
  begin
    web.ClassListAdd(disc_h, 'spin');
    web.ClassListAdd(play_h, 'on');
    web.SetInnerText(play_h, 'Pause');
  end
  else
  begin
    web.ClassListRemove(disc_h, 'spin');
    web.ClassListRemove(play_h, 'on');
    web.SetInnerText(play_h, 'Play');
  end;
end;

procedure UpdateBpmText;
begin
  Str(bpm, num_str);
  text_str := num_str + ' BPM';
  web.SetInnerText(bpm_lbl_h, text_str);
end;

procedure UpdateTrackText;
begin
  if track_idx = 0 then web.SetInnerText(title_h, 'Aurora')
  else if track_idx = 1 then web.SetInnerText(title_h, 'Circuit')
  else if track_idx = 2 then web.SetInnerText(title_h, 'Deep Water')
  else web.SetInnerText(title_h, 'Arcade');
  UpdateLoopText;
end;

procedure UpdateVolClasses;
var
  i: Integer;
begin
  for i := 0 to 3 do
  begin
    if i = vol_idx then web.ClassListAdd(vol_h[i], 'on')
    else web.ClassListRemove(vol_h[i], 'on');
  end;
end;

procedure SelectTrack(t: Integer);
var
  i, v, s: Integer;
begin
  track_idx := t;
  bpm := TrackBpm(t);
  step_sec := 60.0 / (Double(bpm) * 4.0);
  for i := 0 to TRACK_COUNT - 1 do
  begin
    if i = t then web.ClassListAdd(track_h[i], 'on')
    else web.ClassListRemove(track_h[i], 'on');
  end;
  // The score display is the track: mark every cell that carries a note.
  for v := 0 to VOICES - 1 do
  begin
    for s := 0 to STEPS - 1 do
    begin
      if NoteAt(t, v, s) <> NO_NOTE then web.ClassListAdd(cell_h[v * STEPS + s], 'note')
      else web.ClassListRemove(cell_h[v * STEPS + s], 'note');
    end;
  end;
  for v := 0 to VOICES - 1 do
  begin
    levels[v] := 0;
  end;
  RepaintVu;
  UpdateTrackText;
  UpdateBpmText;
end;

// The transport is two controls, and they mean different things: Pause holds
// the position (the playhead stays where it is, the bar counter keeps its
// count) and Stop rewinds to bar 0. Sharing one button makes that easy to get
// wrong — this used to restart from column 0 on every resume, which quietly
// reset `loop_count` and made the "N loops played" readout lie.
procedure StartOrPause;
begin
  if playing then
  begin
    playing := false;
    paused := true;
    SetTransportClasses;
    exit;
  end;
  // The animation loop is already running: web.OnTick registered this
  // program's tick handler AND started it at boot (the facade's shape — the
  // old code called dom_start_animation_loop by hand on the first Play, and
  // carried a `loop_started` flag to do it once). Tick returns immediately
  // while stopped, so an idle box costs one comparison per frame.
  if audio_h <> 0 then web.CallMethod0(audio_h, 'resume');
  playing := true;
  if paused then
  begin
    // Resume: step, loop_count and the marked column are all still where the
    // pause left them, so only the step timer needs re-arming. The first Tick
    // after this will advance from the current column.
    paused := false;
    next_time := web.NowMs + step_sec * 1000.0;
    SetTransportClasses;
    UpdateAudioLabel;
    exit;
  end;
  // A fresh start is bar 0, column 0: clear any playhead left by Stop, sound
  // the downbeat on the click rather than a beat later, and aim the NEXT step
  // a full step away — otherwise the first animation frame after the click (a
  // few ms later) would fire step 1 on top of step 0.
  step := 0;
  loop_count := 0;
  ClearColumn(marked_col);
  next_time := web.NowMs + step_sec * 1000.0;
  FireStep;
  UpdateLoopText;
  SetTransportClasses;
  UpdateAudioLabel;
end;

procedure StopPlayback;
var
  v: Integer;
begin
  playing := false;
  paused := false;              // Stop is the control that forgets the position
  ClearColumn(marked_col);
  step := 0;
  loop_count := 0;
  for v := 0 to VOICES - 1 do
  begin
    levels[v] := 0;
  end;
  RepaintVu;
  SetTransportClasses;
  UpdateLoopText;
end;

// ---------------------------------------------------------------------------
// Keyboard: Space = play/pause, S = stop
// ---------------------------------------------------------------------------

// Modifier state, read straight off the event PASSED IN, never off the
// web.LastEvent global: the bridge keeps one shared slot for "the current
// event", and a handler can synchronously dispatch another one (start or stop
// playback resumes the AudioContext, whose 'statechange' fires the badge
// callback). Reading the global afterwards would read the wrong event.
function EventFlagIsTrue(ev: Integer; key: string): Boolean;
begin
  // A string compare, not GetPropertyInt: the DOM stringifies a boolean, and
  // the numeric getter reads 'true' as 0 — which would disable the guards
  // below instead of applying them.
  EventFlagIsTrue := web.GetPropertyStr(ev, key) = 'true';
end;

procedure HandleKey;
var
  ev, k: Integer;
  key: String[255];
begin
  ev := web.LastEvent;                 // capture before anything can re-dispatch
  key := web.GetPropertyStr(ev, 'key');
  if Length(key) <> 1 then exit;
  if EventFlagIsTrue(ev, 'ctrlKey') or EventFlagIsTrue(ev, 'metaKey') then exit;
  // Held keys fire keydown over and over (evt.repeat). Acting on those would
  // flip the transport at the OS repeat rate, so a shortcut is one press.
  if EventFlagIsTrue(ev, 'repeat') then exit;
  k := Ord(key[1]);
  if k = CH_SPACE then StartOrPause
  else if (k = CH_LOWER_S) or (k = CH_LOWER_S - 32) then StopPlayback
  else exit;
  web.CallMethod0(ev, 'preventDefault');
end;

// ---------------------------------------------------------------------------
// Event handlers — registered BY NAME (DOMPLAN.md D3)
// ---------------------------------------------------------------------------
// The unit assigns the ids and owns the dispatch table, so this file owns
// neither: OnTick is the animation-frame callback, the rest are DOM events,
// and the two repeating groups (4 track rows, 4 volume buttons) match on the
// id the handler RECEIVES — track_cb / vol_cb — instead of an id this program
// invented. Every handler reads web.LastEvent, the event the unit stored
// before it called us.

procedure OnTick(id: Integer);
begin Tick; end;

procedure OnPlay(id: Integer);
begin StartOrPause; end;

procedure OnStop(id: Integer);
begin StopPlayback; end;

// The AudioContext's own 'statechange' — resume() is asynchronous, so this is
// the only honest moment to re-read the state.
procedure OnAudioState(id: Integer);
begin UpdateAudioLabel; end;

procedure OnKeyDown(id: Integer);
begin HandleKey; end;

procedure OnBpmDown(id: Integer);
begin
  if bpm > BPM_MIN then bpm := bpm - BPM_STEP;
  if bpm < BPM_MIN then bpm := BPM_MIN;
  step_sec := 60.0 / (Double(bpm) * 4.0);
  UpdateBpmText;
end;

procedure OnBpmUp(id: Integer);
begin
  if bpm < BPM_MAX then bpm := bpm + BPM_STEP;
  if bpm > BPM_MAX then bpm := BPM_MAX;
  step_sec := 60.0 / (Double(bpm) * 4.0);
  UpdateBpmText;
end;

procedure OnTrack(id: Integer);
var i: Integer;
begin
  for i := 0 to TRACK_COUNT - 1 do
    if track_cb[i] = id then SelectTrack(i);
end;

procedure OnVol(id: Integer);
var i: Integer;
begin
  for i := 0 to 3 do
    if vol_cb[i] = id then
    begin
      vol_idx := i;
      if audio_h <> 0 then web.SetPropertyF64(master_gain, 'value', VolGain(i));
      UpdateVolClasses;
    end;
end;

// ---------------------------------------------------------------------------
// Building the interface
// ---------------------------------------------------------------------------

// Five sheets, each ONE string literal rather than a `+` chain, which reads
// better for a stylesheet. (The old reason — this compiler clamped a
// concatenated string to 255 bytes, so a sheet was silently truncated
// mid-rule — has not been true since docs/features.md §10.41.)
procedure InjectStyles;
begin
  web.AddStyle(
    '.mb-root{display:flex;flex-direction:column;gap:12px;width:100%;max-width:720px;align-self:center;box-sizing:border-box;padding:14px;background:#0a0e17;border:1px solid #1b2436;border-radius:12px;color:#cdd7ea;font:13px/1.45 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}.mb-head{display:flex;align-items:center;gap:12px}.mb-now{flex:1 1 auto;min-width:0}.mb-title{font-size:16px;font-weight:700;color:#e8eefc}.mb-sub{font-size:12px;color:#8fa1c0}.mb-audio{font-size:11px;padding:3px 8px;border-radius:999px;border:1px solid #24304a;color:#8fa1c0;white-space:nowrap}.mb-audio.on{color:#04121a;background:#4ecdc4;border-color:#4ecdc4;font-weight:700}');
  web.AddStyle(
    '.mb-disc{width:46px;height:46px;border-radius:50%;flex:none;background:repeating-conic-gradient(#1b2334 0 12deg,#232d42 12deg 24deg);box-shadow:inset 0 0 0 8px #111826,inset 0 0 0 9px #2c3a54,0 2px 10px rgba(0,0,0,.5)}.mb-disc.spin{animation:mb-spin 2.4s linear infinite}@keyframes mb-spin{to{transform:rotate(360deg)}}');
  web.AddStyle(
    '.mb-tracks{display:flex;flex-direction:column;gap:4px}.mb-track{display:flex;justify-content:space-between;gap:10px;padding:6px 9px;border:1px solid #1b2436;border-radius:7px;background:#0d1220;cursor:pointer}.mb-track:hover{border-color:#38507e;background:#121a2c}.mb-track.on{border-color:#4ecdc4;background:#11212a}.mb-track.on .mb-tname{color:#4ecdc4;font-weight:700}.mb-tname{color:#cdd7ea}.mb-tmeta{color:#6b7c9c;font-size:12px}');
  web.AddStyle(
    '.mb-scope{display:flex;flex-direction:column;gap:6px}.mb-row{display:flex;align-items:center;gap:8px}.mb-vlabel{width:46px;flex:none;font-size:11px;letter-spacing:.1em;color:#6b7c9c}.mb-cells{display:grid;grid-template-columns:repeat(16,1fr);gap:2px;flex:1 1 auto}.mb-cell{height:13px;border-radius:3px;background:#141b2a}.mb-cell.note{background:#26405f}.mb-cell.now{background:#4ecdc4;box-shadow:0 0 7px rgba(78,205,196,.7)}.mb-cell.note.now{background:#ffd166;box-shadow:0 0 9px rgba(255,209,102,.8)}.mb-vu{display:grid;grid-template-columns:repeat(8,5px);gap:2px;flex:none}.mb-seg{height:13px;border-radius:2px;background:#141b2a}.mb-seg.lit{background:#4ecdc4}.mb-steps{display:grid;grid-template-columns:repeat(16,1fr);gap:2px}.mb-dot{height:4px;border-radius:2px;background:#1b2436}.mb-dot.now{background:#4ecdc4}');
  web.AddStyle(
    '.mb-controls{display:flex;flex-wrap:wrap;align-items:center;gap:6px}.mb-btn{font:inherit;padding:5px 11px;color:#cdd7ea;background:#131a28;border:1px solid #24304a;border-radius:7px;cursor:pointer}.mb-btn:hover{background:#1a2437;border-color:#38507e}.mb-btn:focus-visible{outline:2px solid #4ecdc4;outline-offset:1px}.mb-btn.on{background:#4ecdc4;border-color:#4ecdc4;color:#04121a;font-weight:700}.mb-bpm{min-width:74px;text-align:center;color:#cdd7ea}.mb-sep{width:1px;height:20px;margin:0 5px;background:#1b2436}.mb-status{color:#6b7c9c;font-size:12px}');
end;

// Returns the handle; the CALLER registers its handler (a procedure now, not
// an integer the program had to invent).
function MakeButton(parent: Integer; caption: string; tip: string): Integer;
var
  b: Integer;
begin
  b := web.CreateElement('button');
  web.SetClassName(b, 'mb-btn');
  web.SetInnerText(b, caption);
  web.SetPropertyStr(b, 'type', 'button');
  web.SetPropertyStr(b, 'title', tip);
  web.AppendChild(parent, b);
  MakeButton := b;
end;

procedure AddSeparator(parent: Integer);
var
  s: Integer;
begin
  s := web.CreateElement('span');
  web.SetClassName(s, 'mb-sep');
  web.AppendChild(parent, s);
end;

procedure AddTrack(parent, idx: Integer; name: string; meta: string);
var
  row, t, m: Integer;
begin
  row := web.CreateElement('div');
  web.SetClassName(row, 'mb-track');
  web.AppendChild(parent, row);
  t := web.CreateElement('span');
  web.SetClassName(t, 'mb-tname');
  web.SetInnerText(t, name);
  web.AppendChild(row, t);
  m := web.CreateElement('span');
  web.SetClassName(m, 'mb-tmeta');
  web.SetInnerText(m, meta);
  web.AppendChild(row, m);
  track_h[idx] := row;
end;

procedure AddVoiceRow(parent, v: Integer; vname: string);
var
  row, lab, cells, vu, el: Integer;
  s, i: Integer;
begin
  row := web.CreateElement('div');
  web.SetClassName(row, 'mb-row');
  web.AppendChild(parent, row);
  lab := web.CreateElement('span');
  web.SetClassName(lab, 'mb-vlabel');
  web.SetInnerText(lab, vname);
  web.AppendChild(row, lab);
  cells := web.CreateElement('div');
  web.SetClassName(cells, 'mb-cells');
  web.AppendChild(row, cells);
  for s := 0 to STEPS - 1 do
  begin
    el := web.CreateElement('span');
    web.SetClassName(el, 'mb-cell');
    web.AppendChild(cells, el);
    cell_h[v * STEPS + s] := el;
  end;
  vu := web.CreateElement('div');
  web.SetClassName(vu, 'mb-vu');
  web.AppendChild(row, vu);
  for i := 0 to SEGMENTS - 1 do
  begin
    el := web.CreateElement('span');
    web.SetClassName(el, 'mb-seg');
    web.AppendChild(vu, el);
    seg_h[v * SEGMENTS + i] := el;
  end;
end;

procedure BuildUI;
var
  head, now, scope, controls, el, b, i: Integer;
begin
  InjectStyles;

  root_h := web.CreateElement('div');
  web.SetClassName(root_h, 'mb-root');
  web.AppendChild(stage_h, root_h);

  // --- header: the record, the track, the audio state ---
  head := web.CreateElement('div');
  web.SetClassName(head, 'mb-head');
  web.AppendChild(root_h, head);
  disc_h := web.CreateElement('div');
  web.SetClassName(disc_h, 'mb-disc');
  web.AppendChild(head, disc_h);
  now := web.CreateElement('div');
  web.SetClassName(now, 'mb-now');
  web.AppendChild(head, now);
  title_h := web.CreateElement('div');
  web.SetClassName(title_h, 'mb-title');
  web.AppendChild(now, title_h);
  sub_h := web.CreateElement('div');
  web.SetClassName(sub_h, 'mb-sub');
  web.AppendChild(now, sub_h);
  audio_lbl_h := web.CreateElement('span');
  web.SetClassName(audio_lbl_h, 'mb-audio');
  web.AppendChild(head, audio_lbl_h);

  // --- the playlist ---
  el := web.CreateElement('div');
  web.SetClassName(el, 'mb-tracks');
  web.AppendChild(root_h, el);
  AddTrack(el, 0, 'Aurora', '96 BPM · square lead');
  AddTrack(el, 1, 'Circuit', '132 BPM · sawtooth lead');
  AddTrack(el, 2, 'Deep Water', '72 BPM · sine lead');
  AddTrack(el, 3, 'Arcade', '168 BPM · square lead');
  for i := 0 to TRACK_COUNT - 1 do
    track_cb[i] := web.On(track_h[i], 'click', OnTrack);

  // --- the visualiser: piano roll + meters, every element a <span> ---
  scope := web.CreateElement('div');
  web.SetClassName(scope, 'mb-scope');
  web.AppendChild(root_h, scope);
  AddVoiceRow(scope, VOX_LEAD, 'LEAD');
  AddVoiceRow(scope, VOX_BASS, 'BASS');
  AddVoiceRow(scope, VOX_CLICK, 'CLICK');

  // the bar position, 16 dots (the playhead, in miniature)
  steps_row_h := web.CreateElement('div');
  web.SetClassName(steps_row_h, 'mb-steps');
  web.AppendChild(root_h, steps_row_h);
  for i := 0 to STEPS - 1 do
  begin
    el := web.CreateElement('span');
    web.SetClassName(el, 'mb-dot');
    web.AppendChild(steps_row_h, el);
    dot_h[i] := el;
  end;

  // --- transport ---
  controls := web.CreateElement('div');
  web.SetClassName(controls, 'mb-controls');
  web.AppendChild(root_h, controls);
  play_h := MakeButton(controls, 'Play', 'Start or pause (Space)');
  web.On(play_h, 'click', OnPlay);
  b := MakeButton(controls, 'Stop', 'Stop and rewind (S)');
  web.On(b, 'click', OnStop);
  AddSeparator(controls);
  b := MakeButton(controls, '-', 'Slower by 8 BPM');
  web.On(b, 'click', OnBpmDown);
  bpm_lbl_h := web.CreateElement('span');
  web.SetClassName(bpm_lbl_h, 'mb-bpm');
  web.AppendChild(controls, bpm_lbl_h);
  b := MakeButton(controls, '+', 'Faster by 8 BPM');
  web.On(b, 'click', OnBpmUp);
  AddSeparator(controls);
  vol_h[0] := MakeButton(controls, '25%', 'Volume 25%');
  vol_h[1] := MakeButton(controls, '50%', 'Volume 50%');
  vol_h[2] := MakeButton(controls, '75%', 'Volume 75%');
  vol_h[3] := MakeButton(controls, '100%', 'Volume 100%');
  for i := 0 to 3 do
    vol_cb[i] := web.On(vol_h[i], 'click', OnVol);

  el := web.CreateElement('div');
  web.SetClassName(el, 'mb-status');
  web.SetInnerText(el, 'Every element above — the scope, the meters, the playhead — is a DOM node. No canvas.');
  web.AppendChild(root_h, el);
end;

// ---------------------------------------------------------------------------
// The body IS pascaldom_main (the pascaldom ABI)
// ---------------------------------------------------------------------------
// No wrapper procedure, no `exports` clause, no dispatcher: the host calls the
// body once after instantiate, and the unit's dispatch table routes each event
// to the handler registered above.
begin
  web := TWeb.Create;                    // wraps `document`
  // The mount point is the HOST's business and this source ships to more than
  // one: the IDE runs its examples under #stage, a standalone page often has
  // neither id, and handle 0 is the bridge's RESERVED event slot rather than
  // "no parent" (dom_canvas_create would throw on it). Ask, then fall back.
  stage_h := web.GetElementById('stage');
  if stage_h = 0 then stage_h := web.GetElementById('app');
  if stage_h = 0 then stage_h := web.Doc;

  BuildUI;
  BuildAudio;
  SelectTrack(track_idx);
  UpdateVolClasses;
  SetTransportClasses;
  UpdateAudioLabel;

  web.On(web.Doc, 'keydown', OnKeyDown);
  // The animation loop: one registration, and it is the thing that drives the
  // sequencer (Tick compares web.NowMs against the next step's deadline).
  web.OnTick(OnTick);
end.
