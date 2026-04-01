#!/usr/bin/env python3
"""
Blends the Gemini watermark (lower-right sparkle) into the background
by detecting bright logo pixels and replacing them with nearby background texture.
"""

import os
import glob
from PIL import Image


def find_logo_mask(img, search_w=250, search_h=250, brightness_threshold=244):
    """
    Return a set of (x, y) pixel coordinates belonging to the Gemini sparkle logo.
    The logo is a bright-white 4-point star in the lower-right corner.
    """
    w, h = img.size
    mask = set()

    # Sample background color from a quiet region (left side of the search area)
    bg_samples = []
    for y in range(h - search_h, h, 4):
        for x in range(w - search_w, w - search_w + 40, 4):
            bg_samples.append(img.getpixel((x, y)))
    if bg_samples:
        bg_brightness = sum((p[0]+p[1]+p[2])/3 for p in bg_samples) / len(bg_samples)
    else:
        bg_brightness = 235

    # Use a threshold that's notably brighter than the background
    threshold = max(brightness_threshold, bg_brightness + 8)

    for y in range(h - search_h, h):
        for x in range(w - search_w, w):
            p = img.getpixel((x, y))
            if (p[0] + p[1] + p[2]) / 3 > threshold:
                mask.add((x, y))

    return mask


def fill_logo(img, mask):
    """
    For each masked pixel, replace it with the color of the nearest
    non-masked pixel found by scanning outward in 4 directions.
    """
    if not mask:
        return img

    pixels = img.load()
    w, h = img.size

    for (x, y) in mask:
        sources = []

        # Scan up
        for dy in range(1, h):
            ny = y - dy
            if ny < 0:
                break
            if (x, ny) not in mask:
                sources.append(pixels[x, ny])
                break

        # Scan down
        for dy in range(1, h):
            ny = y + dy
            if ny >= h:
                break
            if (x, ny) not in mask:
                sources.append(pixels[x, ny])
                break

        # Scan left
        for dx in range(1, w):
            nx = x - dx
            if nx < 0:
                break
            if (nx, y) not in mask:
                sources.append(pixels[nx, y])
                break

        # Scan right
        for dx in range(1, w):
            nx = x + dx
            if nx >= w:
                break
            if (nx, y) not in mask:
                sources.append(pixels[nx, y])
                break

        if sources:
            n = len(sources)
            nc = len(sources[0])
            pixels[x, y] = tuple(int(sum(s[c] for s in sources) / n) for c in range(nc))

    return img


def process_image(image_path, output_path=None, copy_if_no_logo=False):
    """
    copy_if_no_logo: if no sparkle mask is found, still write output_path
    by copying the input image (used by batch pipelines so every item gets an output).
    """
    img = Image.open(image_path).convert("RGBA")
    w, h = img.size

    mask = find_logo_mask(img)
    if not mask:
        if copy_if_no_logo and output_path is not None:
            img.save(output_path)
            print(f"  No logo found — saved copy -> {os.path.basename(output_path)}")
        else:
            print(f"  No logo found — skipping.")
        return

    xs = [p[0] for p in mask]
    ys = [p[1] for p in mask]
    print(f"  Logo mask: {len(mask)} pixels, "
          f"bbox ({min(xs)},{min(ys)})-({max(xs)},{max(ys)})")

    fill_logo(img, mask)

    if output_path is None:
        base, ext = os.path.splitext(image_path)
        output_path = base + "_no_logo" + ext

    img.save(output_path)
    print(f"  Saved -> {os.path.basename(output_path)}")


if __name__ == "__main__":
    folder = os.path.dirname(os.path.abspath(__file__))
    # Only process originals, not previously generated outputs
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
