#!/usr/bin/env python3
"""
Removes the Gemini watermark using GeminiWatermarkTool (reverse alpha-blending).
https://github.com/allenk/GeminiWatermarkTool

Binary discovery order:
  1. GWT_PATH environment variable
  2. bin/GeminiWatermarkTool[.exe] relative to this file
  3. GeminiWatermarkTool on system PATH
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path


def _find_binary() -> Path:
    exe_name = "GeminiWatermarkTool.exe" if sys.platform == "win32" else "GeminiWatermarkTool"

    # 1. Explicit env var
    env_path = os.environ.get("GWT_PATH")
    if env_path:
        p = Path(env_path)
        if p.is_file():
            return p
        raise RuntimeError(f"GWT_PATH={env_path!r} does not point to a file")

    # 2. Next to sys.executable — works when frozen by PyInstaller (backend/ dir)
    next_to_exe = Path(sys.executable).parent / exe_name
    if next_to_exe.is_file():
        return next_to_exe

    # 3. bin/ next to this script — dev/source checkout layout
    local = Path(__file__).parent / "bin" / exe_name
    if local.is_file():
        return local

    # 4. System PATH
    found = shutil.which(exe_name)
    if found:
        return Path(found)

    raise RuntimeError(
        "GeminiWatermarkTool binary not found. "
        "Place it at bin/GeminiWatermarkTool, set GWT_PATH, or add it to PATH.\n"
        "Download: https://github.com/allenk/GeminiWatermarkTool/releases"
    )


def process_image(image_path, output_path=None, copy_if_no_logo=False) -> int:
    """
    Remove the Gemini watermark from image_path using GeminiWatermarkTool.

    copy_if_no_logo: if no watermark is detected, still write output_path
    by copying the input image (used by batch pipelines so every item gets an output).

    Returns the size in bytes of the written output file, or 0 if nothing was written.
    """
    src = Path(image_path)
    if output_path is None:
        output_path = src.parent / (src.stem + "_no_logo" + src.suffix)
    dst = Path(output_path)

    binary = _find_binary()
    try:
        result = subprocess.run(
            [str(binary), "-i", str(src), "-o", str(dst)],
            capture_output=True,
            text=True,
            timeout=120,
        )
    except subprocess.TimeoutExpired:
        print(f"  GWT timed out after 120s", file=sys.stderr)
        if copy_if_no_logo:
            shutil.copy2(str(src), str(dst))
            print(f"  GWT timeout — saved copy -> {dst.name}", file=sys.stderr)
            return dst.stat().st_size
        return 0

    if result.returncode == 0 and dst.exists():
        print(f"  Watermark removed -> {dst.name}", file=sys.stderr)
        return dst.stat().st_size

    # Watermark not detected or tool error
    if result.returncode != 0:
        msg = f"  GWT exit {result.returncode}"
        if result.stderr:
            msg += f": {result.stderr.strip()}"
        print(msg, file=sys.stderr)
    elif result.stderr:
        print(f"  GWT: {result.stderr.strip()}", file=sys.stderr)
    if copy_if_no_logo:
        shutil.copy2(str(src), str(dst))
        print(f"  No watermark detected — saved copy -> {dst.name}", file=sys.stderr)
        return dst.stat().st_size

    print(f"  No watermark detected — skipping.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    import glob
    folder = os.path.dirname(os.path.abspath(__file__))
    images = [
        p for p in glob.glob(os.path.join(folder, "Gemini_Generated_Image_*.png"))
        if "_no_logo" not in os.path.basename(p)
    ]

    if not images:
        print("No Gemini_Generated_Image_*.png files found.")
    else:
        for path in sorted(images):
            print(f"Processing: {os.path.basename(path)}")
            process_image(path)
