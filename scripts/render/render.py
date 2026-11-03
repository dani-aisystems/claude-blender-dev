"""Render any frame ranges of the scene camera, resumable (playbook Step 5).

  tools/bl scene.blend -P scripts/render/gpu.py -P scripts/render/render.py -- \
      --frames 1-360 --out renders/<project>/full
  tools/bl scene.blend -P scripts/render/gpu.py -P scripts/render/render.py -- \
      --frames 105-145,285-360 --out renders/<project>/full --force

Stills check (playbook Step 3): --frames <18 spread frames> --res-pct 50 --samples 40.
Existing non-empty frames are skipped unless --force. Files: <out>/f_####.png
"""

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bpy  # noqa: E402

from lib.bl_args import parse, parse_frame_ranges  # noqa: E402
from lib.safe_paths import ensure_allowed  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--prefix", default="f_")
    ap.add_argument("--res-pct", type=int, default=0, help="0 = keep scene setting")
    ap.add_argument("--samples", type=int, default=0, help="0 = keep scene setting")
    ap.add_argument("--engine", default="keep", choices=["keep", "eevee", "cycles"])
    ap.add_argument("--force", action="store_true", help="re-render frames that already exist")
    args = parse(ap)

    scene = bpy.context.scene
    if scene.camera is None:
        raise SystemExit("Scene has no camera")
    out = ensure_allowed(args.out)
    out.mkdir(parents=True, exist_ok=True)
    r = scene.render
    if args.engine != "keep":
        r.engine = "CYCLES" if args.engine == "cycles" else "BLENDER_EEVEE"
    if args.res_pct:
        r.resolution_percentage = args.res_pct
    if args.samples:
        if r.engine == "CYCLES":
            scene.cycles.samples = args.samples
        else:
            scene.eevee.taa_render_samples = args.samples
    r.image_settings.file_format = "PNG"

    done, skipped, times = [], [], []
    for f in parse_frame_ranges(args.frames):
        path = out / f"{args.prefix}{f:04d}.png"
        if path.exists() and path.stat().st_size > 0 and not args.force:
            skipped.append(f)
            continue
        t0 = time.time()
        scene.frame_set(f)
        r.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        times.append(time.time() - t0)
        done.append(f)
        print(f"RENDERED frame {f} in {times[-1]:.2f}s", flush=True)
    avg = sum(times) / len(times) if times else 0
    print("RENDER_RESULT " + json.dumps({"rendered": len(done), "skipped": len(skipped),
                                         "avg_s_per_frame": round(avg, 2), "engine": r.engine, "out": str(out)}))


if __name__ == "__main__":
    main()
