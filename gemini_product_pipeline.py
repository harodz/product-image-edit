#!/usr/bin/env python3
"""
Batch product shots: Gemini Nano Banana image edit, then remove lower-right Gemini sparkle.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import shlex
import shutil
import ssl
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from dotenv import load_dotenv
from google import genai
from tqdm import tqdm
from google.genai import types
from google.genai.errors import APIError
from PIL import Image

from remove_gemini_logo import process_image

DEFAULT_PROMPT = (
    "Clean it up and remove customer logo for a product shot. "
    "White background only. Professional Lighting."
)

DEFAULT_MODEL = "gemini-3.1-flash-image-preview"

# Tier-1-oriented default; see https://ai.google.dev/gemini-api/docs/rate-limits
DEFAULT_WORKERS = 10

DEFAULT_MAX_API_RETRIES = 6

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

# Per-input-dir progress: which images succeeded vs still pending (failures stay pending).
STATE_FILENAME = "_pipeline_image_state.json"

_REPO_ROOT = Path(__file__).resolve().parent


class _ThreadLocalClients(threading.local):
    """Per-thread genai.Client so each worker has its own connection pool."""
    client: "genai.Client | None" = None


_tl_clients = _ThreadLocalClients()


def _get_thread_client() -> "genai.Client":
    if _tl_clients.client is None:
        # 120 s per-request timeout: image generation p99 is ~60-90 s;
        # this prevents hung workers while still covering tail latency.
        # TimeoutErrors are caught as retryable transport errors upstream.
        _tl_clients.client = genai.Client(
            http_options=types.HttpOptions(timeout=120_000),
        )
    return _tl_clients.client


class _TokenBucket:
    """
    Simple token-bucket rate limiter.
    Blocks the calling thread until a token is available.

    capacity  – maximum burst size (tokens)
    rate      – tokens refilled per second (e.g. 10/60 ≈ 0.167 for 10 RPM)
    """

    def __init__(self, capacity: float, rate: float) -> None:
        self._capacity = capacity
        self._rate = rate
        self._tokens = float(capacity)
        self._last_refill = time.monotonic()
        self._lock = threading.Lock()

    def acquire(self) -> None:
        while True:
            with self._lock:
                now = time.monotonic()
                elapsed = now - self._last_refill
                self._tokens = min(
                    self._capacity,
                    self._tokens + elapsed * self._rate,
                )
                self._last_refill = now
                if self._tokens >= 1.0:
                    self._tokens -= 1.0
                    return
                # How long until the next token arrives
                wait = (1.0 - self._tokens) / self._rate
            time.sleep(wait)


class EventEmitter:
    """Thread-safe JSON Lines emitter to stdout. No-ops when not enabled."""

    def __init__(self, enabled: bool, lock: threading.Lock) -> None:
        self._enabled = enabled
        self._lock = lock

    def emit(self, obj: dict) -> None:
        if not self._enabled:
            return
        line = json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n"
        with self._lock:
            try:
                sys.stdout.write(line)
                sys.stdout.flush()
            except OSError:
                pass


def _frozen_base_dir() -> Path | None:
    if getattr(sys, "frozen", False):
        meipass = getattr(sys, "_MEIPASS", None)
        if meipass:
            return Path(meipass)
    return None


def _default_app_data_dir() -> Path:
    """Writable per-user directory (matches Flutter path_provider application support intent)."""
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/com.example.productImageEditFrontend"
    if sys.platform == "win32":
        base = os.environ.get("APPDATA", str(Path.home()))
        return Path(base) / "com.example.productImageEditFrontend"
    xdg = os.environ.get("XDG_DATA_HOME")
    if xdg:
        return Path(xdg) / "com.example.productImageEditFrontend"
    return Path.home() / ".local/share/com.example.productImageEditFrontend"


def _app_data_dir() -> Path:
    """Directory for .env, _failed staging, etc. Set PRODUCT_IMAGE_EDIT_APP_DATA from the Flutter host."""
    env = os.environ.get("PRODUCT_IMAGE_EDIT_APP_DATA")
    if env:
        return Path(env)
    # Frozen onefile binary run without the Flutter shell (unusual): use a stable user dir.
    if _FROZEN_BASE is not None:
        return _default_app_data_dir()
    # Normal `uv run python ...` from the repo: keep artifacts beside the project.
    return _REPO_ROOT


_FROZEN_BASE = _frozen_base_dir()
_APP_DATA_ROOT = _app_data_dir()
_FAILED_ROOT = _APP_DATA_ROOT / "_failed"


def _input_is_under_failed_tree(input_dir: Path) -> bool:
    inp = input_dir.resolve()
    root = _FAILED_ROOT.resolve()
    return inp == root or root in inp.parents


def _failed_dir_for_run(input_dir: Path) -> Path:
    """Isolated staging per invocation when not already retrying from under _failed/."""
    if _input_is_under_failed_tree(input_dir):
        return input_dir.resolve()
    stamp_ms = int(time.time() * 1000)
    return _FAILED_ROOT / f"{stamp_ms}_{os.getpid()}"


def iter_input_images(input_dir: Path) -> list[tuple[Path, Path]]:
    """Walk input_dir recursively. Return (absolute path, path relative to input_dir)."""
    root = input_dir.resolve()
    out: list[tuple[Path, Path]] = []
    for p in sorted(root.rglob("*")):
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS:
            out.append((p, p.relative_to(root)))
    return out


def load_retry_paths_list(path: Path) -> list[Path]:
    """Load relative paths from a *_paths.txt (one per line; # comments; blanks skipped; deduped)."""
    text = path.read_text(encoding="utf-8")
    seen: set[str] = set()
    out: list[Path] = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key = line.replace("\\", "/")
        if key in seen:
            continue
        seen.add(key)
        out.append(Path(key))
    return out


def _rel_key(rel: Path) -> str:
    return rel.as_posix()


def state_file_path(input_dir: Path) -> Path:
    return input_dir.resolve() / STATE_FILENAME


def atomic_write_json(path: Path, obj: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(obj, ensure_ascii=False, indent=2) + "\n"
    fd, tmp = tempfile.mkstemp(
        suffix=".tmp",
        prefix=path.name + ".",
        dir=path.parent,
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(payload)
        os.replace(tmp, path)
    except BaseException:
        try:
            Path(tmp).unlink(missing_ok=True)
        except OSError:
            pass
        raise


# v2 per-image state (aligned with Flutter OutputReviewItem + GeminiStage + CleanupStage).
REVIEW_VALUES = frozenset({"approved", "needsEdit", "rejected", "unreviewed"})
GEMINI_VALUES = frozenset({"pending", "processing", "done", "failed", "safetyBlocked"})
CLEANUP_VALUES = frozenset({"pending", "processing", "done"})


def _default_image_record() -> dict:
    return {"review": "unreviewed", "gemini": "pending", "cleanup": "pending"}


def _normalize_image_record(raw: dict | None) -> dict:
    rec = _default_image_record()
    if not raw:
        return rec
    r = raw.get("review")
    if isinstance(r, str) and r in REVIEW_VALUES:
        rec["review"] = r
    g = raw.get("gemini")
    if isinstance(g, str) and g in GEMINI_VALUES:
        rec["gemini"] = g
    c = raw.get("cleanup")
    if isinstance(c, str) and c in CLEANUP_VALUES:
        rec["cleanup"] = c
    return rec


def image_record_is_runnable(rec: dict) -> bool:
    """Matches Flutter batch + Python queue: needsEdit/rejected always re-queue; else need incomplete stages."""
    review = rec.get("review", "unreviewed")
    if review in ("needsEdit", "rejected"):
        return True
    if rec.get("gemini", "pending") != "done" or rec.get("cleanup", "pending") != "done":
        return True
    return False


def _migrate_v1_raw_to_images(raw: dict, all_keys: set[str]) -> dict[str, dict]:
    proc = set(raw.get("processed", []))
    proc &= all_keys
    images: dict[str, dict] = {}
    for k in sorted(all_keys):
        if k in proc:
            images[k] = {
                "review": "unreviewed",
                "gemini": "done",
                "cleanup": "done",
            }
        else:
            images[k] = _default_image_record()
    return images


def _output_rel_to_input_key(out_rel_posix: str, all_keys: set[str]) -> str | None:
    """Map OUTPUT_DIR-relative clean PNG path to input relative key."""
    p = Path(out_rel_posix)
    if p.suffix.lower() != ".png":
        return None
    name = p.name
    suf = "_product_clean.png"
    if not name.endswith(suf):
        return None
    stem_base = name[: -len(suf)]
    parent = p.parent.as_posix()
    for k in all_keys:
        pk = Path(k)
        if pk.parent.as_posix() == parent and pk.stem == stem_base:
            return k
    return None


def _merge_legacy_review_state(
    output_dir: Path, all_keys: set[str], images: dict[str, dict]
) -> None:
    """Overlay review flags from OUTPUT_DIR/.review_state.json (absolute or relative paths)."""
    rp = output_dir.resolve() / ".review_state.json"
    if not rp.is_file():
        return
    try:
        data = json.loads(rp.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return
    if not isinstance(data, dict):
        return
    out_root = output_dir.resolve()
    for path_str, status in data.items():
        if not isinstance(path_str, str) or not isinstance(status, str):
            continue
        if status not in REVIEW_VALUES:
            continue
        pth = Path(path_str)
        if not pth.is_absolute():
            pth = out_root / path_str
        try:
            rel = pth.resolve().relative_to(out_root)
        except ValueError:
            continue
        ik = _output_rel_to_input_key(rel.as_posix(), all_keys)
        if ik is None:
            continue
        rec = images.setdefault(ik, _default_image_record())
        rec["review"] = status


def load_or_init_pipeline_state(
    input_dir: Path,
    scanned: list[tuple[Path, Path]],
    *,
    output_dir: Path | None = None,
) -> dict:
    """
    Load or create STATE_FILENAME as v2 ``images`` map.
    Migrates v1 processed/not_processed; merges legacy .review_state.json from output_dir when provided.
    Reconciles with scan (new keys default to pending; removed keys dropped).
    """
    path = state_file_path(input_dir)
    all_keys = {_rel_key(r) for _, r in scanned}

    if not path.is_file():
        images = {k: _default_image_record() for k in sorted(all_keys)}
        data = {"version": 2, "images": images}
        atomic_write_json(path, data)
        return data

    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        raise RuntimeError(f"Could not read pipeline state {path}: {e}") from e

    ver = raw.get("version", 1)
    if ver >= 2 and isinstance(raw.get("images"), dict):
        images = {}
        raw_img = raw["images"]
        for k, v in raw_img.items():
            if k not in all_keys:
                continue
            images[k] = _normalize_image_record(v if isinstance(v, dict) else None)
        for k in sorted(all_keys):
            if k not in images:
                images[k] = _default_image_record()
    else:
        images = _migrate_v1_raw_to_images(raw, all_keys)

    if output_dir is not None:
        _merge_legacy_review_state(output_dir.resolve(), all_keys, images)

    data = {"version": 2, "images": images}
    atomic_write_json(path, data)
    return data


def flush_pipeline_state_v2(
    state_path: Path,
    all_image_keys: set[str],
    *,
    success_keys: set[str],
    failure_category_by_key: dict[str, str],
) -> None:
    """
    Merge success/failure into v2 state. Re-reads the file first so concurrent Flutter edits are preserved.
    """
    try:
        raw = json.loads(state_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        raw = {}
    ver = raw.get("version", 1)
    if ver >= 2 and isinstance(raw.get("images"), dict):
        images: dict[str, dict] = {
            k: _normalize_image_record(v if isinstance(v, dict) else None)
            for k, v in raw["images"].items()
            if k in all_image_keys
        }
    else:
        images = _migrate_v1_raw_to_images(raw, all_image_keys)

    for k in sorted(all_image_keys):
        if k not in images:
            images[k] = _default_image_record()

    for k in success_keys:
        if k not in all_image_keys:
            continue
        rec = dict(images.get(k, _default_image_record()))
        rec["gemini"] = "done"
        rec["cleanup"] = "done"
        # After a successful re-run, surface new output for gallery review.
        if rec.get("review") in ("needsEdit", "rejected"):
            rec["review"] = "unreviewed"
        images[k] = rec

    for k, cat in failure_category_by_key.items():
        if k not in all_image_keys:
            continue
        rec = dict(images.get(k, _default_image_record()))
        rec["gemini"] = "safetyBlocked" if cat == "safety_filter" else "failed"
        rec["cleanup"] = "pending"
        images[k] = rec

    atomic_write_json(state_path, {"version": 2, "images": images})


def iter_input_images_from_retry_list(
    input_dir: Path, rel_paths: list[Path]
) -> tuple[list[tuple[Path, Path]], list[str]]:
    """Resolve only listed paths under input_dir. Return (images, warning lines for skips)."""
    root = input_dir.resolve()
    out: list[tuple[Path, Path]] = []
    warnings: list[str] = []
    for rel in rel_paths:
        norm = rel.as_posix()
        if norm == ".." or norm.startswith("../") or "/../" in f"/{norm}/":
            warnings.append(f"skip unsafe path: {rel}")
            continue
        abs_path = (root / rel).resolve()
        try:
            rel_clean = abs_path.relative_to(root)
        except ValueError:
            warnings.append(f"skip path outside input dir: {rel}")
            continue
        if not abs_path.is_file():
            warnings.append(f"missing or not a file: {rel}")
            continue
        if abs_path.suffix.lower() not in IMAGE_EXTENSIONS:
            warnings.append(f"skip non-image extension: {rel}")
            continue
        out.append((abs_path, rel_clean))
    out.sort(key=lambda t: t[1].as_posix())
    return out, warnings


def output_paths_for(
    rel: Path, output_dir: Path, raw_dir: Path | None
) -> tuple[Path, Path | None]:
    """Mirror rel's parent under output_dir; filenames get _product_clean / _gemini suffixes."""
    final_rel = rel.parent / f"{rel.stem}_product_clean.png"
    final_path = output_dir / final_rel
    raw_path = None
    if raw_dir is not None:
        raw_path = raw_dir / rel.parent / f"{rel.stem}_gemini.png"
    return final_path, raw_path


def extract_output_image(response) -> Image.Image | None:
    for part in response.parts:
        if part.inline_data is not None:
            try:
                return part.as_image()
            except Exception:
                continue
    return None


def _is_retryable_api_error(exc: BaseException) -> bool:
    if not isinstance(exc, APIError):
        return False
    code = getattr(exc, "code", None)
    return code in (429, 503)


def _iter_exception_chain(exc: BaseException):
    seen: set[int] = set()
    cur: BaseException | None = exc
    while cur is not None and id(cur) not in seen:
        seen.add(id(cur))
        yield cur
        cur = cur.__cause__ or cur.__context__


def _is_retryable_transport_error(exc: BaseException) -> bool:
    """Transient TLS/TCP issues (e.g. SSL: UNEXPECTED_EOF_WHILE_READING) and connection drops."""
    for e in _iter_exception_chain(exc):
        if isinstance(
            e,
            (
                ssl.SSLError,
                ConnectionError,
                TimeoutError,
                BrokenPipeError,
                ConnectionResetError,
            ),
        ):
            return True
        # httpx / urllib3 often wrap the above; __cause__ usually preserves SSLError
        if type(e).__name__ in (
            "ReadError",
            "WriteError",
            "ConnectError",
            "RemoteProtocolError",
            "ProtocolError",
        ):
            return True
    return False


def _categorize_error(exc: BaseException) -> str:
    """Classify an exception into one of three UI-facing error categories."""
    if isinstance(exc, APIError):
        if getattr(exc, "code", None) == 429:
            return "rate_limit"
        msg = str(exc).lower()
        if any(w in msg for w in ("safety", "blocked", "harm")):
            return "safety_filter"
        return "api_error"
    if _is_retryable_transport_error(exc):
        return "api_error"
    msg = str(exc).lower()
    if any(w in msg for w in ("safety", "blocked", "harm")):
        return "safety_filter"
    return "api_error"


def _emit_progress(
    emitter: EventEmitter,
    done: int,
    total: int,
    failed: int,
    start_time: float,
) -> None:
    elapsed = time.time() - start_time
    obj: dict = {
        "event": "progress",
        "ts": time.time(),
        "done": done,
        "total": total,
        "failed": failed,
    }
    if elapsed > 5 and done > 0:
        ipm = round(done / elapsed * 60, 2)
        obj["ipm"] = ipm
        remaining = total - done
        obj["eta_s"] = int(remaining / (done / elapsed)) if done < total else 0
    emitter.emit(obj)


def _flush_image_log(log_dir: Path, rel: Path, img_log: list[str]) -> None:
    lp = log_dir / rel.parent / f"{rel.stem}.log"
    lp.parent.mkdir(parents=True, exist_ok=True)
    lp.write_text("\n".join(img_log) + "\n", encoding="utf-8")


def _retry_after_seconds(exc: APIError) -> float | None:
    r = getattr(exc, "response", None)
    if r is None:
        return None
    try:
        h = r.headers.get("Retry-After")
        if h is None:
            return None
        return float(h)
    except (TypeError, ValueError):
        return None


def _generate_content_with_retry(
    client: genai.Client,
    *,
    model: str,
    contents: list,
    use_image_config: bool,
    log_rel: Path,
    print_lock: threading.Lock | None,
    max_api_retries: int,
    retry_backoff_base: float,
    emitter: EventEmitter | None = None,
    img_log: list[str] | None = None,
) -> object:
    """Call generate_content; retry 429/503 and transient TLS/connection errors with backoff."""
    max_attempts = max(1, 1 + max_api_retries)

    def log_retry(msg: str) -> None:
        if print_lock is not None:
            with print_lock:
                print(msg, file=sys.stderr)
        else:
            print(msg, file=sys.stderr)

    last_exc: BaseException | None = None
    for attempt in range(max_attempts):
        kwargs: dict = {"model": model, "contents": contents}
        if use_image_config:
            kwargs["config"] = types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
            )
        try:
            return client.models.generate_content(**kwargs)
        except APIError as e:
            last_exc = e
            if not _is_retryable_api_error(e) or attempt >= max_attempts - 1:
                raise
            ra = _retry_after_seconds(e)
            if ra is not None:
                sleep_s = max(ra, retry_backoff_base * (0.5 + random.random() * 0.5))
            else:
                exp = retry_backoff_base * (2**attempt)
                jitter = random.uniform(0, exp * 0.25)
                sleep_s = min(exp + jitter, 60.0)
            log_retry(
                f"  {log_rel}: API {getattr(e, 'code', '?')} — retry "
                f"{attempt + 1}/{max_attempts - 1} in {sleep_s:.1f}s"
            )
            if img_log is not None:
                img_log.append(
                    f"backoff {sleep_s:.1f}s attempt {attempt + 1}: API {getattr(e, 'code', '?')}"
                )
            if emitter:
                emitter.emit({
                    "event": "backoff_start",
                    "path": log_rel.as_posix(),
                    "ts": time.time(),
                    "duration_s": round(sleep_s, 1),
                    "attempt": attempt + 1,
                    "reason": "rate_limit" if getattr(e, "code", None) == 429 else "server_error",
                    "api_code": getattr(e, "code", None),
                })
            time.sleep(sleep_s)
            if emitter:
                emitter.emit({
                    "event": "backoff_end",
                    "path": log_rel.as_posix(),
                    "ts": time.time(),
                })
        except Exception as e:
            last_exc = e
            if not _is_retryable_transport_error(e) or attempt >= max_attempts - 1:
                raise
            exp = retry_backoff_base * (2**attempt)
            jitter = random.uniform(0, exp * 0.25)
            sleep_s = min(exp + jitter, 60.0)
            log_retry(
                f"  {log_rel}: {type(e).__name__} ({e}) — retry "
                f"{attempt + 1}/{max_attempts - 1} in {sleep_s:.1f}s"
            )
            if img_log is not None:
                img_log.append(
                    f"backoff {sleep_s:.1f}s attempt {attempt + 1}: {type(e).__name__}"
                )
            if emitter:
                emitter.emit({
                    "event": "backoff_start",
                    "path": log_rel.as_posix(),
                    "ts": time.time(),
                    "duration_s": round(sleep_s, 1),
                    "attempt": attempt + 1,
                    "reason": "transport_error",
                })
            time.sleep(sleep_s)
            if emitter:
                emitter.emit({
                    "event": "backoff_end",
                    "path": log_rel.as_posix(),
                    "ts": time.time(),
                })
    assert last_exc is not None
    raise last_exc


def run_one(
    model: str,
    prompt: str,
    source: Path,
    rel: Path,
    raw_path: Path | None,
    final_path: Path,
    use_image_config: bool,
    *,
    print_lock: threading.Lock | None = None,
    emitter: EventEmitter | None = None,
    img_log: list[str] | None = None,
    rate_limiter: "_TokenBucket | None" = None,
    max_api_retries: int = DEFAULT_MAX_API_RETRIES,
    retry_backoff_base: float = 2.0,
) -> None:
    if rate_limiter is not None:
        rate_limiter.acquire()
    client = _get_thread_client()
    t_gemini_start = time.monotonic()
    image_input = Image.open(source)
    contents: list = [prompt, image_input]
    response = _generate_content_with_retry(
        client,
        model=model,
        contents=contents,
        use_image_config=use_image_config,
        log_rel=rel,
        print_lock=print_lock,
        max_api_retries=max_api_retries,
        retry_backoff_base=retry_backoff_base,
        emitter=emitter,
        img_log=img_log,
    )

    gemini_latency_ms = int((time.monotonic() - t_gemini_start) * 1000)
    if emitter:
        emitter.emit({
            "event": "gemini_done",
            "path": rel.as_posix(),
            "ts": time.time(),
            "latency_ms": gemini_latency_ms,
        })
    if img_log is not None:
        img_log.append(f"gemini_done latency={gemini_latency_ms}ms")

    out_img = extract_output_image(response)
    if out_img is None:
        raise RuntimeError(
            "No image in API response; try again or pass --use-response-modalities"
        )

    final_path.parent.mkdir(parents=True, exist_ok=True)

    if raw_path is not None:
        raw_path.parent.mkdir(parents=True, exist_ok=True)
        out_img.save(raw_path)
        output_bytes = process_image(str(raw_path), str(final_path), copy_if_no_logo=True)
    else:
        fd, temp_name = tempfile.mkstemp(
            suffix=".tmp_gemini.png",
            prefix=f"{final_path.stem}_",
            dir=final_path.parent,
        )
        os.close(fd)
        temp_raw = Path(temp_name)
        try:
            out_img.save(temp_raw)
            output_bytes = process_image(str(temp_raw), str(final_path), copy_if_no_logo=True)
        finally:
            if temp_raw.exists():
                temp_raw.unlink()

    if emitter:
        emitter.emit({
            "event": "cleanup_done",
            "path": rel.as_posix(),
            "ts": time.time(),
            "output_bytes": output_bytes,
        })
    if img_log is not None:
        img_log.append(f"cleanup_done output_bytes={output_bytes}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Gemini product-shot pipeline: edit images then strip Gemini corner logo.",
    )
    parser.add_argument(
        "input_dir",
        type=Path,
        help="Directory tree of source images (.jpg, .jpeg, .png, .webp); subfolders are mirrored under --output-dir",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("output"),
        help="Directory for final cleaned images; matches input subfolder layout (default: ./output). "
        "Use a different path per parallel run to avoid overwriting outputs.",
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
        "--workers",
        type=int,
        default=DEFAULT_WORKERS,
        metavar="N",
        help=(
            f"Parallel image jobs (threads). Default {DEFAULT_WORKERS} targets typical Tier 1 image quotas (IPM); "
            "check https://aistudio.google.com/rate-limit. Lower on Free tier or if you see 429 errors."
        ),
    )
    parser.add_argument(
        "--max-api-retries",
        type=int,
        default=DEFAULT_MAX_API_RETRIES,
        metavar="N",
        help=(
            f"Max retries after transient API errors (429/503) or network/TLS failures; "
            f"default {DEFAULT_MAX_API_RETRIES}. Uses exponential backoff and Retry-After when present."
        ),
    )
    parser.add_argument(
        "--retry-backoff-base",
        type=float,
        default=2.0,
        metavar="SEC",
        help="Base seconds for exponential backoff when retrying 429/503 or transport errors (default: 2).",
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
    parser.add_argument(
        "--copy-failed",
        action="store_true",
        help="Copy failed sources under _failed/<run>/ for a smaller retry batch",
    )
    parser.add_argument(
        "--failed-log",
        type=Path,
        default=None,
        metavar="PATH",
        help="Append per-failure JSON Lines and a companion *_paths.txt next to this path (optional).",
    )
    parser.add_argument(
        "--no-failed-log",
        action="store_true",
        help="Do not write --failed-log JSONL or companion path list even if --failed-log is set.",
    )
    parser.add_argument(
        "--retry-paths-file",
        type=Path,
        default=None,
        metavar="PATH",
        help=(
            "Only process listed paths (relative to input_dir); ignores "
            f"{STATE_FILENAME} progress in the input folder."
        ),
    )
    parser.add_argument(
        "--no-progress",
        action="store_true",
        help="Disable the tqdm progress bar (stderr).",
    )
    parser.add_argument(
        "--log-dir",
        type=Path,
        default=None,
        metavar="DIR",
        help="Write per-image log files to DIR/<rel_path_stem>.log for the UI 'View Logs' feature.",
    )
    parser.add_argument(
        "--rate-limit",
        type=float,
        default=None,
        metavar="RPM",
        help=(
            "Maximum API requests per minute across all workers (token-bucket rate limiter). "
            "Set to your tier's image-generation RPM limit to prevent 429 bursts. "
            "Default: no limit (rely on per-worker backoff only)."
        ),
    )

    args = parser.parse_args()

    if args.workers < 1:
        print("--workers must be >= 1", file=sys.stderr)
        return 1
    if args.max_api_retries < 0:
        print("--max-api-retries must be >= 0", file=sys.stderr)
        return 1

    # Packaged app: .env lives next to the Flutter app support dir (set via PRODUCT_IMAGE_EDIT_APP_DATA).
    # Dev: still loads repo-root .env.
    load_dotenv(_APP_DATA_ROOT / ".env")
    if _FROZEN_BASE is None:
        load_dotenv(_REPO_ROOT / ".env")
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

    if args.retry_paths_file is not None:
        rp = args.retry_paths_file.resolve()
        if not rp.is_file():
            print(f"Not a file: {rp}", file=sys.stderr)
            return 1
        try:
            rels = load_retry_paths_list(rp)
        except OSError as e:
            print(f"Could not read {rp}: {e}", file=sys.stderr)
            return 1
        if not rels:
            print(f"No paths in {rp}", file=sys.stderr)
            return 1
        images, retry_warnings = iter_input_images_from_retry_list(input_dir, rels)
        for w in retry_warnings:
            print(w, file=sys.stderr)
        if not images:
            print(f"No matching images under {input_dir} for --retry-paths-file", file=sys.stderr)
            return 1
        work_items = sorted(images, key=lambda t: t[1].as_posix())
        use_pipeline_state = False
        pipeline_state_path: Path | None = None
        all_image_keys: set[str] | None = None
    else:
        all_images = iter_input_images(input_dir)
        if not all_images:
            print(f"No images found under {input_dir}", file=sys.stderr)
            return 1
        try:
            st = load_or_init_pipeline_state(
                input_dir, all_images, output_dir=output_dir
            )
        except (OSError, RuntimeError) as e:
            print(str(e), file=sys.stderr)
            return 1
        pipeline_state_path = state_file_path(input_dir)
        all_image_keys = {_rel_key(r) for _, r in all_images}
        img_map: dict[str, dict] = st.get("images", {})
        work_items = [
            (p, r)
            for p, r in all_images
            if image_record_is_runnable(
                _normalize_image_record(img_map.get(_rel_key(r)))
            )
        ]
        work_items.sort(key=lambda t: t[1].as_posix())
        use_pipeline_state = True
        if not work_items:
            print(
                f"No runnable images among {len(all_image_keys)} under {input_dir}; "
                f"see {pipeline_state_path}",
                file=sys.stderr,
            )
            return 0
        n_skip = len(all_image_keys) - len(work_items)
        print(
            f"Pipeline state: {pipeline_state_path} ({len(work_items)} to process, "
            f"{n_skip} skipped as done/approved)",
            file=sys.stderr,
        )

    raw_dir = output_dir / "_raw" if args.keep_raw else None
    if raw_dir:
        raw_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    failed_dir = _failed_dir_for_run(input_dir) if args.copy_failed else None

    print_lock = threading.Lock()
    emitter = EventEmitter(enabled=True, lock=print_lock)

    rate_limiter: _TokenBucket | None = None
    if args.rate_limit is not None and args.rate_limit > 0:
        # Burst of min(workers, rpm) so workers can start without stalling, then steady-state
        burst = min(args.workers, args.rate_limit)
        rate_limiter = _TokenBucket(capacity=burst, rate=args.rate_limit / 60.0)
        print(
            f"Rate limiter: {args.rate_limit:.0f} RPM "
            f"(burst={burst:.0f}, {args.workers} workers)",
            file=sys.stderr,
        )

    log_dir: Path | None = None
    if args.log_dir is not None:
        log_dir = args.log_dir.resolve()
        log_dir.mkdir(parents=True, exist_ok=True)

    state_lock = threading.Lock()
    pending_processed_keys: set[str] = set()
    failure_category_by_key: dict[str, str] = {}
    done = 0
    done_lock = threading.Lock()
    pipeline_start_time = time.time()
    emitter.emit({
        "event": "pipeline_scan",
        "ts": pipeline_start_time,
        "total": len(work_items),
        "paths": [rel.as_posix() for _, rel in work_items],
    })
    failed = 0
    if args.failed_log is not None and not args.no_failed_log:
        failed_log_jsonl = args.failed_log.resolve()
        failed_paths_txt = failed_log_jsonl.with_name(
            f"{failed_log_jsonl.stem}_paths.txt"
        )
    else:
        failed_log_jsonl = None
        failed_paths_txt = None

    def handle_failure(
        src: Path,
        rel: Path,
        e: BaseException,
        img_log: list[str] | None = None,
    ) -> None:
        nonlocal failed
        category = _categorize_error(e)
        failed_event: dict = {
            "event": "image_failed",
            "path": rel.as_posix(),
            "ts": time.time(),
            "error_category": category,
            "error_msg": str(e)[:500],
        }
        api_code = getattr(e, "code", None)
        if api_code is not None:
            failed_event["api_code"] = api_code
        emitter.emit(failed_event)
        if img_log is not None:
            img_log.append(f"FAILED [{category}]: {e}")
            if log_dir is not None:
                _flush_image_log(log_dir, rel, img_log)
        with state_lock:
            failure_category_by_key[_rel_key(rel)] = category
            if use_pipeline_state and pipeline_state_path is not None and all_image_keys is not None:
                flush_pipeline_state_v2(
                    pipeline_state_path,
                    all_image_keys,
                    success_keys=pending_processed_keys,
                    failure_category_by_key=failure_category_by_key,
                )
        with print_lock:
            failed += 1
            print(f"  Error: {e}", file=sys.stderr)
            if failed_log_jsonl is not None and failed_paths_txt is not None:
                record = {
                    "input_dir": str(input_dir),
                    "relative": str(rel).replace("\\", "/"),
                    "source": str(src.resolve()),
                    "error": str(e),
                }
                try:
                    failed_log_jsonl.parent.mkdir(parents=True, exist_ok=True)
                    with open(failed_log_jsonl, "a", encoding="utf-8") as lf:
                        lf.write(json.dumps(record, ensure_ascii=False) + "\n")
                    with open(failed_paths_txt, "a", encoding="utf-8") as pf:
                        pf.write(str(rel).replace("\\", "/") + "\n")
                except OSError as log_err:
                    print(
                        f"  Could not write failure log ({failed_log_jsonl}): {log_err}",
                        file=sys.stderr,
                    )
            if failed_dir is not None:
                try:
                    failed_dir.mkdir(parents=True, exist_ok=True)
                    dest = failed_dir / rel
                    if src.resolve() != dest.resolve():
                        dest.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(src, dest)
                except OSError as copy_err:
                    print(
                        f"  Could not copy to {failed_dir}: {copy_err}",
                        file=sys.stderr,
                    )
        # Emit progress outside print_lock — emitter also acquires print_lock internally.
        _emit_progress(emitter, done, len(work_items), failed, pipeline_start_time)

    show_progress = not args.no_progress

    def process_one(src: Path, rel: Path) -> None:
        nonlocal done
        img_log: list[str] = [f"start: {rel}"]
        emitter.emit({"event": "image_start", "path": rel.as_posix(), "ts": time.time()})

        final_path, raw_path = output_paths_for(rel, output_dir, raw_dir)
        msg = f"Processing: {rel} -> {final_path.relative_to(output_dir)}"
        if show_progress:
            tqdm.write(msg, file=sys.stderr)
        else:
            with print_lock:
                print(msg, file=sys.stderr)
        try:
            run_one(
                args.model,
                args.prompt,
                src,
                rel,
                raw_path,
                final_path,
                args.use_response_modalities,
                print_lock=print_lock,
                emitter=emitter,
                img_log=img_log,
                rate_limiter=rate_limiter,
                max_api_retries=args.max_api_retries,
                retry_backoff_base=args.retry_backoff_base,
            )
        except Exception as e:
            handle_failure(src, rel, e, img_log)
            raise

        if show_progress:
            tqdm.write(f"Done: {rel}", file=sys.stderr)
        else:
            with print_lock:
                print(f"Done: {rel}", file=sys.stderr)
        with state_lock:
            pending_processed_keys.add(_rel_key(rel))
            if use_pipeline_state and pipeline_state_path is not None and all_image_keys is not None:
                flush_pipeline_state_v2(
                    pipeline_state_path,
                    all_image_keys,
                    success_keys=pending_processed_keys,
                    failure_category_by_key=failure_category_by_key,
                )
        with done_lock:
            done += 1
            _emit_progress(emitter, done, len(work_items), failed, pipeline_start_time)
        if log_dir is not None:
            _flush_image_log(log_dir, rel, img_log)

    if args.workers == 1:
        it = (
            tqdm(work_items, desc="Pipeline", unit="img", file=sys.stderr)
            if show_progress
            else work_items
        )
        for src, rel in it:
            try:
                process_one(src, rel)
            except Exception:
                if args.fail_fast:
                    break
    else:
        executor = ThreadPoolExecutor(max_workers=args.workers)
        fail_fast_cancelled = False
        pbar = (
            tqdm(
                total=len(work_items),
                desc="Pipeline",
                unit="img",
                file=sys.stderr,
            )
            if show_progress
            else None
        )
        try:
            future_to_item = {
                executor.submit(process_one, src, rel): (src, rel)
                for src, rel in work_items
            }
            for fut in as_completed(future_to_item):
                src, rel = future_to_item[fut]
                try:
                    fut.result()
                except Exception:
                    if args.fail_fast:
                        fail_fast_cancelled = True
                        break
                finally:
                    if pbar is not None:
                        pbar.update(1)
        finally:
            if pbar is not None:
                pbar.close()
            executor.shutdown(wait=True, cancel_futures=fail_fast_cancelled)

    if (
        use_pipeline_state
        and pipeline_state_path is not None
        and all_image_keys is not None
        and (pending_processed_keys or failure_category_by_key)
    ):
        flush_pipeline_state_v2(
            pipeline_state_path,
            all_image_keys,
            success_keys=pending_processed_keys,
            failure_category_by_key=failure_category_by_key,
        )

    input_bytes = sum(src.stat().st_size for src, _ in work_items if src.exists())
    output_bytes_total = sum(
        p.stat().st_size for p in output_dir.rglob("*_product_clean.png") if p.is_file()
    )
    elapsed_s = time.time() - pipeline_start_time
    emitter.emit({
        "event": "pipeline_complete",
        "ts": time.time(),
        "total": len(work_items),
        "success": len(work_items) - failed,
        "failed": failed,
        "elapsed_s": round(elapsed_s, 1),
        "space_saved_bytes": input_bytes - output_bytes_total,
    })

    if failed:
        print(f"Done with {failed} failure(s).", file=sys.stderr)
        if failed_log_jsonl is not None:
            print("Failure details logged to:", file=sys.stderr)
            print(f"  {failed_log_jsonl}", file=sys.stderr)
            if failed_paths_txt is not None:
                print(f"  {failed_paths_txt} (one relative path per line)", file=sys.stderr)
        if use_pipeline_state and pipeline_state_path is not None:
            print(
                f"Update {pipeline_state_path} or mark images as needsEdit/rejected in the app "
                "to re-queue; failed entries were written to the state file.",
                file=sys.stderr,
            )
        script = Path(__file__).name
        retry_input = failed_dir if failed_dir is not None else input_dir
        retry_parts = [
            "uv",
            "run",
            "python",
            script,
            str(retry_input),
            "--output-dir",
            str(output_dir),
            "--workers",
            str(args.workers),
        ]
        if args.copy_failed:
            retry_parts.append("--copy-failed")
        if args.use_response_modalities:
            retry_parts.append("--use-response-modalities")
        if args.keep_raw:
            retry_parts.append("--keep-raw")
        if args.model != DEFAULT_MODEL:
            retry_parts.extend(["--model", args.model])
        if args.fail_fast:
            retry_parts.append("--fail-fast")
        if args.max_api_retries != DEFAULT_MAX_API_RETRIES:
            retry_parts.extend(["--max-api-retries", str(args.max_api_retries)])
        if args.retry_backoff_base != 2.0:
            retry_parts.extend(["--retry-backoff-base", str(args.retry_backoff_base)])
        if args.failed_log is not None:
            retry_parts.extend(["--failed-log", str(args.failed_log)])
        if args.no_failed_log:
            retry_parts.append("--no-failed-log")
        if failed_paths_txt is not None:
            retry_parts.extend(["--retry-paths-file", str(failed_paths_txt)])
        elif args.retry_paths_file is not None:
            retry_parts.extend(["--retry-paths-file", str(args.retry_paths_file.resolve())])
        if args.no_progress:
            retry_parts.append("--no-progress")
        retry_cmd = " ".join(shlex.quote(p) for p in retry_parts)
        runner_argv = retry_parts[4:]
        print(
            "PRODUCT_IMAGE_PIPELINE_RETRY_JSON="
            + json.dumps({"argv": runner_argv}, ensure_ascii=False),
            file=sys.stderr,
        )
        if failed_dir is not None:
            print(f"Failed sources copied under: {failed_dir}", file=sys.stderr)
        print("Retry with:", file=sys.stderr)
        print(f"  {retry_cmd}", file=sys.stderr)
        return 1
    print("Done.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
