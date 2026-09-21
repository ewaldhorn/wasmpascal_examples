library guess;

// Classic "guess the number" game — the first program everyone writes.
// Uses readln for input (the inline input line — prompt() dialogs only on the
// no-SharedArrayBuffer fallback), write/writeln for
// output, if/else if for feedback, and a repeat-until loop for the game flow.
// You get 7 tries (binary search always wins 1..128 in 7), so the game
// always terminates — even a scripted wrong answer just plays out all tries.

// The ONE bridge entry this file declares, and it has to be declared by hand:
// `uses WEB` would select the pascaldom ABI (the body would become
// `pascaldom_main` and `wasmpascal_init` would be suppressed), which is a real
// change for a CONSOLE program -- the host would boot it as a canvas program
// instead of running it in the console worker. Measured 2026-09-14: the same
// file with `uses WEB` added exports pascaldom_main/invoke_callback/
// set_last_event and no wasmpascal_init. A console program that wants the clock
// keeps the raw external.
function dom_now: Double; external 'pascaldom_env' name 'dom_now';

const
  RANGE = 128; // power of two: (seed and (RANGE-1)) stays in 0..127 unsigned

var
  secret, guess, tries: Integer;

procedure NewSecret;
var
  seed: Cardinal;
begin
  // seed from the clock's µs fraction so each game differs (Trunc(ms) alone
  // is ~2 at program start in a fresh worker, which would always pick 60)
  seed := Cardinal((dom_now - Trunc(dom_now)) * 1000000.0) xor $9E3779B9;
  if seed = 0 then seed := 1;
  // 0..127 via unsigned mask (and uses shr-free bit ops, no signed mod),
  // then +1 -> 1..128. The mask keeps the value in range regardless of sign.
  secret := Integer(seed and (RANGE - 1)) + 1;
end;

begin
  writeln('=== Number Guessing Game ===');
  writeln('I have picked a number between 1 and 128.');
  writeln('You have 7 tries. Good luck!');

  NewSecret;
  tries := 0;

  repeat
    tries := tries + 1;
    write('Guess #', tries, ': ');
    readln(guess);
    if guess < secret then
      writeln('Too low!')
    else if guess > secret then
      writeln('Too high!')
    else
      writeln('Correct! You got it in ', tries, ' tries.');
  until (guess = secret) or (tries >= 7);

  if guess <> secret then
    writeln('Out of tries! The number was ', secret, '.');
  writeln('Thanks for playing!');
end.
