library var_params_demo;

// `var` parameters demo (2026-08-24): by-address semantics. A `var` param is
// the ADDRESS of the caller's storage — the callee reads and writes through
// it, so every change is visible to the caller after the call returns.
//
// Works with globals, record fields, indexed elements, pointer derefs, and
// (since the stack-frame work) LOCALS of every type — scalars, strings,
// records, arrays. Address-taken locals live in a per-call stack frame in
// linear memory (a `__frame_ptr` wasm global anchors the frames, which grow
// down from the top of memory), so they have a real address.
//
// The program body calls Run so the browser IDE (which runs the init body
// via wasmpascal_init) prints the demo; the wasm_run export keeps the CLI /
// node smoke tests working (they drive the function directly).

type
  TRec = record
    x, y: Integer;
  end;

var
  total: Integer;

procedure Swap(var a, b: Integer);   // the classic by-address example
var
  t: Integer;
begin
  t := a;
  a := b;
  b := t;
end;

procedure Shout(var s: String);      // var string param: (addr,len) pair
begin
  s := s + s;      // double it THROUGH the caller's pair
end;

procedure BumpRec(var r: TRec);      // var record param: field write-through
begin
  r.x := r.x + 1;
  r.y := r.y * 2;
end;

procedure FillArr(var a: array[0..2] of Integer); // var array param
var
  i: Integer;
begin
  for i := 0 to 2 do
    a[i] := a[i] + 10;
end;

function Run: Integer;
var
  p, q: Integer;
  s: String;
  rec: TRec;
  arr: array[0..2] of Integer;
  ptr: ^Integer;
begin
  writeln('var parameter demo');
  writeln('------------------');

  // locals passed by var: Swap writes through the frame slots
  p := 1;
  q := 2;
  Swap(p, q);
  writeln('Swap(1,2) on locals -> p=', p, ' q=', q);   // p=2 q=1
  total := p * 10 + q;                                  // 21

  // var string param: appends through the caller's (addr,len) pair
  s := 'hi';
  Shout(s);
  writeln('Shout: s="', s, '" len=', StrLen(s));       // "hihi" len=4
  total := total + StrLen(s) * 100;                     // 421

  // var record param: field write-through
  rec.x := 10;
  rec.y := 3;
  BumpRec(rec);
  writeln('BumpRec: (', rec.x, ',', rec.y, ')');       // (11, 6)
  total := total + rec.x * 1000 + rec.y;                // 11427

  // var array param: element write-through
  arr[0] := 1; arr[1] := 2; arr[2] := 3;
  FillArr(arr);
  writeln('FillArr: ', arr[0], ',', arr[1], ',', arr[2]); // 11,12,13
  total := total + arr[0] * 100 + arr[1] * 10 + arr[2];   // 12660

  // bonus: @ on a local gives its frame-slot address
  ptr := @p;
  ptr^ := ptr^ + 100;       // p: 2 -> 102
  total := total + p;       // 12762

  writeln('total=', total);
  Run := total;
end;

exports
  Run name 'wasm_run';

begin
  Run;
end.
