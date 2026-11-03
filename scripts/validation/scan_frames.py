"""Scan a rendered frame sequence for missing, unreadable, blank or flat frames (playbook Step 5).

  tools/py scripts/validation/scan_frames.py renders/x/full --frames 1-360 [--prefix f_]
Prints the bad frames as a range string you can pass straight back to render.py --frames ... --force.
Exit code 1 if any frame is bad.
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.bl_args import frames_to_ranges, parse_frame_ranges  # noqa: E402


def check_frame(path: Path, min_mean=2.0, max_mean=253.0, min_std=1.0):
    if not path.exists():
        return "missing"
    if path.stat().st_size == 0:
        return "empty file"
    try:
        with Image.open(path) as im:
            a = np.asarray(im.convert("L"), dtype=np.float32)
    except Exception as ex:  # corrupt / truncated
        return f"unreadable: {ex}"
    mean, std = float(a.mean()), float(a.std())
    if mean < min_mean:
        return f"black (mean {mean:.1f})"
    if mean > max_mean:
        return f"white (mean {mean:.1f})"
    if std < min_std:
        return f"flat (std {std:.2f})"
    return None


def scan(directory, frames, prefix="f_"):
    bad = {}
    for f in frames:
        problem = check_frame(Path(directory) / f"{prefix}{f:04d}.png")
        if problem:
            bad[f] = problem
    return bad


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("directory")
    ap.add_argument("--frames", required=True)
    ap.add_argument("--prefix", default="f_")
    a = ap.parse_args(argv)
    frames = parse_frame_ranges(a.frames)
    bad = scan(a.directory, frames, a.prefix)
    print("SCAN_RESULT " + json.dumps({"checked": len(frames), "bad": len(bad),
                                       "rerender": frames_to_ranges(bad.keys()),
                                       "details": {str(k): v for k, v in list(bad.items())[:50]}}))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
