#!/usr/bin/env bash
set -euo pipefail

# Build a distributable macOS app bundle that includes a packaged Python runner.
#
# Embeds dist/pipeline_runner into every built app under:
#   build/macos/Build/Products/{Debug,Profile,Release}/product_image_edit_frontend.app/Contents/Resources/backend/
# so both `flutter run -d macos` (Debug) and release builds use the same fresh binary.
#
# Optional: WITH_DEBUG=1 also runs `flutter build macos --debug` so the Debug bundle exists and gets the runner.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/flutter_app"
DIST_DIR="$ROOT_DIR/dist"
PY_BUILD_DIR="$DIST_DIR/python-build"
RUNNER_DIST_DIR="$PY_BUILD_DIR/dist"
RUNNER_BIN="$RUNNER_DIST_DIR/pipeline_runner"

mkdir -p "$DIST_DIR"
rm -rf "$PY_BUILD_DIR"
mkdir -p "$PY_BUILD_DIR"

GWT_BIN="$ROOT_DIR/bin/GeminiWatermarkTool"

embed_pipeline_runner_in_bundles() {
  if [[ ! -f "$RUNNER_BIN" ]]; then
    echo "error: PyInstaller output missing: $RUNNER_BIN" >&2
    exit 1
  fi
  if [[ ! -f "$GWT_BIN" ]]; then
    echo "error: GeminiWatermarkTool binary missing: $GWT_BIN" >&2
    echo "       Download from https://github.com/allenk/GeminiWatermarkTool/releases" >&2
    exit 1
  fi
  shopt -s nullglob
  local apps=("$FLUTTER_DIR"/build/macos/Build/Products/*/product_image_edit_frontend.app)
  shopt -u nullglob
  if [[ ${#apps[@]} -eq 0 ]]; then
    echo "error: no product_image_edit_frontend.app under build/macos/Build/Products (flutter build failed?)" >&2
    exit 1
  fi
  for app in "${apps[@]}"; do
    local dest_dir="$app/Contents/Resources/backend"
    echo "Embedding pipeline_runner -> $dest_dir/"
    mkdir -p "$dest_dir"
    cp "$RUNNER_BIN" "$dest_dir/pipeline_runner"
    chmod +x "$dest_dir/pipeline_runner"
    cp "$GWT_BIN" "$dest_dir/GeminiWatermarkTool"
    chmod +x "$dest_dir/GeminiWatermarkTool"
  done
}

echo "[1/4] Ensuring Python packager exists..."
if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required. Install uv first."
  exit 1
fi

cd "$ROOT_DIR"
uv run --with pyinstaller pyinstaller \
  --onefile \
  --name pipeline_runner \
  --distpath "$RUNNER_DIST_DIR" \
  --workpath "$PY_BUILD_DIR/build" \
  --specpath "$PY_BUILD_DIR" \
  pipeline_runner_entry.py

echo "[2/4] Building Flutter macOS release app..."
cd "$FLUTTER_DIR"
flutter clean
flutter build macos --release

if [[ "${WITH_DEBUG:-0}" == "1" ]]; then
  echo "[3/4] Building Flutter macOS debug app (WITH_DEBUG=1)..."
  flutter build macos --debug
else
  echo "[3/4] Skipping debug build (set WITH_DEBUG=1 to embed runner for flutter run)"
fi

echo "[4/4] Copying pipeline runner into app bundle(s)..."
embed_pipeline_runner_in_bundles

echo
echo "Packaged app(s) updated with recompiled pipeline_runner:"
for app in "$FLUTTER_DIR"/build/macos/Build/Products/*/product_image_edit_frontend.app; do
  [[ -d "$app" ]] || continue
  echo "  $app"
  echo "    -> Contents/Resources/backend/pipeline_runner"
done
