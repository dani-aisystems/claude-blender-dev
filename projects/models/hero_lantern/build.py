"""Build the hero lantern procedurally from spec.py.

Headless:  tools/bl -P projects/models/hero_lantern/build.py -- --new --save
Live (MCP execute_blender_code):
    import runpy, sys
    sys.argv = ["blender", "--", "--save"]
    runpy.run_path("<abs path>/projects/models/hero_lantern/build.py", run_name="__main__")

Only the ASSET_/DRESS_ collections for this asset are replaced; the rest of the scene is untouched.
--new (empty scene) is refused in a live GUI session.
Output: 4 meshes x 1 material (Roblox rule), single UV set in 0..1, transforms applied,
origin at base centre (world origin).
"""

import argparse
import importlib.util
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WS = HERE.parents[2]
sys.path.insert(0, str(WS / "scripts"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from lib.bl_args import parse  # noqa: E402
from lib.scene_utils import (box_project_uvs, get_collection, hex_to_linear,  # noqa: E402
                             hide_from_glossy, mesh_object_from_bmesh, principled_material,
                             save_versioned, set_metric_units)


def load_spec():
    s = importlib.util.spec_from_file_location("hero_lantern_spec", HERE / "spec.py")
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m.SPEC


# ---------- primitives (all context-free bmesh) ----------

def prism(bm, sides, r_bottom, r_top, z0, height, rot=0.0):
    """Closed n-gon prism/frustum with triangulated caps. Returns its verts."""
    m = Matrix.Translation((0, 0, z0 + height / 2)) @ Matrix.Rotation(rot, 4, "Z")
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=sides,
                                radius1=r_bottom, radius2=r_top, depth=height, matrix=m)
    return res["verts"]


def box(bm, size_xyz, loc, rot_z=0.0):
    m = Matrix.Translation(loc) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Diagonal((*size_xyz, 1.0))
    return bmesh.ops.create_cube(bm, size=1.0, matrix=m)["verts"]


def torus_xz(bm, center, R, r, nu, nv):
    """Torus standing upright in the XZ plane (lantern handle)."""
    rings = []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        ring = []
        for j in range(nv):
            b = 2 * math.pi * j / nv
            d = R + r * math.cos(b)
            ring.append(bm.verts.new(Vector(center) + Vector((d * math.cos(a), r * math.sin(b), d * math.sin(a)))))
        rings.append(ring)
    for i in range(nu):
        for j in range(nv):
            a, b = rings[i], rings[(i + 1) % nu]
            f = bm.faces.new((a[j], b[j], b[(j + 1) % nv], a[(j + 1) % nv]))
            f.smooth = True
    return [v for ring in rings for v in ring]


def bevel_hard_edges(bm, verts, offset, segments, min_angle):
    vs = set(verts)
    edges = [e for e in bm.edges if e.verts[0] in vs and e.verts[1] in vs
             and len(e.link_faces) == 2 and e.calc_face_angle(0.0) > min_angle]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=segments, profile=0.5,
                        affect="EDGES", clamp_overlap=True)


def triangulate_ngons(bm):
    ngons = [f for f in bm.faces if len(f.verts) > 4]
    if ngons:
        bmesh.ops.triangulate(bm, faces=ngons)


def set_smooth(bm, verts, smooth=True):
    vs = set(verts)
    for f in bm.faces:
        if all(v in vs for v in f.verts):
            f.smooth = smooth


# ---------- parts ----------

def build_frame(S):
    n = S["sides"]
    rot = math.pi / n  # flat side facing -Y (camera front)
    bv = S["bevel"]
    min_ang = math.radians(bv["min_angle_deg"])
    bm = bmesh.new()
    z = 0.0
    parts = []
    parts.append(prism(bm, n, S["foot"]["radius"], S["foot"]["radius"], z, S["foot"]["height"], rot))
    z += S["foot"]["height"]
    parts.append(prism(bm, n, S["base"]["radius"], S["base"]["radius"], z, S["base"]["height"], rot))
    z += S["base"]["height"]
    z_body = z
    P = S["posts"]
    for i in range(n):
        a = 2 * math.pi * i / n + rot
        loc = (P["radius"] * math.cos(a), P["radius"] * math.sin(a), z_body + P["height"] / 2)
        parts.append(box(bm, (P["width"], P["width"], P["height"]), loc, a))
    z = z_body + P["height"]
    T = S["top_ring"]
    parts.append(prism(bm, n, T["radius"], T["radius"], z, T["height"], rot))
    z += T["height"]
    R = S["roof"]
    parts.append(prism(bm, n, R["radius_bottom"], R["radius_top"], z, R["height"], rot))
    z += R["height"]
    for verts in parts:
        bevel_hard_edges(bm, verts, bv["offset"], bv["segments"], min_ang)
    C = S["chimney"]
    chim = prism(bm, C["segments"], C["radius"], C["radius"], z - 0.004, C["height"] + 0.004)
    set_smooth(bm, chim)
    z += C["height"]
    cap = prism(bm, C["segments"], C["cap_radius"], C["cap_radius"] * 0.9, z, C["cap_height"])
    bevel_hard_edges(bm, cap, bv["offset"] * 0.8, bv["segments"], min_ang)
    z += C["cap_height"]
    H = S["handle"]
    torus_xz(bm, (0, 0, z + H["major_radius"] - H["minor_radius"] * 1.5), H["major_radius"],
             H["minor_radius"], H["major_segments"], H["minor_segments"])
    triangulate_ngons(bm)
    return bm, z_body


def build_glass(S, z_body):
    n, G, P = S["sides"], S["glass"], S["posts"]
    bm = bmesh.new()
    prism(bm, n, G["radius"], G["radius"], z_body + G["inset"], P["height"] - 2 * G["inset"], math.pi / n)
    return bm


def build_candle(S, z_body):
    C = S["candle"]
    bm = bmesh.new()
    v = prism(bm, C["segments"], C["radius"], C["radius"] * 0.96, z_body - 0.002, C["height"] + 0.002)
    bevel_hard_edges(bm, v, 0.0025, 2, math.radians(40))
    set_smooth(bm, list(bm.verts))
    triangulate_ngons(bm)
    return bm, z_body + C["height"]


def build_flame(S, z_top):
    F = S["flame"]
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=F["u"], v_segments=F["v"], radius=F["radius"])
    zmax = F["radius"] * F["stretch"]
    for v in bm.verts:
        v.co.z *= F["stretch"]
        if v.co.z > 0:
            k = 1.0 - F["taper"] * (v.co.z / zmax) ** 1.3
            v.co.x *= k
            v.co.y *= k
        v.co.z += z_top + F["lift"] + F["radius"] * F["stretch"] * 0.55
    for f in bm.faces:
        f.smooth = True
    return bm


# ---------- assemble ----------

def reset_collections(S):
    for name in (S["collection"], S["dress_collection"]):
        coll = bpy.data.collections.get(name)
        if coll:
            for o in list(coll.objects):
                bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.lights):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)


def build(S):
    set_metric_units()
    reset_collections(S)
    asset = get_collection(S["collection"])
    dress = get_collection(S["dress_collection"])
    mats = {name: principled_material(name, **cfg) for name, cfg in S["materials"].items()}

    frame_bm, z_body = build_frame(S)
    glass_bm = build_glass(S, z_body)
    candle_bm, z_candle_top = build_candle(S, z_body)
    flame_bm = build_flame(S, z_candle_top)

    objs = []
    for name, bm, mat in (("SM_Lantern_Frame", frame_bm, "M_Lantern_Iron"),
                          ("SM_Lantern_Glass", glass_bm, "M_Lantern_Glass"),
                          ("SM_Lantern_Candle", candle_bm, "M_Lantern_Wax"),
                          ("SM_Lantern_Flame", flame_bm, "M_Lantern_Flame")):
        box_project_uvs(bm, margin=0.002)
        objs.append(mesh_object_from_bmesh(name, bm, asset, mats[mat]))
        bm.free()

    # Preview-only glow light inside the glass (not exported). Hidden from glossy (playbook).
    L = S["glow_light"]
    ld = bpy.data.lights.new("LGT_Lantern_Glow", "POINT")
    ld.energy = L["energy_w"]
    ld.color = hex_to_linear(L["color_hex"])[:3]
    ld.shadow_soft_size = L["radius"]
    lo = bpy.data.objects.new("LGT_Lantern_Glow", ld)
    dress.objects.link(lo)
    flame = bpy.data.objects["SM_Lantern_Flame"]
    lo.location = Vector((0, 0, max(Vector(c).z for c in flame.bound_box) - 0.01))
    hide_from_glossy(lo)
    # Round 4: the light sits inside the flame and flooded its diffuse colour to near-white.
    # Light linking: the glow lights everything except the flame (flame colour = its emission).
    recv = bpy.data.collections.get("LL_Lantern_Glow_Receivers") or bpy.data.collections.new("LL_Lantern_Glow_Receivers")
    if flame.name not in recv.objects:
        recv.objects.link(flame)
    lo.light_linking.receiver_collection = recv
    idx = list(recv.objects).index(flame)  # collection_objects is index-aligned with objects
    recv.collection_objects[idx].light_linking.link_state = "EXCLUDE"

    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    tris = {}
    for o in objs:
        me = o.evaluated_get(dg).to_mesh()
        tris[o.name] = sum(len(p.vertices) - 2 for p in me.polygons)
        o.evaluated_get(dg).to_mesh_clear()
    return {"objects": [o.name for o in objs], "tris": tris, "total_tris": sum(tris.values()),
            "budget": S["tri_budget_total"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--new", action="store_true", help="start from an empty scene (headless only)")
    ap.add_argument("--save", action="store_true", help="save as projects/models/hero_lantern/hero_lantern_vNNN.blend")
    args = parse(ap)
    S = load_spec()
    if args.new:
        if not bpy.app.background:
            raise SystemExit("--new is only allowed headless; it would wipe the open scene")
        bpy.ops.wm.read_factory_settings(use_empty=True)
    result = build(S)
    if args.save:
        result["saved"] = save_versioned(HERE, S["name"])
    print("BUILD_RESULT " + json.dumps(result))


if __name__ == "__main__":
    main()
