"""Write godot/assets/data/layout.json from spec.py (host Python; no Blender needed).

  tools/py projects/games/last_light/blender/layout_export.py [--check-only]

Fails (exit 1) if any safe route grazes a reef or the island, or the reef ring leaks.
The output folder is generated content (standing OK to overwrite, DECISIONS Q10).
"""

import argparse
import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "godot" / "assets" / "data" / "layout.json"


def load_module(name, path):
    s = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m


def build():
    spec = load_module("last_light_spec", HERE / "spec.py").SPEC
    layout_mod = load_module("last_light_layout", HERE / "layout.py")
    layout = layout_mod.compute(spec)
    return layout, layout_mod.check(layout, spec)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check-only", action="store_true")
    args = ap.parse_args()
    layout, problems = build()
    for p in problems:
        print("LAYOUT_PROBLEM", p)
    summary = {"reefs": len(layout["reefs"]), "channels": len(layout["channels"]),
               "problems": len(problems)}
    if not args.check_only and not problems:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(layout, indent=1))
        summary["written"] = str(OUT)
    print("LAYOUT_RESULT " + json.dumps(summary))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
