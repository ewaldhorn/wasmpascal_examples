# Objects & classes

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

TP7-style OOP is fully supported — value-type `object` and reference-type `class`, with virtual dispatch, inheritance, and polymorphism.

 **`object` (value type)**

`type TPoint = object x, y: Integer; constructor Init(ax, ay: Integer); procedure Move(dx, dy: Integer); function Tag: Integer; virtual; end;` — instances live where the variable lives (globals, locals, arrays, record fields). No heap unless you ask for it.

`constructor` is a normal method that runs on an existing instance; for virtual-bearing objects it stores the VMT first. Call it as `p.Init(3,4)` on a value var, or `New(p, Init(3,4))` to heap-allocate and construct in one go (`Dispose(p)` frees).

Methods are functions with a hidden `self` address — fields are `self + field_off`, and bare method names inside a method resolve to that object's methods. `with obj do` and `p^.Method` work as expected, and `a := b` copies the whole object (including its VMT word).

`SizeOf(TPoint)` includes the hidden VMT pointer when the type has a virtual method (e.g. 12 = 4 + 2×Integer).

See `../../examples/objects_demo.pas`.

 **Inheritance & virtual dispatch**

`TPoint3D = object(TPoint) z: Integer; function Tag: Integer; override; end;` — fields are a superset (parent first), VMT is a superset (parent slots first). `override` replaces the parent's slot; a child stored in a parent-typed variable still dispatches the child's override (value copy carries the child's VMT word).

`inherited` calls the parent's method: `inherited Init(ax, ay)` (explicit) or bare `inherited;` (forwards current method's params). For virtual methods this is a direct call to the parent's slot, not a re-dispatch.

`New(p3, Init(1,2,3))` on a child correctly keeps the child's VMT (the parent constructor's VMT store is skipped via the hidden VMT-skip flag).

 **`class` (reference type)**

`type TAnimal = class x, y: Integer; constructor Create(ax, ay: Integer); function Speak: Integer; virtual; end;` — variables hold heap references (4 bytes). `TAnimal.Create(1,2)` allocates, constructs, and returns the reference; `a.Free` destroys + disposes, `a.Destroy` is the destructor method alone.

Fields and methods auto-deref the reference: `d.x`, `d.Move(4,5)`, `d.Speak` all go through the heap object. Virtual dispatch is identical to objects, but via the heap instance's VMT.

`TDog = class(TAnimal) z: Integer; function Speak: Integer; override; end;` — **class inheritance works too** (two-level chains like `TLabrador = class(TDog)`). `a := d` (child → parent) is a reference assignment; `a.Speak` dispatches the child's override (true polymorphism). `SizeOf(TAnimal) = 4` (the reference).

Built-in `TObject`/`TStrings`/`TStringList` are just classes on this same machinery (the embedded `classes` unit is always merged).

See `../../examples/classes_demo.pas`. Typed const aggregates like `Origin: TPoint = (x: 10; y: 20)` and `Scores: array[0..2] of Integer = (10,20,30)` (see `../../examples/typed_const_demo.pas`) and `s + c` where `c: Char` also landed in 0.5.0.
