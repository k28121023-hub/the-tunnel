#!/usr/bin/env bash
# Export the root (business, 11 words), /travel/ (20 words), and /food/
# (20 words) web builds from the same tree. The active data/word_set.json and the UI font subset
# are swapped per export, then restored so the working tree stays on the
# default business set and the full committed font.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-godot}"
FONT="assets/fonts/NotoSansTC.ttf"
WORD_SET="data/word_set.json"
WORKDIR="${TMPDIR:-/tmp}/tunnel-web-export-$$"

cleanup() {
  if [[ -f "$WORKDIR/NotoSansTC.full.ttf" ]]; then
    cp -a "$WORKDIR/NotoSansTC.full.ttf" "$FONT"
  fi
  if [[ -f "$WORKDIR/word_set.default.json" ]]; then
    cp -a "$WORKDIR/word_set.default.json" "$WORD_SET"
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

if [[ ! -x "$GODOT" ]] && ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "godot not found: $GODOT" >&2
  exit 1
fi

# Start from the committed full font, not a leftover subset from a prior run.
if [[ "$(stat -c%s "$FONT")" -lt 8000000 ]]; then
  echo "Font looks subsetted; restoring from git"
  git checkout -- "$FONT"
fi
if [[ "$(stat -c%s "$FONT")" -lt 8000000 ]]; then
  echo "Committed font is still too small to subset from" >&2
  exit 1
fi

mkdir -p "$WORKDIR"
cp -a "$FONT" "$WORKDIR/NotoSansTC.full.ttf"
cp -a tools/word_sets/business.json "$WORKDIR/word_set.default.json"

export_one() {
  local set_id="$1"
  local dest="$2"
  local share_engine="${3:-}"
  echo "=== Exporting word set: $set_id -> $dest ==="
  cp -a "tools/word_sets/${set_id}.json" "$WORD_SET"
  cp -a "$WORKDIR/NotoSansTC.full.ttf" "$FONT"
  python3 tools/subset-ui-font.py
  rm -rf "$dest"
  mkdir -p "$dest"
  "$GODOT" --headless --path "$ROOT" --editor --import --quit
  "$GODOT" --headless --path "$ROOT" --export-release Web "$dest/game.html"
  if [[ -n "$share_engine" ]]; then
    node tools/prepare-web.cjs "$dest" --share-engine="$share_engine"
    # Engine binaries live in the parent Pages directory; drop the copy.
    rm -f "$dest"/engine-*
  else
    node tools/prepare-web.cjs "$dest"
  fi
  test -f "$dest/index.html"
  test -f "$dest/sw.js"
  test -f "$dest/loading-status.js"
}

export_one business "$WORKDIR/business"
export_one travel "$WORKDIR/travel" "../"
export_one food "$WORKDIR/food" "../"

rm -rf build/web
mkdir -p build/web/travel build/web/food
cp -a "$WORKDIR/business/." build/web/
cp -a "$WORKDIR/travel/." build/web/travel/
cp -a "$WORKDIR/food/." build/web/food/
touch build/web/.nojekyll

# Subpath builds must point at the shared root engine and must not ship a second copy.
shopt -s nullglob
root_wasm=(build/web/engine-*.wasm.gz)
if [[ ${#root_wasm[@]} -lt 1 ]]; then
  echo "root engine wasm.gz missing" >&2
  exit 1
fi
root_br=(build/web/engine-*.wasm.br)
if [[ ${#root_br[@]} -lt 1 ]]; then
  echo "root engine wasm.br missing" >&2
  exit 1
fi
if ! compgen -G 'build/web/asset-*.brotli-dec.wasm.gz' >/dev/null; then
  echo "root brotli decoder wasm.gz missing" >&2
  exit 1
fi
for variant in travel food; do
  grep -q 'href="../engine-' "build/web/${variant}/index.html"
  grep -q 'src="../engine-' "build/web/${variant}/index.html"
  grep -q '../engine-[0-9a-f]*\.wasm\.br' "build/web/${variant}/index.html"
  grep -q '../asset-[0-9a-f]*\.brotli-dec\.wasm\.gz' "build/web/${variant}/index.html"
  if compgen -G "build/web/${variant}/engine-*" >/dev/null; then
    echo "${variant}/ still contains engine files; they should be shared from ../" >&2
    exit 1
  fi
  if compgen -G "build/web/${variant}/asset-*.brotli-dec.wasm.gz" >/dev/null; then
    echo "${variant}/ has its own brotli decoder; it should be shared from ../" >&2
    exit 1
  fi
done

echo "Exported root (business), /travel/ (travel), and /food/ (food) into build/web"
