#!/usr/bin/env bash
set -euo pipefail

# Refresh Python deps, rebuild the PyInstaller pipeline_runner, and produce a
# Flutter macOS release .app with the runner embedded (see flutter_app/scripts/package_macos.sh).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKIP_SYNC=0
WITH_DEBUG=0

usage() {
  cat <<'EOF'
Usage: build_python_and_flutter.sh [--skip-sync] [--with-debug-bundle] [--help]

  1. uv sync (unless --skip-sync)
  2. PyInstaller one-file pipeline_runner from pipeline_runner_entry.py
  3. flutter build macos --release
  4. Optional: flutter build macos --debug (--with-debug-bundle) so `flutter run` uses the same binary
  5. Copy pipeline_runner into every .app under build/macos/Build/Products/*/

Options:
  --skip-sync          Skip uv sync when dependencies are already up to date
  --with-debug-bundle  Also build the Debug .app and embed the runner (for `flutter run -d macos`)
  -h, --help           Show this help

Requires: uv, flutter (and Xcode toolchain for macOS desktop builds).
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

cd "$ROOT"

for cmd in uv flutter; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: ${cmd} is not in PATH" >&2
    exit 1
  fi
done

if [[ "$SKIP_SYNC" -eq 0 ]]; then
  echo "==> uv sync"
  uv sync
fi

echo "==> PyInstaller runner + Flutter macOS build(s) + embed"
export WITH_DEBUG
bash "$ROOT/flutter_app/scripts/package_macos.sh"
