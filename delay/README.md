# Delay Demo

Demonstrates non-blocking execution pauses using `Delay(ms)` in [WasmPascal](https://wasmpascal.com/).

Because console Pascal programs run inside a dedicated Web Worker thread, calling `Delay` safely blocks the worker without freezing the browser's UI or animation frames.
