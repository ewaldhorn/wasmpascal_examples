program classes_demo;
// Classes demo — reference types with `Create`/`Free`, virtual dispatch,
// `override`, `inherited`, polymorphism through parent references, and
// two-level inheritance. A class variable holds a heap pointer; `Create`
// allocates + constructs, `Free` destroys + disposes.

type
  TAnimal = class
    x, y: Integer;
    constructor Create(ax, ay: Integer);
    function Speak: Integer; virtual;
    procedure Move(dx, dy: Integer); virtual;
    function Sum: Integer;
  end;

  TDog = class(TAnimal)
    z: Integer;
    constructor Create(ax, ay, az: Integer);
    function Speak: Integer; override;
    procedure Move(dx, dy: Integer); override;
    procedure Bark; virtual;
    function Total: Integer;
  end;

  TLabrador = class(TDog)
    w: Integer;
    constructor Create(ax, ay, az, aw: Integer);
    function Speak: Integer; override;
    procedure Bark; override;
  end;

var
  a: TAnimal;
  d: TDog;
  lab: TLabrador;

constructor TAnimal.Create(ax, ay: Integer);
begin
  x := ax;
  y := ay;
end;

function TAnimal.Speak: Integer;
begin
  Speak := x + y;
end;

procedure TAnimal.Move(dx, dy: Integer);
begin
  x := x + dx;
  y := y + dy;
end;

function TAnimal.Sum: Integer;
begin
  Sum := x + y;
end;

constructor TDog.Create(ax, ay, az: Integer);
begin
  inherited Create(ax, ay);
  z := az;
end;

function TDog.Speak: Integer;
begin
  Speak := inherited Speak + 1000;
end;

procedure TDog.Move(dx, dy: Integer);
begin
  inherited Move(dx, dy);
  z := z + 1;
end;

procedure TDog.Bark;
begin
  z := z + 10;
end;

function TDog.Total: Integer;
begin
  Total := x + y + z;
end;

constructor TLabrador.Create(ax, ay, az, aw: Integer);
begin
  inherited Create(ax, ay, az);
  w := aw;
end;

function TLabrador.Speak: Integer;
begin
  Speak := inherited Speak + 2000;
end;

procedure TLabrador.Bark;
begin
  inherited Bark;
  w := w + 5;
end;

begin
  writeln('--- classes: Create + fields ---');
  d := TDog.Create(1, 2, 3);
  writeln('TDog(1,2,3): ', d.x, ' ', d.y, ' ', d.z, ' total=', d.Total);
  d.Move(4, 5);
  writeln('after Move(4,5): ', d.x, ' ', d.y, ' ', d.z);
  d.Bark;
  writeln('after Bark: z=', d.z);

  writeln('--- classes: virtual + override + inherited ---');
  writeln('TDog.Speak=', d.Speak, ' (Animal sum + 1000)');
  lab := TLabrador.Create(10, 20, 30, 40);
  writeln('TLabrador(10,20,30,40): ', lab.x, ' ', lab.y, ' ', lab.z, ' ', lab.w);
  writeln('TLabrador.Speak=', lab.Speak, ' (TDog speak + 2000)');
  lab.Bark;
  writeln('after Bark: z=', lab.z, ' w=', lab.w);

  writeln('--- classes: polymorphism ---');
  d := TDog.Create(2, 3, 4);
  a := d; // child -> parent reference
  writeln('a := d (TDog 2,3,4) a.Speak=', a.Speak, ' (dispatches TDog override)');
  a.Move(7, 8);
  writeln('a.Move(7,8) -> a=', a.x, ' ', a.y, ' d.z=', d.z, ' (same heap object)');
  writeln('static via child: d.Sum=', d.Sum);

  writeln('--- classes: two levels + Free ---');
  lab := TLabrador.Create(1, 1, 1, 1);
  a := lab;
  writeln('a := lab (TLabrador) a.Speak=', a.Speak);
  writeln('SizeOf(TAnimal)=', SizeOf(TAnimal), ' (reference = 4)');
  d.Free;
  lab.Free;
  // a still points at freed memory in this demo — don't use after Free in real code
  writeln('freed (no crash = ok)');
end.
