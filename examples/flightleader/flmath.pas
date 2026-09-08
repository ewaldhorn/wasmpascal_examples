// flmath.pas — FLIGHT LEADER math: 3D vector/rotation helpers, the xorshift
// RNG, and the world→camera→screen projection used by both the simulation
// (spawning effects at projected positions) and the renderer.
unit flmath;

interface

uses
  fldefs;

function NextRand: Cardinal;
function RandF: Single;
function RandRange(lo, hi: Single): Single;
function RandRangeI(lo, hi: Integer): Integer;

function fclamp(v, lo, hi: Single): Single;
function flerp(a, b, t: Single): Single;
function fSin(a: Single): Single;
function fCos(a: Single): Single;
function fAtan2(y, x: Single): Single;
function fPow(b, e: Single): Single;
function ParseF64(buf: Integer; blen: Integer): Double;
function v3dot(ax, ay, az, bx, by, bz: Single): Single;
procedure v3cross(ax, ay, az, bx, by, bz: Single; var ox, oy, oz: Single);
function v3len(x, y, z: Single): Single;
procedure v3norm(x, y, z: Single; var ox, oy, oz: Single);
procedure v3scale(x, y, z, s: Single; var ox, oy, oz: Single);

// Rotation helpers (right-handed, y-up, z-forward):
//   RotX(+a): pitch up   (0,0,1) -> (0, sin a, cos a)
//   RotY(+a): turn left  (0,0,1) -> (sin a, 0, cos a)
//   RotZ(+a): roll left  (1,0,0) -> (cos a, sin a, 0)
procedure RotX(a, x, y, z: Single; var ox, oy, oz: Single);
procedure RotY(a, x, y, z: Single; var ox, oy, oz: Single);
procedure RotZ(a, x, y, z: Single; var ox, oy, oz: Single);

// Player's world-space forward unit vector from yaw/pitch.
procedure PlayerForward(var fx, fy, fz: Single);

// Project a world point through the player camera; on return `visible` is
// true and (sx, sy) are canvas pixels, `scale` = FOCAL / depth (for sizing).
procedure ProjToScreen(wx, wy, wz: Single; var sx, sy, scale: Single; var visible: Boolean);

// Camera-space depth of a world point (used for culling).
function DepthOf(wx, wy, wz: Single): Single;

implementation

function NextRand: Cardinal;
begin
  rng_state := rng_state xor (rng_state shl 13);
  rng_state := rng_state xor (rng_state shr 17);
  rng_state := rng_state xor (rng_state shl 5);
  NextRand := rng_state;
end;

function RandF: Single;
begin
  RandF := Single(NextRand and $FFFFFF) / 16777216.0;
end;

function RandRange(lo, hi: Single): Single;
begin
  RandRange := lo + (hi - lo) * RandF;
end;

function RandRangeI(lo, hi: Integer): Integer;
begin
  RandRangeI := lo + Integer(RandF * Single(hi - lo + 1));
end;

function fclamp(v, lo, hi: Single): Single;
begin
  if v < lo then fclamp := lo
  else if v > hi then fclamp := hi
  else fclamp := v;
end;

function flerp(a, b, t: Single): Single;
begin
  flerp := a + (b - a) * t;
end;

// Float wrappers over the Double-signature odin_env math imports (see the
// externals note in fldefs — the compiler's math builtins don't promote
// Single args to f64).
function fSin(a: Single): Single;
begin
  fSin := Single(mSin(Double(a)));
end;

function fCos(a: Single): Single;
begin
  fCos := Single(mCos(Double(a)));
end;

function fAtan2(y, x: Single): Single;
begin
  fAtan2 := Single(mAtan2(Double(y), Double(x)));
end;

function fPow(b, e: Single): Single;
begin
  fPow := Single(mPow(Double(b), Double(e)));
end;

// Parse an ASCII decimal (with optional sign and fraction) — used for the
// batch_get_property_str number reads (clientX/clientY, rect fields).
function ParseF64(buf: Integer; blen: Integer): Double;
var
  i, s: Integer;
  ip, frac, scale: Double;
begin
  ip := 0.0; frac := 0.0; scale := 0.1; s := 1; i := 0;
  if blen > 0 then
  begin
    if PByte(buf)[0] = 45 then begin s := -1; i := 1; end   // '-'
    else if PByte(buf)[0] = 43 then i := 1;                  // '+'
    while (i < blen) and (PByte(buf)[i] <> 46) do            // '.'
    begin
      ip := ip * 10.0 + Double(PByte(buf)[i] - 48);
      i := i + 1;
    end;
    if (i < blen) and (PByte(buf)[i] = 46) then
    begin
      i := i + 1;
      while i < blen do
      begin
        frac := frac + Double(PByte(buf)[i] - 48) * scale;
        scale := scale * 0.1;
        i := i + 1;
      end;
    end;
  end;
  ParseF64 := (ip + frac) * Double(s);
end;

function v3dot(ax, ay, az, bx, by, bz: Single): Single;
begin
  v3dot := ax * bx + ay * by + az * bz;
end;

procedure v3cross(ax, ay, az, bx, by, bz: Single; var ox, oy, oz: Single);
begin
  ox := ay * bz - az * by;
  oy := az * bx - ax * bz;
  oz := ax * by - ay * bx;
end;

function v3len(x, y, z: Single): Single;
begin
  v3len := Sqrt(x * x + y * y + z * z);
end;

procedure v3norm(x, y, z: Single; var ox, oy, oz: Single);
var
  l: Single;
begin
  l := Sqrt(x * x + y * y + z * z);
  if l < 0.0001 then
  begin
    ox := 0; oy := 0; oz := 1;
  end else begin
    ox := x / l; oy := y / l; oz := z / l;
  end;
end;

procedure v3scale(x, y, z, s: Single; var ox, oy, oz: Single);
begin
  ox := x * s; oy := y * s; oz := z * s;
end;

procedure RotX(a, x, y, z: Single; var ox, oy, oz: Single);
var
  c, s: Single;
begin
  c := fCos(a);
  s := fSin(a);
  ox := x;
  oy := y * c + z * s;
  oz := -y * s + z * c;
end;

procedure RotY(a, x, y, z: Single; var ox, oy, oz: Single);
var
  c, s: Single;
begin
  c := fCos(a);
  s := fSin(a);
  ox := x * c + z * s;
  oy := y;
  oz := -x * s + z * c;
end;

procedure RotZ(a, x, y, z: Single; var ox, oy, oz: Single);
var
  c, s: Single;
begin
  c := fCos(a);
  s := fSin(a);
  ox := x * c - y * s;
  oy := x * s + y * c;
  oz := z;
end;

procedure PlayerForward(var fx, fy, fz: Single);
var
  tx, ty, tz: Single;
begin
  // forward = rotY(yaw) * rotX(pitch) * (0,0,1)
  RotX(player.pitch, 0, 0, 1, tx, ty, tz);
  RotY(player.yaw, tx, ty, tz, fx, fy, fz);
end;

procedure ProjToScreen(wx, wy, wz: Single; var sx, sy, scale: Single; var visible: Boolean);
var
  dx, dy, dz: Single;
  p1x, p1y, p1z: Single;
  cxp, cyp, czp: Single;
begin
  dx := wx - player.px;
  dy := wy - player.py;
  dz := wz - player.pz;
  // camera = rotY(-yaw) * rotX(-pitch) * (rel)
  RotX(-player.pitch, dx, dy, dz, p1x, p1y, p1z);
  RotY(-player.yaw, p1x, p1y, p1z, cxp, cyp, czp);
  if czp <= NEARZ then
  begin
    visible := false;
    sx := 0; sy := 0; scale := 1.0;
  end else begin
    visible := true;
    scale := FOCAL / czp;
    sx := Single(CW) * 0.5 + cxp * scale;
    sy := Single(CH) * 0.5 - cyp * scale;
  end;
end;

function DepthOf(wx, wy, wz: Single): Single;
var
  dx, dy, dz: Single;
  p1x, p1y, p1z: Single;
  cxp, cyp, czp: Single;
begin
  dx := wx - player.px;
  dy := wy - player.py;
  dz := wz - player.pz;
  RotX(-player.pitch, dx, dy, dz, p1x, p1y, p1z);
  RotY(-player.yaw, p1x, p1y, p1z, cxp, cyp, czp);
  DepthOf := czp;
end;

end.
