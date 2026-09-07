# Console Breakout

A full-featured classic Breakout arcade game rendered entirely in text mode on an 80x25 character screen using the Turbo Pascal `Crt` unit emulation in [WasmPascal](https://wasmpascal.com/).

Features:
- 5 colored rows of bricks, a moving ball, and a paddle.
- Realistic paddle-segment bounce physics.
- Real-time keyboard polling (`KeyPressed` and `ReadKey`) with frame timing paced by `Delay`.
- Score tracking, lives counter, and win/loss states.

All rendering is performed via character cell updates (`GotoXY` and `write`) mapped directly to the virtual terminal.
