#!/usr/bin/env python3
"""
Blends the Gemini watermark (lower-right sparkle) into the background
by detecting bright logo pixels and replacing them with nearby background texture.
"""

import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


def _corner_mean_rgb(arr, k=24):
    """
    Mean RGB from k×k patches at the four image corners. For catalog shots with
    white margins, this is a neutral fill target (unlike the left strip inside
    the lower-right search box, which often overlaps the product).
    """
    h, w = arr.shape[:2]
    kk = min(max(2, k), h // 3, w // 3, 48)
    c = np.concatenate(
        [
            arr[:kk, :kk, :3].reshape(-1, 3),
            arr[:kk, w - kk : w, :3].reshape(-1, 3),
            arr[h - kk : h, :kk, :3].reshape(-1, 3),
            arr[h - kk : h, w - kk : w, :3].reshape(-1, 3),
        ],
        axis=0,
    ).astype(np.float32)
    return c.mean(axis=0)


def _estimate_background_mean_rgb(
    arr, search_w=250, search_h=250
):
    """
    Mean RGB from a subsampled strip on the left of the lower-right search box
    (same geometry as logo detection). Used only for adaptive logo brightness
    thresholding (not for inpaint color — that uses `_corner_mean_rgb`).
    """
    h, w = arr.shape[:2]
    y0 = max(0, h - search_h)
    x0 = max(0, w - search_w)
    region = arr[y0:h, x0:w, :3].astype(np.float32)
    bg_strip = region[:, :40:4, :]
    bg_strip_s = bg_strip[::4, :, :]
    if bg_strip_s.size > 0:
        mean_rgb = bg_strip_s.mean(axis=(0, 1)).astype(np.float32)
    else:
        mean_rgb = np.array([235.0, 235.0, 235.0], dtype=np.float32)
    return mean_rgb


def find_logo_mask(arr, search_w=250, search_h=250, brightness_threshold=244):
    """
    Return a boolean mask array (h x w) where True = Gemini sparkle logo pixel.
    arr: numpy RGBA array (h, w, 4), dtype uint8.
    """
    h, w = arr.shape[:2]
    y0 = max(0, h - search_h)
    x0 = max(0, w - search_w)

    region = arr[y0:h, x0:w, :3].astype(np.float32)  # RGB only

    mean_rgb = _estimate_background_mean_rgb(arr, search_w, search_h)
    bg_brightness = float(mean_rgb.mean())

    threshold = max(float(brightness_threshold), bg_brightness + 8)

    brightness = region.mean(axis=2)        # (search_h, search_w)
    region_mask = brightness > threshold    # bool array in the search region

    full_mask = np.zeros((h, w), dtype=bool)
    full_mask[y0:h, x0:w] = region_mask
    return full_mask


def find_streak_halo_mask(
    arr,
    logo_mask,
    search_w=250,
    search_h=250,
    *,
    dilate_kernel=41,
):
    """
    Pixels just outside the bright logo mask can still be green-tinted smear
    (mean luminance ~240–244, below the 244 logo threshold). They are not
    repaired if we only fill `logo_mask`. This halo is: inside the search
    region, within a dilated envelope of the logo, matching near-white + green
    cast + low chroma (unlike saturated product colors).
    """
    h, w = arr.shape[:2]
    y0 = max(0, h - search_h)
    x0 = max(0, w - search_w)
    search_region = np.zeros((h, w), dtype=bool)
    search_region[y0:h, x0:w] = True

    pil_m = Image.fromarray((logo_mask.astype(np.uint8) * 255))
    dilated = np.asarray(pil_m.filter(ImageFilter.MaxFilter(int(dilate_kernel)))) > 127

    rgb = arr[..., :3].astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mu = (r + g + b) / 3.0
    chroma = np.maximum.reduce([r, g, b]) - np.minimum.reduce([r, g, b])
    streak_like = (
        (mu > 237)
        & (mu < 253)
        & ((g - r) >= 2)
        & ((g - b) >= 2)
        & (chroma <= 30)
    )
    return dilated & (~logo_mask) & streak_like & search_region


def fill_logo(
    arr,
    mask,
    *,
    bg_mean_rgb=None,
    min_fill_brightness=None,
    search_w=250,
    search_h=250,
):
    """
    Replace each masked pixel with the average of the nearest non-masked
    pixel found by scanning outward in 4 directions (up, down, left, right).
    Only directions whose sample is background-like (high luminance) are used,
    so product-colored edge pixels are not smeared into white padding (streaks).
    Operates in-place on arr (h, w, 4) uint8.
    """
    if not mask.any():
        return

    if bg_mean_rgb is None:
        bg_mean_rgb = _corner_mean_rgb(arr)
    bg_mean_rgb = np.asarray(bg_mean_rgb, dtype=np.float32).reshape(3)
    if min_fill_brightness is None:
        min_fill_brightness = max(220.0, float(bg_mean_rgb.mean()) - 10.0)

    h, w = arr.shape[:2]

    # For each direction, build a lookup: for every column/row the index of the
    # first non-masked pixel scanning from the masked pixel outward.
    # This is done with cumsum tricks per row/column so we avoid Python loops
    # over the search region.

    # Precompute "nearest non-masked above" for each pixel using a running scan
    # along columns (top-to-bottom).  We store the last seen non-masked row index.
    # Similarly for below, left, right.

    fill = arr.astype(np.float32)
    nmask = ~mask   # True where pixel is usable (not logo)

    # ---- up: for each (y, x), find the nearest y' < y where nmask[y', x] ----
    # We scan column by column but that's still O(h*w) in numpy, fast enough.
    # Build a "last good row index" array by scanning top→bottom.
    last_good_row = np.full((w,), -1, dtype=np.int32)
    last_good_color = np.zeros((w, 4), dtype=np.float32)
    up_color = np.zeros((h, w, 4), dtype=np.float32)
    up_valid = np.zeros((h, w), dtype=bool)
    for y in range(h):
        good = nmask[y]                       # (w,) bool
        last_good_color[good] = fill[y, good]  # update usable pixels
        last_good_row[good] = y
        valid = last_good_row >= 0
        up_valid[y] = valid
        up_color[y] = last_good_color         # broadcast per column

    # ---- down: scan bottom→top ----
    last_good_row[:] = -1
    last_good_color[:] = 0
    down_color = np.zeros((h, w, 4), dtype=np.float32)
    down_valid = np.zeros((h, w), dtype=bool)
    for y in range(h - 1, -1, -1):
        good = nmask[y]
        last_good_color[good] = fill[y, good]
        last_good_row[good] = y
        valid = last_good_row >= 0
        down_valid[y] = valid
        down_color[y] = last_good_color

    # ---- left: scan left→right along each row ----
    last_good_col = np.full((h,), -1, dtype=np.int32)
    last_good_color_row = np.zeros((h, 4), dtype=np.float32)
    left_color = np.zeros((h, w, 4), dtype=np.float32)
    left_valid = np.zeros((h, w), dtype=bool)
    for x in range(w):
        good = nmask[:, x]                         # (h,) bool
        last_good_color_row[good] = fill[good, x]
        last_good_col[good] = x
        valid = last_good_col >= 0
        left_valid[:, x] = valid
        left_color[:, x] = last_good_color_row

    # ---- right: scan right→left along each row ----
    last_good_col[:] = -1
    last_good_color_row[:] = 0
    right_color = np.zeros((h, w, 4), dtype=np.float32)
    right_valid = np.zeros((h, w), dtype=bool)
    for x in range(w - 1, -1, -1):
        good = nmask[:, x]
        last_good_color_row[good] = fill[good, x]
        last_good_col[good] = x
        valid = last_good_col >= 0
        right_valid[:, x] = valid
        right_color[:, x] = last_good_color_row

    # ---- average the valid directions for each masked pixel ----
    # Stack valid flags and colors: shape (4, h, w) and (4, h, w, 4)
    valid_stack = np.stack(
        [up_valid, down_valid, left_valid, right_valid], axis=0
    ).astype(np.float32)   # (4, h, w)
    color_stack = np.stack(
        [up_color, down_color, left_color, right_color], axis=0
    )                      # (4, h, w, 4)

    # Drop sweep hits that are chromatic / product-colored (prevents green streaks).
    dir_brightness = color_stack[..., :3].mean(axis=-1)
    valid_stack = valid_stack * (dir_brightness >= min_fill_brightness)

    # Only average over valid directions
    n_valid = valid_stack.sum(axis=0)                         # (h, w)
    n_valid_safe = np.where(n_valid > 0, n_valid, 1.0)        # avoid /0
    blended = (color_stack * valid_stack[..., None]).sum(axis=0) / n_valid_safe[..., None]
    # (h, w, 4)

    no_valid = (n_valid == 0) & mask
    if no_valid.any():
        fallback = np.concatenate([bg_mean_rgb, np.array([255.0], dtype=np.float32)])
        blended[no_valid] = fallback

    arr[mask] = np.clip(blended[mask], 0, 255).astype(np.uint8)


def process_image(image_path, output_path=None, copy_if_no_logo=False) -> int:
    """
    copy_if_no_logo: if no sparkle mask is found, still write output_path
    by copying the input image (used by batch pipelines so every item gets an output).

    Returns the size in bytes of the written output file, or 0 if nothing was written.
    """
    img = Image.open(image_path).convert("RGBA")
    arr = np.asarray(img, dtype=np.uint8).copy()

    mask = find_logo_mask(arr)
    if not mask.any():
        if copy_if_no_logo and output_path is not None:
            img.save(output_path)
            print(f"  No logo found — saved copy -> {os.path.basename(output_path)}")
            return Path(output_path).stat().st_size
        else:
            print(f"  No logo found — skipping.")
            return 0

    ys, xs = np.where(mask)
    print(f"  Logo mask: {mask.sum()} pixels, "
          f"bbox ({xs.min()},{ys.min()})-({xs.max()},{ys.max()})")

    halo = find_streak_halo_mask(arr, mask)
    repair = mask | halo
    if halo.any():
        print(f"  Streak halo: +{halo.sum()} pixels (sub-threshold smear near logo)")

    fill_logo(arr, repair)

    if output_path is None:
        base, ext = os.path.splitext(image_path)
        output_path = base + "_no_logo" + ext

    Image.fromarray(arr, "RGBA").save(output_path)
    print(f"  Saved -> {os.path.basename(output_path)}")
    return Path(output_path).stat().st_size


if __name__ == "__main__":
    import glob
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
