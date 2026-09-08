# Colours (TextColor / TextBackground)

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

``

```pascal
TextColor(4);          // blue foreground (palette index)
TextBackground(1);    // red background (palette index)
TextColor('ff0000ff');  // opaque red (RRGGBBAA)
TextBackground('0000ff80'); // blue bg, 50% alpha
TextColorRGB(255, 0, 0); // opaque red (r,g,b)
BackgroundRGB(0, 0, 255); // blue background (r,g,b)
writeln('hi');       // rendered with the current colours
```

Set the colour for subsequent console output; it applies until changed (there is no reset call — set both back to defaults).

**Palette indices** (0..15, TP's TextColor numbers):

- `0` black `1` red `2` green `3` yellow/brown
- `4` blue `5` magenta `6` cyan `7` light gray (default fg)
- `8` dark gray `9` light red `10` light green `11` light yellow
- `12` light blue `13` light magenta `14` light cyan `15` white

**`uses Crt`** — the built-in `Crt` unit provides the 16 TP7 colour constants (`Black`, `Blue`, `Red`, `LightGreen`, `White`, …) so you can write `TextColor(Red)` instead of `TextColor(4)`. `ClrScr`/`TextColor`/`TextBackground`/ `GotoXY`/`Delay`/`ReadKey`/ `UpCase`/`KeyPressed` are compiler builtins, so the unit only brings the names into scope.

**Hex strings** — an 8-digit `RRGGBBAA` string gives an arbitrary colour with alpha (CSS order, alpha last): `TextColor('ff0000ff')` is opaque red, `'0000ff80'` is blue at 50% alpha. The value must be exactly ​8 hex digits; anything else is a compile error.

**RGB components** — `TextColorRGB(r, g, b)` and `BackgroundRGB(r, g, b)` (alias `TextBackgroundRGB`) take runtime `0..255` components (opaque, alpha 255), so a colour can be computed in a loop: `TextColorRGB(i * 5, 0, 0)` ramps red. See `../../examples/enhanced_colours.pas`.

Colour runs render into the output panel as `<span style="color:..;background:..">` and coexist with a graphics canvas on the same page. See `../../examples/colors.pas`.
