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
# set -> (resolution, maps). Exterior/legacy sets: 1k diffuse + GL normal + roughness (tri_pbr).
# Stage 1b interior sets: 2k diffuse + GL normal + ARM (room_pbr). The 2k copies are generated, so they
# are gitignored (.gitignore): regenerate with this script from assets/textures, whose sources are
# re-fetchable from Poly Haven with tools/fetch_cc0.py (IDs and licence in assets/ASSET_LICENSES.md).
CC0 = {
    "cliff_side": ("1k", ("diff", "nor_gl", "rough")),
    "coast_land_rocks_01": ("1k", ("diff", "nor_gl", "rough")),
    "sparse_grass": ("1k", ("diff", "nor_gl", "rough")),
    "painted_concrete": ("1k", ("diff", "nor_gl", "rough")),
    "rusty_painted_metal": ("1k", ("diff", "nor_gl", "rough")),
    "distressed_painted_planks": ("1k", ("diff", "nor_gl", "rough")),
    "plastered_wall_02": ("2k", ("diff", "nor_gl", "arm")),
    "concrete_floor_worn_001": ("2k", ("diff", "nor_gl", "arm")),
    "oak_veneer_01": ("2k", ("diff", "nor_gl", "arm")),
    "dark_wooden_planks": ("2k", ("diff", "nor_gl", "arm")),
    "green_metal_rust": ("2k", ("diff", "nor_gl", "arm")),
    "metal_plate_02": ("2k", ("diff", "nor_gl", "arm")),
}
MAPS = {"diff": ("Diffuse", "diff"), "nor_gl": ("nor_gl",), "rough": ("Rough", "rough"), "arm": ("arm",)}


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
    for t, (res, keys) in CC0.items():
        d = WS / "assets" / "textures" / t
        for key in keys:
            tags = MAPS[key]
            hits = [f for f in d.glob(f"*_{res}.*") if any(f"_{tag}_" in f.name for tag in tags)]
            if not hits:
                raise SystemExit(f"missing {t} {key} at {res} in {d} (fetch it with tools/fetch_cc0.py)")
            dst = TEX_OUT / f"{t}_{key}{hits[0].suffix}"
            if not dst.exists() or dst.stat().st_mtime < hits[0].stat().st_mtime:
                shutil.copy2(hits[0], dst)
    n_set = 0
    for f in sorted(TEX_OUT.glob("*.png")) + sorted(TEX_OUT.glob("*.jpg")):
        n_set += import_params(f)
    print("SYNC textures ->", sorted(p.name for p in TEX_OUT.iterdir())[:3], "...", len(list(TEX_OUT.iterdir())),
          f"(import settings written for {n_set})")


# Godot import settings for 3D material textures. Materials are built in code (materials.gd), so
# Godot never auto-detects them as 3D textures; left alone they import lossless WITHOUT mipmaps,
# which shimmers and aliases at distance (Stage 0 audit). Normal maps get the normal-map flag
# (RGTC; every sampler uses hint_normal, which reconstructs Z).
IMPORT_PARAMS = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0"}


def import_params(tex: Path) -> int:
    """Write/patch <tex>.import so Godot re-imports it VRAM-compressed with mipmaps. Keeps uid/remap."""
    imp = tex.with_name(tex.name + ".import")
    want = dict(IMPORT_PARAMS)
    want["compress/normal_map"] = "1" if "_nor" in tex.stem else "2"
    if not imp.exists():
        imp.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                       + "".join(f"{k}={v}\n" for k, v in want.items()))
        return 1
    lines = imp.read_text().splitlines()
    seen = set()
    out = []
    in_params = False
    for ln in lines:
        if ln.startswith("["):
            in_params = ln.strip() == "[params]"
        key = ln.split("=", 1)[0] if in_params and "=" in ln else None
        if key in want:
            ln = f"{key}={want[key]}"
            seen.add(key)
        out.append(ln)
    missing = [k for k in want if k not in seen]
    if missing:
        if "[params]" not in out:
            out += ["", "[params]", ""]
        out += [f"{k}={want[k]}" for k in missing]
    text = "\n".join(out) + "\n"
    if text != imp.read_text():
        imp.write_text(text)
        return 1
    return 0


if __name__ == "__main__":
    main(sys.argv[1:])
