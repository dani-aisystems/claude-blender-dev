"""Copy the latest versioned GLB exports into the Godot project (generated folder; DECISIONS Q10).

  tools/py projects/games/last_light/blender/sync_assets.py watch_room lighthouse ...
Also copies the selected CC0 texture maps (colour, OpenGL normal, roughness) into godot/assets/textures.
"""

import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WS = HERE.parents[3]
EXPORTS = WS / "exports" / "last_light" / "gltf"
MODELS = HERE.parent / "godot" / "assets" / "models"
TEX_OUT = HERE.parent / "godot" / "assets" / "textures"
CC0 = ["cliff_side", "coast_land_rocks_01", "sparse_grass", "painted_concrete", "rusty_painted_metal",
       "distressed_painted_planks"]
MAPS = {"diff": ("Diffuse", "diff"), "nor_gl": ("nor_gl",), "rough": ("Rough", "rough")}


def latest(name):
    best, best_n = None, -1
    for f in EXPORTS.glob(f"{name}_v*.glb"):
        m = re.match(rf"^{re.escape(name)}_v(\d+)$", f.stem)
        if m and int(m.group(1)) > best_n:
            best, best_n = f, int(m.group(1))
    return best


def main(names):
    MODELS.mkdir(parents=True, exist_ok=True)
    for n in names:
        src = latest(n)
        if src is None:
            raise SystemExit(f"no export for {n} in {EXPORTS}")
        shutil.copy2(src, MODELS / f"{n}.glb")
        print(f"SYNC {src.name} -> godot/assets/models/{n}.glb")
    TEX_OUT.mkdir(parents=True, exist_ok=True)
    for t in CC0:
        d = WS / "assets" / "textures" / t
        for key, tags in MAPS.items():
            hits = [f for f in d.glob("*_1k.*") if any(f"_{tag}_" in f.name for tag in tags)]
            if hits:
                dst = TEX_OUT / f"{t}_{key}{hits[0].suffix}"
                if not dst.exists() or dst.stat().st_mtime < hits[0].stat().st_mtime:
                    shutil.copy2(hits[0], dst)
    print("SYNC textures ->", sorted(p.name for p in TEX_OUT.iterdir())[:3], "...", len(list(TEX_OUT.iterdir())))


if __name__ == "__main__":
    main(sys.argv[1:])
