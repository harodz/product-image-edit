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
uv run python gemini_product_pipeline.py /path/to/input_images --output-dir ./product_output
```

Useful options:

| Flag | Meaning |
|------|---------|
| `--keep-raw` | Also save watermarked API outputs under `OUTPUT_DIR/_raw/` |
| `--prompt "..."` | Override the edit instruction |
| `--model gemini-2.5-flash-image` | Use Nano Banana instead of default Nano Banana 2 (`gemini-3.1-flash-image-preview`) |
| `--fail-fast` | Stop on the first error |
| `--use-response-modalities` | If the model returns no image, retry logic with explicit TEXT+IMAGE modalities |

## Logo removal only

If you already have Gemini-generated PNGs named `Gemini_Generated_Image_*.png` in this project folder:

```bash
uv run python remove_gemini_logo.py
```

Or import `process_image` from `remove_gemini_logo` and pass paths programmatically.

## Output layout

- **Finals:** `--output-dir` → `*_product_clean.png` (watermark removed).
- **Optional:** `--output-dir/_raw/` → `*_gemini.png` (API output before logo removal) when `--keep-raw` is set.

## Notes

- Generated images may include SynthID watermarking per Google’s policy; this tool only removes the visible corner sparkle when it matches the expected bright region.
- Large batches are subject to API rate limits and per-image cost.
