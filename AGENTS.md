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

4. For logo removal only on existing Gemini exports in-repo, use `remove_gemini_logo.py` as documented in `README.md`.

## Files to change

- **`gemini_product_pipeline.py`** — CLI, API calls, orchestration.
- **`remove_gemini_logo.py`** — Logo detection/inpainting; extend `process_image` only if watermark handling changes.
- **`pyproject.toml`** — Dependencies (`google-genai`, `pillow`).

Do not delete or overwrite user input images. Add new behavior with flags or new modules instead of breaking defaults.

## Constraints

- Default model is `gemini-3.1-flash-image-preview` (Nano Banana 2); `gemini-2.5-flash-image` is the older Nano Banana.
- Batch jobs consume API quota; handle errors per file unless `--fail-fast` is requested.
- If the API returns no image part, callers can retry with `--use-response-modalities`.

## Optional

Project-specific Cursor rules can live under `.cursor/rules/` if needed later.
