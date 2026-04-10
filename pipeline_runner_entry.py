#!/usr/bin/env python3
"""Wrapper entrypoint for packaging the pipeline as a binary."""

import multiprocessing
import sys


if __name__ == "__main__":
    # Required for multiprocessing spawn/fork support in PyInstaller binaries.
    multiprocessing.freeze_support()

    # Python's multiprocessing.resource_tracker (and spawn) re-execute
    # sys.executable — which in a frozen binary is *this* binary — with
    # interpreter flags like `-B -S -I -c <bootstrap_code>`.
    # Intercept that before argparse ever sees it.
    _argv = sys.argv[1:]
    _interp_flags = {"-B", "-S", "-I", "-u", "-v", "-q", "-d", "-O", "-OO"}
    while _argv and _argv[0] in _interp_flags:
        _argv.pop(0)
    if _argv and _argv[0] == "-c" and len(_argv) >= 2:
        exec(compile(_argv[1], "<string>", "exec"))  # noqa: S102
        raise SystemExit(0)

    from gemini_product_pipeline import main
    raise SystemExit(main())
