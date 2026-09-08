# Growable Particle Pool

Demonstrates an efficient swap-remove dynamic object pool pattern in [WasmPascal](https://wasmpascal.com/).

Holding the mouse spawns particles that drift upward and fade out over time. Dead particles are removed in constant time using a swap-with-tail pattern, avoiding memory churn and runtime heap allocations.
