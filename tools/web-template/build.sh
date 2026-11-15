#!/usr/bin/env bash
# Build a Godot 4.5.1 single-thread, 2D-only web export template.
# Env:
#   GODOT_SRC   engine source (checkout of 4.5.1-stable)
#   EMSDK_DIR   emsdk root with 4.0.10 installed
#   OUTPUT_ZIP  destination zip (default: build/templates/web_nothreads_release.zip)
#   JOBS        scons -j (default: nproc, capped at 6)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_SRC="${GODOT_SRC:-}"
EMSDK_DIR="${EMSDK_DIR:-}"
OUTPUT_ZIP="${OUTPUT_ZIP:-$ROOT/build/templates/web_nothreads_release.zip}"
JOBS="${JOBS:-$(nproc)}"
if [ "$JOBS" -gt 6 ]; then JOBS=6; fi

if [ -z "$GODOT_SRC" ] || [ ! -f "$GODOT_SRC/SConstruct" ]; then
  echo "GODOT_SRC must point at a Godot 4.5.1-stable checkout" >&2
  exit 1
fi
if [ -z "$EMSDK_DIR" ] || [ ! -f "$EMSDK_DIR/emsdk_env.sh" ]; then
  echo "EMSDK_DIR must point at an emsdk install" >&2
  exit 1
fi

EMSDK_QUIET=1 source "$EMSDK_DIR/emsdk_env.sh"
emcc --version | head -1

cp "$ROOT/tools/web-template/custom.py" "$GODOT_SRC/custom.py"
# Record the flag set used for this artifact (also used as a cache key input).
mkdir -p "$(dirname "$OUTPUT_ZIP")"
(
  cd "$GODOT_SRC"
  # lto=full must be on the CLI: production=yes otherwise resets lto to auto (thin on web).
  scons -j "$JOBS" platform=web target=template_release lto=full
)

# threads=no produces godot.web.template_release.wasm32.nothreads.zip
ZIP="$(ls -1 "$GODOT_SRC"/bin/godot.web.template_release.wasm32*.zip | head -1)"
if [ ! -f "$ZIP" ]; then
  echo "Template zip not found in $GODOT_SRC/bin" >&2
  ls -la "$GODOT_SRC/bin" >&2 || true
  exit 1
fi
cp -f "$ZIP" "$OUTPUT_ZIP"
echo "Wrote $OUTPUT_ZIP ($(wc -c < "$OUTPUT_ZIP") bytes) from $ZIP"
# If the zip contains a wasm, report its size for logs.
python3 - << PY
import zipfile, os
zpath = os.environ.get("OUTPUT_ZIP") or "$OUTPUT_ZIP"
with zipfile.ZipFile(zpath) as zf:
    print("template contents:")
    for info in zf.infolist():
        print(f"  {info.filename}: {info.file_size} bytes")
PY
