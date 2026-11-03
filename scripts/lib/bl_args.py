"""Argument parsing for scripts run as ``blender -b [file] -P script.py -- <args>``."""

import argparse
import sys


def script_argv(argv=None):
    """Return the arguments after ``--`` (Blender ignores everything after it)."""
    argv = sys.argv if argv is None else argv
    return argv[argv.index("--") + 1:] if "--" in argv else []


def parse(parser: argparse.ArgumentParser, argv=None):
    return parser.parse_args(script_argv(argv))


def parse_frame_ranges(spec: str) -> list[int]:
    """'1-10,15,20-22' -> [1..10, 15, 20, 21, 22] (sorted, unique)."""
    frames: set[int] = set()
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            lo, hi = int(a), int(b)
            if hi < lo:
                lo, hi = hi, lo
            frames.update(range(lo, hi + 1))
        else:
            frames.add(int(part))
    return sorted(frames)


def frames_to_ranges(frames) -> str:
    """[1,2,3,7,9,10] -> '1-3,7,9-10'."""
    frames = sorted(set(frames))
    out, start, prev = [], None, None
    for f in frames:
        if start is None:
            start = prev = f
        elif f == prev + 1:
            prev = f
        else:
            out.append(f"{start}-{prev}" if start != prev else str(start))
            start = prev = f
    if start is not None:
        out.append(f"{start}-{prev}" if start != prev else str(start))
    return ",".join(out)
