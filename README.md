# Product Image Edit

Batch-turn casual product photos into clean white-background shots using Google’s **Gemini** image models (Nano Banana / Nano Banana 2), then remove the lower-right Gemini sparkle watermark.

## Prerequisites

- Python **3.14+** (see `.python-version`)
- A [Gemini API key](https://aistudio.google.com/apikey) from Google AI Studio

## Setup

```bash
cd /path/to/Product_Image_Edit
uv sync
```

Set your API key using a **`.env`** file in the project root (recommended):

```bash
cp .env.example .env
# Edit .env and set GEMINI_API_KEY=... (or GOOGLE_API_KEY=...)
```

The pipeline loads `.env` automatically via `python-dotenv`. You can still use shell exports if you prefer.

## Product pipeline (edit + logo removal)

Processes every `.jpg`, `.jpeg`, `.png`, and `.webp` in a folder. Final images are written to `--output-dir` as `{original_stem}_product_clean.png`.

**Default edit prompt:**  
`Clean it up and remove customer logo for a product shot. White background only. Professional Lighting.`

```bash
uv run python gemini_product_pipeline.py /path/to/input_images --output-dir ./output
```

Useful options:

| Flag | Meaning |
|------|---------|
| `--workers N` | Parallel image jobs (threads). Default **10** is aimed at typical **Tier 1** image quotas (IPM/RPM); check [AI Studio rate limits](https://aistudio.google.com/rate-limit). Each worker gets its own HTTP connection pool. |
| `--rate-limit RPM` | Token-bucket rate limiter: cap total API calls to **RPM** requests per minute across all workers. Set this to your tier’s image-generation RPM to prevent 429 bursts (e.g. `--rate-limit 10` for Free tier). Without this flag the pipeline relies on per-worker backoff only. |
| `--max-api-retries N` | Retries after transient API errors **429** / **503** with exponential backoff and **Retry-After** when the API sends it (default: 6). |
| `--retry-backoff-base SEC` | Base delay in seconds for that backoff (default: 2). |
| `--keep-raw` | Also save watermarked API outputs under `OUTPUT_DIR/_raw/` |
| `--prompt "..."` | Override the edit instruction |
| `--model gemini-2.5-flash-image` | Use Nano Banana instead of default Nano Banana 2 (`gemini-3.1-flash-image-preview`) |
| `--fail-fast` | Stop on the first error |
| `--use-response-modalities` | If the model returns no image, retry logic with explicit TEXT+IMAGE modalities |
| `--copy-failed` | Copy failed sources under `_failed/<run>/` for a smaller retry batch |
| `--failed-log PATH` | Optional: append per-failure JSON Lines to PATH; also writes PATH’s sibling `*_paths.txt` (one relative path per failed image) |
| `--no-failed-log` | With `--failed-log`, do not write the JSONL or companion path list |
| `--retry-paths-file PATH` | Process only these paths (relative to `input_dir`); ignores `_pipeline_image_state.json` for this run |
| `--no-progress` | Disable the tqdm progress bar on stderr (on by default) |
| `--structured-events` | Write machine-readable JSON Lines events to **stdout** (for Flutter UI integration). Stderr remains human-readable. |
| `--log-dir DIR` | Write per-image log files to `DIR/<stem>.log` (used by the UI’s **View Logs** button). |

Progress is stored in **`<input_dir>/_pipeline_image_state.json`**: lists **`processed`** and **`not_processed`** (relative paths). The file is created on the first run and flushed once after all workers finish (not after every image, to reduce I/O contention). Failures leave the path pending—re-run the same command to retry only what is still listed under **`not_processed`**.

If **`--failed-log`** is set, each failed image is also appended to the JSONL with `input_dir`, `relative`, `source`, and `error`, and the companion **`_paths.txt`** lists failed paths. Stderr’s **Retry with:** command includes **`--retry-paths-file`** when those files were written. With **`--copy-failed`**, point the next run at the copied `_failed/...` folder; the suggested command preserves your flags.

## Logo removal only

Watermark removal is handled by [GeminiWatermarkTool](https://github.com/allenk/GeminiWatermarkTool) (reverse alpha-blending). Download the binary for your platform from the releases page and place it at `bin/GeminiWatermarkTool` (macOS/Linux) or `bin\GeminiWatermarkTool.exe` (Windows). The `bin/` directory is git-ignored.

The binary is discovered in this order at runtime:
1. `GWT_PATH` environment variable
2. `bin/GeminiWatermarkTool[.exe]` next to this repo
3. `GeminiWatermarkTool` on system `PATH`

If you already have Gemini-generated PNGs named `Gemini_Generated_Image_*.png` in this project folder:

```bash
uv run python remove_gemini_logo.py
```

Or import `process_image` from `remove_gemini_logo` and pass paths programmatically.

## Output layout

- **Finals:** `--output-dir` → `*_product_clean.png` (watermark removed).
- **Optional:** `--output-dir/_raw/` → `*_gemini.png` (API output before logo removal) when `--keep-raw` is set.
- **Progress / retries:** `<input_dir>/_pipeline_image_state.json` (always, unless you only use `--retry-paths-file`). Optional detailed failure logs next to **`--failed-log PATH`** if you pass that flag.

## Security (API keys)

- **Nothing in this repo embeds your API key** in the Flutter/Dart source or release **assets**. Keys exist only on disk at runtime: project `.env` (CLI / dev) or the desktop app’s **application support** `.env` after you enter or save a key in the UI.
- **Do not commit** `.env` (already in `.gitignore`). The packaged macOS script only copies the `pipeline_runner` binary into the `.app`, not any `.env`.
- **GitHub:** pushes and pull requests run [`.github/workflows/no-secrets.yml`](.github/workflows/no-secrets.yml): it rejects any tracked file matching `.env` / `.env.*` except `.env.example`, and runs **TruffleHog** (`--only-verified`) over the change range.
- The in-app **command preview** lists only pipeline arguments (paths, flags)—never environment variables or the key. Activity logs are **redacted** if a line looks like `GEMINI_API_KEY=…` / `GOOGLE_API_KEY=…`.

## Notes

- Generated images may include SynthID watermarking per Google’s policy. The visible corner sparkle is removed via [GeminiWatermarkTool](https://github.com/allenk/GeminiWatermarkTool) using reverse alpha-blending; SynthID (invisible statistical watermark) cannot be removed.
- Large batches are subject to API rate limits and per-image cost. The pipeline retries **429** / **503** responses automatically. For persistent quota errors use **`--rate-limit RPM`** to smooth out the request rate, or lower `--workers`; see your [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits).

## Flutter Desktop App (UI + Pipeline)

The repo also includes a desktop Flutter app under `flutter_app` that drives this Python pipeline:

```bash
cd flutter_app
flutter pub get
flutter run -d macos
```

Current UI capabilities:
- Pipeline settings form is editable.
- In-app **Gemini API key** field (obscured): pre-filled from your project `.env` when developing from the repo, and saved to the app’s application-support `.env` for packaged runs.
- **Input selection:** drag-and-drop a folder or image file, type a path directly, click **Browse Folder** to open a system folder picker, or click **Select Image(s)** to pick one or more individual image files. Single images and multi-file selections are staged automatically under app support so the pipeline receives a directory.
- Run Python pipeline from UI and view live processing logs.
- **Batch Dashboard** — full per-image state dashboard:
  - **Dual-stage progress bar**: purple segment for images in the Gemini API stage, teal segment for images in cleanup (logo removal). Displays active counts alongside the bar.
  - **Heartbeat monitor**: pulsing dot showing active worker count. Turns amber with a countdown timer when a `429` rate-limit backoff is in progress.
  - **Metric tiles**: live ETA (based on current throughput), images-per-minute, and success rate.
  - **Processing grid**: scrollable per-image table with 40×40 thumbnail (hover to expand), filename, Gemini stage icon (spinning sparkle → green check or red error), cleanup stage icon, per-image latency, and **View Logs** / **Retry** action buttons.
  - **Failure side panel**: slides in when any image fails; groups errors by type (Safety Filter, Rate Limit, API Error) with counts; includes Retry All, Open Output Folder, and a live workers slider.
  - **Console drawer**: collapsible log area filtered to critical events only (`RETRYING`, `429`, `Error:`, `Backoff`).
  - **Finality overlay**: on 100% completion, shows total count, elapsed time, and space saved; large **Open Output Folder** and **Start New Batch** buttons.
- **Live gallery:** the Output Review Gallery refreshes automatically every ~4 seconds while the pipeline is running, so finished images appear without a manual refresh.

For distribution packaging (single coherent app bundle):

**macOS**
```bash
./flutter_app/scripts/package_macos.sh
```
Builds a standalone Python runner and embeds it into the Flutter `.app` bundle (`Contents/Resources/backend/pipeline_runner`). Also embeds `bin/GeminiWatermarkTool` as `Contents/Resources/backend/GeminiWatermarkTool` — the binary must be present before running the script.

**Windows** (run in PowerShell on a Windows machine with Flutter + uv installed)
```powershell
powershell -ExecutionPolicy Bypass -File flutter_app\scripts\package_windows.ps1
```
Builds `pipeline_runner.exe` with PyInstaller and embeds it into the Flutter Windows release at `data\flutter_assets\backend\pipeline_runner.exe`. Also embeds `bin\GeminiWatermarkTool.exe` alongside it. The script copies Flutter source to a local NTFS temp dir before building to avoid MSBuild failures on Mac-shared drives (Parallels/VMware).

**Shipped desktop app (no Python install required):** release builds only need a `.env` with `GEMINI_API_KEY` (or `GOOGLE_API_KEY`) in the Flutter **application support** directory (the UI shows the exact path on Pipeline Settings). The Flutter host passes that directory to the runner as `PRODUCT_IMAGE_EDIT_APP_DATA`, so config and `_failed/` staging stay in one writable place.

Cross-platform status:
- `PipelineRunner` checks for bundled backend binaries on macOS, Linux, and Windows release bundles.
- Packaging scripts exist for **macOS** (`package_macos.sh`) and **Windows** (`package_windows.ps1`).
- **Development** runs (`flutter run` without an embedded runner) still use **Python 3** plus `gemini_product_pipeline.py` from the repo. On macOS, GUI apps launched from the IDE often inherit a short `PATH`—the app also probes `/usr/bin/python3` (Xcode CLT), `/opt/homebrew/bin/python3`, and `/usr/local/bin/python3`. On Windows, `python`, `py` (Python Launcher), and common uv install locations are probed automatically.
- For Linux distribution, copy `pipeline_runner` into the bundle’s `data/flutter_assets/backend/` directory (same layout Flutter uses for assets).

## Third-party licenses

This project ships [GeminiWatermarkTool](https://github.com/allenk/GeminiWatermarkTool) (© 2024 AllenK / Kwyshell) as a pre-built binary for watermark removal. It is distributed under the **MIT License** — see [`LICENSES/GeminiWatermarkTool.txt`](LICENSES/GeminiWatermarkTool.txt). Both packaging scripts copy this license file into the app bundle alongside the binary (`backend/GeminiWatermarkTool.LICENSE.txt`) to satisfy the MIT attribution requirement.

## Stitch exports for UI alignment

Stitch reference outputs are stored in top-level `stitch_exports/`:

- `stitch_exports/screenshots/` - exported screen images
- `stitch_exports/html/` - exported screen HTML source
- `stitch_exports/docs/` - exported PRD/document screens
- `stitch_exports/raw/` - raw metadata and export manifest
- `stitch_exports/design_system_tokens.json` - normalized design tokens used by Flutter theme updates
- `stitch_exports/download_errors.txt` - failed download log (should be empty when exports succeed)

Use `curl -L` when downloading hosted Stitch URLs so redirects are followed correctly:

```bash
mkdir -p stitch_exports/screenshots stitch_exports/html stitch_exports/docs stitch_exports/raw
curl -L "<SCREENSHOT_URL>" -o stitch_exports/screenshots/<name>.png
curl -L "<HTML_URL>" -o stitch_exports/html/<name>.html
```

When refreshing UI from Stitch:

1. Re-export/update files under `stitch_exports/`.
2. Compare latest screenshots/HTML against Flutter screens in `flutter_app/lib/screens/`.
3. Keep shared style parity in `flutter_app/lib/theme/design_tokens.dart` and shared widgets under `flutter_app/lib/widgets/`.
