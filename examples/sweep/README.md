# PascalSweep (Minesweeper)

A complete, multi-unit Minesweeper game engine and user interface implemented in Pascal and compiled with [WasmPascal](https://wasmpascal.com/).

Architecture:
- `sweepdefs.pas`: Core constants, grid boundaries, and cell state representations.
- `sweeprand.pas`: Seeded pseudo-random number generator for reproducible mine distribution.
- `sweepdraw.pas`: Canvas rendering routines for tiles, numbers, flags, and LCD counters.
- `sweepgame.pas`: Minefield initialization, click resolution, and recursive zero-tile flood clearing.
- `sweepscreen.pas`: Screen coordinates, hit-testing, and layout management.
- `sweepstore.pas`: Persistent high scores and statistics tracking.
- `sweephost.pas`: Glue layer binding the game engine to browser DOM and audio events.
- `sweep.pas`: Root program managing state and export symbols.
