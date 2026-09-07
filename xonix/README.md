# Xonix

A faithful port of the classic arcade territory-capture game Xonix to [WasmPascal](https://wasmpascal.com/).

Features:
- 40x25 cell grid with a surrounding land perimeter and open sea.
- Real-time trail carving across the sea with keyboard controls.
- Enemy flood-fill algorithm: when a trail connects to land, all sea reachable by bouncing enemy balls is preserved, capturing enclosed regions.
- Multi-level difficulty progression with increasing ball counts and batched 2D canvas rendering.
