# Music Box

A music player whose visualiser is made of DOM elements and nothing else, compiled with [WasmPascal](https://wasmpascal.com/).

Where `paint.pas` uses the DOM to build an interface, this one uses it to render motion: there is no canvas, no framebuffer, and no pixel buffer anywhere in the program. The scope is a grid of `<span>`s whose classes change every step, the meters are rows of segments that light up, the playhead is a class on a column, and the record spins because CSS says so.

Covers:
- DOM rendering at animation-frame rate through `web.OnTick` — at most ~32 classList operations per step, and fifteen steps in sixteen allocate nothing.
- Web Audio from Pascal: `web.NewAudioContext` plus the facade's generic call-method / get-set-property methods, one oscillator and gain per note wired into a master gain.
- Two independent clocks, the animation frame (`web.NowMs`) and the audio context, deliberately not bound to each other so the visualiser keeps running when a browser refuses to start audio before a user gesture.

The four tunes live in the source's `SCORE` table — the example ships no audio files.
