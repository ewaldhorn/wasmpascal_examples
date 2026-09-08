# Flight Leader

A sophisticated 3D wireframe vector flight combat game compiled to WebAssembly via [WasmPascal](https://wasmpascal.com/).

Demonstrates an advanced modular Pascal codebase:
- `fldefs.pas`: Vector mathematics types, 3D matrices, camera projections, and entity definitions.
- `flmath.pas`: Fast fixed/floating-point 3D trigonometry and coordinate transformations.
- `flbatch.pas`: Batched vector graphics command buffer management.
- `flfx.pas`: Particle emitters, vapor trails, and explosion simulations.
- `flsim.pas`: Flight dynamics, pitch/roll/yaw physics, and adversary targeting.
- `flrender.pas`: Conformant-array 3D polygon projection and canvas rendering.
- `flightleader.pas`: Root program, input orchestration, and combat loop.
