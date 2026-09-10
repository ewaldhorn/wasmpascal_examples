unit mp_effect;

{ Port of effect.odin: effect data + lifetime. Drawing lives in mp_sprites. }

interface

uses
  mp_defs;

procedure NewCoinEffect(var e: TEffect; x, y: Double; amount: Integer);

procedure NewSparkleEffect(var e: TEffect; x, y: Double);

function EffectUpdate(var e: TEffect; dt: Double): Boolean;

implementation

procedure NewCoinEffect(var e: TEffect; x, y: Double; amount: Integer);
begin
  e.kind := EK_COIN_FLOAT;
  e.x := x;
  e.y := y;
  e.value := amount;
  e.timer := EFFECT_FLOAT_DURATION;
  e.max_timer := EFFECT_FLOAT_DURATION;
end;

procedure NewSparkleEffect(var e: TEffect; x, y: Double);
begin
  e.kind := EK_SPARKLE;
  e.x := x;
  e.y := y;
  e.value := 0;
  e.timer := SPARKLE_DURATION;
  e.max_timer := SPARKLE_DURATION;
end;

function EffectUpdate(var e: TEffect; dt: Double): Boolean;
begin
  e.timer := e.timer - dt;
  EffectUpdate := e.timer > 0.0;
end;

begin
end.
