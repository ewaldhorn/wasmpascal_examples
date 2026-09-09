library adder;

{ ------------------------------------------------------------------ }
{ adder.pas is a minimal WasmPascal library example.                 }
{                                                                    }
{ Exports a single function, Add, that takes two Integer arguments   }
{ and returns their sum as an Integer.                               }
{                                                                    }
{ Compile at https://wasmpascal.com/ → Run → Export → Save as        }
{ adder.wasm, then load with the companion index.html.               }
{ ------------------------------------------------------------------ }

{ Add two integers and return the result. }
function Add(a, b: Integer): Integer;
begin
  Add := a + b;
end;

{ The exports clause writes named entries into the WASM export table.  }
{ Without this, Add exists in the binary but is invisible to the host. }
{ Notice you can specify the name if you like, by default, it exports  }
{ the Add function as ADD.                                             }
exports
  Add name 'Add';

begin
  { Library initialisation block. Nothing to do here. }
end.
