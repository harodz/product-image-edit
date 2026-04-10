# Agent workflow

## Goal

Turn a directory of source photos into professional white-background product images: call the Gemini image API (`gemini_product_pipeline.py`), then strip the lower-right Gemini sparkle using `remove_gemini_logo.process_image`.

## Run order

1. Install deps: `uv sync` from the repo root.
2. Ensure the API key is available: copy `.env.example` to `.env` and set `GEMINI_API_KEY` (or `GOOGLE_API_KEY`). The pipeline loads `.env` from the project root. **Never commit `.env` or paste keys into source files.**
3. Run the pipeline with an explicit output directory:

   ```bash
   uv run python gemini_product_pipeline.py <input_dir> --output-dir <output_dir>
   ```

   By default the pipeline uses **`--workers 10`** (thread pool, one `genai.Client` per thread) to overlap API latency; that default targets typical **Tier 1** image quotas—tune `--workers` and `--rate-limit RPM` using [AI Studio rate limits](https://aistudio.google.com/rate-limit). `--rate-limit` activates a token-bucket limiter across all workers to prevent synchronized 429 bursts; omit it when not needed. Transient **429** / **503** responses are retried with backoff (`--max-api-retries`, `--retry-backoff-base`). Progress is stored in **`<input_dir>/_pipeline_image_state.json`** (v2: per-image `review`, `gemini`, `cleanup`; v1 files migrate on load) and flushed once after all workers finish. The work queue includes images that are not fully done **or** whose `review` is `needsEdit` / `rejected` (re-run). **`--keep-raw`** or **`--save-gemini-png`** writes `*_gemini.png` under `OUTPUT_DIR/_raw/` in addition to `*_product_clean.png`. Optional **`--failed-log PATH`** appends JSONL plus a companion `*_paths.txt`; **`--retry-paths-file`** ignores the state file for the listed paths only.

4. For logo removal only on existing Gemini exports in-repo, use `remove_gemini_logo.py` as documented in `README.md`.

## Files to change

- **`gemini_product_pipeline.py`** — CLI, API calls, orchestration. Each worker thread uses its own `genai.Client` (via `_get_thread_client()`). `_TokenBucket` rate-limits requests globally when `--rate-limit` is set. v2 state flush updates per-image records (successes and failures). JSON Lines events (e.g. `pipeline_scan`) go to stdout when the emitter is enabled; `--log-dir` writes per-image logs.
- **`remove_gemini_logo.py`** — Logo detection/inpainting using numpy array operations (no Python pixel loops). `find_logo_mask` uses vectorized brightness thresholding; `fill_logo` uses 4-directional cumulative sweeps. `process_image` returns output file size in bytes.
- **`pyproject.toml`** — Dependencies (`google-genai`, `numpy`, `pillow`).
- **`flutter_app/lib/app/app_state.dart`** — UI state; reads/writes **`<input_dir>/_pipeline_image_state.json`** for review + persisted stages (batch list shows **runnable** images only). `ImageJobState` (mutable, keyed by basename), `GeminiStage` / `CleanupStage` / `ReviewStatus`, log/JSON event parsing, gallery refresh, `reloadRunnableJobsFromDisk()`, and `openOutputFolder()`. `PipelineRunSnapshot` exposes `imageJobs`, `is429Backoff`, `backoffSecondsRemaining`, `throughputIPM`, `eta`, `successRate`, and `spaceSavedBytes`.
- **`flutter_app/lib/screens/batch_dashboard_screen.dart`** — Full per-image dashboard; see README for feature list. Key widgets: `_GlobalStatusHeader` (progress bar + heartbeat + metric tiles), `_ProcessingGrid` (scrollable table), `_FailureSidePanel` (collapsible right panel, groups errors by type), `_CollapsibleConsole` (filtered critical events), `_FinalityOverlay` (completion modal).
- **`flutter_app/lib/widgets/folder_drop_field.dart`** — Input widget; supports folder pick, multi-image file pick, and drag-drop.
- **`flutter_app/lib/screens/`** — Screen widgets consuming `AppState.snapshot`.

Do not delete or overwrite user input images. Add new behavior with flags or new modules instead of breaking defaults.

## Constraints

- Default model is `gemini-3.1-flash-image-preview` (Nano Banana 2); `gemini-2.5-flash-image` is the older Nano Banana.
- Batch jobs consume API quota; handle errors per file unless `--fail-fast` is requested. Each worker has its own `genai.Client`; use `--rate-limit RPM` to cap the global request rate and avoid synchronized 429 bursts. Lower `--workers` if quota errors persist after retries.
- If the API returns no image part, callers can retry with `--use-response-modalities`.
- **Never** commit API keys, ship them inside the Flutter asset bundle, or persist them in `settings.json`. Keys belong only in `.env` (ignored by git) or the app’s application-support `.env` at runtime.
- GitHub Actions runs **TruffleHog** plus a check that rejects tracked `.env` / `.env.*` files (except `.env.example`); see `.github/workflows/no-secrets.yml`.

## Optional

Project-specific Cursor rules can live under `.cursor/rules/` if needed later.
