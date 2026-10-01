#!/bin/sh
# Build triangle.wasm and stage a self-contained site in dist/.
#
#   1. compile triangle.pas  -> dist/triangle.wasm  (via the repo's CLI compiler)
#   2. copy the runtime files (index.html, host.js) into dist/
#
# dist/ is wiped and restaged only AFTER a successful compile, so a typo cannot
# destroy the last good build.
#
#   ./build.sh     compile and stage
#   ./serve.sh     build, then serve dist/ on http://localhost:8080/
#
# Override the compiler path with WPCOMPILE if this folder has been copied
# somewhere else:
#
#   WPCOMPILE=/path/to/wpcompile.mjs ./build.sh
set -e
cd "$(dirname "$0")"

WPCOMPILE="${WPCOMPILE:-../../../tools/wpcompile.mjs}"
DIST=dist

if [ ! -f "$WPCOMPILE" ]; then
  echo "build: no compiler at $WPCOMPILE" >&2
  echo "build: set WPCOMPILE to the repo's tools/wpcompile.mjs" >&2
  exit 1
fi

# Compile to a temporary file first: a failed compile leaves dist/ untouched.
TMPWASM="$(mktemp -t triangle_build).wasm"
trap 'rm -f "$TMPWASM"' EXIT

node "$WPCOMPILE" triangle.pas -o "$TMPWASM"

rm -rf "$DIST"
mkdir -p "$DIST"
mv "$TMPWASM" "$DIST/triangle.wasm"
trap - EXIT

cp index.html host.js "$DIST/"

echo "build: staged $DIST/ ($(wc -c < "$DIST/triangle.wasm" | tr -d ' ') B wasm)"
echo "build: run ./serve.sh and open http://localhost:8080/"
