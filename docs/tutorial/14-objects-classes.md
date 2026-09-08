# Objects & classes

> Lesson from the WasmPascal in-browser **Learn Pascal** tutorial. Source: `webpascal/index.html`.

wasmpascal supports TP7-style OOP — value-type `object` and reference-type `class`, with constructors, virtual dispatch, inheritance, and polymorphism.

```pascal
type
  TPoint = object
    x, y: Integer;
    constructor Init(ax, ay: Integer);
    procedure Move(dx, dy: Integer);
    function Tag: Integer; virtual;
  end;
  TPoint3D = object(TPoint)
    z: Integer;
    constructor Init(ax, ay, az: Integer);
    function Tag: Integer; override;
  end;

var p: TPoint; q: TPoint3D; pb: TPoint;

constructor TPoint.Init(ax, ay: Integer);
begin x := ax; y := ay; end;
function TPoint.Tag: Integer; begin Tag := 2; end;
constructor TPoint3D.Init(ax, ay, az: Integer);
begin inherited Init(ax, ay); z := az; end;
function TPoint3D.Tag: Integer; begin Tag := 3; end;

begin
  p.Init(3, 4); // value-type: lives where the var lives
  q.Init(1, 2, 3);
  pb := q;                      // copy carries the 3D VMT — virtual dispatch
  writeln('p.Tag=', p.Tag);   // 2
  writeln('q.Tag=', q.Tag);   // 3
  writeln('pb.Tag=', pb.Tag); // 3 — child's override via base var
end.
```

`object` is a **value type** — like a record with methods. A `constructor` runs on an existing instance (or on a heap block with `New(p, Init(...))` / `Dispose(p)`). `virtual` methods dispatch through a hidden VMT; `override` replaces the parent slot; `inherited` calls the parent's method (explicit `inherited Init(...)` or bare `inherited;` forwarding current params). See `../../examples/objects_demo.pas` for the full tour (static + virtual + `with` + `New` + `SizeOf`).

```pascal
type
  TAnimal = class
    x, y: Integer;
    constructor Create(ax, ay: Integer);
    function Speak: Integer; virtual;
  end;
  TDog = class(TAnimal)
    z: Integer;
    constructor Create(ax, ay, az: Integer);
    function Speak: Integer; override;
  end;

var d: TDog; a: TAnimal;

constructor TAnimal.Create(ax, ay: Integer);
begin x := ax; y := ay; end;
function TAnimal.Speak: Integer; begin Speak := x + y; end;
constructor TDog.Create(ax, ay, az: Integer);
begin inherited Create(ax, ay); z := az; end;
function TDog.Speak: Integer; begin Speak := inherited Speak + 1000; end;

begin
  d := TDog.Create(1, 2, 3);
  a := d;                       // reference assignment — same heap object
  writeln(a.Speak);           // 1003 — dispatches TDog.Speak via parent ref
  writeln(SizeOf(TAnimal)); // 4 — class vars are references
  d.Free;                       // destructor + dispose
end.
```

`class` is a **reference type** — variables hold heap pointers. `Create` allocates + constructs, `Free` destroys + disposes. Inheritance works the same as for objects, including two-level chains like `TLabrador = class(TDog)` and `inherited` in both constructors and virtual methods. A child assigned to a parent reference still dispatches the child's override — true polymorphism. Built-in `TObject`/`TStrings`/`TStringList` are just classes on this machinery. See `../../examples/classes_demo.pas`. Typed const aggregates (`Origin: TPoint = (x: 10; y: 20)`) and `s + c` where `c: Char` are also new in 0.5.0 (see `../../examples/typed_const_demo.pas`).

*Try it: paste this into the [WasmPascal editor](https://wasmpascal.com/) and press Run.*
