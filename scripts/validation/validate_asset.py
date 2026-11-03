"""Validate an asset collection against a target's budgets and the workspace conventions.

Usage:
  tools/bl file.blend -P scripts/validation/validate_asset.py -- \
      --collection ASSET_hero_lantern --target roblox [--json renders/x/validation.json] [--strict]

Live session (MCP): runpy.run_path(<abs path>, run_name="__main__") with sys.argv set, or
import and call validate(collection_name, target) -> dict.

Each rule -> PASS / WARN / FAIL. Prints one line prefixed VALIDATION_RESULT (JSON).
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bmesh  # noqa: E402
import bpy  # noqa: E402

from exports.presets import PRESETS  # noqa: E402
from lib.bl_args import parse  # noqa: E402
from lib.safe_paths import ensure_allowed  # noqa: E402

EPS = 1e-4
MESH_PREFIXES = ("SM_", "SK_", "UCX_", "UBX_", "UCP_", "USP_",
                 # game-rig hooks (THE LAST LIGHT): moving parts, needles, lamps, screens, glass, collision
                 "PT_", "NDL_", "LMP_", "SCR_", "GLS_", "COL_")
# Articulated parts keep a pivot rotation (local Z = hinge axis) by design; scale must still be 1.
ARTICULATED_PREFIXES = ("PT_", "NDL_")


def _rule(results, obj, rule, status, detail):
    results.append({"object": obj, "rule": rule, "status": status, "detail": detail})


def mesh_stats(obj, depsgraph):
    ev = obj.evaluated_get(depsgraph)
    me = ev.to_mesh()
    try:
        bm = bmesh.new()
        bm.from_mesh(me)
        tris = sum(len(f.verts) - 2 for f in bm.faces)
        ngons = sum(1 for f in bm.faces if len(f.verts) > 4)
        non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
        zero_area = sum(1 for f in bm.faces if f.calc_area() < 1e-10)
        uv_layers = len(me.uv_layers)
        uv_out = 0
        if uv_layers:
            uvl = bm.loops.layers.uv.active
            for f in bm.faces:
                for loop in f.loops:
                    u, v = loop[uvl].uv
                    if u < -EPS or u > 1 + EPS or v < -EPS or v > 1 + EPS:
                        uv_out += 1
        stats = dict(tris=tris, verts=len(bm.verts), faces=len(bm.faces), ngons=ngons,
                     non_manifold_edges=non_manifold, zero_area_faces=zero_area,
                     uv_layers=uv_layers, uv_loops_outside_0_1=uv_out)
        bm.free()
        return stats
    finally:
        ev.to_mesh_clear()


def validate(collection_name: str, target: str) -> dict:
    preset = PRESETS[target]
    budget = preset["budgets"]
    coll = bpy.data.collections.get(collection_name)
    if coll is None:
        raise SystemExit(f"Collection not found: {collection_name}")
    depsgraph = bpy.context.evaluated_depsgraph_get()
    results, objects = [], {}
    meshes = [o for o in coll.all_objects if o.type == "MESH"]
    if not meshes:
        _rule(results, collection_name, "has_meshes", "FAIL", "no mesh objects")

    from mathutils import Vector
    all_pts = []
    for o in meshes:
        s = mesh_stats(o, depsgraph)
        mats = [slot.material.name for slot in o.material_slots if slot.material]
        s.update(materials=mats, dimensions=[round(d, 5) for d in o.dimensions],
                 location=[round(v, 5) for v in o.location],
                 rotation=[round(v, 5) for v in o.rotation_euler],
                 scale=[round(v, 5) for v in o.scale])
        objects[o.name] = s
        all_pts += [o.matrix_world @ Vector(c) for c in o.bound_box]

        _rule(results, o.name, "naming",
              "PASS" if o.name.startswith(MESH_PREFIXES) else "WARN",
              f"mesh objects should start with {MESH_PREFIXES[:2]} (or a collision prefix)")
        for m in mats:
            if not m.startswith("M_"):
                _rule(results, o.name, "material_naming", "WARN", f"material '{m}' should start with M_")
        _rule(results, o.name, "tris_budget",
              "PASS" if s["tris"] <= budget["max_tris_per_mesh"] else "FAIL",
              f"{s['tris']} tris (max {budget['max_tris_per_mesh']})")
        n_mats = len(mats)
        _rule(results, o.name, "materials_per_mesh",
              "PASS" if 1 <= n_mats <= budget["max_materials_per_mesh"] else "FAIL",
              f"{n_mats} material(s) (allowed 1..{budget['max_materials_per_mesh']})")
        scale_ok = all(abs(v - 1) < EPS for v in o.scale)
        if o.name.startswith(ARTICULATED_PREFIXES):
            _rule(results, o.name, "transforms_applied", "PASS" if scale_ok else "FAIL",
                  f"articulated part: pivot rotation allowed, scale={s['scale']}")
        else:
            applied = scale_ok and all(abs(v) < EPS for v in o.rotation_euler)
            _rule(results, o.name, "transforms_applied", "PASS" if applied else "FAIL",
                  f"scale={s['scale']} rot={s['rotation']}")
        if s["uv_layers"] == 0:
            _rule(results, o.name, "uv_present", "FAIL", "no UV map")
        else:
            _rule(results, o.name, "uv_layers",
                  "PASS" if s["uv_layers"] <= budget["max_uv_layers"] else "FAIL",
                  f"{s['uv_layers']} UV layer(s) (max {budget['max_uv_layers']})")
            if budget["uv_in_unit_square"]:
                _rule(results, o.name, "uv_in_0_1",
                      "PASS" if s["uv_loops_outside_0_1"] == 0 else "FAIL",
                      f"{s['uv_loops_outside_0_1']} UV loops outside 0..1")
        _rule(results, o.name, "ngons", "PASS" if s["ngons"] == 0 else "WARN", f"{s['ngons']} n-gons")
        if s["non_manifold_edges"]:
            _rule(results, o.name, "watertight",
                  "FAIL" if budget["require_manifold"] else "WARN",
                  f"{s['non_manifold_edges']} non-manifold edges")
        else:
            _rule(results, o.name, "watertight", "PASS", "0 non-manifold edges")
        _rule(results, o.name, "zero_area_faces",
              "PASS" if s["zero_area_faces"] == 0 else "WARN", f"{s['zero_area_faces']} degenerate faces")

    # Textures
    for o in meshes:
        for slot in o.material_slots:
            m = slot.material
            if not (m and m.use_nodes):
                continue
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    w, h = n.image.size
                    big = max(w, h)
                    st = "FAIL" if big > budget["max_texture_px"] else ("WARN" if big > budget["warn_texture_px"] else "PASS")
                    _rule(results, o.name, "texture_size", st, f"{n.image.name} {w}x{h}")

    summary = {}
    if all_pts:
        lo = [min(p[i] for p in all_pts) for i in range(3)]
        hi = [max(p[i] for p in all_pts) for i in range(3)]
        size = [hi[i] - lo[i] for i in range(3)]
        centre = [(hi[i] + lo[i]) / 2 for i in range(3)]
        summary = dict(bounds_min=[round(v, 4) for v in lo], bounds_max=[round(v, 4) for v in hi],
                       size_m=[round(v, 4) for v in size],
                       total_tris=sum(s["tris"] for s in objects.values()),
                       mesh_count=len(objects))
        tol = 0.01 * max(size)  # 1% of the asset's largest dimension
        base_ok = abs(lo[2]) <= tol and abs(centre[0]) <= tol and abs(centre[1]) <= tol
        _rule(results, collection_name, "origin_at_base_centre", "PASS" if base_ok else "WARN",
              f"bounds min z={lo[2]:.4f}, centre xy=({centre[0]:.4f},{centre[1]:.4f})")
        plausible = 0.01 <= max(size) <= 500
        _rule(results, collection_name, "plausible_size_m", "PASS" if plausible else "WARN",
              f"largest dimension {max(size):.3f} m")

    counts = {k: sum(1 for r in results if r["status"] == k) for k in ("PASS", "WARN", "FAIL")}
    overall = "FAIL" if counts["FAIL"] else ("WARN" if counts["WARN"] else "PASS")
    return {"collection": collection_name, "target": target, "overall": overall, "counts": counts,
            "summary": summary, "objects": objects, "rules": results}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--collection", required=True)
    ap.add_argument("--target", default="roblox", choices=sorted(PRESETS))
    ap.add_argument("--json", default="")
    ap.add_argument("--strict", action="store_true", help="exit 1 on FAIL")
    args = parse(ap)
    report = validate(args.collection, args.target)
    if args.json:
        p = ensure_allowed(args.json)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(report, indent=2))
    print("VALIDATION_RESULT " + json.dumps({k: report[k] for k in ("target", "overall", "counts", "summary")}))
    for r in report["rules"]:
        if r["status"] != "PASS":
            print(f"  {r['status']:4} {r['object']}: {r['rule']} - {r['detail']}")
    if args.strict and report["overall"] == "FAIL":
        sys.exit(1)


if __name__ == "__main__":
    main()
