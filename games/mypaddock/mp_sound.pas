unit mp_sound;

{ M5: sound events. Port of game.odin's sound.odin public play_* procs.
  The Odin side synthesises Web Audio directly; here each event is one
  host call, app_env.play_sound(id), and the host (host.js) owns the
  oscillator/sweep patches — same parameters as sound.odin.
  sfx_on lives here (not mp_game) so there is no unit cycle: mp_game
  uses mp_sound and reads/writes sfx_on directly. }

interface

uses
  mp_defs;

var
  sfx_on: Boolean = true;

procedure PlayFeed;
procedure PlayWater;
procedure PlayShear;
procedure PlayCoin;
procedure PlayPurchase;
procedure PlayDenied;
procedure PlaySold;

implementation

procedure aPlaySound(id: Integer); external 'app_env' name 'play_sound';

procedure PlayFeed;
begin
  if sfx_on then aPlaySound(SND_FEED);
end;

procedure PlayWater;
begin
  if sfx_on then aPlaySound(SND_WATER);
end;

procedure PlayShear;
begin
  if sfx_on then aPlaySound(SND_SHEAR);
end;

procedure PlayCoin;
begin
  if sfx_on then aPlaySound(SND_COIN);
end;

procedure PlayPurchase;
begin
  if sfx_on then aPlaySound(SND_PURCHASE);
end;

procedure PlayDenied;
begin
  if sfx_on then aPlaySound(SND_DENIED);
end;

procedure PlaySold;
begin
  if sfx_on then aPlaySound(SND_SOLD);
end;

begin
end.
