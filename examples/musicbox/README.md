# Music Box

A music player with a DOM elements-based visualiser, compiled with [WasmPascal](https://wasmpascal.com/).

This app uses the DOM the create the UI. There's basically just a grid of `<span>`s whose classes change every step, the meters are rows of segments that light up, the playhead is a class on a column, and the record spins thanks to CSS changes.

Covers:
- DOM rendering at animation-frame rate through `web.OnTick`, not recommended practice, of course, but entirely possible on most systems.
- Web Audio from Pascal: `web.NewAudioContext`, simple to get started, yet pretty convenient.
- Two independent clocks, the animation frame (`web.NowMs`) and the audio context, not linked to each other so the visualiser keeps running when a browser refuses to start audio before any user interaction. Bit contrived as a demo, but it was fun to build!

The tunes live in the source's `SCORE` table — the example ships no actual audio files, it's all just code!
