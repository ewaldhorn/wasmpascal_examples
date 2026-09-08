unit sweepscreen;

interface

uses
  sweepdefs,
  sweepgame,
  sweepdraw;

procedure DrawCell(i, j, cx, cy: Integer; pressed: Boolean);

procedure DrawFrame;

implementation


procedure DrawCell(i, j, cx, cy: Integer; pressed: Boolean);
var
  idx: Integer;
  cs: Integer;
  is_bomb: Boolean;
begin
  idx := i * MAX_H + j;
  cs := cells[idx];
  is_bomb := bombs[idx];

  if (state = ST_LOST) and is_bomb then
  begin
    if cs = CS_OPENED then
      CFillRect(cx, cy, CELL_SIZE, CELL_SIZE, 255, 40, 40)
    else
      CFillRect(cx, cy, CELL_SIZE, CELL_SIZE, 224, 224, 224);
    CRectThick(cx, cy, CELL_SIZE, CELL_SIZE, 1, 128, 128, 128);
    DrawMine(cx, cy, CELL_SIZE, CELL_SIZE);
    if cs = CS_FLAGGED then DrawFlag(cx, cy, CELL_SIZE, CELL_SIZE);
    Exit;
  end;

  if (state = ST_LOST) and (not is_bomb) and (cs = CS_FLAGGED) then
  begin
    CFillRect(cx, cy, CELL_SIZE, CELL_SIZE, 224, 224, 224);
    CRectThick(cx, cy, CELL_SIZE, CELL_SIZE, 1, 128, 128, 128);
    DrawFlag(cx, cy, CELL_SIZE, CELL_SIZE);
    DrawX(cx, cy, CELL_SIZE, CELL_SIZE, 200, 0, 0);
    Exit;
  end;

  if cs <> CS_OPENED then
  begin
    if pressed then
      DrawBevel(cx, cy, CELL_SIZE, CELL_SIZE, 3, false)
    else
      DrawBevel(cx, cy, CELL_SIZE, CELL_SIZE, 2, false);
    if cs = CS_FLAGGED then DrawFlag(bix, biy, biw, bih)
    else if cs = CS_UNCERTAIN then DrawQMark(bix, biy, biw, bih);
    Exit;
  end;

  CFillRect(cx, cy, CELL_SIZE, CELL_SIZE, 224, 224, 224);
  CRectThick(cx, cy, CELL_SIZE, CELL_SIZE, 1, 128, 128, 128);
  if nums[idx] > 0 then
  begin
    NumColour(Integer(nums[idx]));
    SetActive(num_r, num_g, num_b, 255);
    DrawSevenSeg(cx + 6, cy + 3, 12, 18, Integer(nums[idx]));
  end;
end;

procedure DrawFrame;
var
  elapsed: Integer;
  i, j: Integer;
  cxx, cyy: Integer;
begin
  SyncLevel;
  CFillRect(0, 0, CANVAS_W, CANVAS_H, 28, 30, 38);

  WindowSize(bx, by);
  WindowOrigin;

  CFillRect(win_ox, win_oy, win_w, win_h, 192, 192, 192);
  DrawBevel(win_ox, win_oy, win_w, win_h, 4, false);
  DrawBevel(win_ox + 10, win_oy + 10, win_w - 20, 40, 2, true);
  top_x := bix; top_y := biy; top_w := biw; top_h := bih;

  FieldRect;
  show_levels := state = ST_UNDEFINED;

  // hover + press state
  cell_i := 0; cell_j := 0;
  if CellAt(mouse_x, mouse_y) then
  begin
    if mouse_down and (mouse_down_btn = MB_LEFT) then
      if (state <> ST_WON) and (state <> ST_LOST) then
        if (cells[cell_i * MAX_H + cell_j] <> CS_OPENED) and (cells[cell_i * MAX_H + cell_j] <> CS_FLAGGED) then
          pressing_board := true;
  end;

  FaceRect;
  face_pressed := false;
  if FaceHit(mouse_x, mouse_y) and mouse_down and (mouse_down_btn = MB_LEFT) then
    face_pressed := true;
  DrawBevel(face_x, face_y, face_w, face_h, 2, face_pressed);

  face_state := FS_NORMAL;
  if state = ST_WON then face_state := FS_WON
  else if state = ST_LOST then face_state := FS_LOST
  else if pressing_board then face_state := FS_WORRIED;
  DrawFace(bix, biy, biw, bih, face_state);

  // mine counter (hidden while level select shown)
  if not show_levels then
  begin
    SetActive(192, 192, 192, 255);
    DrawBevel(top_x + 5, top_y + 6, 41, 25, 1, true);
    DrawCounter(top_x + 5, top_y + 6, 41, 25, nbombs - FlagCount);
  end;

  // timer
  SetActive(192, 192, 192, 255);
  DrawBevel(top_x + top_w - 5 - 41, top_y + 6, 41, 25, 1, true);
  elapsed := 0;
  if state <> ST_UNDEFINED then
    elapsed := Integer(last_time - start_time);
  DrawCounter(top_x + top_w - 5 - 41, top_y + 6, 41, 25, elapsed);

  // level buttons
  if show_levels then
  begin
    FillLevelButtons;
    if difficulty <> 0 then DrawBevel(lbr0x, lbr0y, lbr0w, lbr0h, 1, false);
    SetActive(0, 0, 0, 255);
    DrawSevenSeg(lbr0x + 6, lbr0y + 3, 12, 18, 1);
    if difficulty <> 1 then DrawBevel(lbr1x, lbr1y, lbr1w, lbr1h, 1, false);
    SetActive(0, 0, 0, 255);
    DrawSevenSeg(lbr1x + 6, lbr1y + 3, 12, 18, 2);
    if difficulty <> 2 then DrawBevel(lbr2x, lbr2y, lbr2w, lbr2h, 1, false);
    SetActive(0, 0, 0, 255);
    DrawSevenSeg(lbr2x + 6, lbr2y + 3, 12, 18, 3);
  end;

  DrawBevel(field_x - 4, field_y - 4, field_w + 8, field_h + 8, 4, true);

  for i := 0 to bx - 1 do
    for j := 0 to by - 1 do
    begin
      cxx := field_x + i * CELL_SIZE;
      cyy := field_y + j * CELL_SIZE;
      if (cell_i = i) and (cell_j = j) and mouse_down and (mouse_down_btn = MB_LEFT) then
        DrawCell(i, j, cxx, cyy, true)
      else
        DrawCell(i, j, cxx, cyy, false);
    end;
end;

begin
end.
