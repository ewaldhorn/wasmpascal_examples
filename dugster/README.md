# Dugster

A complete, multi-module retro arcade game inspired by Dig Dug and Boulder Dash, written in modular Pascal and compiled to WebAssembly with [WasmPascal](https://wasmpascal.com/).

This project demonstrates a multi-unit Pascal architecture:
- `dugdefs.pas`: Core data definitions, grid dimensions, tile constants, and entity records.
- `duglevel.pas`: Procedural underground cavern generation, dirt layouts, and rock placements.
- `dugfx.pas`: Canvas sprite and tile rendering routines.
- `dugsim.pas`: Game simulation physics, digging mechanics, rock gravity, and monster AI.
- `dugrender.pas`: Full viewport rendering and HUD display.
- `dugster.pas`: Main game entry point, loop scheduling, and event handling.

Controls:
- Arrow keys / WASD to move and dig.
- Space to pump / attack enemies.
- R to restart after game over.
