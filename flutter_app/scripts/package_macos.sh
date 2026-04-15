#!/usr/bin/env bash
set -euo pipefail

# Build a distributable macOS app bundle that includes a packaged Python runner.
#
# Steps:
#   1. uv sync (unless --skip-sync)
#   2. PyInstaller one-file pipeline_runner from pipeline_runner_entry.py
#   3. flutter build macos --release
#   4. Optional: flutter build macos --debug (--with-debug-bundle) so `flutter run` uses the same binary
#   5. Copy pipeline_runner + GeminiWatermarkTool into every .app under build/macos/Build/Products/*/
#   6. Sign and notarize the Release app
#
# Requires: uv, flutter (and Xcode toolchain for macOS desktop builds).

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/flutter_app"
DIST_DIR="$ROOT_DIR/dist"
PY_BUILD_DIR="$DIST_DIR/python-build"
RUNNER_DIST_DIR="$PY_BUILD_DIR/dist"
RUNNER_BIN="$RUNNER_DIST_DIR/pipeline_runner"
GWT_BIN="$ROOT_DIR/bin/GeminiWatermarkTool"

CODESIGN_ID="Developer ID Application: Dayu Zhang (XV6YBSV75V)"
NOTARY_PROFILE="notarytool-profile"

SKIP_SYNC=0
WITH_DEBUG=0

usage() {
  cat <<'EOF'
Usage: package_macos.sh [--skip-sync] [--with-debug-bundle] [--help]

  1. uv sync (unless --skip-sync)
  2. PyInstaller one-file pipeline_runner from pipeline_runner_entry.py
  3. flutter build macos --release
  4. Optional: flutter build macos --debug (--with-debug-bundle) so `flutter run` uses the same binary
  5. Copy pipeline_runner + GeminiWatermarkTool into every .app under build/macos/Build/Products/*/
  6. Sign and notarize the Release app

Options:
  --skip-sync          Skip uv sync when dependencies are already up to date
  --with-debug-bundle  Also build the Debug .app and embed the runner (for `flutter run -d macos`)
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-sync) SKIP_SYNC=1 ;;
    --with-debug-bundle) WITH_DEBUG=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

for cmd in uv flutter; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: ${cmd} is not in PATH" >&2
    exit 1
  fi
done

mkdir -p "$DIST_DIR"
rm -rf "$PY_BUILD_DIR"
mkdir -p "$PY_BUILD_DIR"

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
    cp "$ROOT_DIR/LICENSES/GeminiWatermarkTool.txt" "$dest_dir/GeminiWatermarkTool.LICENSE.txt"
  done
}

sign_and_notarize_app() {
  local app="$1"
  local zip="$DIST_DIR/product_image_edit_frontend.zip"

  # Sign inside-out: frameworks first, then loose executables, then the bundle.
  # Do NOT use --deep for signing — it does not reliably propagate
  # --options runtime to nested binaries in Resources/ or Frameworks/.

  echo "  Signing frameworks..."
  for framework in "$app/Contents/Frameworks/"*.framework; do
    [[ -d "$framework" ]] || continue
    codesign --force --options runtime --timestamp \
      --sign "$CODESIGN_ID" "$framework"
  done

  echo "  Signing backend binaries..."
  for bin in \
      "$app/Contents/Resources/backend/pipeline_runner" \
      "$app/Contents/Resources/backend/GeminiWatermarkTool"; do
    [[ -f "$bin" ]] || continue
    codesign --force --options runtime --timestamp \
      --sign "$CODESIGN_ID" "$bin"
  done

  echo "  Signing app bundle..."
  codesign --force --options runtime --timestamp \
    --sign "$CODESIGN_ID" "$app"

  echo "  Verifying signature..."
  codesign --verify --deep --strict --verbose=2 "$app"

  echo "  Creating zip for notarization..."
  rm -f "$zip"
  ditto -c -k --keepParent "$app" "$zip"

  echo "  Submitting for notarization (this may take a few minutes)..."
  xcrun notarytool submit "$zip" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "  Stapling notarization ticket..."
  xcrun stapler staple "$app"

  echo "  Verifying Gatekeeper acceptance..."
  spctl --assess --type exec --verbose "$app"

  rm -f "$zip"
  echo "  Done: signed + notarized."
}

echo "[1/6] Syncing Python dependencies..."
cd "$ROOT_DIR"
if [[ "$SKIP_SYNC" -eq 0 ]]; then
  uv sync
else
  echo "  Skipped (--skip-sync)"
fi

echo "[2/6] Building PyInstaller pipeline_runner..."
uv run --with pyinstaller pyinstaller \
  --onefile \
  --name pipeline_runner \
  --codesign-identity "$CODESIGN_ID" \
  --distpath "$RUNNER_DIST_DIR" \
  --workpath "$PY_BUILD_DIR/build" \
  --specpath "$PY_BUILD_DIR" \
  pipeline_runner_entry.py

echo "[3/6] Building Flutter macOS release app..."
cd "$FLUTTER_DIR"
flutter clean
flutter build macos --release

if [[ "$WITH_DEBUG" -eq 1 ]]; then
  echo "[4/6] Building Flutter macOS debug app (--with-debug-bundle)..."
  flutter build macos --debug
else
  echo "[4/6] Skipping debug build (pass --with-debug-bundle to also build debug)"
fi

echo "[5/6] Copying pipeline runner into app bundle(s)..."
embed_pipeline_runner_in_bundles

echo "[6/6] Signing and notarizing Release app..."
RELEASE_APP="$FLUTTER_DIR/build/macos/Build/Products/Release/product_image_edit_frontend.app"
if [[ -d "$RELEASE_APP" ]]; then
  sign_and_notarize_app "$RELEASE_APP"
else
  echo "  Warning: Release app not found, skipping notarization."
fi

echo
echo "Done. Packaged app(s):"
for app in "$FLUTTER_DIR"/build/macos/Build/Products/*/product_image_edit_frontend.app; do
  [[ -d "$app" ]] || continue
  echo "  $app"
  echo "    -> Contents/Resources/backend/pipeline_runner"
  echo "    -> Contents/Resources/backend/GeminiWatermarkTool"
done
