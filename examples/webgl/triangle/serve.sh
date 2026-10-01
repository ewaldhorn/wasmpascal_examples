#!/bin/sh
# Build, then serve the staged site in dist/.
#
#   ./serve.sh        then open http://localhost:8080/
#
# A .wasm file cannot be fetched over file://, so the page needs a real HTTP
# server; python3's is the one that needs no installing.
set -e
cd "$(dirname "$0")"

./build.sh
echo "serving dist/ on http://localhost:8080/  (Ctrl-C to stop)"
exec python3 -m http.server 8080 --directory dist
