// breakout.pas — a console-mode Breakout game for the 80x25 text screen.
//
// 5 rows of colored blocks, a '*' ball, and a 9-wide '=' paddle. Arrow keys
// (and A/D) move the paddle; the ball bounces off walls, blocks and the
// paddle (the bounce angle follows where the ball hits the paddle). Clear
// all 90 blocks to win; you have 3 lives. Press R after a game to restart.
//
// This is the first example built on the console key input: KeyPressed /
// ReadKey poll a key ring fed by the host (arrow keys arrive TP-style as
// #0 + scan code: left #75, right #77), Delay paces the frame, and Random /
// Randomize give a random serve direction. The host synthesizes held-key
// repeats at frame rate, so HOLDING an arrow moves the paddle every frame;
// HandleKeys drains every queued key per frame, so rapid taps queue up and
// all apply. The ball moves every second frame (a deliberate cadence) so it
// travels at about half the paddle's top speed. Rendering is per-cell
// (GotoXY + write one char): the worker syncs the screen once per frame at
// the Delay boundary, so a frame of a few dozen cell writes costs ONE render.
// No strings, no heap — the whole game is scalars and a boolean block grid.

program breakout;
{$Screen 80 25}
uses Crt;

const
  PaddleLen = 9;
  PaddleRow = 23;
  BallRow0  = 22;   // ball starts just above the paddle
  BlockRows = 5;
  BlocksPerRow = 18;
  BlockLeft = 5;    // first block column (18 x 3 + 17 gaps = 71 cols, centered)

var
  blocks: array[1..BlockRows] of array[1..BlocksPerRow] of Boolean;
  paddleX, ballX, ballY, dx, dy: Integer;
  score, lives, blocksLeft, state: Integer;     // state: 0=play 1=win 2=lost
  ballTick: Boolean;   // ball moves every 2nd frame (slower than the paddle)
  endShown: Boolean;

// Write one character at (x, y), 1-based. All game drawing goes through this.
procedure Cell(x, y: Integer; ch: Char);
begin
  GotoXY(x, y);
  write(ch);
end;

// Row color: each block row is a classic breakout color; everything else
// (border, paddle) is white.
function RowColor(y: Integer): Integer;
begin
  case y of
    2: RowColor := Red;
    3: RowColor := LightRed;
    4: RowColor := Yellow;
    5: RowColor := Green;
    6: RowColor := LightGreen;
    else RowColor := White;
  end;
end;

// Is there a live block at (x, y)? Blocks are 3 cells wide with a 1-cell
// gap, so the column within a block slots into a 4-wide pattern.
function IsBlock(x, y: Integer): Boolean;
var j: Integer;
begin
  IsBlock := false;
  if (y < 2) or (y > 6) or (x < BlockLeft) or (x > 75) then exit;
  if (x - BlockLeft) mod 4 = 3 then exit; // gap column
  j := (x - BlockLeft) div 4 + 1;
  IsBlock := blocks[y - 1][j];
end;

// Score/lives HUD on row 24. Row 24 is reserved for the HUD: nothing else
// ever draws there (the playfield is rows 2..23, the banners are rows 13/15).
// The fixed widths (score:3, lives always one digit) mean a redraw fully
// overwrites the previous text — a shorter value can't leave residue.
procedure DrawHud;
begin
  GotoXY(1, 24);
  TextColor(White);
  write('Score: ', score:3, '   Lives: ', lives);
end;

// Destroy the block containing (x, y): clear its 3 cells, score, and check
// for a win.
procedure DestroyBlock(x, y: Integer);
var
  j, i: Integer;
begin
  j := (x - BlockLeft) div 4 + 1;
  blocks[y - 1][j] := false;
  blocksLeft := blocksLeft - 1;
  score := score + 1;
  TextColor(White);
  for i := 0 to 2 do Cell(BlockLeft + (j - 1) * 4 + i, y, ' ');
  if blocksLeft = 0 then state := 1;
  DrawHud;
end;

// Draw the paddle at its current position.
procedure DrawPaddle;
var i: Integer;
begin
  TextColor(White);
  for i := 0 to PaddleLen - 1 do Cell(paddleX + i, PaddleRow, '=');
end;

// Move the paddle one cell left/right (dir = -1 or +1), clamped inside the
// walls, then redraw it.
procedure MovePaddle(dir: Integer);
var i: Integer;
begin
  TextColor(White);
  for i := 0 to PaddleLen - 1 do Cell(paddleX + i, PaddleRow, ' ');
  if dir > 0 then
  begin
    if paddleX + PaddleLen <= 79 then paddleX := paddleX + 1;
  end
  else
  begin
    if paddleX > 2 then paddleX := paddleX - 1;
  end;
  for i := 0 to PaddleLen - 1 do Cell(paddleX + i, PaddleRow, '=');
end;

// Serve the ball from the middle of the paddle in a random horizontal
// direction (Randomize was called once at startup).
procedure Serve;
begin
  if Random(2) = 0 then dx := -1 else dx := 1;
  dy := -1;
  ballX := paddleX + 4;
  ballY := BallRow0;
  Cell(ballX, ballY, '*');
end;

// The ball got past the paddle: lose a life and re-serve, or game over.
procedure MissBall;
begin
  lives := lives - 1;
  if lives <= 0 then state := 2
  else Serve;
  DrawHud;
end;

// Advance the ball one cell, bounce off walls/blocks/paddle, and handle a
// miss. Collisions are checked against the horizontal and vertical neighbor
// cells before moving, so the bounce direction matches the face that was hit.
procedure MoveBall;
var
  nx, ny: Integer;
begin
  TextColor(White);
  Cell(ballX, ballY, ' '); // erase the old ball
  // walls (the ball travels within the 2..79 x 2..24 playfield)
  if ballX + dx < 2 then dx := 1
  else if ballX + dx > 79 then dx := -1;
  if ballY + dy < 2 then dy := 1;
  // blocks
  if IsBlock(ballX + dx, ballY) then
  begin
    DestroyBlock(ballX + dx, ballY);
    dx := -dx;
  end;
  if IsBlock(ballX, ballY + dy) then
  begin
    DestroyBlock(ballX, ballY + dy);
    dy := -dy;
  end;
  nx := ballX + dx;
  ny := ballY + dy;
  // corner hit: destination itself is a block (both neighbors were clear) —
  // reverse BOTH axes so the ball bounces off the corner instead of passing
  // through at an angle.
  if IsBlock(nx, ny) then
  begin
    DestroyBlock(nx, ny);
    dx := -dx;
    dy := -dy;
    nx := ballX + dx;
    ny := ballY + dy;
  end;
  // paddle: the playfield's bottom wall. A hit bounces the ball and steers
  // it by where it landed; a miss costs a life.
  if ny >= PaddleRow then
  begin
    if (nx >= paddleX) and (nx <= paddleX + PaddleLen - 1) then
    begin
      dy := -dy;
      if nx < paddleX + 4 then dx := -1
      else if nx > paddleX + 4 then dx := 1;
      ny := BallRow0; // stay above the paddle; never draw into it
    end
    else
    begin
      MissBall;
      exit;
    end;
  end;
  ballX := nx;
  ballY := ny;
  Cell(ballX, ballY, '*');
end;

// Fresh game: clear the whole screen (including the end banner and any
// leftover paddle/ball from a previous game), then draw the border, blocks,
// paddle and serve. The score/lives HUD (row 24) is drawn by DrawHud, which
// is also called whenever a block is destroyed or a life is lost.
procedure NewGame;
var
  x, y, j: Integer;
begin
  ClrScr;         // no residue from the previous game (banner, paddle, ball)
  state := 0;
  score := 0;
  lives := 3;
  blocksLeft := BlockRows * BlocksPerRow;
  endShown := false;
  TextColor(White);
  // border
  for x := 1 to 80 do
  begin
    Cell(x, 1, '#');
    Cell(x, 25, '#');
  end;
  for y := 2 to 24 do
  begin
    Cell(1, y, '#');
    Cell(80, y, '#');
  end;
  // blocks
  for y := 1 to BlockRows do
  begin
    TextColor(RowColor(y + 1));
    for j := 1 to BlocksPerRow do
    begin
      blocks[y][j] := true;   // the LOGIC grid — must mirror the drawing
      for x := 0 to 2 do Cell(BlockLeft + (j - 1) * 4 + x, y + 1, '#');
    end;
  end;
  paddleX := 36;
  DrawPaddle;
  Serve;
  DrawHud;
end;

// Read pending keys. Arrow keys arrive as the extended pair #0 + scan code
// (#75 left / #77 right); A/D work too. All queued keys are drained each
// frame (while KeyPressed), so burst taps and the host's held-key repeats
// both move the paddle as fast as the game can track. In the end state, R
// restarts.
procedure HandleKeys;
var ch: Char;
begin
  while KeyPressed do
  begin
    ch := ReadKey;
    if ch = #0 then ch := ReadKey;
    if state <> 0 then
    begin
      if (ch = 'r') or (ch = 'R') then NewGame;
    end
    else if (ch = #75) or (ch = 'a') or (ch = 'A') then MovePaddle(-1)
    else if (ch = #77) or (ch = 'd') or (ch = 'D') then MovePaddle(1);
  end;
end;

// Banner for win / game over.
procedure ShowEnd;
begin
  GotoXY(36, 13);
  if state = 1 then
  begin
    TextColor(Yellow);
    write('YOU WIN!');
  end
  else
  begin
    TextColor(LightRed);
    write('GAME OVER');
  end;
  GotoXY(29, 15);
  TextColor(White);
  write('Press R to play again');
end;

begin
  ClrScr;
  Randomize;      // random serve directions
  NewGame;
  while true do
  begin
    HandleKeys;
    if state = 0 then
    begin
      if ballTick then MoveBall;
      ballTick := not ballTick;
    end
    else if not endShown then
    begin
      ShowEnd;
      endShown := true;
    end;
    Delay(35);    // ~28 fps; the worker flushes the screen once per frame
  end;
end.
