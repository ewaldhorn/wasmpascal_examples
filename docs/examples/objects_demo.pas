program objects_demo;
// Objects demo — TP7 `object` value types with constructors, static
// methods, virtual dispatch, inheritance, `inherited`, and heap allocation
// via `New(p, Init(...))`. Objects are VALUE types (no heap unless you
// ask for it with New); virtual methods carry a VMT and dispatch through it.

type
  TPoint = object
    x, y: Integer;
    constructor Init(ax, ay: Integer);
    procedure Move(dx, dy: Integer);
    function Sum: Integer;
    function Tag: Integer; virtual;
  end;

  TPoint3D = object(TPoint)
    z: Integer;
    constructor Init(ax, ay, az: Integer);
    function Tag: Integer; override;
    function Sum3: Integer;
  end;

var
  p: TPoint;
  q: TPoint3D;
  pb: TPoint;
  hp: ^TPoint;
  hp3: ^TPoint3D;

constructor TPoint.Init(ax, ay: Integer);
begin
  x := ax;
  y := ay;
end;

procedure TPoint.Move(dx, dy: Integer);
begin
  x := x + dx;
  y := y + dy;
end;

function TPoint.Sum: Integer;
begin
  Sum := x + y;
end;

function TPoint.Tag: Integer;
begin
  Tag := 2;
end;

constructor TPoint3D.Init(ax, ay, az: Integer);
begin
  inherited Init(ax, ay);
  z := az;
end;

function TPoint3D.Tag: Integer;
begin
  Tag := 3;
end;

function TPoint3D.Sum3: Integer;
begin
  Sum3 := x + y + z;
end;

begin
  writeln('--- objects: static methods ---');
  p.Init(3, 4);
  writeln('p after Init(3,4): ', p.x, ' ', p.y, ' sum=', p.Sum);
  p.Move(10, 20);
  writeln('p after Move(10,20): ', p.x, ' ', p.y);

  writeln('--- objects: with + copy ---');
  with p do writeln('with p: ', x, ' ', y);
  q.Init(1, 2, 3);
  pb := q; // value copy carries the 3D VMT
  writeln('q=3D(1,2,3) sum3=', q.Sum3, ' tag=', q.Tag);
  writeln('pb := q  (base var holds child) tag=', pb.Tag, ' (virtual dispatch)');

  writeln('--- objects: virtual + inherited ---');
  writeln('p.Tag=', p.Tag);
  writeln('q.Tag=', q.Tag);
  // override via a base-typed copy dispatches the child
  writeln('pb.Tag after copy from 3D: ', pb.Tag);

  writeln('--- objects: New(p, Init) heap ---');
  New(hp, Init(7, 8));
  writeln('hp^ after New(7,8): ', hp^.x, ' ', hp^.y, ' sum=', hp^.Sum, ' tag=', hp^.Tag);
  New(hp3, Init(4, 5, 6));
  writeln('hp3^ after New(4,5,6): ', hp3^.x, ' ', hp3^.y, ' ', hp3^.z, ' sum3=', hp3^.Sum3);
  Dispose(hp);
  Dispose(hp3);

  writeln('--- SizeOf ---');
  writeln('SizeOf TPoint=', SizeOf(TPoint));
  writeln('SizeOf TPoint3D=', SizeOf(TPoint3D));
end.
