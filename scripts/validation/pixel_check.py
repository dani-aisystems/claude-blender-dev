"""Measure a rendered colour against a target hex (playbook: "checked the pixel value against the hex").

  tools/py scripts/validation/pixel_check.py renders/x/angle_00.png --at 320,300 --radius 4 --target "#C4703A"
Averages a (2r+1)^2 patch in display (sRGB) space and reports per-channel difference
and a simple Euclidean RGB distance. AgX tone mapping lightens saturated colours; if the
distance is large, lower exposure / darken the base colour and re-measure.
"""

import argparse
import json
import sys

import numpy as np
from PIL import Image


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def measure(path, x, y, radius=4):
    with Image.open(path) as im:
        a = np.asarray(im.convert("RGB"), dtype=np.float32)
    patch = a[max(0, y - radius):y + radius + 1, max(0, x - radius):x + radius + 1]
    return tuple(int(round(v)) for v in patch.reshape(-1, 3).mean(axis=0))


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--at", required=True, help="x,y in pixels")
    ap.add_argument("--radius", type=int, default=4)
    ap.add_argument("--target", required=True)
    ap.add_argument("--max-distance", type=float, default=25.0)
    a = ap.parse_args(argv)
    x, y = (int(v) for v in a.at.split(","))
    got = measure(a.image, x, y, a.radius)
    tgt = hex_rgb(a.target)
    diff = [g - t for g, t in zip(got, tgt)]
    dist = float(np.linalg.norm(diff))
    ok = dist <= a.max_distance
    print("PIXEL_RESULT " + json.dumps({"measured": "#%02X%02X%02X" % got, "target": a.target.upper(),
                                        "diff_rgb": diff, "distance": round(dist, 1), "ok": ok}))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
