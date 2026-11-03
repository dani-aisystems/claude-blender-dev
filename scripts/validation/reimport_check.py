"""Re-import an exported FBX/GLB into an empty scene and compare it with the source validation report.

Usage (fresh process, so nothing from the source file leaks in):
  tools/bl -P scripts/validation/reimport_check.py -- --file exports/x/roblox/x_v001.fbx \
      --source-json renders/x/validation_roblox.json --expected-scale 3.5714

Checks: file loads, mesh count, total triangle count, material set, overall size / expected scale.
Prints REIMPORT_RESULT (JSON); exits 1 on mismatch.
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from lib.bl_args import parse  # noqa: E402
from lib.safe_paths import ensure_allowed  # noqa: E402


def empty_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_file(path: Path):
    ext = path.suffix.lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        raise SystemExit(f"Unsupported: {ext}")


def stats():
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    dg = bpy.context.evaluated_depsgraph_get()
    tris, mats, pts = 0, set(), []
    per = {}
    for o in meshes:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        bm = bmesh.new()
        bm.from_mesh(me)
        t = sum(len(f.verts) - 2 for f in bm.faces)
        bm.free()
        ev.to_mesh_clear()
        tris += t
        names = [s.material.name.split(".")[0] for s in o.material_slots if s.material]
        mats.update(names)
        per[o.name] = {"tris": t, "materials": names}
        pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    size = [0, 0, 0]
    if pts:
        size = [max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3)]
    return {"mesh_count": len(meshes), "total_tris": tris, "materials": sorted(mats),
            "size": [round(v, 4) for v in size], "objects": per}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    ap.add_argument("--source-json", required=True)
    ap.add_argument("--expected-scale", type=float, default=1.0)
    ap.add_argument("--json", default="")
    ap.add_argument("--tolerance", type=float, default=0.01, help="relative size tolerance")
    args = parse(ap)

    src = json.loads(Path(args.source_json).read_text())
    empty_scene()
    import_file(Path(args.file))
    got = stats()

    src_mats = sorted({m for o in src["objects"].values() for m in o["materials"]})
    src_size = sorted(src["summary"]["size_m"])          # axis-order independent (Y-up vs Z-up)
    exp_size = [v * args.expected_scale for v in src_size]
    got_size = sorted(got["size"])
    size_ok = all(abs(g - e) <= max(args.tolerance * e, 1e-3) for g, e in zip(got_size, exp_size))

    checks = {
        "loaded": got["mesh_count"] > 0,
        "mesh_count": got["mesh_count"] == src["summary"]["mesh_count"],
        "total_tris": got["total_tris"] == src["summary"]["total_tris"],
        "materials": got["materials"] == src_mats,
        "size": size_ok,
    }
    result = {"file": args.file, "ok": all(checks.values()), "checks": checks,
              "expected": {"mesh_count": src["summary"]["mesh_count"], "total_tris": src["summary"]["total_tris"],
                           "materials": src_mats, "size_sorted": [round(v, 4) for v in exp_size]},
              "got": {**got, "size_sorted": got_size}}
    if args.json:
        p = ensure_allowed(args.json)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(result, indent=2))
    print("REIMPORT_RESULT " + json.dumps({k: result[k] for k in ("file", "ok", "checks")}))
    if not result["ok"]:
        print("EXPECTED", json.dumps(result["expected"]))
        print("GOT", json.dumps({k: v for k, v in got.items() if k != "objects"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
