# Flutter Frontend (Stitch-Based)

This folder contains a desktop-first Flutter UI implementation based on Stitch project `1862088916126695377`.

## Included

- High-fidelity screens:
  - Pipeline Settings
  - Batch Processing Dashboard
  - Output Review Gallery
- Tokenized dark theme based on the `Obsidian Flux` design system asset
- Downloaded Stitch references under `stitch_exports/`

## Stitch Export Refresh

```bash
./stitch_exports/fetch_stitch_exports.sh
```

## Run

```bash
flutter pub get
flutter run -d macos
```

## What Works Now

- Editable pipeline settings (input/output folders, workers, retries, model, prompt).
- Drag a folder onto **Input Directory** to set the source folder.
- Click **Run Pipeline** to execute the real Python pipeline and stream logs into the dashboard.
- **Preview Command** shows the exact command line generated from current settings.

## Requirements For Running Pipeline From UI

- Python + project dependencies installed in the repo root (`uv sync`).
- A repo-root `.env` with `GEMINI_API_KEY` or `GOOGLE_API_KEY`.
- The UI resolves and runs `../gemini_product_pipeline.py` during local development.

## Package For macOS Distribution

This project includes a packaging helper script that bundles Flutter UI + Python pipeline runner:

```bash
cd /path/to/Product_Image_Edit
chmod +x flutter_app/scripts/package_macos.sh
./flutter_app/scripts/package_macos.sh
```

The script:
- Builds a standalone `pipeline_runner` binary via PyInstaller.
- Builds Flutter macOS release app.
- Copies the Python runner into:
  - `product_image_edit_frontend.app/Contents/Resources/backend/pipeline_runner`

At runtime, the app prefers this bundled runner; if not found, it falls back to local dev execution with `python3 gemini_product_pipeline.py`.

## Known Packaging Prereqs

- Xcode command line tools and macOS build toolchain installed.
- CocoaPods installed for macOS Flutter plugins.
