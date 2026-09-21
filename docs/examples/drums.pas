// drums.pas — RETRO DRUM MACHINE: a 6-track 16-step sequencer
//
// Original contribution by Nico van Zyl (https://nicovanzyl.com/)
// Ported to Pascal by Ewald Horn
//
// What it is: six rows (kick, snare, closed hat, open hat, clap, rim) by
// sixteen steps, drawn as a neon grid on a 512x320 pixel canvas. Click a pad
// to toggle it (toggling one ON previews its sound), press Play to run the
// sequencer at 120 BPM, watch the playhead sweep.
//
// How it maps to the WEB bridge:
//   - canvas + pointer: MakeCanvas/RenderCanvas over a Byte pixel buffer, and
//     the paint.pas bounding-rect dance (getBoundingClientRect +
//     EventClientX/Y) to map a CSS-scaled click back to canvas pixels.
//   - clock: web.NowMs against a next-step deadline, the musicbox.pas
//     Tick/Advance/FireStep shape, including its background-tab resync.
//   - pitched voices (kick/sine, snare/triangle, hats/square): hand-built
//     osc -> gain -> master voices through the generic CallMethod bridge,
//     exactly like musicbox.pas EmitOsc, with the Odin envelope (peak 0.4,
//     pitch falling to 20 Hz over 0.06 s).
//   - noise voices (clap/rim): web.AudioNoise — the ONE sound the generic
//     bridge cannot spell, because it has no typed-array write with which to
//     fill an AudioBuffer, so the host owns the cached noise samples.

{$M 2M}
library drums;

uses
  Web;

const
  DW = 512;
  DH = 320;
  NPX = DW * DH * 4;

  TRACKS = 6;
  STEPS = 16;
  CELLS = TRACKS * STEPS;

  GRID_X = 74;
  GRID_Y = 82;
  CELL_W = 24;
  CELL_H = 24;
  PITCH_X = 27;      // CELL_W + 3 gap
  PITCH_Y = 30;      // CELL_H + 6 gap

  BPM = 120;

  // Default groove, row-major: kick four-on-the-floor, snare on 5 and 13,
  // hats off-beat, clap and rim accents.
  PAT: array[0..CELLS - 1] of Integer = (
    1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0,
    0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
    1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0,
    0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0);

  // Voice per track: 0 = sine, 1 = triangle, 2 = square, 3 = noise.
  KIND: array[0..TRACKS - 1] of Integer = (0, 1, 2, 2, 3, 3);
  FREQ: array[0..TRACKS - 1] of Integer = (60, 200, 8000, 6000, 1200, 400);

  // Neon cell colours, one per track, and their dim "off" variants.
  NR: array[0..TRACKS - 1] of Integer = (0, 255, 255, 255, 160, 0);
  NG: array[0..TRACKS - 1] of Integer = (240, 0, 230, 153, 0, 255);
  NB: array[0..TRACKS - 1] of Integer = (220, 180, 0, 0, 255, 100);
  DR: array[0..TRACKS - 1] of Integer = (10, 42, 42, 42, 26, 0);
  DG: array[0..TRACKS - 1] of Integer = (42, 0, 37, 24, 0, 40);
  DB: array[0..TRACKS - 1] of Integer = (40, 30, 0, 0, 48, 16);

var
  web: TWeb;
  pixels: array[0..NPX - 1] of Byte;
  pattern: array[0..CELLS - 1] of Integer;

  playing: Boolean = false;
  step: Integer = 0;
  next_time: Double = 0.0;
  step_sec: Double = 0.125;      // recomputed from BPM at boot

  audio_h: Integer = 0;
  master_node: Integer = 0;
  master_gain: Integer = 0;
  audio_now: Double = 0.0;

  cv_h: Integer = 0;
  play_h: Integer = 0;
  status_h: Integer = 0;

  rect_left: Double = 0.0;
  rect_top: Double = 0.0;
  rect_scale_x: Double = 1.0;
  rect_scale_y: Double = 1.0;

// ---------------------------------------------------------------------------
// Pixel helpers — the whole renderer is canvas primitives over the buffer.
// RenderCanvas pushes it in one call.
// ---------------------------------------------------------------------------

procedure SetPx(x, y: Integer; r, g, b: Byte);
var
  i: Integer;
begin
  if (x < 0) or (y < 0) or (x >= DW) or (y >= DH) then exit;
  i := (y * DW + x) * 4;
  pixels[i] := r;
  pixels[i + 1] := g;
  pixels[i + 2] := b;
  pixels[i + 3] := 255;
end;

procedure FillRect(x, y, w, h: Integer; r, g, b: Byte);
var
  ix, iy: Integer;
begin
  for iy := y to y + h - 1 do
    for ix := x to x + w - 1 do
      SetPx(ix, iy, r, g, b);
end;

procedure StrokeRect(x, y, w, h, t: Integer; r, g, b: Byte);
var
  k: Integer;
begin
  for k := 0 to t - 1 do
  begin
    FillRect(x + k, y + k, w - 2 * k, 1, r, g, b);
    FillRect(x + k, y + h - 1 - k, w - 2 * k, 1, r, g, b);
    FillRect(x + k, y + k, 1, h - 2 * k, r, g, b);
    FillRect(x + w - 1 - k, y + k, 1, h - 2 * k, r, g, b);
  end;
end;

procedure VLine(x, y0, y1: Integer; r, g, b: Byte);
var
  y: Integer;
begin
  for y := y0 to y1 do
    SetPx(x, y, r, g, b);
end;

procedure FillCircle(cx, cy, rad: Integer; r, g, b: Byte);
var
  dx, dy: Integer;
begin
  for dy := -rad to rad do
    for dx := -rad to rad do
      if dx * dx + dy * dy <= rad * rad then
        SetPx(cx + dx, cy + dy, r, g, b);
end;

// ---------------------------------------------------------------------------
// Tiny 3x5 bitmap font
// ---------------------------------------------------------------------------

procedure DrawGlyph(ch: Char; x, y, scale: Integer; r, g, b: Byte);
var
  rows: array[0..4] of String[3];
  ri, ci: Integer;
begin
  case ch of
    '0': begin rows[0] := '111'; rows[1] := '101'; rows[2] := '101'; rows[3] := '101'; rows[4] := '111'; end;
    '1': begin rows[0] := '010'; rows[1] := '110'; rows[2] := '010'; rows[3] := '010'; rows[4] := '111'; end;
    '2': begin rows[0] := '111'; rows[1] := '001'; rows[2] := '111'; rows[3] := '100'; rows[4] := '111'; end;
    '3': begin rows[0] := '111'; rows[1] := '001'; rows[2] := '111'; rows[3] := '001'; rows[4] := '111'; end;
    '4': begin rows[0] := '101'; rows[1] := '101'; rows[2] := '111'; rows[3] := '001'; rows[4] := '001'; end;
    '5': begin rows[0] := '111'; rows[1] := '100'; rows[2] := '111'; rows[3] := '001'; rows[4] := '111'; end;
    '6': begin rows[0] := '111'; rows[1] := '100'; rows[2] := '111'; rows[3] := '101'; rows[4] := '111'; end;
    '7': begin rows[0] := '111'; rows[1] := '001'; rows[2] := '010'; rows[3] := '010'; rows[4] := '010'; end;
    '8': begin rows[0] := '111'; rows[1] := '101'; rows[2] := '111'; rows[3] := '101'; rows[4] := '111'; end;
    '9': begin rows[0] := '111'; rows[1] := '101'; rows[2] := '111'; rows[3] := '001'; rows[4] := '111'; end;
    'A': begin rows[0] := '010'; rows[1] := '101'; rows[2] := '111'; rows[3] := '101'; rows[4] := '101'; end;
    'B': begin rows[0] := '110'; rows[1] := '101'; rows[2] := '110'; rows[3] := '101'; rows[4] := '110'; end;
    'C': begin rows[0] := '111'; rows[1] := '100'; rows[2] := '100'; rows[3] := '100'; rows[4] := '111'; end;
    'D': begin rows[0] := '110'; rows[1] := '101'; rows[2] := '101'; rows[3] := '101'; rows[4] := '110'; end;
    'E': begin rows[0] := '111'; rows[1] := '100'; rows[2] := '110'; rows[3] := '100'; rows[4] := '111'; end;
    'H': begin rows[0] := '101'; rows[1] := '101'; rows[2] := '111'; rows[3] := '101'; rows[4] := '101'; end;
    'I': begin rows[0] := '111'; rows[1] := '010'; rows[2] := '010'; rows[3] := '010'; rows[4] := '111'; end;
    'K': begin rows[0] := '101'; rows[1] := '101'; rows[2] := '110'; rows[3] := '101'; rows[4] := '101'; end;
    'L': begin rows[0] := '100'; rows[1] := '100'; rows[2] := '100'; rows[3] := '100'; rows[4] := '111'; end;
    'M': begin rows[0] := '101'; rows[1] := '111'; rows[2] := '111'; rows[3] := '101'; rows[4] := '101'; end;
    'N': begin rows[0] := '101'; rows[1] := '111'; rows[2] := '111'; rows[3] := '111'; rows[4] := '101'; end;
    'O': begin rows[0] := '111'; rows[1] := '101'; rows[2] := '101'; rows[3] := '101'; rows[4] := '111'; end;
    'P': begin rows[0] := '110'; rows[1] := '101'; rows[2] := '110'; rows[3] := '100'; rows[4] := '100'; end;
    'R': begin rows[0] := '110'; rows[1] := '101'; rows[2] := '110'; rows[3] := '101'; rows[4] := '101'; end;
    'S': begin rows[0] := '111'; rows[1] := '100'; rows[2] := '111'; rows[3] := '001'; rows[4] := '111'; end;
    'U': begin rows[0] := '101'; rows[1] := '101'; rows[2] := '101'; rows[3] := '101'; rows[4] := '111'; end;
    else begin rows[0] := '000'; rows[1] := '000'; rows[2] := '000'; rows[3] := '000'; rows[4] := '000'; end;
  end;
  for ri := 0 to 4 do
    for ci := 1 to 3 do
      if rows[ri][ci] = '1' then
        FillRect(x + (ci - 1) * scale, y + ri * scale, scale, scale, r, g, b);
end;

procedure DrawText(s: string; x, y, scale: Integer; r, g, b: Byte);
var
  i, cursor: Integer;
begin
  cursor := x;
  for i := 1 to Length(s) do
  begin
    if s[i] = ' ' then
      cursor := cursor + 4 * scale
    else
    begin
      DrawGlyph(s[i], cursor, y, scale, r, g, b);
      cursor := cursor + 4 * scale;
    end;
  end;
end;

procedure TrackLabel(t, y: Integer; r, g, b: Byte);
begin
  if t = 0 then DrawText('K', 24, y, 2, r, g, b)
  else if t = 1 then DrawText('SN', 24, y, 2, r, g, b)
  else if t = 2 then DrawText('HH', 24, y, 2, r, g, b)
  else if t = 3 then DrawText('OH', 24, y, 2, r, g, b)
  else if t = 4 then DrawText('CL', 24, y, 2, r, g, b)
  else DrawText('RM', 24, y, 2, r, g, b);
end;

// ---------------------------------------------------------------------------
// The synth. Pitched voices are hand-built osc -> gain -> master voices
// (peak 0.4, pitch falling to 20 Hz); noise voices go
// through web.AudioNoise. One AudioClock read per step, shared by the chord.
// ---------------------------------------------------------------------------

function AudioClock: Double;
begin
  if audio_h = 0 then
  begin
    AudioClock := 0.0;
    exit;
  end;
  AudioClock := web.GetPropertyF64(audio_h, 'currentTime');
end;

procedure DrumTone(freq: Double; wave: string);
var
  osc, gn, freq_p, gain_p: Integer;
  t: Double;
begin
  if audio_h = 0 then exit;
  t := audio_now;
  osc := web.CallMethodRet(audio_h, 'createOscillator');
  gn := web.CallMethodRet(audio_h, 'createGain');
  web.SetPropertyStr(osc, 'type', wave);
  freq_p := web.GetProperty(osc, 'frequency');
  web.SetPropertyF64(freq_p, 'value', freq);
  gain_p := web.GetProperty(gn, 'gain');
  web.SetPropertyF64(gain_p, 'value', 0.4);
  web.CallMethod1h(osc, 'connect', gn);
  web.CallMethod1h(gn, 'connect', master_node);
  web.CallMethod2f(freq_p, 'exponentialRampToValueAtTime', 20.0, t + 0.06);
  web.CallMethod2f(gain_p, 'exponentialRampToValueAtTime', 0.001, t + 0.08);
  web.CallMethod0(osc, 'start');
  web.CallMethod1f(osc, 'stop', t + 0.1);
  web.ReleaseHandle(freq_p);
  web.ReleaseHandle(gain_p);
  web.ReleaseHandle(osc);
  web.ReleaseHandle(gn);
end;

procedure PlayTrack(t: Integer);
begin
  if audio_h = 0 then exit;
  if KIND[t] = 3 then
    web.AudioNoise(audio_h, master_node, 0.06, 0.4)
  else if KIND[t] = 1 then
    DrumTone(Double(FREQ[t]), 'triangle')
  else if KIND[t] = 2 then
    DrumTone(Double(FREQ[t]), 'square')
  else
    DrumTone(Double(FREQ[t]), 'sine');
end;

procedure BuildAudio;
var
  dest: Integer;
begin
  audio_h := web.NewAudioContext;
  if audio_h = 0 then exit;
  master_node := web.CallMethodRet(audio_h, 'createGain');
  master_gain := web.GetProperty(master_node, 'gain');
  web.SetPropertyF64(master_gain, 'value', 0.2);
  dest := web.GetProperty(audio_h, 'destination');
  web.CallMethod1h(master_node, 'connect', dest);
  web.ReleaseHandle(dest);
end;

// ---------------------------------------------------------------------------
// The sequencer — wall-clock stepping (like musicbox.pas Advance), so BPM
// holds whatever the frame rate does.
// ---------------------------------------------------------------------------

procedure FireStep;
var
  t: Integer;
begin
  audio_now := AudioClock;
  for t := 0 to TRACKS - 1 do
    if pattern[t * STEPS + step] <> 0 then
      PlayTrack(t);
end;

procedure Advance;
begin
  step := step + 1;
  if step >= STEPS then
    step := 0;
  FireStep;
end;

procedure Tick(id: Integer);
var
  t: Double;
begin
  if not playing then exit;
  t := web.NowMs;
  if t < next_time then exit;
  if t > next_time + step_sec * 4000.0 then next_time := t;
  Advance;
  next_time := next_time + step_sec * 1000.0;
end;

// ---------------------------------------------------------------------------
// The renderer: frame, title, step separators, six labelled rows, playhead.
// ---------------------------------------------------------------------------

procedure Render;
var
  s, t, x, y: Integer;
  d: Integer;
begin
  FillRect(0, 0, DW, DH, 5, 5, 16);
  StrokeRect(8, 8, DW - 16, DH - 16, 2, 0, 240, 220);
  StrokeRect(14, 14, DW - 28, DH - 28, 1, 12, 12, 34);

  DrawText('DRUM 120 BPM', 26, 26, 2, 0, 240, 220);
  if playing then
    DrawText('RUN', 400, 26, 2, 0, 255, 100)
  else
    DrawText('PAUSE', 384, 26, 2, 68, 68, 112);

  for s := 0 to STEPS - 1 do
  begin
    x := GRID_X + s * PITCH_X;
    if s mod 4 = 0 then
      VLine(x - 5, GRID_Y - 6, GRID_Y + TRACKS * PITCH_Y - 2, 68, 68, 112);
    d := (s + 1) mod 10;
    DrawGlyph(Chr(48 + d), x + 8, GRID_Y - 24, 1, 68, 68, 112);
  end;

  for t := 0 to TRACKS - 1 do
  begin
    y := GRID_Y + t * PITCH_Y;
    TrackLabel(t, y + 8, Byte(NR[t]), Byte(NG[t]), Byte(NB[t]));
    FillCircle(60, y + 12, 4, Byte(NR[t]), Byte(NG[t]), Byte(NB[t]));
    for s := 0 to STEPS - 1 do
    begin
      x := GRID_X + s * PITCH_X;
      if pattern[t * STEPS + s] <> 0 then
      begin
        FillRect(x, y, CELL_W, CELL_H, Byte(NR[t]), Byte(NG[t]), Byte(NB[t]));
        FillRect(x + 5, y + 5, CELL_W - 10, CELL_H - 10, 255, 255, 255);
        FillRect(x + 7, y + 7, CELL_W - 14, CELL_H - 14, Byte(NR[t]), Byte(NG[t]), Byte(NB[t]));
      end
      else
        FillRect(x, y, CELL_W, CELL_H, Byte(DR[t]), Byte(DG[t]), Byte(DB[t]));
      StrokeRect(x, y, CELL_W, CELL_H, 1, 12, 12, 34);
    end;
  end;

  x := GRID_X + step * PITCH_X;
  StrokeRect(x - 2, GRID_Y - 4, CELL_W + 4, TRACKS * PITCH_Y - 4, 2, 255, 255, 255);
  FillRect(x + 2, GRID_Y + TRACKS * PITCH_Y + 4, CELL_W - 4, 5, 255, 255, 255);

  web.RenderCanvas(Integer(@pixels), NPX);
end;

// ---------------------------------------------------------------------------
// Pointer input — the paint.pas rect dance, then the cell-toggle math.
// ---------------------------------------------------------------------------

procedure RefreshRect;
var
  rect: Integer;
  // Named rw/rh, NOT dw/dh: identifiers are case-insensitive, so dw IS the
  // DW const above — Double(DW) / dw would read the same variable twice and
  // the scale would come out exactly 1.0 whatever the canvas's CSS size is
  // (every click then lands up-left of the pointer). Same trap paint.pas
  // documents for its N/n const/local collision.
  rw, rh: Double;
begin
  if cv_h = 0 then exit;
  rect := web.CallMethodRet(cv_h, 'getBoundingClientRect');
  rect_left := web.GetPropertyF64(rect, 'left');
  rect_top := web.GetPropertyF64(rect, 'top');
  rw := web.GetPropertyF64(rect, 'width');
  rh := web.GetPropertyF64(rect, 'height');
  web.ReleaseHandle(rect);
  if rw > 0.5 then rect_scale_x := Double(DW) / rw;
  if rh > 0.5 then rect_scale_y := Double(DH) / rh;
end;

procedure HandleDown(id: Integer);
var
  px, py, rel_x, rel_y: Integer;
  step_i, track_i: Integer;
begin
  RefreshRect;
  px := Trunc((web.EventClientX - rect_left) * rect_scale_x);
  py := Trunc((web.EventClientY - rect_top) * rect_scale_y);
  rel_x := px - GRID_X;
  rel_y := py - GRID_Y;
  if (rel_x < 0) or (rel_y < 0) then exit;
  step_i := rel_x div PITCH_X;
  track_i := rel_y div PITCH_Y;
  if (step_i < 0) or (step_i >= STEPS) then exit;
  if (track_i < 0) or (track_i >= TRACKS) then exit;
  if rel_x mod PITCH_X >= CELL_W then exit;
  if rel_y mod PITCH_Y >= CELL_H then exit;
  if pattern[track_i * STEPS + step_i] <> 0 then
    pattern[track_i * STEPS + step_i] := 0
  else
  begin
    pattern[track_i * STEPS + step_i] := 1;
    if audio_h <> 0 then
    begin
      web.CallMethod0(audio_h, 'resume');
      audio_now := AudioClock;
      PlayTrack(track_i);
    end;
  end;
  Render;
end;

// ---------------------------------------------------------------------------
// Transport
// ---------------------------------------------------------------------------

procedure UpdateTransportText;
begin
  if playing then
  begin
    web.SetInnerText(play_h, 'STOP');
    web.SetInnerText(status_h, 'playing — click pads to toggle · 120 BPM');
  end
  else
  begin
    web.SetInnerText(play_h, 'PLAY');
    web.SetInnerText(status_h, 'paused — click pads to toggle, then PLAY · 120 BPM');
  end;
end;

procedure HandlePlay(id: Integer);
begin
  playing := not playing;
  if audio_h <> 0 then
    web.CallMethod0(audio_h, 'resume');
  if playing then
  begin
    next_time := web.NowMs;
    FireStep;
  end;
  UpdateTransportText;
  Render;
end;

procedure HandleTick(id: Integer);
begin
  Tick(id);
  Render;
end;

var
  stage_h, panel_h, title_h: Integer;
  i: Integer;

begin
  web := TWeb.Create;
  web.AddStyle('.drums{font:14px sans-serif;padding:10px;color:#ddd;background:#222}'
    + '.drums h1{font-size:16px;margin:0 0 8px;color:#8cf}'
    + '.drums button{font-size:14px;margin:4px 8px 4px 0;padding:4px 12px}'
    + '.drums .status{font:12px monospace;color:#9c9;margin-top:8px}'
    + '#stage canvas{border:1px solid #555;cursor:pointer;image-rendering:pixelated}');

  stage_h := web.GetElementById('stage');
  panel_h := web.CreateElement('div');
  web.SetClassName(panel_h, 'drums');
  title_h := web.CreateElement('h1');
  web.SetInnerText(title_h, 'Drums — A 16-step Sequencer');
  web.AppendChild(panel_h, title_h);
  web.AppendChild(stage_h, panel_h);

  cv_h := web.MakeCanvas(panel_h, DW, DH);

  play_h := web.CreateElement('button');
  web.AppendChild(panel_h, play_h);
  status_h := web.CreateElement('div');
  web.SetClassName(status_h, 'status');
  web.AppendChild(panel_h, status_h);

  for i := 0 to CELLS - 1 do
    pattern[i] := PAT[i];
  step_sec := 60.0 / (Double(BPM) * 4.0);
  BuildAudio;

  web.On(cv_h, 'pointerdown', HandleDown);
  web.On(play_h, 'click', HandlePlay);
  web.OnTick(HandleTick);

  UpdateTransportText;
  Render;
  web.Log('drums: ready');
end.
