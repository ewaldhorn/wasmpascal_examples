# Guess the Number

The classic interactive number guessing game running in the browser with [WasmPascal](https://wasmpascal.com/).

Uses standard Pascal `readln` for user input (answered at an inline input line in the console grid, or through browser dialogs on the no-SharedArrayBuffer fallback), `writeln` for feedback, and a repeat-until loop giving the player 7 tries to find the secret number.
