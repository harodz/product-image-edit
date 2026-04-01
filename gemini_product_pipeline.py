#!/usr/bin/env python3
"""
Batch product shots: Gemini Nano Banana image edit, then remove lower-right Gemini sparkle.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from google import genai
from google.genai import types
from PIL import Image

from remove_gemini_logo import process_image

DEFAULT_PROMPT = (
    "Clean it up and remove customer logo for a product shot. "
    "White background only. Professional Lighting."
)

DEFAULT_MODEL = "gemini-3.1-flash-image-preview"

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

_PROJECT_ROOT = Path(__file__).resolve().parent


def list_input_images(input_dir: Path) -> list[Path]:
    out: list[Path] = []
    for p in sorted(input_dir.iterdir()):
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS:
            out.append(p)
    return out


def extract_output_image(response) -> Image.Image | None:
    for part in response.parts:
        if part.inline_data is not None:
            try:
                return part.as_image()
            except Exception:
                continue
    return None


def run_one(
    client: genai.Client,
    model: str,
    prompt: str,
    source: Path,
    raw_path: Path | None,
    final_path: Path,
    use_image_config: bool,
) -> None:
    image_input = Image.open(source)
    contents: list = [prompt, image_input]
    kwargs: dict = {"model": model, "contents": contents}
    if use_image_config:
        kwargs["config"] = types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
        )
    response = client.models.generate_content(**kwargs)

    out_img = extract_output_image(response)
    if out_img is None:
        raise RuntimeError(
            "No image in API response; try again or pass --use-response-modalities"
        )

    final_path.parent.mkdir(parents=True, exist_ok=True)

    if raw_path is not None:
        raw_path.parent.mkdir(parents=True, exist_ok=True)
        out_img.save(raw_path)
        process_image(str(raw_path), str(final_path), copy_if_no_logo=True)
    else:
        temp_raw = final_path.with_name(final_path.stem + ".tmp_gemini.png")
        try:
            out_img.save(temp_raw)
            process_image(str(temp_raw), str(final_path), copy_if_no_logo=True)
        finally:
            if temp_raw.exists():
                temp_raw.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Gemini product-shot pipeline: edit images then strip Gemini corner logo.",
    )
    parser.add_argument(
        "input_dir",
        type=Path,
        help="Directory containing source images (.jpg, .jpeg, .png, .webp)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("product_output"),
        help="Directory for final cleaned images (default: ./product_output)",
    )
    parser.add_argument(
        "--prompt",
        default=DEFAULT_PROMPT,
        help="Edit instruction sent with each image",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Gemini image model (default: {DEFAULT_MODEL})",
    )
    parser.add_argument(
        "--keep-raw",
        action="store_true",
        help="Also save watermarked API outputs under OUTPUT_DIR/_raw/",
    )
    parser.add_argument(
        "--fail-fast",
        action="store_true",
        help="Stop on the first API or processing error",
    )
    parser.add_argument(
        "--use-response-modalities",
        action="store_true",
        help="Send response_modalities TEXT+IMAGE (if the model returns no image without it)",
    )

    args = parser.parse_args()

    load_dotenv(_PROJECT_ROOT / ".env")
    load_dotenv()

    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()

    if not input_dir.is_dir():
        print(f"Not a directory: {input_dir}", file=sys.stderr)
        return 1

    if not os.environ.get("GEMINI_API_KEY") and not os.environ.get("GOOGLE_API_KEY"):
        print(
            "Set GEMINI_API_KEY (or GOOGLE_API_KEY) for the Gemini API.",
            file=sys.stderr,
        )
        return 1

    images = list_input_images(input_dir)
    if not images:
        print(f"No images found in {input_dir}", file=sys.stderr)
        return 1

    client = genai.Client()
    raw_dir = output_dir / "_raw" if args.keep_raw else None
    if raw_dir:
        raw_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    failed = 0
    for src in images:
        stem = src.stem
        final_path = output_dir / f"{stem}_product_clean.png"
        raw_path = None
        if raw_dir is not None:
            raw_path = raw_dir / f"{stem}_gemini.png"

        print(f"Processing: {src.name} -> {final_path.name}")
        try:
            run_one(
                client,
                args.model,
                args.prompt,
                src,
                raw_path,
                final_path,
                args.use_response_modalities,
            )
        except Exception as e:
            failed += 1
            print(f"  Error: {e}", file=sys.stderr)
            if args.fail_fast:
                return 1

    if failed:
        print(f"Done with {failed} failure(s).", file=sys.stderr)
        return 1
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
