# package_windows.ps1
# Build a distributable Windows release that embeds the Python pipeline runner.
#
# Embeds dist\pipeline_runner.exe into the Flutter release output at:
#   build\windows\x64\runner\Release\data\flutter_assets\backend\pipeline_runner.exe
#
# Run from repo root or from flutter_app\scripts\:
#   powershell -ExecutionPolicy Bypass -File flutter_app\scripts\package_windows.ps1

$ErrorActionPreference = 'Stop'

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT_DIR = (Resolve-Path "$SCRIPT_DIR\..\..").Path
$FLUTTER_DIR = "$ROOT_DIR\flutter_app"
$DIST_DIR = "$ROOT_DIR\dist"
$PY_BUILD_DIR = "$DIST_DIR\python-build"
$RUNNER_DIST_DIR = "$PY_BUILD_DIR\dist"
$RUNNER_BIN = "$RUNNER_DIST_DIR\pipeline_runner.exe"
$GWT_BIN = "$ROOT_DIR\bin\GeminiWatermarkTool.exe"
# $RELEASE_DIR is set after the Flutter build (may use a local temp copy — see step 2).
$RELEASE_DIR = $null

New-Item -ItemType Directory -Force -Path $DIST_DIR | Out-Null
if (Test-Path $PY_BUILD_DIR) { Remove-Item -Recurse -Force $PY_BUILD_DIR }
New-Item -ItemType Directory -Force -Path $PY_BUILD_DIR | Out-Null

# ---------------------------------------------------------------------------
# [1/4] Build Python pipeline runner
# ---------------------------------------------------------------------------
Write-Host "[1/4] Building Python pipeline runner with PyInstaller..."

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Error "uv is required. Install uv first: https://docs.astral.sh/uv/"
    exit 1
}

Push-Location $ROOT_DIR
try {
    # Redirect the uv virtualenv to a local Windows temp path.
    # The project .venv may have been created on macOS and contains Unix symlinks
    # that Windows cannot remove (os error 87 on a shared/network drive).
    $env:UV_PROJECT_ENVIRONMENT = "$env:TEMP\product_image_edit_venv_win"

    & uv run --with pyinstaller pyinstaller `
        --onefile `
        --name pipeline_runner `
        --distpath $RUNNER_DIST_DIR `
        --workpath "$PY_BUILD_DIR\build" `
        --specpath $PY_BUILD_DIR `
        pipeline_runner_entry.py
    if ($LASTEXITCODE -ne 0) { throw "PyInstaller failed (exit $LASTEXITCODE)" }
} finally {
    Remove-Item Env:\UV_PROJECT_ENVIRONMENT -ErrorAction SilentlyContinue
    Pop-Location
}

if (-not (Test-Path $RUNNER_BIN)) {
    Write-Error "PyInstaller output missing: $RUNNER_BIN"
    exit 1
}

# ---------------------------------------------------------------------------
# [2/4] Build Flutter Windows release
# ---------------------------------------------------------------------------
Write-Host "[2/4] Building Flutter Windows release..."

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter is not on PATH. Install Flutter: https://docs.flutter.dev/get-started/install/windows"
    exit 1
}

# The Mac-shared drive (C:\Mac\Home\...) is not NTFS, so MSBuild's flutter_assemble
# step fails with "Incorrect function" when writing file attributes. Directory
# junctions also cannot be created on non-NTFS volumes. The only reliable fix:
# copy the Flutter source to a local NTFS temp dir and build entirely there.
$LOCAL_FLUTTER_DIR = "$env:TEMP\product_image_edit_flutter_app"
if (Test-Path $LOCAL_FLUTTER_DIR) { Remove-Item -Recurse -Force $LOCAL_FLUTTER_DIR }

Write-Host "  Copying flutter_app source to local NTFS temp dir..."
Write-Host "  (from: $FLUTTER_DIR)"
Write-Host "  (to:   $LOCAL_FLUTTER_DIR)"
# robocopy /E = recurse including empty dirs; /XD excludes dirs; exit codes 0-7 = success.
& robocopy "$FLUTTER_DIR" "$LOCAL_FLUTTER_DIR" /E /XD build stitch_exports .dart_tool /XF .flutter-plugins .flutter-plugins-dependencies /NFL /NDL /NJH /NJS /A-:R | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed (exit $LASTEXITCODE)" }

Push-Location $LOCAL_FLUTTER_DIR
try {
    Write-Host "  Running flutter pub get..."
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed (exit $LASTEXITCODE)" }

    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed (exit $LASTEXITCODE)" }
} finally {
    Pop-Location
}

$RELEASE_DIR = "$LOCAL_FLUTTER_DIR\build\windows\x64\runner\Release"

# ---------------------------------------------------------------------------
# [3/4] Embed pipeline_runner.exe into app bundle
# ---------------------------------------------------------------------------
Write-Host "[3/4] Embedding pipeline_runner.exe into app bundle..."

if (-not (Test-Path $RELEASE_DIR)) {
    Write-Error "Flutter Windows build output not found: $RELEASE_DIR"
    exit 1
}

if (-not (Test-Path $GWT_BIN)) {
    Write-Error "GeminiWatermarkTool.exe not found: $GWT_BIN`nDownload from https://github.com/allenk/GeminiWatermarkTool/releases"
    exit 1
}

$BACKEND_DIR = "$RELEASE_DIR\data\flutter_assets\backend"
New-Item -ItemType Directory -Force -Path $BACKEND_DIR | Out-Null
Copy-Item $RUNNER_BIN "$BACKEND_DIR\pipeline_runner.exe" -Force
Copy-Item $GWT_BIN "$BACKEND_DIR\GeminiWatermarkTool.exe" -Force

Write-Host "  -> $BACKEND_DIR\pipeline_runner.exe"
Write-Host "  -> $BACKEND_DIR\GeminiWatermarkTool.exe"

# ---------------------------------------------------------------------------
# [4/4] Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] Done. Release app:"
Write-Host "  $RELEASE_DIR"
Write-Host ""
Write-Host "To run: $RELEASE_DIR\product_image_edit_frontend.exe"
