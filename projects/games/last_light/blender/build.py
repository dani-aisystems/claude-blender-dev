"""Build THE LAST LIGHT's lighthouse exterior and watch room procedurally from spec.py.

v3: reference reconstruction (REFERENCE_SPEC.md): circular room, R1 floor plan.

Headless:  tools/bl -P projects/games/last_light/blender/build.py -- --new --save
Collections (only these are replaced):
  ASSET_lighthouse   tower, gallery catwalk, exhaust stack, roof, lantern, dome, PT_optic
  ASSET_watch_room   interior: shell, floor, ceiling, furniture, devices, hooks
Hook naming (Godot binds by name, see DESIGN.md):
  PT_/NDL_ articulated parts: pivot at origin, rotation axis = local Z (Godot local Y)
  LMP_ lamps, SCR_ screens, GLS_ glass, COL_*-convcolonly collision, IA_/FOCUS_/SPAWN_/LIGHT_ empties
Static geometry is merged per material ("buckets") to keep draw calls low.
"""

import argparse
import importlib.util
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WS = HERE.parents[3]
sys.path.insert(0, str(WS / "scripts"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from lib.bl_args import parse  # noqa: E402
from lib.scene_utils import (box_project_uvs, get_collection, principled_material,  # noqa: E402
                             save_versioned, set_metric_units)


def load_spec():
    s = importlib.util.spec_from_file_location("ll_spec", HERE / "spec.py")
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m.SPEC


S = load_spec()
R = S["room"]
F = R["floor_z"]
CEIL = R["ceiling_z"]
H = CEIL - F
R_IN = R["r_in"]
R_OUT = R_IN + R["wall"]

# ------------------------------------------------------------------ materials

MATS = {
    # name: (base hex, roughness, metallic, extra). Godot swaps most of these for textured PBR by name.
    "M_LL_Concrete": ("#7D7A73", 0.85, 0.0, {}),
    "M_LL_ConcreteExt": ("#8A8780", 0.9, 0.0, {}),
    "M_LL_Stone": ("#5E5A54", 0.9, 0.0, {}),
    "M_LL_Floor": ("#3E3C38", 0.45, 0.0, {}),
    "M_LL_Wood": ("#4A3020", 0.6, 0.0, {}),
    "M_LL_WoodDark": ("#2C1E15", 0.55, 0.0, {}),
    "M_LL_SteelPaint": ("#45534B", 0.55, 0.35, {}),
    "M_LL_SteelRust": ("#3F3A35", 0.7, 0.6, {}),
    "M_LL_Iron": ("#1E2022", 0.5, 0.7, {}),
    "M_LL_Brass": ("#A8823C", 0.32, 1.0, {}),
    "M_LL_Bakelite": ("#141212", 0.35, 0.0, {}),
    "M_LL_EngineGreen": ("#55705A", 0.5, 0.4, {}),
    "M_LL_Red": ("#8E1F18", 0.45, 0.1, {}),
    "M_LL_Rope": ("#9C8459", 0.9, 0.0, {}),
    "M_LL_Glass": ("#A9BCC4", 0.04, 0.0, {"alpha": 0.18}),
    "M_LL_Lens": ("#D8E4E0", 0.02, 0.0, {"alpha": 0.35}),
    "M_LL_Copper": ("#4F7A6C", 0.6, 0.6, {}),
    "M_LL_Paper": ("#E3DCC6", 0.9, 0.0, {}),
    "M_LL_Leather": ("#5B1F18", 0.55, 0.0, {}),
    "M_LL_Ceramic": ("#E8E4DA", 0.3, 0.0, {}),
    # Stage 1 iteration 4 props (Godot: materials.gd PLAIN)
    "M_LL_ClothBlue": ("#1F2B47", 0.85, 0.0, {}),
    "M_LL_Whisky": ("#6E3C10", 0.12, 0.0, {}),
    "M_LL_Oilskin": ("#52451F", 0.3, 0.0, {}),     # waxed olive, the Visitor's coat colour
    "M_LL_Lamp": ("#FFE2B0", 0.4, 0.0, {"emission_hex": "#FFB45C", "emission_strength": 2.0}),
    "M_LL_LampRed": ("#8A1A12", 0.4, 0.0, {"emission_hex": "#FF2A1A", "emission_strength": 0.0}),
    "M_LL_LampGreen": ("#1A5A2A", 0.4, 0.0, {"emission_hex": "#40FF70", "emission_strength": 0.0}),
    "M_LL_LampAmber": ("#6A4810", 0.4, 0.0, {"emission_hex": "#FFAA20", "emission_strength": 0.0}),
    "M_LL_Screen": ("#06140C", 0.2, 0.0, {}),
    "M_LL_Collision": ("#FF00FF", 1.0, 0.0, {}),
}
TEXTURED = {"M_LL_Atlas": "T_LL_Atlas.png", "M_LL_Chart": "T_LL_Chart.png", "M_LL_Rose": "T_LL_Rose.png",
            "M_LL_Rug": "T_LL_Rug.png",
            "M_LL_Photo": "T_LL_Photo.png", "M_LL_Logbook": "T_LL_Logbook.png",   # documents.py (Iteration A)
            "M_LL_Props": "T_LL_Props.png"}                                    # documents.py (Stage 1 iteration 4)


def textured_material(name, image_path):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(image_path), check_existing=True)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.6
    rough_path = Path(image_path).with_name(Path(image_path).stem + "_rough.png")
    if rough_path.exists():          # Stage 1 iteration 5: per-texel roughness (glTF packs it as metallicRoughness)
        rt = nt.nodes.new("ShaderNodeTexImage")
        rt.image = bpy.data.images.load(str(rough_path), check_existing=True)
        rt.image.colorspace_settings.name = "Non-Color"
        nt.links.new(rt.outputs["Color"], bsdf.inputs["Roughness"])
        bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def material(name):
    if name in TEXTURED:
        return textured_material(name, HERE / "tex" / TEXTURED[name])
    base, rough, metal, extra = MATS[name]
    return principled_material(name, base, roughness=rough, metallic=metal, **extra)


# ------------------------------------------------------------------ frames + primitives

def wall_frame(bearing_deg):
    """Columns: right (along the wall, seen from inside), outward, up."""
    b = math.radians(bearing_deg)
    return Vector((math.cos(b), -math.sin(b), 0.0)), Vector((math.sin(b), math.cos(b), 0.0)), Vector((0, 0, 1))


def dp(bearing, along, z, dist):
    """Point at `dist` from the room centre on the bearing, `along` to the right, `z` above the floor."""
    r, o, u = wall_frame(bearing)
    return o * dist + r * along + u * (F + z)


def back_dist(width, gap=0.03):
    """Distance from the centre to the back plane of a flat device of `width` against the curved wall."""
    return math.sqrt(R_IN ** 2 - (width / 2) ** 2) - gap


def basis(x, y, z):
    return Matrix((x, y, z)).transposed()   # columns


def basis_z(z_axis, hint=Vector((0, 0, 1))):
    z = z_axis.normalized()
    if abs(z.dot(hint.normalized())) > 0.95:
        hint = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))
    x = hint.cross(z).normalized()
    y = z.cross(x).normalized()
    return basis(x, y, z)


def wb(bearing):
    r, o, u = wall_frame(bearing)
    return basis(r, o, u)


def m4(loc, b3=None):
    m = (b3 or Matrix.Identity(3)).to_4x4()
    m.translation = loc
    return m


BEVEL = {"on": True, "max": 0.006}
STAIR_DEPTH = 0.62                    # stair bulkhead depth into the room (Stage 1 iteration 3)    # Stage 1 iteration 2: small chamfers so edges catch the light


def box(bm, loc, size, b3=None, bevel=None, segs=1):
    """Box; every box thicker than 12 mm gets a small chamfer (min(6 mm, 20 % of its thinnest side)).
    bevel=0 disables it (colliders); a number forces that width; segs > 1 rounds the edge."""
    mat = m4(Vector(loc), b3) @ Matrix.Diagonal((*size, 1.0))
    verts = bmesh.ops.create_cube(bm, size=1.0, matrix=mat)["verts"]
    thin = min(abs(v) for v in size)
    w = bevel if bevel is not None else (min(BEVEL["max"], 0.2 * thin) if BEVEL["on"] and thin >= 0.012 else 0.0)
    if w <= 0.0:
        return verts
    faces = list({f for v in verts for f in v.link_faces})
    edges = list({e for v in verts for e in v.link_edges})
    out = bmesh.ops.bevel(bm, geom=edges, offset=w, offset_type="OFFSET", segments=segs, profile=0.5,
                          affect="EDGES", clamp_overlap=True)
    keep = [f for f in faces if f.is_valid] + list(out.get("faces", []))
    return list({v for f in keep for v in f.verts})


def cyl(bm, loc, r1, r2, depth, segs, b3=None, caps=True):
    """Cylinder/cone along the frame's local Z, centred at loc."""
    return bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=segs, radius1=r1, radius2=r2,
                                 depth=depth, matrix=m4(Vector(loc), b3))["verts"]


def sphere(bm, loc, radius, u=12, v=8):
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius, matrix=m4(Vector(loc)))


def torus(bm, loc, R_, r_, nu=20, nv=8, b3=None):
    b3 = b3 or Matrix.Identity(3)
    rings = []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        ring = []
        for j in range(nv):
            c = 2 * math.pi * j / nv
            d = R_ + r_ * math.cos(c)
            ring.append(bm.verts.new(Vector(loc) + b3 @ Vector((d * math.cos(a), d * math.sin(a), r_ * math.sin(c)))))
        rings.append(ring)
    for i in range(nu):
        for j in range(nv):
            a, b2 = rings[i], rings[(i + 1) % nu]
            bm.faces.new((a[j], b2[j], b2[(j + 1) % nv], a[(j + 1) % nv]))


def hexa(bm, pts):
    v = [bm.verts.new(p) for p in pts]
    for f in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        bm.faces.new([v[i] for i in f])
    return v


def ibeam(bm, loc, length, b3, h=0.24, w=0.14, tw=0.02, tf=0.02):
    """Closed, manifold I-beam along the frame's local Y (profile in local X/Z). Replaces three
    overlapping boxes whose coplanar web/flange faces z-fought (Stage 0 audit, I-beams read as black)."""
    hx, hz, t = w / 2, h / 2, tw / 2
    prof = [(-hx, -hz), (hx, -hz), (hx, -hz + tf), (t, -hz + tf), (t, hz - tf), (hx, hz - tf),
            (hx, hz), (-hx, hz), (-hx, hz - tf), (-t, hz - tf), (-t, -hz + tf), (-hx, -hz + tf)]
    ends = []
    for y in (-length / 2, length / 2):
        ends.append([bm.verts.new(Vector(loc) + b3 @ Vector((x, y, z))) for x, z in prof])
    a, b = ends
    faces = []
    for i in range(12):
        j = (i + 1) % 12
        faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    for e in (a, b):
        for cap in ((0, 1, 2, 3, 10, 11), (10, 3, 4, 9), (9, 4, 5, 6, 7, 8)):
            faces.append(bm.faces.new([e[k] for k in cap]))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return a + b


def seg_cyl(bm, p0, p1, r, segs=8):
    d = Vector(p1) - Vector(p0)
    cyl(bm, (Vector(p0) + Vector(p1)) / 2, r, r, d.length, segs, basis_z(d))


def disc_uv(bm, uv, center, b3, radius, segs, cell, cell_px=512, atlas_px=2048):
    """Flat disc (normal = local Z), UV-mapped to an atlas cell (cell=None: whole texture)."""
    if cell is None:
        cx, cy, cell_px, atlas_px, pad = 0, 0, 1, 1, 0.0
    else:
        cx, cy, pad = (cell % 4) * cell_px, (cell // 4) * cell_px, 8.0
    rim = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        rim.append((bm.verts.new(Vector(center) + b3 @ Vector((radius * math.cos(a), radius * math.sin(a), 0))), a))
    c = bm.verts.new(Vector(center))

    def uv_of(a, rr):
        px = cx + cell_px / 2 + rr * math.cos(a) * (cell_px / 2 - pad)
        py = cy + cell_px / 2 - rr * math.sin(a) * (cell_px / 2 - pad)
        return (px / atlas_px, 1.0 - py / atlas_px)
    for i in range(segs):
        (v0, a0), (v1, a1) = rim[i], rim[(i + 1) % segs]
        f = bm.faces.new((c, v0, v1))
        for loop, val in zip(f.loops, (uv_of(0, 0), uv_of(a0, 1), uv_of(a1, 1))):
            loop[uv].uv = val


def quad_uv(bm, uv, center, b3, w, h, uv_rect):
    u0, v0, u1, v1 = uv_rect
    corners = [(-w / 2, -h / 2, u0, v0), (w / 2, -h / 2, u1, v0), (w / 2, h / 2, u1, v1), (-w / 2, h / 2, u0, v1)]
    vs = [bm.verts.new(Vector(center) + b3 @ Vector((x, y, 0))) for x, y, _, _ in corners]
    f = bm.faces.new(vs)
    for loop, (_, _, u, v) in zip(f.loops, corners):
        loop[uv].uv = (u, v)


def atlas_cell_rect(cell, sub_row=None):
    c = S["atlas"]["cell"]
    N = S["atlas"]["size"]
    x0, y0 = (cell % 4) * c, (cell // 4) * c
    if sub_row is None:
        return (x0 / N, 1 - (y0 + c) / N, (x0 + c) / N, 1 - y0 / N)
    ys = y0 + sub_row * 128
    return (x0 / N, 1 - (ys + 128) / N, (x0 + c) / N, 1 - ys / N)


def label_rect(text):
    labels = S["atlas"]["labels"]
    i = labels.index(text)
    return atlas_cell_rect(S["atlas"]["cells"]["labels_" + "abcd"[i // 4]], i % 4)


CELLS = S["atlas"]["cells"]


# ------------------------------------------------------------------ scene plumbing

class Builder:
    def __init__(self, coll):
        self.coll = coll
        self.buckets = {}

    def bm(self, mat, prefix="SM_Room"):
        key = (prefix, mat)
        if key not in self.buckets:
            bm = bmesh.new()
            bm.loops.layers.uv.new("UVMap")
            self.buckets[key] = bm
        return self.buckets[key]

    def uv(self, bm):
        return bm.loops.layers.uv["UVMap"]

    def flush(self):
        for (prefix, mat), bm in self.buckets.items():
            self.mesh_obj(f"{prefix}_{mat.replace('M_LL_', '')}", bm, mat, keep_uv=mat in TEXTURED)
        self.buckets = {}

    def mesh_obj(self, name, bm, mat, matrix=None, keep_uv=False, extra_mats=()):
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        if not keep_uv and mat not in ("M_LL_Glass",):
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if not keep_uv:
            box_project_uvs(bm)
        me = bpy.data.meshes.new(name)
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        # Stage 1 iteration 2: smooth shading split at 35 degrees, so cylinders, the round wall and tori
        # shade smoothly while box edges stay crisp (the glTF exporter writes the split normals).
        if not name.startswith("COL_"):
            for poly in me.polygons:
                poly.use_smooth = True
            if hasattr(me, "set_sharp_from_angle"):
                me.set_sharp_from_angle(angle=math.radians(35.0))
        for mname in (mat, *extra_mats):
            me.materials.append(material(mname))
        obj = bpy.data.objects.new(name, me)
        self.coll.objects.link(obj)
        if matrix is not None:
            obj.matrix_world = matrix
        return obj

    def part(self, name, mat, loc, b3, build_fn, keep_uv=False, extra_mats=()):
        """Articulated part. build_fn may tag faces with material_index 1.. for extra_mats (e.g. a white
        index line on a knob) so the detail rotates with the part without a child node."""
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        build_fn(bm, uvl)
        return self.mesh_obj(name, bm, mat, matrix=m4(Vector(loc), b3), keep_uv=keep_uv, extra_mats=extra_mats)

    def empty(self, name, loc, half_size=(0.1, 0.1, 0.1), b3=None, kind="CUBE"):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = kind
        e.matrix_world = m4(Vector(loc), b3) @ Matrix.Diagonal((*half_size, 1.0))
        self.coll.objects.link(e)
        return e

    def collider(self, name, loc, size, b3=None):
        bm = bmesh.new()
        bm.loops.layers.uv.new("UVMap")
        box(bm, (0, 0, 0), size, bevel=0.0)
        obj = self.mesh_obj(f"COL_{name}-convcolonly", bm, "M_LL_Collision")
        obj.matrix_world = m4(Vector(loc), b3)
        obj.data.transform(obj.matrix_basis)
        obj.matrix_basis = Matrix.Identity(4)
        return obj


# ------------------------------------------------------------------ control parts

def knob_fn(radius, height):
    def f(bm, uv):
        cyl(bm, (0, 0, height / 2), radius, radius * 0.85, height, 20)
        cyl(bm, (0, 0, height * 0.12), radius * 1.15, radius * 1.15, height * 0.24, 20)
        box(bm, (0, radius * 0.55, height + 0.004), (radius * 0.18, radius * 1.0, 0.008))
    return f


def lathe(bm, center, b3, profile, segs=32):
    """Closed solid of revolution about the frame's local Z. profile = closed loop of (radius, z) points.
    Used for gauge bezels and flanges: a RING, so nothing covers the dial face (Iteration A)."""
    rings = []
    for rr, zz in profile:
        rings.append([bm.verts.new(Vector(center) + b3 @ Vector((rr * math.cos(2 * math.pi * i / segs),
                                                                   rr * math.sin(2 * math.pi * i / segs), zz)))
                      for i in range(segs)])
    n = len(rings)
    out = []
    for k in range(n):
        a, b2 = rings[k], rings[(k + 1) % n]
        for i in range(segs):
            j = (i + 1) % segs
            out.append(bm.faces.new((a[i], a[j], b2[j], b2[i])))
    return out


def prism(bm, pts, z0, z1):
    """Convex flat polygon (local XY) extruded from z0 to z1. Returns its verts."""
    lo = [bm.verts.new((x, y, z0)) for x, y in pts]
    hi = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    return lo + hi


def made(bm, fn):
    """Run fn() and return the verts it added to bm (to tag() them with a second material)."""
    before = set(bm.verts)
    fn()
    return [v for v in bm.verts if v not in before]


def tag(verts, index):
    for v in verts:
        for f in v.link_faces:
            f.material_index = index


# ------------------------------------------------------------------ small-prop helpers (Stage 1 iteration 5)
# The room is at its 32-material cap: small props are one material (M_LL_Props, documents.py atlas) whose
# colours come from flat swatches and whose roughness comes from T_LL_Props_rough.png.

PA = S["props_atlas"]
DC = S["desk_chart"]


def sw_uv(name):
    sw, A = PA["swatch"], PA["size"]
    i = list(PA["swatches"]).index(name)
    x = sw["x0"] + (i % sw["cols"]) * sw["px"] + sw["px"] / 2
    y = sw["y0"] + (i // sw["cols"]) * sw["px"] + sw["px"] / 2
    return (x / A, 1 - y / A)


def region_uv(name, u, v):
    """(u, v) in 0..1 inside an atlas region (v = 0 at the region's bottom edge) -> mesh UV."""
    x0, y0, x1, y1 = PA["regions"][name]
    A = PA["size"]
    return ((x0 + u * (x1 - x0)) / A, 1 - (y1 - v * (y1 - y0)) / A)


def region_rect(name, u0=0.0, v0=0.0, u1=1.0, v1=1.0):
    a, b = region_uv(name, u0, v0), region_uv(name, u1, v1)
    return (a[0], a[1], b[0], b[1])


def solid(B, swatch, fn, prefix="SM_Room"):
    """Run fn(bm) to add CLOSED geometry to the props bucket, fix its winding (textured buckets skip the
    flush-time recalc) and paint every face with one swatch."""
    bm = B.bm("M_LL_Props", prefix)
    vs = made(bm, lambda: fn(bm))
    faces = list({f for v in vs for f in v.link_faces})
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    uvl, uv = B.uv(bm), sw_uv(swatch)
    for f in faces:
        for lp in f.loops:
            lp[uvl].uv = uv
    return vs


def lathe_uv(bm, uvl, center, b3, prof, segs, uvf):
    """Open solid of revolution about local Z with a UV wrap: prof = [(r, z, v)], u = angle / 2 pi.
    segs + 1 columns so the seam keeps its UVs. Outward winding when the profile runs outside-up."""
    rings = []
    for rr, zz, _ in prof:
        rings.append([bm.verts.new(Vector(center) + b3 @ Vector((rr * math.cos(2 * math.pi * i / segs),
                                                                   rr * math.sin(2 * math.pi * i / segs), zz)))
                      for i in range(segs + 1)])
    faces = []
    for k in range(len(prof) - 1):
        a, b2 = rings[k], rings[k + 1]
        for i in range(segs):
            f = bm.faces.new((a[i], a[i + 1], b2[i + 1], b2[i]))
            for lp, (ii, kk) in zip(f.loops, ((i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1))):
                lp[uvl].uv = uvf(ii / segs, prof[kk][2])
            faces.append(f)
    return faces


def frames(pts, n0=None):
    """Parallel-transport frames (T, N, B) along a polyline."""
    pts = [Vector(p) for p in pts]
    T = [(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(len(pts))]
    ref = Vector(n0) if n0 is not None else (Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0)))
    N = (ref - T[0] * ref.dot(T[0])).normalized()
    out = []
    for i, t in enumerate(T):
        if i:
            N = (N - t * N.dot(t)).normalized()
        out.append((t, N, t.cross(N)))
    return pts, out


def sweep(bm, pts, r, segs=8, ry=None, n0=None, caps=True):
    """Closed tube along a polyline (elliptical when ry is given: r along N, ry along B)."""
    pts, fr = frames(pts, n0)
    ry = r if ry is None else ry
    rings = []
    for p, (t, N, Bv) in zip(pts, fr):
        rings.append([bm.verts.new(p + N * (r * math.cos(2 * math.pi * j / segs)) + Bv * (ry * math.sin(2 * math.pi * j / segs)))
                      for j in range(segs)])
    for a, b2 in zip(rings, rings[1:]):
        for j in range(segs):
            k = (j + 1) % segs
            bm.faces.new((a[j], a[k], b2[k], b2[j]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])


def bezier(p0, p1, p2, p3, n):
    p0, p1, p2, p3 = (Vector(p) for p in (p0, p1, p2, p3))
    return [p0 * (1 - t) ** 3 + p1 * 3 * t * (1 - t) ** 2 + p2 * 3 * t * t * (1 - t) + p3 * t ** 3
            for t in (i / (n - 1) for i in range(n))]


def resample(pts, step):
    pts = [Vector(p) for p in pts]
    out, acc = [pts[0]], 0.0
    for a, b in zip(pts, pts[1:]):
        seg = (b - a).length
        while acc + seg >= step:
            t = (step - acc) / seg
            a = a + (b - a) * t
            seg = (b - a).length
            out.append(a.copy())
            acc = 0.0
        acc += seg
    if (out[-1] - pts[-1]).length > 1e-6:
        out.append(pts[-1])
    return out


def coil(path, radius, pitch, per_turn=8, n0=(0, 0, 1)):
    """Helix wound around a polyline: a coiled telephone-style cord."""
    pts, fr = frames(resample(path, pitch / per_turn), n0)
    return [p + N * (radius * math.cos(2 * math.pi * i / per_turn)) + Bv * (radius * math.sin(2 * math.pi * i / per_turn))
            for i, (p, (t, N, Bv)) in enumerate(zip(pts, fr))]


def rot_about(axis, deg):
    return Matrix.Rotation(math.radians(deg), 3, Vector(axis))


def needle_fn(length, width=0.006):
    """Tapered pointer with a counterweight tail and a raised hub. Local Z layers (part sits 4 mm above
    the dial face): blade 5-8 mm, hub 3-11 mm, so needle + hub stay below the gauge glass (Iteration A)."""
    def f(bm, uv):
        w = width
        prism(bm, [(-w * 0.55, -0.22 * length), (w * 0.55, -0.22 * length), (w * 0.3, 0.86 * length),
                   (0.0, length), (-w * 0.3, 0.86 * length)], 0.005, 0.008)
        cyl(bm, (0, -0.21 * length, 0.0065), w * 0.85, w * 0.85, 0.003, 12)     # rounded counterweight tail
        cyl(bm, (0, 0, 0.007), w * 2.0, w * 1.6, 0.008, 16)                     # hub / pivot boss
    return f


def selector_fn(radius):
    """Rotary selector (bar knob): fluted skirt, body, tapered pointer bar with a WHITE index inlay
    (material index 1) so the active position reads from the first-person view."""
    def f(bm, uv):
        cyl(bm, (0, 0, 0.006), radius * 1.3, radius * 1.25, 0.012, 24)            # skirt on the plate
        for k in range(24):                                                        # flutes
            a = 2 * math.pi * k / 24
            box(bm, (radius * 1.27 * math.cos(a), radius * 1.27 * math.sin(a), 0.006), (0.004, 0.006, 0.011),
                basis_z(Vector((0, 0, 1)), Vector((math.cos(a), math.sin(a), 0))))
        cyl(bm, (0, 0, 0.022), radius * 0.78, radius * 0.7, 0.022, 20)            # body
        L = radius * 1.3                                                           # tip stops at the index tick
        prism(bm, [(-radius * 0.3, -L * 0.5), (radius * 0.3, -L * 0.5), (radius * 0.2, L * 0.92),
                   (0.0, L), (-radius * 0.2, L * 0.92)], 0.012, 0.046)               # pointer bar
        tag(prism(bm, [(-0.0035, 0.0), (0.0035, 0.0), (0.0035, L * 0.88), (0.0, L * 0.95), (-0.0035, L * 0.88)],
                  0.04, 0.0475), 1)                                                  # index line, 1.5 mm proud
    return f


def toggle_fn(length=0.08):
    def f(bm, uv):
        cyl(bm, (0, 0, 0), 0.018, 0.018, 0.04, 12)
        box(bm, (0, length / 2, 0), (0.016, length, 0.016))
        cyl(bm, (0, length, 0), 0.016, 0.016, 0.03, 12)
    return f


def gauge(B, name, center, b3, radius, cell, needle_mat="M_LL_Bakelite"):
    """Panel instrument, layered along the face normal with no two surfaces in one plane (Iteration A):
         case   (dark iron cup)            -30 .. -4 mm   (behind the face)
         dial   (atlas disc)                 +3 mm
         needle (NDL_ part at +4 mm)        +7 .. +15 mm  (blade + hub)
         glass  (disc inside the bezel)    +18.5 .. +21.5 mm
         bezel  (brass RING, inner 0.985 r) -6 .. +24 mm
    Before: the bezel was a solid brass cylinder whose top cap sat exactly at the dial plane (+3 mm), so the
    two z-fought ("jagged brass shapes through the face", IMG_3117 / IMG_3121), and the hub top touched the
    glass. One shared function, so the fix covers all eight dials."""
    z = b3.col[2]
    c = Vector(center)
    r = radius
    cyl(B.bm("M_LL_Iron"), c - z * 0.017, r * 1.06, r * 1.06, 0.026, 32, b3)
    lathe(B.bm("M_LL_Brass"), c, b3, [(r * 0.985, -0.006), (r * 1.15, -0.006), (r * 1.15, 0.004),
                                       (r * 1.11, 0.018), (r * 1.05, 0.024), (r * 0.985, 0.024)], 40)
    for k in range(4):   # bezel screws, on the bezel flange
        a = math.pi / 4 + k * math.pi / 2
        sphere(B.bm("M_LL_Iron"), c + b3 @ Vector((r * 1.12 * math.cos(a), r * 1.12 * math.sin(a), 0.009)), max(0.003, r * 0.035), 8, 5)
    atlas = B.bm("M_LL_Atlas")
    disc_uv(atlas, B.uv(atlas), c + z * 0.003, b3, r, 48, cell)
    B.part(f"NDL_{name}", needle_mat, c + z * 0.004, b3, needle_fn(r * 0.86, max(0.004, r * 0.065)))
    cyl(B.bm("M_LL_Glass", "SM_GaugeGlass"), c + z * 0.02, r * 0.99, r * 0.99, 0.003, 40, b3)


def lamp(B, name, center, b3, color, r=0.018):
    z = b3.col[2]
    cyl(B.bm("M_LL_Brass"), Vector(center) - z * 0.004, r * 1.5, r * 1.5, 0.012, 16, b3)
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    sphere(bm, Vector(center) + z * 0.006, r)
    B.mesh_obj(f"LMP_{name}", bm, {"red": "M_LL_LampRed", "green": "M_LL_LampGreen", "amber": "M_LL_LampAmber"}[color])


def label(B, text, center, b3, w=0.16):
    atlas = B.bm("M_LL_Atlas")
    quad_uv(atlas, B.uv(atlas), Vector(center) + b3.col[2] * 0.002, b3, w, w / 4, label_rect(text))


def face_frame(bearing, along, z, dist, tilt_deg=0.0):
    """Frame on a device face facing the room centre: X right, Y up-the-surface, Z = normal."""
    r, o, u = wall_frame(bearing)
    t = math.radians(tilt_deg)
    n = (-o) * math.cos(t) + u * math.sin(t)
    y = n.cross(r).normalized()
    return basis(r, y, n), dp(bearing, along, z, dist)


def rivets(B, p0, p1, n, b3, r=0.007):
    for k in range(n):
        p = Vector(p0).lerp(Vector(p1), (k + 0.5) / n)
        sphere(B.bm("M_LL_Iron"), p + b3.col[2] * 0.002, r, 6, 4)


def toggle_frame(fb3):
    return basis(fb3.col[1], fb3.col[2], fb3.col[0])   # lever sticks out (Y = normal), hinge = panel right


def drop(B, bearing, along, z_top, z_bottom, dist, r=0.02):
    seg_cyl(B.bm("M_LL_Iron", "SM_RoomPipes"), dp(bearing, along, z_top, dist), dp(bearing, along, z_bottom, dist), r)
    # Stage 1 iteration 5: saddle clips back to the wall (the drops floated in front of it)
    wall = math.sqrt(max(R_IN ** 2 - along ** 2, 0.0))
    gap = wall - dist
    if 0.0 < gap < 0.12:
        n = max(2, int(abs(z_top - z_bottom) / 0.55) + 1)
        for k in range(n):
            z = z_bottom + (z_top - z_bottom) * (k + 0.5) / n
            box(B.bm("M_LL_Iron", "SM_RoomPipes"), dp(bearing, along, z, (dist + wall) / 2 + r * 0.25),
                (r * 2.6, gap + r * 0.5, 0.028), wb(bearing), bevel=0.0)


# ------------------------------------------------------------------ room shell

def in_window(b):
    return any(abs(((b - c + 180) % 360) - 180) < R["bay_half_deg"] for c in R["window_bays"])


def ring_seg(bm, b0, b1, r0, r1, z0, z1):
    def P(b, rr, z):
        a = math.radians(b)
        return Vector((rr * math.sin(a), rr * math.cos(a), F + z))
    return hexa(bm, [P(b0, r0, z0), P(b0, r1, z0), P(b1, r1, z0), P(b1, r0, z0),
                     P(b0, r0, z1), P(b0, r1, z1), P(b1, r1, z1), P(b1, r0, z1)])


def build_shell(B):
    N = R["segments"]
    W = R["window"]
    conc = B.bm("M_LL_Concrete")
    for i in range(N):
        b0, b1 = -180 + 360 * i / N, -180 + 360 * (i + 1) / N
        if in_window((b0 + b1) / 2):
            ring_seg(conc, b0, b1, R_IN, R_OUT, 0, W["sill"])
            ring_seg(conc, b0, b1, R_IN, R_OUT, W["top"], H)
            ring_seg(B.bm("M_LL_WoodDark"), b0, b1, R_IN - 0.035, R_IN, 0.05, W["sill"] - 0.04)          # wainscot
            ring_seg(B.bm("M_LL_Wood"), b0, b1, R_IN - 0.14, R_IN + 0.12, W["sill"] - 0.04, W["sill"])     # sill board
            # raised panelling: top and bottom rails proud of the recessed wainscot (stiles below)
            ring_seg(B.bm("M_LL_Wood", "SM_Wainscot"), b0, b1, R_IN - 0.055, R_IN - 0.035, 0.74, 0.86)
            ring_seg(B.bm("M_LL_Wood", "SM_Wainscot"), b0, b1, R_IN - 0.055, R_IN - 0.035, 0.05, 0.17)
        else:
            ring_seg(conc, b0, b1, R_IN, R_OUT, 0, H)
            ring_seg(B.bm("M_LL_Iron", "SM_RoomBand"), b0, b1, R_IN - 0.014, R_IN, 0.0, 0.14)          # dark skirting
            # oak dado rail at the paint line (room_pbr dado_h = 1.05): a stepped half-round
            ring_seg(B.bm("M_LL_Wood", "SM_DadoRail"), b0, b1, R_IN - 0.022, R_IN, 1.03, 1.07)
            ring_seg(B.bm("M_LL_Wood", "SM_DadoRail"), b0, b1, R_IN - 0.012, R_IN, 1.022, 1.078)
        # stepped crown moulding where the wall meets the ceiling (all the way round)
        ring_seg(B.bm("M_LL_Concrete", "SM_Cornice"), b0, b1, R_IN - 0.06, R_IN, H - 0.06, H)
        ring_seg(B.bm("M_LL_Concrete", "SM_Cornice"), b0, b1, R_IN - 0.03, R_IN, H - 0.11, H - 0.06)
    for i in range(32):
        b = -180 + 360 * (i + 0.5) / 32
        r, o, u = wall_frame(b)
        B.collider(f"wall_{i}", o * (R_IN + 0.3) + u * (F + H / 2),
                   (2 * (R_IN + 0.3) * math.tan(math.pi / 32) + 0.1, 0.6, H), basis(r, o, u))
    # window bays: flat glazing on the chord, heavy riveted steel frames, 2x2 panes (R1-R3)
    for c in R["window_bays"]:
        r, o, u = wall_frame(c)
        bs = basis(r, o, u)
        gr = W["glass_r"]
        chord = 2 * gr * math.tan(math.radians(R["bay_half_deg"])) * 0.98
        z0, z1 = W["sill"], W["top"]
        zc, hh = (z0 + z1) / 2, z1 - z0
        fr = W["frame"]
        steel = B.bm("M_LL_SteelRust", "SM_WinFrame")

        def at(along, z, inset=0.0):
            return o * (gr - inset) + r * along + u * (F + z)
        for s in (-1, 1):
            box(steel, at(s * (chord / 2 - fr / 2), zc), (fr, 0.16, hh), bs)
        box(steel, at(0, z0 + fr / 2), (chord, 0.16, fr), bs)
        box(steel, at(0, z1 - fr / 2), (chord, 0.16, fr), bs)
        box(steel, at(0, zc), (fr * 0.75, 0.12, hh), bs)
        box(steel, at(0, z0 + hh * 0.55), (chord, 0.12, fr * 0.65), bs)
        fb3 = basis(r, u, -o)
        for s in (-1, 1):
            rivets(B, at(s * (chord / 2 - fr / 2), z0 + 0.05, 0.081), at(s * (chord / 2 - fr / 2), z1 - 0.05, 0.081), 9, fb3)
        rivets(B, at(-chord / 2 + 0.06, z1 - fr / 2, 0.081), at(chord / 2 - 0.06, z1 - fr / 2, 0.081), 12, fb3)
        gb = bmesh.new()
        gb.loops.layers.uv.new("UVMap")
        box(gb, at(0, zc, -0.01), (chord - 0.02, 0.012, hh - 0.02), bs)
        B.mesh_obj(f"GLS_window_{int(c) % 360:03d}", gb, "M_LL_Glass")
        box(steel, at(0, z1 + 0.04, 0.12), (chord + 0.1, 0.4, 0.08), bs)
        # wainscot stiles under this bay: 5 stiles -> 4 raised panels
        for k in range(5):
            sb_ = c + (k - 2) * (R["bay_half_deg"] * 2 / 4) * 0.94
            box(B.bm("M_LL_Wood", "SM_Wainscot"), dp(sb_, 0, (0.17 + 0.74) / 2, R_IN - 0.045), (0.07, 0.02, 0.57), wb(sb_))
        # Stage 1 iteration 5: glazing beads round each pane (room side) and two hinges per casement
        mx, tz = fr * 0.375, z0 + hh * 0.55
        bw = 0.014
        for (xa, xb) in ((-chord / 2 + fr, -mx), (mx, chord / 2 - fr)):
            for (za, zb) in ((z0 + fr, tz - fr * 0.325), (tz + fr * 0.325, z1 - fr)):
                xm, zm = (xa + xb) / 2, (za + zb) / 2
                for zz in (za + bw / 2, zb - bw / 2):
                    box(steel, at(xm, zz, 0.008), (xb - xa, 0.012, bw), bs, bevel=0.0)
                for xx in (xa + bw / 2, xb - bw / 2):
                    box(steel, at(xx, zm, 0.008), (bw, 0.012, zb - za - 2 * bw), bs, bevel=0.0)
        for sx in (-1, 1):
            for hz_ in (z0 + 0.22, z1 - 0.22):
                cyl(steel, at(sx * (chord / 2 - fr - 0.006), hz_, 0.082), 0.011, 0.011, 0.07, 10)
                box(steel, at(sx * (chord / 2 - fr - 0.03), hz_, 0.081), (0.04, 0.004, 0.06), bs, bevel=0.0)
        # brass casement fittings: a lever handle on the centre mullion and a stay on the bottom rail
        brass = B.bm("M_LL_Brass", "SM_WinBrass")
        hp = at(0.0, z0 + hh * 0.42, 0.075)
        cyl(brass, hp, 0.018, 0.018, 0.018, 12, fb3)
        box(brass, hp - o * 0.012 + r * 0.045, (0.09, 0.016, 0.012), bs)
        box(brass, at(-chord / 4, z0 + fr + 0.018, 0.07), (chord * 0.32, 0.014, 0.012), bs)
        cyl(brass, at(-chord / 4 - chord * 0.16, z0 + fr + 0.018, 0.07), 0.012, 0.012, 0.02, 10, fb3)
    # floor tiles inside the circle, with a hole for the stair well
    floor = B.bm("M_LL_Floor")
    cell = 0.25
    n = int((R_IN + 0.3) / cell) + 1
    sb = R["stair"]
    sr, so, _ = wall_frame(sb)
    for ix in range(-n, n):
        for iy in range(-n, n):
            cx, cy = (ix + 0.5) * cell, (iy + 0.5) * cell
            if math.hypot(cx, cy) > R_IN + 0.3:
                continue
            v = Vector((cx, cy, 0))
            # the stair hatch: only cells lying wholly inside the bulkhead (a cell centre inside but its edge
            # 10 cm out in the room opened a lit slot across the floor in front of the door)
            if abs(v.dot(sr)) < 0.6 - cell / 2 and back_dist(1.3, 0.0) - STAIR_DEPTH + cell / 2 + 0.02 < v.dot(so) < 3.4:
                continue
            box(floor, (cx, cy, F - 0.1), (cell, cell, 0.2), bevel=0.0)   # one seamless slab: no 25 cm tile grooves
    B.collider("floor", (0, 0, F - 0.25), (8, 8, 0.5))
    rose = B.bm("M_LL_Rose")
    disc_uv(rose, B.uv(rose), (0, 0, F + 0.002), Matrix.Identity(3), 0.62, 48, None)
    torus(B.bm("M_LL_Brass"), (0, 0, F + 0.003), 0.63, 0.012, 48, 6)
    # ceiling + steel I-beams (R2/R3)
    cyl(B.bm("M_LL_Concrete", "SM_RoomCeiling"), (0, 0, CEIL + 0.1), R_OUT, R_OUT, 0.2, 64)
    B.collider("ceiling", (0, 0, CEIL + 0.25), (8, 8, 0.5))
    rust = B.bm("M_LL_SteelPaint", "SM_CeilBeams")  # grey-green riveted steel; own bucket for the cutaway
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        d = Vector((math.sin(a), math.cos(a), 0))
        side = d.cross(Vector((0, 0, 1)))
        b3 = basis(side, d, Vector((0, 0, 1)))
        L = R_IN - 0.45
        c = d * (0.45 + L / 2) + Vector((0, 0, CEIL - 0.12))
        ibeam(rust, c, L, b3)
        rivets(B, c - d * (L / 2 - 0.1) + side * 0.012 + Vector((0, 0, -0.05)),
               c + d * (L / 2 - 0.1) + side * 0.012 + Vector((0, 0, -0.05)), 10, basis(d, Vector((0, 0, 1)), side))
    # riveted boss plate where the eight beams meet (was a plain torus)
    cyl(rust, (0, 0, CEIL - 0.03), 0.52, 0.52, 0.05, 40)
    cyl(rust, (0, 0, CEIL - 0.11), 0.4, 0.44, 0.12, 40)
    for k in range(16):
        a = 2 * math.pi * k / 16
        sphere(B.bm("M_LL_Iron", "SM_CeilBeams"), (0.47 * math.cos(a), 0.47 * math.sin(a), CEIL - 0.058), 0.01, 8, 5)
    for z, rr in ((2.78, 0.035), (2.92, 0.025)):
        torus(B.bm("M_LL_Iron", "SM_RoomPipes"), (0, 0, F + z), R_IN - 0.08, rr, 96, 8)
    for b in range(-180, 180, 20):
        box(B.bm("M_LL_Iron", "SM_RoomPipes"), dp(b, 0, 2.85, R_IN - 0.04), (0.03, 0.09, 0.22), wb(b))


# ------------------------------------------------------------------ navigation desk (R1/R3)

def build_desk(B):
    b = R["desk"]
    bs = wb(b)
    r, o, u = wall_frame(b)
    w, d, top = 2.2, 0.85, 0.78
    back = back_dist(w)
    c = back - d / 2
    # Stage 1 iteration 5: rounded (bullnose) oak top; drawer fronts with 6 mm reveals instead of 3 cm gaps,
    # brass bar pulls on posts, a lock on each top drawer, a black kick strip (was: flat brass slabs)
    box(B.bm("M_LL_Wood"), dp(b, 0, top - 0.025, c), (w, d, 0.05), bs, bevel=0.012, segs=3)
    box(B.bm("M_LL_WoodDark"), dp(b, 0, top - 0.06, c - d / 2 + 0.02), (w - 0.04, 0.03, 0.04), bs)
    front = c - (d - 0.06) / 2
    for s in (-1, 1):
        px = s * (w / 2 - 0.27)
        box(B.bm("M_LL_SteelPaint"), dp(b, px, (top - 0.05) / 2, c), (0.5, d - 0.06, top - 0.05), bs)
        box(B.bm("M_LL_Bakelite", "SM_Props"), dp(b, px, 0.04, front - 0.004), (0.5, 0.012, 0.08), bs, bevel=0.0)
        pitch = (top - 0.05 - 0.085) / 3
        for k in range(3):
            zc_ = 0.085 + pitch * (k + 0.5)
            box(B.bm("M_LL_SteelPaint"), dp(b, px, zc_, front - 0.008), (0.47, 0.016, pitch - 0.006), bs, bevel=0.003)
            brass = B.bm("M_LL_Brass", "SM_Props")
            pz = zc_ + pitch * 0.18
            for sx in (-1, 1):
                seg_cyl(brass, dp(b, px + sx * 0.05, pz, front - 0.016), dp(b, px + sx * 0.05, pz, front - 0.038), 0.005, 10)
                cyl(brass, dp(b, px + sx * 0.05, pz, front - 0.0165), 0.009, 0.009, 0.002, 12, basis_z(o))
            seg_cyl(brass, dp(b, px - 0.065, pz, front - 0.04), dp(b, px + 0.065, pz, front - 0.04), 0.0055, 12)
            if k == 2:
                cyl(brass, dp(b, px, zc_ - pitch * 0.2, front - 0.017), 0.011, 0.011, 0.002, 16, basis_z(o))
                box(B.bm("M_LL_Bakelite", "SM_Props"), dp(b, px, zc_ - pitch * 0.2 - 0.002, front - 0.0182), (0.003, 0.0006, 0.009), bs, bevel=0.0)
    B.collider("desk", dp(b, 0, 0.42, c), (w + 0.04, d + 0.04, 0.84), bs)
    B.empty("IA_drawer", dp(b, -(w / 2 - 0.27), 0.2, c - d / 2 - 0.02), (0.24, 0.06, 0.11), bs)
    # teleprinter forecast sheet beside the radar
    fs = basis_z(u, r * math.cos(-0.25) + o * math.sin(-0.25))
    B.empty("IA_forecast", dp(b, 0.82, top + 0.03, c - 0.25), (0.12, 0.15, 0.04), fs)
    # transceiver (left of centre, R3)
    steel = B.bm("M_LL_SteelPaint")
    rx_d = back - 0.2
    box(steel, dp(b, -0.38, top + 0.14, rx_d), (0.56, 0.34, 0.28), bs)
    for k in range(8):                                             # ventilation louvres on the case top
        box(B.bm("M_LL_Bakelite", "SM_RadioVent"), dp(b, -0.38 - 0.21 + k * 0.06, top + 0.2815, rx_d + 0.03), (0.012, 0.19, 0.003), bs)
    fb3, fc = face_frame(b, -0.38, top + 0.14, rx_d - 0.17 - 0.002)
    rect = atlas_cell_rect(CELLS["radio_dial"])
    rect = (rect[0], rect[1] + (rect[3] - rect[1]) * 0.29, rect[2], rect[1] + (rect[3] - rect[1]) * 0.71)
    quad_uv(B.bm("M_LL_Atlas"), B.uv(B.bm("M_LL_Atlas")), fc + fb3.col[1] * 0.06 + fb3.col[2] * 0.001, fb3, 0.3, 0.13, rect)
    gauge(B, "signal", fc + fb3.col[0] * 0.21 + fb3.col[1] * 0.06, fb3, 0.045, CELLS["signal"])
    for key, x in (("volume", -0.18), ("channel", 0.0)):
        B.part(f"PT_{key}", "M_LL_Bakelite", fc + fb3.col[0] * x - fb3.col[1] * 0.07, fb3, knob_fn(0.028, 0.03))
        label(B, key.upper(), fc + fb3.col[0] * x - fb3.col[1] * 0.118, fb3, 0.08)
    lamp(B, "radio_rx", fc + fb3.col[0] * 0.15 - fb3.col[1] * 0.07, fb3, "green", 0.012)
    lamp(B, "radio_tx", fc + fb3.col[0] * 0.21 - fb3.col[1] * 0.07, fb3, "red", 0.012)
    label(B, "VHF  CH 16", fc + fb3.col[0] * 0.18 - fb3.col[1] * 0.115, fb3, 0.12)
    for s in (-1, 1):
        seg_cyl(B.bm("M_LL_Brass"), fc + fb3.col[0] * (s * 0.3) + fb3.col[1] * 0.1 + fb3.col[2] * 0.02,
                fc + fb3.col[0] * (s * 0.3) - fb3.col[1] * 0.1 + fb3.col[2] * 0.02, 0.008)
    # the desk microphone (PT_handset = its press-to-talk bar) is in build_desk_detail
    # radar (right of centre, R1)
    rd = back - 0.24
    box(steel, dp(b, 0.42, top + 0.22, rd), (0.44, 0.44, 0.44), bs)
    pb3, pc = face_frame(b, 0.42, top + 0.24, rd - 0.22 - 0.002)
    cyl(B.bm("M_LL_Iron"), pc + pb3.col[2] * 0.03, 0.185, 0.17, 0.06, 32, pb3, caps=False)
    # rubber viewing hood: a solid ring (an open tube is single-sided and vanishes from inside)
    lathe(B.bm("M_LL_Bakelite", "SM_RadarHood"), pc, pb3, [(0.168, 0.004), (0.19, 0.004), (0.2, 0.14), (0.182, 0.14)], 40)
    sbm = bmesh.new()
    uvl = sbm.loops.layers.uv.new("UVMap")
    segs, rim = 48, []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        rim.append((sbm.verts.new(pc + pb3.col[2] * 0.004 + pb3 @ Vector((0.16 * math.cos(a), 0.16 * math.sin(a), 0))), a))
    cv = sbm.verts.new(pc + pb3.col[2] * 0.004)
    for i in range(segs):
        (v0, a0), (v1, a1) = rim[i], rim[(i + 1) % segs]
        f = sbm.faces.new((cv, v0, v1))
        for loop, (aa, rr) in zip(f.loops, ((0, 0), (a0, 1), (a1, 1))):
            loop[uvl].uv = (0.5 + 0.5 * rr * math.cos(aa), 0.5 + 0.5 * rr * math.sin(aa))
    B.mesh_obj("SCR_radar", sbm, "M_LL_Screen", keep_uv=True)
    label(B, "RADAR", pc - pb3.col[1] * 0.205, pb3, 0.1)
    # desk lamp (R1/R3)
    lb = dp(b, -0.92, top, back - 0.18)
    cyl(B.bm("M_LL_Brass"), lb + Vector((0, 0, 0.015)), 0.085, 0.08, 0.03, 20)
    elbow = lb + u * 0.32 + o * 0.02
    head = elbow + u * 0.14 - o * 0.26 + r * 0.05
    seg_cyl(B.bm("M_LL_Brass"), lb + u * 0.03, elbow, 0.011)
    seg_cyl(B.bm("M_LL_Brass"), elbow, head, 0.011)
    shade_dir = (-o * 0.45 - u * 0.85 + r * 0.15).normalized()
    cyl(B.bm("M_LL_SteelPaint", "SM_RoomShade"), head + shade_dir * 0.07, 0.035, 0.11, 0.14, 24, basis_z(shade_dir), caps=False)
    bulb = bmesh.new()
    bulb.loops.layers.uv.new("UVMap")
    sphere(bulb, head + shade_dir * 0.11, 0.03)
    B.mesh_obj("LMP_desk", bulb, "M_LL_Lamp")
    B.empty("LIGHT_desk", head + shade_dir * 0.14, (0.05, 0.05, 0.05), basis_z(-shade_dir), kind="SINGLE_ARROW")
    # chart, open logbook, compass, binoculars, books, mug, pencil cup
    top_b3 = basis(r, o, u)
    # the chart sheet itself is built by build_desk_detail (folded, rotated, corners lifted)
    # Station log (IMG_3119): open NLB ledger with the real 13/14 Nov entries (documents.py -> T_LL_Logbook).
    # Before: two blank paper boxes, and basis_z(u, ~r) turned the book 90 degrees (spine across the reader).
    lr = (r * math.cos(0.12) + o * math.sin(0.12)).normalized()
    lb3 = basis(lr, u.cross(lr), u)
    lbc = dp(b, -0.6, top, c - 0.16)
    logbook(B, lbc, lb3)
    B.empty("IA_logbook", lbc + u * 0.05, (0.3, 0.12, 0.06), lb3)
    B.empty("IA_chart", dp(b, 0.1, top + 0.05, c - 0.12), (0.42, 0.32, 0.06), top_b3)
    cc = dp(b, 0.45, top + 0.0215, c - 0.2)        # stands on the chart (iteration 5: the sheet is 1.2 mm up)
    cyl(B.bm("M_LL_Brass"), cc, 0.07, 0.07, 0.04, 24)
    disc_uv(B.bm("M_LL_Atlas"), B.uv(B.bm("M_LL_Atlas")), cc + u * 0.021, Matrix.Identity(3), 0.06, 32, CELLS["bearing"])
    build_desk_detail(B)     # Stage 1 iteration 5: mug, pencil pot, books, binoculars, mic, cables, papers, pipe
    # chair + rug (R1/R3)
    chair_d = c - d / 2 - 0.45
    seat = dp(b, 0.05, 0.46, chair_d)
    build_chair(B, seat, rot_about(u, 8.0) @ bs)       # Stage 1 iteration 5: turned spindle chair, pushed back askew
    B.collider("chair", seat - u * 0.05, (0.48, 0.48, 0.9), bs)
    quad_uv(B.bm("M_LL_Rug"), B.uv(B.bm("M_LL_Rug")), dp(b, 0.0, 0.006, chair_d + 0.05), basis(r, o, u), 2.1, 1.45, (0, 0, 1, 1))
    B.empty("IA_radio", dp(b, -0.2, top + 0.2, back - 0.25), (0.42, 0.3, 0.26), bs)
    B.empty("IA_radar", pc + pb3.col[2] * 0.05, (0.2, 0.2, 0.08), pb3)
    B.empty("FOCUS_radio", dp(b, 0.0, 1.32, chair_d + 0.05), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_radio_at", dp(b, 0.0, top + 0.18, back - 0.32), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_chart", dp(b, 0.1, 1.55, c - 0.62), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_chart_at", dp(b, 0.1, top, c - 0.05), (0.05, 0.05, 0.05), kind="SPHERE")
    drop(B, b, -1.06, 2.78, top, back - 0.02)


# ------------------------------------------------------------------ desk micro-detail (Stage 1 iteration 5)
# Real sizes: Falcon-type enamel mug 80 x 80 mm; hex pencil 7 mm across flats; Captain Field's parallel rule
# ~380 x 45 mm blades; 7x50 porro binoculars; desk mic with a press-to-talk bar and a coiled cord.

def pencil(B, base, axis, L, body, sharpened=True, r=0.004, eraser=False):
    """Hex pencil from its blunt end `base` along `axis`: lacquered body, sharpened wood cone, graphite."""
    ax = Vector(axis).normalized()
    b3 = basis_z(ax)
    cone, tip = (0.017, 0.004) if sharpened else (0.0, 0.0)
    body_len = L - cone - tip
    solid(B, body, lambda bm: cyl(bm, Vector(base) + ax * (body_len / 2), r, r, body_len, 6, b3))
    if eraser:
        ferrule = Vector(base) - ax * 0.006
        cyl(B.bm("M_LL_Brass", "SM_Props"), ferrule, r * 1.02, r * 1.02, 0.012, 12, b3)
        solid(B, "eraser", lambda bm: cyl(bm, ferrule - ax * 0.009, r * 0.95, r * 0.9, 0.007, 12, b3))
    if sharpened:
        c0 = Vector(base) + ax * body_len
        solid(B, "wood_raw", lambda bm: cyl(bm, c0 + ax * (cone / 2), r * 0.9, 0.0011, cone, 12, b3))
        solid(B, "graphite", lambda bm: cyl(bm, c0 + ax * (cone + tip / 2), 0.0011, 0.0002, tip, 8, b3))


def fountain_pen(B, tip, axis):
    """Uncapped fountain pen lying with its nib at `tip`: brass nib, black section, brass band, barrel."""
    ax = Vector(axis).normalized()
    b3 = basis_z(ax)
    flat = b3 @ Matrix.Diagonal((1.0, 0.35, 1.0))
    p = Vector(tip)
    cyl(B.bm("M_LL_Brass", "SM_Props"), p - ax * 0.007, 0.0005, 0.0045, 0.014, 8, flat)          # nib
    solid(B, "lacquer_black", lambda bm: cyl(bm, p - ax * 0.023, 0.0046, 0.0052, 0.018, 16, b3))  # section
    cyl(B.bm("M_LL_Brass", "SM_Props"), p - ax * 0.033, 0.0059, 0.0059, 0.002, 16, b3)            # band
    solid(B, "lacquer_black", lambda bm: cyl(bm, p - ax * 0.0765, 0.0058, 0.0058, 0.085, 16, b3))
    solid(B, "lacquer_black", lambda bm: cyl(bm, p - ax * 0.122, 0.0058, 0.0035, 0.006, 16, b3))


def pen_cap(B, open_end, axis, clip_dir):
    ax = Vector(axis).normalized()
    b3 = basis_z(ax)
    p = Vector(open_end)
    solid(B, "lacquer_black", lambda bm: cyl(bm, p + ax * 0.031, 0.0066, 0.0066, 0.062, 16, b3))
    solid(B, "lacquer_black", lambda bm: cyl(bm, p + ax * 0.065, 0.0066, 0.004, 0.006, 16, b3))
    brass = B.bm("M_LL_Brass", "SM_Props")
    cyl(brass, p + ax * 0.002, 0.0069, 0.0069, 0.004, 16, b3)                                   # cap band
    cd = Vector(clip_dir).normalized()
    box(brass, p + ax * 0.04 + cd * 0.0074, (0.0035, 0.042, 0.0012), basis(ax.cross(cd), ax, cd), bevel=0.0)
    sphere(brass, p + ax * 0.02 + cd * 0.0078, 0.0019, 8, 6)


def build_chart_sheet(B, cc, cb3):
    """The chart as paper: a 40 x 30 grid with a centre fold ridge, a softer cross fold and two lifted near
    corners; a 0.8 mm edge band. Returns hz(x, y), the sheet height above the desk (objects sit on it)."""
    w, h = DC["w"], DC["h"]

    def hz(x, y):
        z = 0.0012 + 0.0016 * math.exp(-(x / 0.02) ** 2) + 0.0009 * math.exp(-(y / 0.02) ** 2)
        for (qx, qy, lift) in ((-w / 2, -h / 2, 0.007), (w / 2, -h / 2, 0.012)):
            d = math.hypot(x - qx, y - qy)
            if d < 0.1:
                z += lift * (1 - d / 0.1) ** 2
        return z
    nx, ny = 40, 30
    bm = B.bm("M_LL_Chart")
    uvl = B.uv(bm)
    P = lambda x, y, dz=0.0: cc + cb3 @ Vector((x, y, hz(x, y) + dz))
    g = [[bm.verts.new(P(-w / 2 + w * i / nx, -h / 2 + h * j / ny)) for j in range(ny + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(ny):
            f = bm.faces.new((g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1]))
            for lp, (a, b2) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                lp[uvl].uv = (a / nx, b2 / ny)
    # edge band: perimeter walked anticlockwise from above, quads (top_p, bot_p, bot_q, top_q) face outward
    per = ([(-w / 2 + w * i / nx, -h / 2) for i in range(nx)] + [(w / 2, -h / 2 + h * j / ny) for j in range(ny)]
           + [(w / 2 - w * i / nx, h / 2) for i in range(nx)] + [(-w / 2, h / 2 - h * j / ny) for j in range(ny)])
    pm = B.bm("M_LL_Props")
    puv, uv = B.uv(pm), sw_uv("paper_white")
    for k in range(len(per)):
        (x0, y0), (x1, y1) = per[k], per[(k + 1) % len(per)]
        vs = [pm.verts.new(P(x0, y0)), pm.verts.new(P(x0, y0, -0.0008)), pm.verts.new(P(x1, y1, -0.0008)), pm.verts.new(P(x1, y1))]
        f = pm.faces.new(vs)
        for lp in f.loops:
            lp[puv].uv = uv
    return hz


def build_chair(B, seat, cb):
    """Spindle-back office chair (seat centre `seat`, frame cb: x across, y toward the desk, z up): turned and
    splayed legs, H-stretchers, a rounded saddle seat, tapered spindles, a bowed top rail; the keeper's
    navy gansey thrown over the back (T_LL_Props knit). Before: square boxes throughout."""
    ch = B.bm("M_LL_Wood", "SM_Chair")
    P = lambda x, y, z: seat + cb @ Vector((x, y, z))
    box(ch, P(0, 0, 0.0), (0.44, 0.42, 0.036), cb, bevel=0.012, segs=3)
    turned = [(0.0, 0.0), (0.0155, 0.0), (0.0165, 0.02), (0.0135, 0.05), (0.0115, 0.2), (0.0155, 0.225), (0.0175, 0.245),
              (0.0155, 0.265), (0.0125, 0.285), (0.016, 0.44), (0.0, 0.44)]
    feet = {}
    for sx in (-1, 1):
        for sy in (-1, 1):
            top_ = P(sx * 0.18, sy * 0.165, -0.018)
            foot = P(sx * 0.205, sy * 0.19, -0.46)
            ax = top_ - foot
            sc = ax.length / 0.44
            lathe(ch, foot, basis_z(ax) @ Matrix.Diagonal((1.0, 1.0, sc)), turned, 14)
            feet[(sx, sy)] = (foot, ax)
    at = lambda sx, sy, t: feet[(sx, sy)][0] + feet[(sx, sy)][1] * t
    for sx in (-1, 1):                                                   # side stretchers
        seg_cyl(ch, at(sx, -1, 0.3), at(sx, 1, 0.3), 0.0095, 10)
    seg_cyl(ch, (at(-1, -1, 0.3) + at(-1, 1, 0.3)) / 2, (at(1, -1, 0.3) + at(1, 1, 0.3)) / 2, 0.0095, 10)   # H bar
    bow = lambda x: -0.19 - 0.028 * (1 - (x / 0.215) ** 2)
    for sx in (-1, 1):                                                   # back posts
        seg_cyl(ch, P(sx * 0.195, -0.185, 0.0), P(sx * 0.205, bow(sx * 0.205) + 0.004, 0.44), 0.014, 12)
    for k in range(5):
        x = -0.12 + k * 0.06
        b0, b1 = P(x, -0.185, 0.01), P(x, bow(x), 0.43)
        cyl(ch, (b0 + b1) / 2, 0.0095, 0.0075, (b1 - b0).length, 10, basis_z(b1 - b0))
    rail = [P(x, bow(x), 0.455) for x in [-0.215 + 0.43 * i / 10 for i in range(11)]]
    sweep(ch, rail, 0.032, 10, ry=0.012, n0=cb.col[2])
    # the gansey over the top rail: short drop on the sitter's side, long drop behind, sagging edges, folds
    path = [(0.045, -0.12), (0.04, -0.06), (0.032, 0.0), (0.02, 0.03), (0.0, 0.044), (-0.022, 0.03), (-0.036, 0.0),
            (-0.05, -0.08), (-0.06, -0.16), (-0.062, -0.24), (-0.056, -0.3)]
    nx = 14
    pm = B.bm("M_LL_Props")
    uvl = B.uv(pm)
    g = []
    for i in range(nx + 1):
        x = -0.19 + 0.38 * i / nx
        col = []
        for j, (yy, zz) in enumerate(path):
            hang = min(1.0, abs(zz) / 0.1) if zz < 0 else 0.0
            sag = -0.035 * (x / 0.19) ** 2 * hang
            fold = 0.007 * math.sin(x * 38 + j * 0.9) * hang
            col.append(pm.verts.new(P(x, bow(x) + yy + fold, 0.455 + zz + sag)))
        g.append(col)
    for i in range(nx):
        for j in range(len(path) - 1):
            f = pm.faces.new((g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1]))
            for lp, (a, b2) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                lp[uvl].uv = region_uv("knit", a / nx, b2 / (len(path) - 1))
    for sx in (-1, 1):                                                   # sleeves hanging behind
        sl = bezier(P(sx * 0.17, bow(sx * 0.17) - 0.05, 0.42), P(sx * 0.19, bow(sx * 0.19) - 0.07, 0.3),
                    P(sx * 0.15, bow(sx * 0.15) - 0.075, 0.2), P(sx * 0.13, bow(sx * 0.13) - 0.07, 0.11), 9)   # hang straight, no X
        solid(B, "knit_navy", lambda bm, sl=sl: sweep(bm, sl, 0.034, 10, ry=0.02, n0=cb.col[1]))


def build_desk_detail(B):
    """Stage 1 iteration 5: the desk's small objects rebuilt to stand up to the radio focus view, plus the
    keeper's traces (cold tea, pipe, pencil work, reading glasses, a stores note). Story-neutral: nothing
    here anticipates tonight's events."""
    b = R["desk"]
    r, o, u = wall_frame(b)
    bs = wb(b)
    w, d, top = 2.2, 0.85, 0.78
    back = back_dist(w)
    c = back - d / 2
    D = lambda along, z, dist: dp(b, along, top + z, dist)
    # ---- chart: rotated a few degrees, folded, two corners lifted; the keeper's tools on it
    cc = D(0.1, 0.0, c - 0.12)
    cb3 = rot_about(u, DC["rot_deg"]) @ basis(r, o, u)
    hz = build_chart_sheet(B, cc, cb3)
    CP = lambda x, y, dz=0.0: cc + cb3 @ Vector((x, y, hz(x, y) + dz))
    uv_xy = lambda uv: ((uv[0] - 0.5) * DC["w"], (uv[1] - 0.5) * DC["h"])
    # Captain Field's parallel rule: two black blades, brass links, brass knobs; slightly opened
    rb3 = cb3 @ rot_about((0, 0, 1), 4.0)
    rc = CP(0.12, -0.258, 0.0016)           # cabin pass: along the near margin, clear of the leading lines
    for k, (sy, sx) in enumerate(((-0.0232, 0.0), (0.0232, 0.012))):      # closed: the blades meet
        blade = rc + rb3 @ Vector((sx, sy, 0.00275))
        solid(B, "vulcanite", lambda bm, blade=blade: box(bm, blade, (0.38, 0.045, 0.0055), rb3, bevel=0.0018))
        edge = blade + rb3 @ Vector((0.0, (-1 if k == 0 else 1) * 0.0175, 0.0029))     # engraved scale along the outer edge
        solid(B, "paper_white", lambda bm, edge=edge: box(bm, edge, (0.35, 0.004, 0.0003), rb3, bevel=0.0))
        cyl(B.bm("M_LL_Brass", "SM_Props"), blade + rb3 @ Vector((0.04 if k else -0.04, 0.0, 0.0075)), 0.0072, 0.006, 0.01, 16, rb3)
    for lx in (-0.13, 0.13):
        a0, a1 = rc + rb3 @ Vector((lx, -0.0232, 0.0063)), rc + rb3 @ Vector((lx + 0.012, 0.0232, 0.0063))
        dd = a1 - a0
        box(B.bm("M_LL_Brass", "SM_Props"), (a0 + a1) / 2, (0.012, dd.length + 0.014, 0.0015),
            basis(dd.cross(rb3.col[2]).normalized(), dd.normalized(), rb3.col[2]), bevel=0.0)
        for e in (a0, a1):
            cyl(B.bm("M_LL_Brass", "SM_Props"), e + rb3.col[2] * 0.0011, 0.0034, 0.0034, 0.0012, 10, rb3)
    # brass dividers lying open beside the rule
    hinge = CP(0.345, 0.17, 0.003)          # cabin pass: right margin, off the soundings
    for tip in ((0.25, 0.115), (0.275, 0.215)):
        tp = CP(tip[0], tip[1], 0.0015)
        dv = tp - hinge
        cyl(B.bm("M_LL_Brass", "SM_Props"), hinge + dv * 0.42, 0.0026, 0.0018, dv.length * 0.84, 10, basis_z(dv))
        cyl(B.bm("M_LL_Iron", "SM_Props"), hinge + dv * 0.92, 0.0012, 0.0002, dv.length * 0.16, 8, basis_z(dv))
    cyl(B.bm("M_LL_Brass", "SM_Props"), hinge + cb3.col[2] * 0.001, 0.0085, 0.0085, 0.006, 20, cb3)
    seg_cyl(B.bm("M_LL_Brass", "SM_Props"), hinge, CP(0.373, 0.178, 0.004), 0.0028, 8)
    # a green pencil stub left on the chart (the bearing work)
    s0, s1 = CP(0.27, -0.215, 0.0042), CP(0.355, -0.19, 0.0042)     # beside the rule
    pencil(B, s0, s1 - s0, (s1 - s0).length, "pencil_green")
    # ---- the enamel mug: cold tea at ~55 %, beside its newest ring
    mx, my = uv_xy(DC["mug_uv"])
    mb3 = basis(r, o, u) @ rot_about((0, 0, 1), 35.0)
    mc = D(0.62, 0.0, back - 0.62)          # cabin pass: off the chart (IMG_3139), in front of the radar
    mv = PA["mug_v"]
    prof = [(0.0, 0.0, 0.0), (0.034, 0.0, 0.04), (0.0385, 0.003, 0.07), (0.0395, 0.010, 0.10), (0.040, 0.075, 0.66),
            (0.0408, 0.079, mv["rim_v0"]), (0.0418, 0.0815, 0.76), (0.0412, 0.084, 0.80), (0.0395, 0.0832, mv["rim_v1"]),
            (0.0388, 0.079, mv["inner_top"]), (0.0388, 0.006, mv["inner_bottom"]), (0.0, 0.005, 1.0)]
    pm = B.bm("M_LL_Props")
    lathe_uv(pm, B.uv(pm), mc, mb3, prof, 40, lambda uu, vv: region_uv("mug", uu, vv))
    hp = [mc + mb3 @ Vector((0.0435 + 0.023 * math.cos(math.radians(a)), 0.0, 0.045 + 0.025 * math.sin(math.radians(a))))
          for a in range(100, -101, -20)]
    solid(B, "enamel_white", lambda bm: sweep(bm, hp, 0.0058, 8, ry=0.0021, n0=mb3.col[1]))
    solid(B, "tea", lambda bm: cyl(bm, mc + mb3.col[2] * mv["tide_z"][-1], 0.0387, 0.0387, 0.001, 40, mb3))
    # ---- brass shell-case pencil pot with five things in it, each leaning on the rim at its own angle
    pc2 = D(-0.75, 0.0, back - 0.42)
    lathe(B.bm("M_LL_Brass", "SM_Props"), pc2, Matrix.Identity(3),
          [(0.0, 0.0), (0.034, 0.0), (0.034, 0.006), (0.031, 0.008), (0.0325, 0.011), (0.0325, 0.108), (0.0336, 0.11),
           (0.0314, 0.11), (0.0314, 0.009), (0.0, 0.009)], 32)
    items = [(25, 0.016, 0.178, "pencil_yellow"), (105, 0.008, 0.165, "chinagraph"), (170, 0.018, 0.168, "pencil_green"),
             (245, 0.012, 0.142, "ballpoint"), (320, 0.006, 0.152, "rule")]
    for ang, off, L, kind in items:
        a = math.radians(ang)
        dirh = r * math.cos(a) + o * math.sin(a)
        b0 = pc2 - dirh * off + u * 0.01
        rim = pc2 + dirh * 0.027 + u * 0.11
        ax = (rim - b0).normalized()
        if kind.startswith("pencil"):
            pencil(B, b0, ax, L, kind, eraser=(kind == "pencil_yellow"))
        elif kind == "chinagraph":
            b3 = basis_z(ax)
            solid(B, "chinagraph_red", lambda bm: cyl(bm, b0 + ax * (L - 0.01) / 2, 0.0045, 0.0045, L - 0.01, 12, b3))
            solid(B, "chinagraph_red", lambda bm: cyl(bm, b0 + ax * (L - 0.005), 0.0042, 0.0016, 0.01, 12, b3))
        elif kind == "ballpoint":
            b3 = basis_z(ax)
            solid(B, "ballpoint", lambda bm: cyl(bm, b0 + ax * (L - 0.022) / 2, 0.0042, 0.0042, L - 0.022, 6, b3))
            solid(B, "cap_blue", lambda bm: cyl(bm, b0 + ax * (L - 0.011), 0.0047, 0.0043, 0.022, 12, b3))
            box(B.bm("M_LL_Iron", "SM_Props"), b0 + ax * (L - 0.02) + basis_z(ax).col[0] * 0.0052,
                (0.0012, 0.003, 0.028), basis(basis_z(ax).col[0], basis_z(ax).col[1], ax), bevel=0.0)
        else:      # six-inch steel rule
            side = ax.cross(u).normalized()
            box(B.bm("M_LL_Iron", "SM_Props"), b0 + ax * L / 2, (0.0125, 0.0009, L), basis(side, ax.cross(side), ax), bevel=0.0)
    # ---- logbook: uncapped pen in the gutter, its cap on the right page, reading glasses folded on the left
    lr = (r * math.cos(0.12) + o * math.sin(0.12)).normalized()
    lb3 = basis(lr, u.cross(lr), u)
    lbc = D(-0.6, 0.0, c - 0.16)
    pw = 0.28
    page_z = lambda x: 0.006 + 0.012 * math.sin(min(1.0, abs(x) / pw * 1.25) * math.pi / 2) - 0.002 * abs(x) / pw   # = logbook zt (top sheet)
    LP = lambda x, y, dz=0.0: lbc + lb3 @ Vector((x, y, page_z(x) + dz))
    fountain_pen(B, LP(0.02, 0.07, 0.0064), lb3 @ Vector((-0.05, 1.0, 0.0)))
    cap_o = LP(0.17, -0.07, 0.0068)
    pen_cap(B, cap_o, lb3 @ Vector((-0.3, 1.0, 0.0)), lb3.col[2])
    gc = LP(-0.165, 0.035, 0.0)
    gb3 = lb3 @ rot_about((0, 0, 1), -8.0)
    for s in (-1, 1):
        # each rim rests on the highest page point under it (the pages rise toward the fore-edge)
        rx_ = -0.165 + s * 0.026
        lift = max(page_z(rx_ + k * 0.0045) for k in range(-5, 6)) - page_z(-0.165) + 0.0018
        rim_c = gc + gb3 @ Vector((s * 0.026, 0.0, lift))
        solid(B, "tortoise", lambda bm, rim_c=rim_c: torus(bm, rim_c, 0.0205, 0.0016, 24, 6, gb3))
        cyl(B.bm("M_LL_Glass", "SM_PropsGlass"), rim_c, 0.0198, 0.0198, 0.0012, 24, gb3)
        hinge_p = gc + gb3 @ Vector((s * 0.048, 0.004, lift + 0.0008))
        tip_p = gc + gb3 @ Vector((-s * 0.032, 0.008 + (0.004 if s > 0 else 0.0), lift + 0.0032 + (0.0012 if s > 0 else 0.0)))
        solid(B, "tortoise", lambda bm, a=hinge_p, e=tip_p: sweep(bm, [a, e, e + (e - a).normalized() * 0.012 - gb3.col[2] * 0.0025],
                                                             0.0012, 6, ry=0.0022, n0=gb3.col[2]))
    bl = max(page_z(-0.165 + k * 0.004) for k in range(-3, 4)) - page_z(-0.165) + 0.0018
    bridge = [gc + gb3 @ Vector((x, 0.0, bl + 0.004 * (1 - (x / 0.0062) ** 2))) for x in (-0.0062, -0.003, 0.0, 0.003, 0.0062)]
    solid(B, "tortoise", lambda bm: sweep(bm, bridge, 0.0014, 6))
    # ---- desk microphone: cast base, chrome stem and yoke, grey head; PT_handset is the press-to-talk bar
    mic = D(0.05, 0.0, back - 0.17)          # cabin pass: off the chart, between the radio and the radar
    solid(B, "hammertone", lambda bm: lathe(bm, mic, Matrix.Identity(3), [(0.0, 0.0), (0.056, 0.0), (0.058, 0.004), (0.054, 0.014),
                                                                         (0.042, 0.022), (0.012, 0.026), (0.0, 0.026)], 32))
    solid(B, "chrome", lambda bm: cyl(bm, mic + u * 0.03, 0.009, 0.009, 0.008, 16))
    solid(B, "chrome", lambda bm: cyl(bm, mic + u * 0.078, 0.0055, 0.0055, 0.096, 12))
    solid(B, "chrome", lambda bm: box(bm, mic + u * 0.126, (0.074, 0.009, 0.006), bs, bevel=0.0))
    for s in (-1, 1):
        solid(B, "chrome", lambda bm, s=s: box(bm, mic + r * (s * 0.0345) + u * 0.151, (0.005, 0.011, 0.054), bs, bevel=0.0))
        solid(B, "chrome", lambda bm, s=s: cyl(bm, mic + r * (s * 0.038) + u * 0.155, 0.0065, 0.0065, 0.005, 12, basis_z(r)))
    hax = (-o * math.cos(math.radians(14)) + u * math.sin(math.radians(14))).normalized()
    hc = mic + u * 0.155
    pill = [(0.0, -0.034), (0.017, -0.033), (0.026, -0.025), (0.0285, -0.01), (0.0285, 0.01), (0.026, 0.025), (0.017, 0.033), (0.0, 0.034)]
    solid(B, "hammertone", lambda bm: lathe(bm, hc, basis_z(hax), pill, 28))
    solid(B, "iron_chip", lambda bm: cyl(bm, hc + hax * 0.0335, 0.0175, 0.0175, 0.0012, 24, basis_z(hax)))
    solid(B, "chrome", lambda bm: torus(bm, hc, 0.0289, 0.0022, 28, 6, basis_z(hax)))
    B.part("PT_handset", "M_LL_Bakelite", mic - o * 0.044 + u * 0.022, Matrix.Identity(3),
           lambda bm, uv: box(bm, (0, 0, 0), (0.048, 0.014, 0.007), bevel=0.0015))
    # coiled cord from the mic across the chart's top margin to the radio's front socket, then a lead and a plug
    fb3, fc = face_frame(b, -0.38, top + 0.14, back - 0.2 - 0.17 - 0.002)
    sock = fc + fb3.col[0] * 0.24 - fb3.col[1] * 0.11
    def zc(along, dist):                    # on the chart: its sheet height; off it: the desk top
        lx, ly = (cb3.transposed() @ (D(along, 0, dist) - cc))[:2]
        on = abs(lx) <= DC["w"] / 2 and abs(ly) <= DC["h"] / 2
        return (hz(lx, ly) if on else 0.0) + 0.0068
    pts = [(-0.004, back - 0.205), (-0.05, back - 0.27), (-0.1, back - 0.31), (-0.13, back - 0.395)]
    path = bezier(*[D(a, zc(a, dd), dd) for a, dd in pts], 24)
    turns = coil(path, 0.0052, 0.0062, 8)
    solid(B, "rubber", lambda bm: sweep(bm, turns, 0.0016, 5))
    lead = bezier(path[-1], path[-1] + (path[-1] - path[-2]).normalized() * 0.01, sock - fb3.col[2] * 0.03 - u * 0.02, sock + fb3.col[2] * 0.022, 10)
    solid(B, "rubber", lambda bm: sweep(bm, lead, 0.0019, 6))
    solid(B, "rubber", lambda bm: cyl(bm, sock + fb3.col[2] * 0.012, 0.0065, 0.0058, 0.022, 12, fb3))
    solid(B, "chrome", lambda bm: torus(bm, sock + fb3.col[2] * 0.001, 0.009, 0.0016, 16, 5, fb3))
    # ---- radio case: bezel, screws, the coastguard card tucked behind the bezel
    steel = B.bm("M_LL_SteelPaint")
    for (x, y, sx, sy) in ((0, 0.135, 0.56, 0.01), (0, -0.135, 0.56, 0.01), (-0.275, 0, 0.01, 0.28), (0.275, 0, 0.01, 0.28)):
        box(steel, fc + fb3 @ Vector((x, y, 0.004)), (sx, sy, 0.008), fb3, bevel=0.0)
    for x, y in ((-0.265, 0.128), (0.265, 0.128), (-0.265, -0.128), (0.265, -0.128), (-0.274, 0.0), (0.274, 0.0)):
        cyl(B.bm("M_LL_Iron", "SM_Props"), fc + fb3 @ Vector((x, y, 0.0088)), 0.0038, 0.0034, 0.0016, 10, fb3)
    kb3 = fb3 @ rot_about((0, 0, 1), 5.0)
    quad_uv(pm, B.uv(pm), fc + fb3 @ Vector((-0.212, 0.122, 0.0042)), kb3, 0.1, 0.0667, region_rect("sked"))
    # radar case: cooling louvres on its right side
    rd = back - 0.24
    for k in range(7):
        box(B.bm("M_LL_Bakelite", "SM_RadioVent"), D(0.6415, 0.31 + k * 0.018, rd + 0.02), (0.003, 0.24, 0.006), bs, bevel=0.0)
    # ---- cables: radio power + coax, radar and lamp flex run along the back edge to a junction box
    jb = D(-1.05, 0.065, back - 0.035)
    box(steel, jb, (0.09, 0.06, 0.12), bs)
    for k in range(3):
        cyl(B.bm("M_LL_Iron", "SM_Props"), jb + r * (0.046) + u * (-0.035 + k * 0.03), 0.007, 0.006, 0.01, 10, basis_z(r))
    runs = (("cable_grey", 0.0035, (-0.3, 0.06, 3.0), 3.0045, -0.035),
            ("rubber", 0.0045, (-0.46, 0.12, 3.0), 3.0195, -0.005),
            ("cable_grey", 0.0035, (0.42, 0.1, 3.002), 3.0115, 0.025))
    for sw_, cr, (a0, z0, d0), dd, jz in runs:
        start = D(a0, z0, d0)
        down = D(a0 - 0.04, cr, dd)
        end = jb + r * 0.05 + u * jz
        p = bezier(start, start + o * 0.012, down + o * 0.0 + u * 0.03, down, 8)
        p += [D(x, cr, dd) for x in [a0 - 0.08 - 0.1 * i for i in range(int((a0 - 0.08 + 0.95) / 0.1) + 1)]]
        p += bezier(D(-0.95, cr, dd), D(-0.99, cr, dd), end + r * 0.03, end, 6)[1:]
        solid(B, sw_, lambda bm, p=p, cr=cr: sweep(bm, p, cr, 6))
    lamp = D(-0.92, 0.0, back - 0.18)
    flex = bezier(lamp + o * 0.08 + u * 0.008, lamp + o * 0.12 + u * 0.004, jb + r * 0.08 - u * 0.05, jb + r * 0.046 + u * 0.025, 10)
    solid(B, "flex_brown", lambda bm: sweep(bm, flex, 0.003, 6))
    solid(B, "lacquer_black", lambda bm: cyl(bm, lamp - o * 0.055 + u * 0.033, 0.009, 0.008, 0.008, 14))   # lamp switch
    # ---- reference books standing against the radar case (the case is their bookend); the almanac leans
    x_r = 0.64
    for k, (t, hgt, cloth, lean) in enumerate(((0.042, 0.26, "cloth_navy", 0), (0.038, 0.245, "cloth_green", 0),
                                               (0.03, 0.23, "cloth_red", 0), (0.035, 0.215, "cloth_black", 14.0))):
        bd = 0.18
        th = math.radians(lean)
        if lean:
            cx = x_r + t / 2 * math.cos(th) + hgt * math.sin(th) + 0.001
            base = D(cx, t / 2 * math.sin(th), back - 0.12)
        else:
            cx = x_r + t / 2 + 0.001
            base = D(cx, 0.0, back - 0.12)
        kb = bs @ rot_about((0, 1, 0), -lean)
        Pb = lambda x, y, z, base=base, kb=kb: base + kb @ Vector((x, y, z))
        for s in (-1, 1):
            solid(B, cloth, lambda bm, s=s, Pb=Pb, t=t, hgt=hgt, kb=kb: box(bm, Pb(s * (t / 2 - 0.0015), 0.0, hgt / 2), (0.003, bd, hgt), kb, bevel=0.0))
        solid(B, cloth, lambda bm, Pb=Pb, t=t, hgt=hgt, kb=kb: box(bm, Pb(0.0, -bd / 2 + 0.002, hgt / 2), (t, 0.004, hgt), kb, bevel=0.0))
        solid(B, "page_cream", lambda bm, Pb=Pb, t=t, hgt=hgt, kb=kb: box(bm, Pb(0.0, 0.002, hgt / 2), (t - 0.006, bd - 0.008, hgt - 0.008), kb, bevel=0.0))
        sb3 = basis(kb.col[0], kb.col[2], -kb.col[1])
        quad_uv(pm, B.uv(pm), Pb(0.0, -bd / 2 - 0.0003, hgt / 2), sb3, t, hgt, region_rect("spines", k / 4, 0.0, (k + 1) / 4, 1.0))
        x_r = cx + t / 2 if not lean else x_r
    # ---- 7x50 binoculars lying on the desk, strap trailing
    nb3 = bs @ rot_about((0, 0, 1), 25.0)
    nc = D(0.88, 0.0, back - 0.31)
    Np = lambda x, y, z: nc + nb3 @ Vector((x, y, z))
    yb3 = basis_z(nb3.col[1])
    for s in (-1, 1):
        solid(B, "rubber", lambda bm, s=s: cyl(bm, Np(s * 0.058, 0.035, 0.031), 0.031, 0.031, 0.085, 24, yb3))
        solid(B, "hammertone", lambda bm, s=s: box(bm, Np(s * 0.045, -0.025, 0.031), (0.05, 0.045, 0.056), nb3, bevel=0.008))
        solid(B, "rubber", lambda bm, s=s: cyl(bm, Np(s * 0.034, -0.068, 0.034), 0.019, 0.019, 0.04, 20, yb3))
        solid(B, "rubber", lambda bm, s=s: cyl(bm, Np(s * 0.034, -0.094, 0.034), 0.0205, 0.0195, 0.012, 20, yb3))
        cyl(B.bm("M_LL_Iron", "SM_Props"), Np(s * 0.058, 0.079, 0.031), 0.0318, 0.0318, 0.006, 24, yb3)
        cyl(B.bm("M_LL_Glass", "SM_PropsGlass"), Np(s * 0.058, 0.0815, 0.031), 0.026, 0.026, 0.001, 24, yb3)
    solid(B, "hammertone", lambda bm: cyl(bm, Np(0.0, -0.032, 0.05), 0.009, 0.009, 0.075, 14, yb3))
    cyl(B.bm("M_LL_Iron", "SM_Props"), Np(0.0, -0.052, 0.058), 0.012, 0.012, 0.016, 18, basis_z(nb3.col[0]))
    strap = bezier(Np(-0.06, -0.075, 0.04), Np(-0.15, -0.14, 0.0016), Np(0.07, -0.25, 0.0016), Np(0.062, -0.075, 0.04), 18)
    solid(B, "flex_brown", lambda bm: sweep(bm, strap, 0.0014, 6, ry=0.007, n0=(0, 0, 1)))
    # ---- teleprinter forecast: torn top edge, the roll's curl lifting it (IA_forecast unchanged)
    fw, fh = 0.22, 0.198
    fb = rot_about(u, -14.0) @ bs
    fcc = D(0.82, 0.0, c - 0.25)
    nfx, nfy = 10, 9
    fz = lambda y: 0.0006 + 0.006 * max(0.0, (y / (fh / 2) - 0.35) / 0.65) ** 2
    jag = [0.0 if i in (0, nfx) else (0.0018 if i % 2 else -0.0012) for i in range(nfx + 1)]
    g = [[pm.verts.new(fcc + fb @ Vector((-fw / 2 + fw * i / nfx, -fh / 2 + fh * j / nfy + (jag[i] if j == nfy else 0.0),
                                          fz(-fh / 2 + fh * j / nfy)))) for j in range(nfy + 1)] for i in range(nfx + 1)]
    for i in range(nfx):
        for j in range(nfy):
            f = pm.faces.new((g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1]))
            for lp, (a, b2) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                lp[B.uv(pm)].uv = region_uv("forecast", a / nfx, b2 / nfy)
    # ---- the stores note, half under the radio (text upright for the keeper)
    nb = rot_about(u, 12.0) @ bs
    quad_uv(pm, B.uv(pm), D(-0.52, 0.0005, 2.62), nb, 0.203, 0.33, region_rect("note"))
    # ---- pipe resting in a brass ashtray, a little ash and a spent match
    at = D(0.615, 0.0, c - 0.27)
    lathe(B.bm("M_LL_Brass", "SM_Props"), at, Matrix.Identity(3),
          [(0.0, 0.0), (0.05, 0.0), (0.055, 0.018), (0.051, 0.018), (0.046, 0.004), (0.0, 0.004)], 32)
    solid(B, "ash_grey", lambda bm: cyl(bm, at + u * 0.0048, 0.028, 0.032, 0.0016, 14))
    for k, (dx, dy) in enumerate(((0.012, 0.006), (-0.01, 0.012), (0.004, -0.014))):
        solid(B, "ash_dark", lambda bm, dx=dx, dy=dy: sphere(bm, at + r * dx + o * dy + u * 0.0058, 0.0035, 8, 5))
    m0, m1 = at + r * -0.02 + o * -0.02 + u * 0.0052, at + r * 0.025 + o * -0.008 + u * 0.0062
    solid(B, "wood_raw", lambda bm: seg_cyl(bm, m0, m1, 0.0012, 4))
    solid(B, "ash_dark", lambda bm: sphere(bm, m1, 0.0021, 6, 4))
    bowl = at + r * 0.008 + o * 0.012 + u * 0.004
    solid(B, "briar", lambda bm: lathe(bm, bowl, Matrix.Identity(3), [(0.0, 0.0), (0.014, 0.0), (0.0175, 0.012), (0.018, 0.03),
                                                                      (0.017, 0.042), (0.012, 0.042), (0.011, 0.012), (0.0, 0.012)], 24))
    solid(B, "tobacco", lambda bm: cyl(bm, bowl + u * 0.036, 0.0112, 0.0112, 0.002, 16))
    sdir = (-r * 0.75 - o * 0.66).normalized()
    sh0, sh1 = bowl + u * 0.012 + sdir * 0.014, bowl + u * 0.016 + sdir * 0.05
    solid(B, "briar", lambda bm: seg_cyl(bm, sh0, sh1, 0.0065, 14))
    st1 = bowl + u * 0.041 + sdir * 0.118          # rests on the rim, mouthpiece lifted
    solid(B, "vulcanite", lambda bm: cyl(bm, (sh1 + st1) / 2, 0.0058, 0.0032, (st1 - sh1).length, 14, basis_z(sh1 - st1)))
    # ---- tobacco tin by the logbook
    tb3 = bs @ rot_about((0, 0, 1), 75.0)
    tc = D(-0.995, 0.0, 2.30)
    solid(B, "tin_red", lambda bm: box(bm, tc + u * 0.01, (0.11, 0.075, 0.02), tb3, bevel=0.003))
    quad_uv(pm, B.uv(pm), tc + u * 0.0201, tb3, 0.104, 0.069, region_rect("tin"))


# ------------------------------------------------------------------ power (R1/R2: west wall)

def build_power(B):
    steel = B.bm("M_LL_SteelPaint")
    # charger wall cabinet
    b = R["charger"]
    bs = wb(b)
    w = 0.85
    back = back_dist(w, 0.02)
    box(steel, dp(b, 0, 1.45, back - 0.14), (w, 0.28, 0.8), bs)
    fb3, fc = face_frame(b, 0, 1.45, back - 0.28 - 0.002)

    def at(x, z):
        return fc + fb3.col[0] * x + fb3.col[1] * (z - 1.45)
    gauge(B, "battery", at(-0.18, 1.6), fb3, 0.13, CELLS["battery"])
    B.empty("IA_battery", at(-0.18, 1.6) + fb3.col[2] * 0.05, (0.15, 0.15, 0.06), fb3)
    gauge(B, "charge_amps", at(0.22, 1.62), fb3, 0.09, CELLS["charge"])
    box(B.bm("M_LL_Iron"), at(0.22, 1.28), (0.08, 0.12, 0.02), fb3)
    B.part("PT_charge", "M_LL_Bakelite", at(0.22, 1.28) + fb3.col[2] * 0.02, toggle_frame(fb3), toggle_fn(0.08))
    lamp(B, "charge", at(0.22, 1.42), fb3, "green", 0.016)
    label(B, "CHARGE", at(0.22, 1.15), fb3, 0.12)
    B.empty("IA_charge", at(0.22, 1.3) + fb3.col[2] * 0.05, (0.07, 0.1, 0.07), fb3)
    for x in (-w / 2 + 0.03, w / 2 - 0.03):
        rivets(B, at(x, 1.1), at(x, 1.82), 8, fb3)
    for k in range(6):                                             # louvres along the bottom of the charger
        box(B.bm("M_LL_Iron", "SM_PowerDetail"), at(-0.3 + k * 0.06, 1.11) + fb3.col[2] * 0.003, (0.04, 0.008, 0.004), fb3)
    for along in (-0.3, -0.18, 0.0, 0.3):                          # cable glands where the conduits enter
        cyl(B.bm("M_LL_Brass", "SM_PowerDetail"), dp(b, along, 1.865, back - 0.1), 0.024, 0.024, 0.03, 12)
    B.collider("charger", dp(b, 0, 1.45, back - 0.14), (w + 0.02, 0.3, 0.82), bs)
    drop(B, b, -0.3, 2.78, 1.85, back - 0.1)
    drop(B, b, 0.3, 2.78, 1.85, back - 0.1, 0.015)
    # distribution cabinet (floor-standing)
    b = R["distribution"]
    bs = wb(b)
    w, d, h = 0.9, 0.45, 1.85
    back = back_dist(w)
    box(steel, dp(b, 0, h / 2, back - d / 2), (w, d, h), bs)
    box(B.bm("M_LL_Iron"), dp(b, 0, 0.04, back - d / 2 + 0.02), (w - 0.04, d - 0.06, 0.08), bs)
    fb3, fc = face_frame(b, 0, h / 2, back - d - 0.002)

    def at2(x, z):
        return fc + fb3.col[0] * x + fb3.col[1] * (z - h / 2)
    for key, x, lab in (("brk_main", -0.27, "MAIN"), ("brk_lights", 0.02, "ROOM LIGHTS"), ("brk_radar", 0.27, "RADAR")):
        cpos = at2(x, 1.3)
        box(B.bm("M_LL_Iron"), cpos, (0.12, 0.2, 0.03), fb3)
        B.part(f"PT_{key}", "M_LL_Bakelite", cpos + fb3.col[2] * 0.025, toggle_frame(fb3), toggle_fn(0.1 if key == "brk_main" else 0.075))
        label(B, lab, at2(x, 1.1), fb3, 0.17 if key != "brk_main" else 0.12)
        B.empty(f"IA_{key}", cpos + fb3.col[2] * 0.06 + fb3.col[1] * 0.03, (0.08, 0.12, 0.08), fb3)
    lamp(B, "main", at2(-0.27, 1.5), fb3, "red", 0.016)
    # black ebonite switch panel behind the breakers (clear of the labels at 1.1 m: no z-fighting)
    box(B.bm("M_LL_Bakelite", "SM_PowerDetail"), at2(0, 1.4) + fb3.col[2] * 0.003, (0.82, 0.44, 0.006), fb3, bevel=0.0)
    for along in (-0.2, 0.0, 0.2):                                 # cable glands on the cabinet top
        cyl(B.bm("M_LL_Brass", "SM_PowerDetail"), dp(b, along, h + 0.015, back - 0.15), 0.028, 0.028, 0.03, 12)
    label(B, "DANGER  415 V", at2(0, 0.6), fb3, 0.3)
    for x in (-0.43, 0.43):
        box(B.bm("M_LL_Iron"), at2(x, h / 2), (0.012, h - 0.1, 0.012), fb3)
    for k in range(5):
        box(B.bm("M_LL_Iron"), at2(0, 0.2 + k * 0.022), (0.26, 0.006, 0.012), fb3)
    rivets(B, at2(-0.4, 1.75), at2(0.4, 1.75), 10, fb3)
    B.collider("distribution", dp(b, 0, h / 2, back - d / 2), (w + 0.04, d + 0.04, h), bs)
    drop(B, b, 0.0, 2.78, h, back - 0.15, 0.03)
    B.empty("IA_power_panel", dp(b, 0, 1.4, back - d - 0.08), (0.46, 0.5, 0.1), bs)
    # battery bank: two tiers, 12 cells with red terminals
    b = R["batteries"]
    bs = wb(b)
    w, d = 1.2, 0.5
    back = back_dist(w)
    rack = B.bm("M_LL_SteelRust")
    for z in (0.05, 0.5):
        box(rack, dp(b, 0, z, back - d / 2), (w, d, 0.03), bs)
        for k in range(6):
            cx = -w / 2 + 0.11 + k * 0.196
            box(B.bm("M_LL_Bakelite", "SM_RoomCells"), dp(b, cx, z + 0.17, back - d / 2), (0.17, 0.4, 0.3), bs)
            box(B.bm("M_LL_SteelPaint", "SM_CellCrates"), dp(b, cx, z + 0.115, back - d / 2), (0.182, 0.412, 0.19), bs)   # steel crate
            cyl(B.bm("M_LL_Iron", "SM_PowerDetail"), dp(b, cx, z + 0.327, back - d / 2), 0.014, 0.012, 0.016, 8)          # vent cap
            for t in (-0.1, 0.1):
                cyl(B.bm("M_LL_Red"), dp(b, cx, z + 0.335, back - d / 2 + t), 0.018, 0.018, 0.03, 10)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(rack, dp(b, sx * (w / 2 - 0.02), 0.47, back - d / 2 + sy * (d / 2 - 0.02)), (0.03, 0.03, 0.94), bs)
    for zc in (0.41, 0.86):                                        # lead inter-cell connectors, both tiers
        for k in range(5):
            cx = -w / 2 + 0.11 + k * 0.196
            seg_cyl(B.bm("M_LL_Iron", "SM_PowerDetail"), dp(b, cx, zc, back - d / 2 + 0.1), dp(b, cx + 0.196, zc, back - d / 2 - 0.1), 0.008, 6)
    B.collider("batteries", dp(b, 0, 0.47, back - d / 2), (w + 0.04, d + 0.04, 0.95), bs)
    drop(B, b, -0.5, 2.78, 0.95, back - 0.05, 0.025)


# ------------------------------------------------------------------ generator cage (R1/R2: south-west)

def build_generator(B):
    b = R["generator"]
    bs = wb(b)
    r, o, u = wall_frame(b)
    w, d, h = 1.6, 1.5, 1.7
    back = back_dist(w)
    front = back - d
    mesh = B.bm("M_LL_Iron", "SM_GenCage")
    frame = B.bm("M_LL_SteelPaint", "SM_GenCage")
    for sx in (-1, 1):
        for dd in (front, back - 0.02):
            box(frame, dp(b, sx * w / 2, h / 2, dd), (0.05, 0.05, h), bs)
        box(frame, dp(b, sx * w / 2, h, back - d / 2), (0.05, d, 0.05), bs)
    box(frame, dp(b, 0, h, front), (w, 0.05, 0.05), bs)
    box(frame, dp(b, 0, 0.03, front), (w, 0.05, 0.06), bs)
    # open guard (was a dense 6 mm wire grid that hid the engine): 9 mm bars at about 16 cm
    for k in range(1, 10):
        box(mesh, dp(b, -w / 2 + k * w / 10, h / 2, front), (0.009, 0.009, h - 0.05), bs)
    for k in range(1, 9):
        box(mesh, dp(b, 0, k * h / 9, front), (w - 0.05, 0.009, 0.009), bs)
    for sx in (-1, 1):
        for k in range(1, 9):
            box(mesh, dp(b, sx * w / 2, h / 2, front + k * d / 9), (0.009, 0.009, h - 0.05), bs)
        for k in range(1, 9):
            box(mesh, dp(b, sx * w / 2, k * h / 9, back - d / 2), (0.009, d - 0.05, 0.009), bs)
    eng = B.bm("M_LL_EngineGreen")
    ec = back - d / 2 + 0.05
    box(eng, dp(b, -0.1, 0.42, ec), (0.95, 0.55, 0.6), bs)
    box(eng, dp(b, -0.1, 0.12, ec), (1.15, 0.7, 0.16), bs)
    for k in range(3):
        box(eng, dp(b, -0.4 + k * 0.28, 0.82, ec), (0.22, 0.42, 0.2), bs)
        cyl(B.bm("M_LL_Iron"), dp(b, -0.4 + k * 0.28, 0.95, ec), 0.03, 0.03, 0.06, 10)
    # spoked flywheel (was a solid disc)
    fw = dp(b, 0.48, 0.45, ec)
    iron = B.bm("M_LL_Iron")
    torus(iron, fw, 0.29, 0.035, 36, 8, basis_z(r))
    cyl(iron, fw, 0.07, 0.07, 0.14, 20, basis_z(r))
    for k in range(6):
        a = math.pi * k / 6
        spoke = u * math.cos(a) + o * math.sin(a)
        seg_cyl(iron, fw - spoke * 0.27, fw + spoke * 0.27, 0.018, 8)
    # drip tray under the engine
    tray = B.bm("M_LL_Iron", "SM_GenTray")
    box(tray, dp(b, -0.05, 0.012, ec), (1.35, 0.9, 0.008), bs)
    for sx in (-1, 1):
        box(tray, dp(b, sx * 0.675 - 0.05, 0.03, ec), (0.012, 0.9, 0.05), bs)
    for sy in (-1, 1):
        box(tray, dp(b, -0.05, 0.03, ec + sy * 0.45), (1.35, 0.012, 0.05), bs)
    box(eng, dp(b, -0.65, 0.55, ec), (0.12, 0.6, 0.8), bs)
    for k in range(10):
        box(B.bm("M_LL_Iron"), dp(b, -0.72, 0.25 + k * 0.06, ec), (0.01, 0.55, 0.02), bs)
    ex0, ex1 = dp(b, -0.25, 0.95, ec), dp(b, -0.25, 1.4, ec)
    ex2 = dp(b, -0.25, 1.4, R_OUT + 0.1)
    seg_cyl(B.bm("M_LL_SteelRust"), ex0, ex1, 0.07, 14)
    seg_cyl(B.bm("M_LL_SteelRust"), ex1, ex2, 0.07, 14)
    for k in range(6):
        cyl(B.bm("M_LL_Iron"), ex1.lerp(ex2, 0.15 + k * 0.05), 0.085, 0.085, 0.02, 14, basis_z(o))
    B.collider("generator", dp(b, 0, h / 2, back - d / 2), (w + 0.06, d + 0.04, h), bs)
    cb = dp(b, 0.42, 1.25, front - 0.08)
    box(B.bm("M_LL_SteelPaint"), cb, (0.5, 0.14, 0.5), bs)
    fb3, fc = face_frame(b, 0.42, 1.25, front - 0.15 - 0.002)

    def at(x, z):
        return fc + fb3.col[0] * x + fb3.col[1] * (z - 1.25)
    label(B, "GENERATOR", at(0, 1.45), fb3, 0.24)
    # maker plate on the cage's top rail: why there is a generator in the watch room at all
    pb3, pc = face_frame(b, -0.35, h - 0.11, front - 0.03)
    box(B.bm("M_LL_Brass", "SM_GenPlate"), pc + pb3.col[2] * 0.002, (0.3, 0.085, 0.006), pb3)
    label(B, "AUX. SET  No.2", pc + pb3.col[2] * 0.006, pb3, 0.26)
    gauge(B, "fuel", at(-0.12, 1.3), fb3, 0.075, CELLS["fuel"])
    gauge(B, "temp", at(0.12, 1.3), fb3, 0.075, CELLS["temp"])
    lamp(B, "gen_run", at(-0.12, 1.13), fb3, "green", 0.016)
    lamp(B, "gen_hot", at(0.12, 1.13), fb3, "amber", 0.016)
    cyl(B.bm("M_LL_Brass"), at(0.0, 1.07), 0.04, 0.04, 0.014, 24, fb3)

    def button(bm, uv):
        cyl(bm, (0, 0, 0.018), 0.03, 0.028, 0.036, 20)
    B.part("PT_start", "M_LL_Bakelite", at(0.0, 1.07) + fb3.col[2] * 0.006, fb3, button)
    label(B, "START", at(0.0, 1.02), fb3, 0.08)
    B.empty("IA_start", at(0.0, 1.07) + fb3.col[2] * 0.05, (0.06, 0.06, 0.06), fb3)
    fl = dp(b, -0.45, 0.0, front - 0.06)
    seg_cyl(B.bm("M_LL_Brass"), fl, fl + u * 1.0, 0.016)
    seg_cyl(B.bm("M_LL_Brass"), fl + u * 1.0, fl + u * 1.0 + o * 0.12, 0.016)
    vb3, vc = face_frame(b, -0.45, 0.9, front - 0.06 - 0.02)
    cyl(B.bm("M_LL_Iron"), vc, 0.035, 0.035, 0.05, 16, vb3)

    def valve(bm, uv):
        cyl(bm, (0, 0, 0.02), 0.02, 0.02, 0.04, 14)
        box(bm, (0, 0.06, 0.035), (0.03, 0.15, 0.018))
    B.part("PT_fuel_valve", "M_LL_Red", vc + vb3.col[2] * 0.02, vb3, valve)
    label(B, "FUEL VALVE", vc - vb3.col[1] * 0.12, vb3, 0.14)
    B.empty("IA_fuel_valve", vc + vb3.col[2] * 0.06, (0.09, 0.1, 0.07), vb3)
    B.empty("IA_gen_panel", cb - o * 0.1, (0.28, 0.28, 0.1), bs)
    # fuel day-tank on wall brackets above the cage, with a sight glass; the fuel line rises to it
    tb = b + 9.0
    tr, to, tu = wall_frame(tb)
    tank_c = dp(tb, 0, 2.05, R_IN - 0.24)
    tank = B.bm("M_LL_SteelPaint", "SM_DayTank")
    cyl(tank, tank_c, 0.16, 0.16, 0.7, 28, basis_z(tr))
    for sx in (-1, 1):
        box(tank, tank_c + tr * sx * 0.25 + to * 0.12 - tu * 0.12, (0.05, 0.26, 0.04), basis(tr, to, tu))
        box(tank, tank_c + tr * sx * 0.25 + to * 0.22, (0.05, 0.04, 0.3), basis(tr, to, tu))
    sg = tank_c + tr * 0.36 - to * 0.02
    seg_cyl(B.bm("M_LL_Glass", "SM_DayTankGlass"), sg - tu * 0.12, sg + tu * 0.12, 0.012, 10)
    for zz in (-0.13, 0.13):
        cyl(B.bm("M_LL_Brass"), sg + tu * zz, 0.018, 0.018, 0.02, 10)
    top = fl + u * 1.0 + o * 0.12
    seg_cyl(B.bm("M_LL_Brass"), top, tank_c - tu * 0.16 - tr * 0.2, 0.016)
    # extractor fan grille in the wall above the generator (it vents the room while the set runs)
    eb = b - 14.0
    er, eo, eu = wall_frame(eb)
    ecn = dp(eb, 0, 2.35, R_IN - 0.015)
    ebs = basis_z(-eo)
    cyl(B.bm("M_LL_Iron", "SM_Extractor"), ecn, 0.17, 0.17, 0.02, 32, ebs)
    torus(B.bm("M_LL_SteelPaint", "SM_Extractor"), ecn - eo * 0.012, 0.17, 0.012, 32, 6, ebs)
    for k in range(5):
        box(B.bm("M_LL_SteelPaint", "SM_Extractor"), ecn - eo * 0.014 + eu * (-0.12 + k * 0.06), (0.3, 0.01, 0.008), basis(er, eo, eu))
    # the main engines' feed, capped off: they are downstairs and out of action tonight
    cp = dp(b, 0.62, 0.0, back - 0.12)
    seg_cyl(B.bm("M_LL_Iron"), cp - u * 0.1, cp + u * 0.85, 0.035, 12)
    cyl(B.bm("M_LL_Red", "SM_CappedPipe"), cp + u * 0.87, 0.07, 0.07, 0.025, 20)
    box(B.bm("M_LL_Paper", "SM_CappedPipe"), cp + u * 0.72 - o * 0.04, (0.06, 0.004, 0.09), bs)   # "out of service" tag
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    sphere(bm, dp(b, 0.0, h - 0.08, back - d / 2), 0.035)
    B.mesh_obj("LMP_cage", bm, "M_LL_Lamp")


# ------------------------------------------------------------------ stair housing (R1/R2: south)

def build_stair(B):
    b = R["stair"]
    bs = wb(b)
    r, o, u = wall_frame(b)
    w, h = 1.3, 2.3
    back = back_dist(w, 0.0)
    front = back - STAIR_DEPTH          # shallow bulkhead (Daniel: it stuck out 1.2 m around a spiral stair)
    # grey-green riveted bulkhead with dark-green trim (it read as one black slab: iteration 2 review)
    plate = B.bm("M_LL_SteelPaint", "SM_Stair")
    trim = B.bm("M_LL_SteelRust", "SM_StairTrim")
    for sx in (-1, 1):
        box(plate, dp(b, sx * (w / 2), h / 2, (front + back) / 2), (0.04, back - front, h), bs)
    box(plate, dp(b, 0, h, (front + back) / 2), (w + 0.04, back - front, 0.04), bs)
    box(trim, dp(b, 0, h - 0.15, front), (w + 0.04, 0.05, 0.3), bs)
    for sx in (-1, 1):
        box(trim, dp(b, sx * (w / 2 - 0.06), h / 2, front), (0.12, 0.06, h), bs)
        rivets(B, dp(b, sx * (w / 2 - 0.06), 0.1, front - 0.031), dp(b, sx * (w / 2 - 0.06), h - 0.1, front - 0.031), 14, basis(r, u, -o))
    # heavy bulkhead door, CLOSED: hinged at the left jamb, opens inward (Godot animates PT_stair_door)
    hinge = dp(b, -w / 2 + 0.12, 0, front - 0.02)
    db3 = basis(r, u.cross(r), u)          # X = across the opening, Z = up (hinge axis)

    def door(bm, uv):
        # heavy bulkhead door (P0). 20 mm gap underneath: the stair light shows beneath it, and in ch4 a
        # photograph slides through. -Y faces the room.
        yb = Vector((0, 1, 0))
        box(bm, (0.53, 0, 1.04), (1.06, 0.05, 2.04))                    # leaf
        for (x, z, sx, sz) in ((0.53, 2.025, 1.06, 0.07), (0.53, 0.055, 1.06, 0.07), (0.035, 1.04, 0.07, 2.04),
                               (1.025, 1.04, 0.07, 2.04), (0.53, 1.04, 0.92, 0.07)):
            box(bm, (x, -0.033, z), (sx, 0.016, sz))                   # raised flange + mid rail: two panels
        for z in (0.32, 1.04, 1.76):
            cyl(bm, (0.0, -0.01, z), 0.026, 0.026, 0.2, 14)             # hinge knuckles
        for z in (0.45, 1.65):                                         # lever dogs on the latch side
            box(bm, (0.99, -0.05, z), (0.035, 0.035, 0.13))
            cyl(bm, (0.99, -0.045, z + 0.05), 0.014, 0.014, 0.03, 10, basis_z(yb))
        box(bm, (0.95, -0.05, 1.3), (0.14, 0.03, 0.03))                # the bolt that rattles at the knock
        wheel = made(bm, lambda: (cyl(bm, (0.78, -0.06, 1.05), 0.03, 0.03, 0.05, 14, basis_z(yb)),
                                  torus(bm, (0.78, -0.09, 1.05), 0.11, 0.013, 24, 6, basis_z(yb))))
        for k in range(4):                                             # brass handwheel spokes
            a = math.pi * k / 4
            wheel += made(bm, lambda a=a: box(bm, (0.78, -0.09, 1.05), (0.22 * abs(math.cos(a)) + 0.012,
                                                                        0.012, 0.22 * abs(math.sin(a)) + 0.012)))
        tag(wheel, 1)
    B.part("PT_stair_door", "M_LL_SteelPaint", hinge, db3, door, extra_mats=("M_LL_Brass",))
    # a bulkhead lamp over the door, so the door is lit from the room side (the wall lamps sit behind it)
    well_glass(B, 4, dp(b, 0, 2.12, front - 0.03), r, o, u)
    B.empty("IA_door", dp(b, 0, 1.1, front - 0.15), (0.55, 0.15, 0.9), bs)
    B.collider("stair_l", dp(b, -w / 2, h / 2, (front + back) / 2), (0.1, back - front, h), bs)
    B.collider("stair_r", dp(b, w / 2, h / 2, (front + back) / 2), (0.1, back - front, h), bs)
    B.collider("stair_door", dp(b, 0, 1.0, front - 0.02), (1.1, 0.08, 2.0), bs)
    dmid = (front + back) / 2
    B.collider("stair_well", dp(b, 0, 0.5, dmid), (w - 0.1, back - front - 0.06, 1.0), bs)
    # steep ship's stair: drops 3 m along the wall (+r) from the hatch inside the bulkhead; below the floor
    # it runs on under the room. 14 treads at about 60 degrees, iron stringers, an oak handrail.
    iron = B.bm("M_LL_Iron", "SM_Stair")
    rise, run, n = 0.214, 0.124, 14
    x0 = -0.5
    for k in range(n):
        box(iron, dp(b, x0 + run * (k + 0.5), -rise * (k + 1) + 0.01, dmid), (0.16, back - front - 0.12, 0.025), bs)
    dz, dx = -rise * n, run * n
    for sy in (-1, 1):
        dd = dmid + sy * (back - front - 0.08) / 2
        seg_cyl(iron, dp(b, x0, 0.0, dd), dp(b, x0 + dx, dz, dd), 0.02, 8)
    seg_cyl(B.bm("M_LL_Wood", "SM_Stair"), dp(b, x0 + 0.05, 0.9, front + 0.06), dp(b, x0 + dx, dz + 0.9, front + 0.06), 0.022, 10)
    # the shaft below the hatch (concrete), so nothing shows through from the room
    conc = B.bm("M_LL_Concrete", "SM_Stair")
    box(conc, dp(b, 0.35, -1.55, front - 0.03), (2.3, 0.06, 3.1), bs, bevel=0.0)
    box(conc, dp(b, 0.35, -1.55, back + 0.05), (2.3, 0.06, 3.1), bs, bevel=0.0)
    box(conc, dp(b, -0.68, -1.55, dmid), (0.06, back - front + 0.1, 3.1), bs, bevel=0.0)
    box(conc, dp(b, 0.35, -3.1, dmid), (2.3, back - front + 0.1, 0.1), bs, bevel=0.0)
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    sphere(bm, dp(b, 0, h - 0.12, (front + back) / 2), 0.04)
    B.mesh_obj("LMP_stair", bm, "M_LL_Lamp")
    B.empty("LIGHT_stair", dp(b, 0, h - 0.2, (front + back) / 2), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("SPAWN_player", dp(b, 0.0, 0.0, 1.45), (0.2, 0.2, 0.2), kind="ARROWS")
    # story anchors (REFERENCE_SPEC Stage 1 review): the slid photograph lands here; knocks and voice come from here
    B.empty("ANCHOR_door_photo", dp(b, 0.1, 0.004, front - 0.32), (0.12, 0.09, 0.01), bs)
    B.empty("ANCHOR_door_audio", dp(b, 0.0, 1.6, front + 0.05), (0.05, 0.05, 0.05), bs, kind="SPHERE")


# ------------------------------------------------------------------ storage, extinguisher, notice, clock

def build_storage(B):
    b = R["storage"]
    bs = wb(b)
    w, d, h = 1.4, 0.5, 1.5
    back = back_dist(w)
    c = back - d / 2
    rack = B.bm("M_LL_SteelRust", "SM_Storage")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(rack, dp(b, sx * (w / 2 - 0.02), h / 2, c + sy * (d / 2 - 0.02)), (0.035, 0.035, h), bs)
    for z in (0.08, 0.6, 1.1, 1.48):
        box(rack, dp(b, 0, z, c), (w, d, 0.025), bs)
        box(rack, dp(b, 0, z - 0.02, c - d / 2 + 0.005), (w, 0.01, 0.04), bs)       # cabin pass: angle-iron front lip
        for sx in (-1, 1):                                                          # corner bolt heads
            cyl(B.bm("M_LL_Iron", "SM_Storage"), dp(b, sx * (w / 2 - 0.02), z - 0.02, c - d / 2 - 0.001), 0.007, 0.007, 0.004, 6, bs)
    box(B.bm("M_LL_Wood", "SM_Storage"), dp(b, -0.38, 0.27, c), (0.5, 0.42, 0.36), bs)
    for k in range(3):
        box(B.bm("M_LL_WoodDark", "SM_Storage"), dp(b, -0.38, 0.12 + k * 0.13, c - 0.212), (0.5, 0.01, 0.03), bs)
    box(B.bm("M_LL_Red"), dp(b, 0.25, 0.73, c), (0.5, 0.25, 0.24), bs)
    seg_cyl(B.bm("M_LL_Iron"), dp(b, 0.1, 0.88, c), dp(b, 0.4, 0.88, c), 0.012)
    for k in range(2):
        box(B.bm("M_LL_SteelPaint", "SM_Storage"), dp(b, -0.45 + k * 0.28, 0.72, c), (0.24, 0.32, 0.22), bs)
    torus(B.bm("M_LL_Rope"), dp(b, 0.3, 0.17, c), 0.17, 0.06, 20, 8)
    torus(B.bm("M_LL_Rope"), dp(b, 0.3, 0.27, c), 0.13, 0.05, 20, 8)
    build_storm_lantern(B, dp(b, -0.25, 1.1125, c), wall_frame(b))   # cabin pass (IMG_3135): stands ON the shelf
    # the old station logs (1946-1965) in an open oak box: the 1953 log is the chapter-2 clue (IA_archive)
    lb = B.bm("M_LL_Wood", "SM_LogBox")
    lc = dp(b, 0.3, 1.113, c)
    box(lb, lc + Vector((0, 0, 0.005)), (0.44, 0.32, 0.01), bs)
    for sx in (-1, 1):
        box(lb, dp(b, 0.3 + sx * 0.215, 1.18, c), (0.012, 0.32, 0.13), bs)
    for sy in (-1, 1):
        box(lb, dp(b, 0.3, 1.18, c + sy * 0.155), (0.44, 0.012, 0.13), bs)
    for k in range(6):                                          # ledgers standing in the box, spines out
        x = 0.3 - 0.17 + k * 0.066
        tall = 0.27 + 0.02 * ((k * 7) % 3)
        box(B.bm("M_LL_Leather", "SM_LogBox"), dp(b, x, 1.12 + tall / 2, c - 0.01), (0.05, 0.27, tall), bs)
        box(B.bm("M_LL_Paper", "SM_LogBox"), dp(b, x, 1.12 + tall * 0.7, c - 0.147), (0.03, 0.004, 0.05), bs)   # year labels
    B.empty("IA_archive", dp(b, 0.3, 1.27, c - 0.12), (0.24, 0.1, 0.17), bs)
    B.collider("storage", dp(b, 0, h / 2, c), (w + 0.04, d + 0.04, h), bs)
    build_extinguisher(B)                                           # cabin pass (IMG_3134)
    nb3, nc = face_frame(b, 0, 2.05, back_dist(0.4, 0.0))
    quad_uv(B.bm("M_LL_Atlas"), B.uv(B.bm("M_LL_Atlas")), nc + nb3.col[2] * 0.005, nb3, 0.4, 0.4, atlas_cell_rect(CELLS["notice"]))
    cb3, cc = face_frame(100.0, 0.0, 2.2, back_dist(0.4, 0.0))
    cyl(B.bm("M_LL_WoodDark"), cc + cb3.col[2] * 0.02, 0.2, 0.2, 0.04, 32, cb3)
    disc_uv(B.bm("M_LL_Atlas"), B.uv(B.bm("M_LL_Atlas")), cc + cb3.col[2] * 0.042, cb3, 0.18, 40, CELLS["clock"])
    B.part("NDL_clock_h", "M_LL_Iron", cc + cb3.col[2] * 0.045, cb3, needle_fn(0.1, 0.01))
    B.part("NDL_clock_m", "M_LL_Iron", cc + cb3.col[2] * 0.054, cb3, needle_fn(0.15, 0.007))   # blade clears the hour hand


# ------------------------------------------------------------------ light console + optic drive (R1/R2: east)

def build_console(B):
    b = R["console"]
    bs = wb(b)
    r, o, u = wall_frame(b)
    w, d = 1.6, 0.85
    back = back_dist(w)
    front = back - d
    steel = B.bm("M_LL_SteelPaint")
    lower_h = 0.82
    box(steel, dp(b, 0, lower_h / 2, back - d / 2), (w, d, lower_h), bs)
    box(B.bm("M_LL_Iron"), dp(b, 0, 0.04, back - d / 2 + 0.02), (w - 0.04, d - 0.06, 0.08), bs)
    slope_len = 0.55
    tilt = math.degrees(math.atan2(0.18, slope_len))
    top_b3, top_c = face_frame(b, 0, (lower_h + 1.0) / 2, front + slope_len / 2, 90 - tilt)
    box(steel, top_c - top_b3.col[2] * 0.02, (w, math.hypot(0.18, slope_len) + 0.03, 0.04), top_b3)
    for s in (-1, 1):
        pts = [dp(b, s * (w / 2), z, dd) for (dd, z) in [(front, 0.0), (front + slope_len, 0.0), (front + slope_len, 1.0), (front, lower_h)]]
        th = r * 0.02
        hexa(steel, [p - th for p in pts] + [p + th for p in pts])
    hood_d = d - slope_len
    hb3, hc = face_frame(b, 0, 1.2, back - hood_d - 0.002, 15)
    # Instrument hood with its front face IN the 15-degree instrument plane. Before (Iteration A): a box with a
    # vertical front, so the upper half of every tilted dial sat inside it (IMG_3117: dials cut horizontally).
    tilt_c = math.cos(math.radians(15))

    def hood_pt(x, zz, at_wall=False):
        p = hc + r * x + hb3.col[1] * ((zz - 1.2) / tilt_c) - hb3.col[2] * 0.025
        return p + o * (back - p.dot(o)) if at_wall else p
    corners = [(x, at) for x, at in ((-w / 2, False), (-w / 2, True), (w / 2, True), (w / 2, False))]
    hexa(steel, [hood_pt(x, 0.975, at) for x, at in corners] + [hood_pt(x, 1.4, at) for x, at in corners])

    def on_hood(x, y):
        return hc + hb3.col[0] * x + hb3.col[1] * y
    box(steel, hc - hb3.col[2] * 0.015, (w - 0.02, 0.42, 0.03), hb3)
    gauge(B, "bearing", on_hood(0.32, 0.0), hb3, 0.17, CELLS["bearing"], needle_mat="M_LL_Ceramic")
    # brass mounting flange: a RING behind the bezel (it was a solid 0.215 m disc 7 mm IN FRONT of the dial)
    lathe(B.bm("M_LL_Brass"), on_hood(0.32, 0.0), hb3, [(0.19, -0.004), (0.222, -0.004), (0.222, 0.004), (0.19, 0.006)], 48)
    gauge(B, "motor", on_hood(-0.05, 0.03), hb3, 0.09, CELLS["motor"])
    lamp(B, "motor_fault", on_hood(-0.05, -0.13), hb3, "amber")
    lamp(B, "console_power", on_hood(-0.35, -0.13), hb3, "green")
    label(B, "LIGHT CONTROL", on_hood(-0.42, 0.1), hb3, 0.3)
    label(B, "MOTOR LOAD", on_hood(-0.05, -0.17), hb3, 0.12)
    label(B, "BEARING", on_hood(0.32, -0.19), hb3, 0.12)
    rivets(B, on_hood(-0.78, 0.19), on_hood(0.78, 0.19), 16, hb3)
    box(B.bm("M_LL_Paper"), on_hood(-0.62, -0.05) + hb3.col[2] * 0.004, (0.16, 0.11, 0.002), hb3)
    B.empty("IA_note", on_hood(-0.62, -0.05) + hb3.col[2] * 0.03, (0.1, 0.08, 0.04), hb3)

    def on_top(x, y):
        return top_c + top_b3.col[0] * x + top_b3.col[1] * y
    for key, x in (("mode", 0.2), ("intensity", 0.5)):
        cpos = on_top(x, 0.0)
        disc_uv(B.bm("M_LL_Atlas"), B.uv(B.bm("M_LL_Atlas")), cpos + top_b3.col[2] * 0.002, top_b3, 0.1, 40, CELLS[f"{key}_plate"])
        B.part(f"PT_{key}", "M_LL_Bakelite", cpos + top_b3.col[2] * 0.003, top_b3, selector_fn(0.038),
               extra_mats=("M_LL_Ceramic",))
        B.empty(f"IA_{key}", cpos + top_b3.col[2] * 0.03, (0.07, 0.07, 0.05), top_b3)
    for k in range(4):
        sphere(B.bm("M_LL_Iron"), on_top(-0.75 + k * 0.5, 0.14), 0.007, 6, 4)
    fb3, fc = face_frame(b, -0.35, 0.5, front - 0.005)

    def wheel(bm, uv):
        rr = 0.22
        torus(bm, (0, 0, 0.07), rr, 0.016, 40, 8)
        for k in range(8):
            a = 2 * math.pi * k / 8
            seg_cyl(bm, (0, 0, 0.06), (rr * math.cos(a), rr * math.sin(a), 0.07), 0.01, 8)
            sphere(bm, ((rr + 0.045) * math.cos(a), (rr + 0.045) * math.sin(a), 0.07), 0.018, 8, 6)
            seg_cyl(bm, (rr * math.cos(a), rr * math.sin(a), 0.07), ((rr + 0.03) * math.cos(a), (rr + 0.03) * math.sin(a), 0.07), 0.01, 6)
        cyl(bm, (0, 0, 0.04), 0.045, 0.045, 0.08, 16)
    B.part("PT_handwheel", "M_LL_Brass", fc, fb3, wheel)
    cyl(B.bm("M_LL_Iron"), fc + fb3.col[2] * 0.01, 0.06, 0.06, 0.03, 16, fb3)
    B.empty("IA_handwheel", fc + fb3.col[2] * 0.07, (0.26, 0.26, 0.08), fb3)
    label(B, "HANDWHEEL", fc - fb3.col[1] * 0.32, fb3, 0.16)
    box(B.bm("M_LL_SteelPaint"), dp(b, 0.4, 0.42, front - 0.006), (0.5, 0.01, 0.5), bs)
    box(B.bm("M_LL_Brass"), dp(b, 0.6, 0.42, front - 0.015), (0.03, 0.02, 0.1), bs)
    B.collider("console", dp(b, 0, 0.55, back - d / 2), (w + 0.04, d + 0.04, 1.1), bs)
    B.empty("IA_console", dp(b, 0, 0.9, back - d / 2), (0.8, 0.45, 0.3), bs)
    B.empty("FOCUS_console", dp(b, 0.0, 1.55, front - 0.75), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_console_at", dp(b, 0.0, 0.85, front + 0.25), (0.05, 0.05, 0.05), kind="SPHERE")
    drop(B, b, -0.7, 2.78, 1.4, back - 0.05, 0.03)
    st = dp(b - 16, 0, 0, front - 0.45)
    cyl(B.bm("M_LL_Wood"), st + Vector((0, 0, 0.62)), 0.17, 0.17, 0.04, 20)
    for k in range(3):
        a = 2 * math.pi * k / 3
        seg_cyl(B.bm("M_LL_Wood"), st + Vector((0.13 * math.cos(a), 0.13 * math.sin(a), 0.6)), st + Vector((0.2 * math.cos(a), 0.2 * math.sin(a), 0.0)), 0.016)
    torus(B.bm("M_LL_Wood"), st + Vector((0, 0, 0.25)), 0.17, 0.01, 16, 6)
    B.collider("stool", st + Vector((0, 0, 0.32)), (0.4, 0.4, 0.64))


def build_optic_drive(B):
    """Optic drive (Stage 1 iteration 3, REFERENCE_SPEC 1.0): an electric rotation motor and reduction
    gearbox drive the optic above through a vertical shaft; the old weight-driven clockwork is kept as
    standby on the same gear race. No lens parts (the Fresnel optic is in the lantern). The worn tooth
    that stalls the drive at 046 (1953 and tonight) carries a dab of red paint."""
    b = R["optic_drive"]
    r_, o, u = wall_frame(b)
    c = o * 2.78
    cast = B.bm("M_LL_SteelPaint", "SM_OpticDrive")
    brass = B.bm("M_LL_Brass", "SM_OpticDrive")
    # cast pedestal and upper housing (grey-green: brass up there mirrored the dark ceiling as black)
    cyl(cast, c + u * (F + 0.25), 0.42, 0.4, 0.5, 40)
    cyl(brass, c + u * (F + 0.515), 0.37, 0.37, 0.03, 40)
    cyl(brass, c + u * (F + 2.03), 0.36, 0.36, 0.05, 40)
    cyl(cast, c + u * (F + 2.6), 0.24, 0.3, 1.0, 40)
    # octagonal glazed cabinet: brass posts, grey-green astragals, flat panes
    R8 = 0.345
    pts = [Vector((math.cos(2 * math.pi * k / 8 + math.pi / 8), math.sin(2 * math.pi * k / 8 + math.pi / 8), 0)) for k in range(8)]
    for dv in pts:
        box(brass, c + dv * R8 + u * (F + 1.28), (0.03, 0.03, 1.5), basis_z(Vector((0, 0, 1)), Vector((-dv.y, dv.x, 0))))
    for z in (0.56, 1.28, 2.0):
        for k in range(8):
            p0, p1 = c + pts[k] * R8 + u * (F + z), c + pts[(k + 1) % 8] * R8 + u * (F + z)
            seg_cyl(cast, p0, p1, 0.012, 6)
    gb = bmesh.new()
    gb.loops.layers.uv.new("UVMap")
    for k in range(8):
        p0, p1 = c + pts[k] * (R8 - 0.005), c + pts[(k + 1) % 8] * (R8 - 0.005)
        mid = (p0 + p1) / 2
        side = (p1 - p0)
        nrm = Vector((mid.x - c.x, mid.y - c.y, 0)).normalized()
        box(gb, mid + u * (F + 1.28), (side.length - 0.03, 0.006, 1.42), basis(side.normalized(), nrm, Vector((0, 0, 1))), bevel=0.0)
    B.mesh_obj("GLS_optic_drive", gb, "M_LL_Glass")
    # motor and reduction gearbox on the pedestal top
    off = r_ * 0.14
    # cabin pass (IMG_3141 audit): motor and gearbox SIT on the pedestal plate (F+0.53); they floated 9 / 4 cm
    pz = F + 0.53
    box(cast, c + off + u * (pz + 0.03), (0.2, 0.16, 0.06), basis(r_, o, u))                # motor cradle
    cyl(cast, c + off + u * (pz + 0.16), 0.1, 0.1, 0.26, 24, basis_z(r_))                   # motor body
    for k in range(5):
        torus(cast, c + off + r_ * (-0.09 + k * 0.045) + u * (pz + 0.16), 0.102, 0.008, 24, 4, basis_z(r_))   # cooling fins
    cyl(B.bm("M_LL_Iron", "SM_OpticDrive"), c + off + r_ * 0.15 + u * (pz + 0.16), 0.06, 0.06, 0.04, 16, basis_z(r_))
    box(cast, c - r_ * 0.05 + u * (pz + 0.13), (0.2, 0.22, 0.26), basis(r_, o, u))          # gearbox
    lamp(B, "optic_motor", c + off + u * (pz + 0.27) - o * 0.05, basis(r_, -o, u), "green", 0.01)

    def drum(bm, uv):
        # rotating train (turns with the beam): crown wheel with the marked worn tooth, two standby
        # clockwork wheels on the same race, the drive shaft
        red = []
        for z, rr, n in ((-0.38, 0.26, 36), (0.05, 0.17, 24), (0.4, 0.21, 28)):
            cyl(bm, (0, 0, z), rr, rr, 0.035, n)
            cyl(bm, (0, 0, z), 0.05, 0.05, 0.06, 12)
            for i in range(n):
                a = 2 * math.pi * i / n
                vv = made(bm, lambda a=a, rr=rr, z=z: box(bm, ((rr + 0.012) * math.cos(a), (rr + 0.012) * math.sin(a), z),
                                                         (0.022, 0.014, 0.035), basis_z(Vector((0, 0, 1)), Vector((math.cos(a), math.sin(a), 0)))))
                if z < -0.3 and i == 0:
                    red += vv                                          # the worn tooth at 046
        for k in range(4):                                             # crown-wheel spokes
            a = math.pi * k / 4
            box(bm, (0, 0, -0.38), (0.5 * abs(math.cos(a)) + 0.02, 0.5 * abs(math.sin(a)) + 0.02, 0.02))
        cyl(bm, (0, 0, 0.035), 0.03, 0.03, 1.43, 12)                 # drive shaft: seated in the gearbox, up into the top plate
        tag(red, 1)
    B.part("PT_optic_drive", "M_LL_Brass", c + u * (F + 1.28), Matrix.Identity(3), drum, extra_mats=("M_LL_Red",))

    def governor(bm, uv):
        # fly-ball governor HANGING from the cabinet's top plate (cabin pass, IMG_3141: it stood with its
        # spindle through the upper standby wheel and its balls swept the drive shaft). Spin radius 0.12 m.
        cyl(bm, (0, 0, 0.0), 0.011, 0.011, 0.29, 10)                  # spindle, top end in the plate boss
        cyl(bm, (0, 0, 0.135), 0.026, 0.026, 0.02, 12)               # boss under the plate
        cyl(bm, (0, 0, -0.06), 0.026, 0.026, 0.025, 12)              # sliding collar
        for sx in (-1, 1):
            seg_cyl(bm, Vector((0, 0, 0.08)), Vector((sx * 0.09, 0, -0.02)), 0.0045, 6)
            seg_cyl(bm, Vector((0, 0, -0.06)), Vector((sx * 0.06, 0, -0.005)), 0.0035, 6)   # links to the collar
            sphere(bm, Vector((sx * 0.095, 0, -0.035)), 0.025, 12, 8)
    # spindle 0.17 m off the shaft axis: balls clear the shaft by 2 cm and the glazing by 3 cm; their lowest
    # point (F+1.80) is 10 cm above the upper wheel's top (F+1.70); the boss meets the top plate (F+2.005)
    B.part("PT_optic_governor", "M_LL_Brass", c - r_ * 0.15 + o * 0.08 + u * (F + 1.86), Matrix.Identity(3), governor)
    # revolution counter on the gearbox FACE, below the crown wheel (it sat at the wheel's height, inside it)
    rc = c - r_ * 0.05 - o * 0.158 + u * (F + 0.76)
    cyl(brass, rc, 0.04, 0.04, 0.1, 16, basis_z(r_))
    cyl(B.bm("M_LL_Ceramic", "SM_OpticDrive"), rc, 0.042, 0.042, 0.05, 16, basis_z(r_))
    box(brass, rc + o * 0.03, (0.06, 0.04, 0.05), basis(r_, o, u))                      # its mounting bracket
    # standby clockwork: winding crank outside the glazing, and the weight tube down through the floor
    ck = c - o * (R8 + 0.06) + r_ * 0.12 + u * (F + 0.42)
    cyl(B.bm("M_LL_Iron", "SM_OpticDrive"), ck, 0.02, 0.02, 0.08, 10, basis_z(-o))
    box(B.bm("M_LL_Iron", "SM_OpticDrive"), ck - o * 0.04 + u * 0.06, (0.02, 0.02, 0.14))
    cyl(B.bm("M_LL_WoodDark", "SM_OpticDrive"), ck - o * 0.07 + u * 0.12, 0.016, 0.016, 0.07, 10, basis_z(-o))
    wt = c + r_ * 0.5 + o * 0.12
    seg_cyl(B.bm("M_LL_Iron", "SM_OpticDrive"), wt + u * (F - 0.3), wt + u * (F + 0.55), 0.06, 16)
    cyl(brass, wt + u * (F + 0.01), 0.085, 0.085, 0.02, 20)
    # lineshaft to the centre hub (manual fallback from the console handwheel) and the pinion there
    seg_cyl(B.bm("M_LL_Brass", "SM_OpticDrive"), c + u * (CEIL - 0.3), Vector((0, 0, CEIL - 0.3)), 0.045, 12)
    cyl(B.bm("M_LL_Iron"), (0, 0, CEIL - 0.3), 0.16, 0.16, 0.22, 20)

    def gear(bm, uv):
        cyl(bm, (0, 0, 0), 0.13, 0.13, 0.05, 24)
        for i in range(24):
            a = 2 * math.pi * i / 24
            box(bm, (0.14 * math.cos(a), 0.14 * math.sin(a), 0), (0.02, 0.014, 0.05), basis_z(Vector((0, 0, 1)), Vector((math.cos(a), math.sin(a), 0))))
    B.part("PT_optic_gear", "M_LL_Brass", Vector((0, 0, CEIL - 0.44)), Matrix.Identity(3), gear)
    B.collider("optic_drive", c + u * (F + 1.5), (0.86, 0.86, 3.0))


def build_photo(B):
    """The keepers' photograph above the battery rack. (The oak archive cabinet that stood beside the stair
    door was removed in Stage 1 iteration 3 at Daniel's request; the old logs are on the storage shelf.)"""
    pb3, pc = face_frame(-105.0, 0.0, 1.85, back_dist(0.5, 0.0))
    photo_frame(B, pc, pb3)
    B.empty("IA_photo", pc + pb3.col[2] * 0.05, (0.22, 0.18, 0.05), pb3)


def photo_frame(B, pc, pb3, pw=0.33):
    """Framed print (IMG_3122). Before: a blank M_LL_Paper box. Now: the story photograph (documents.py ->
    T_LL_Photo: Iain & Callum Mackay, May 1952) on a backing board, a mitred oak moulding that slopes up to
    a raised inner lip, and a glass pane (shadowless, see station.gd)."""
    ph = pw * 960 / 1180                     # texture aspect
    A, Bh = pw / 2 + 0.034, ph / 2 + 0.034   # moulding outer half-size
    a, bh = pw / 2 - 0.004, ph / 2 - 0.004   # inner edge laps 4 mm over the print
    wood = B.bm("M_LL_WoodDark", "SM_RoomPhoto")
    P = lambda x, y, z: pc + pb3 @ Vector((x, y, z))
    for (ox0, oy0, ox1, oy1, ix0, iy0, ix1, iy1) in ((-A, -Bh, A, -Bh, -a, -bh, a, -bh), (A, -Bh, A, Bh, a, -bh, a, bh),
                                                  (A, Bh, -A, Bh, a, bh, -a, bh), (-A, Bh, -A, -Bh, -a, bh, -a, -bh)):
        hexa(wood, [P(ox0, oy0, 0), P(ox1, oy1, 0), P(ix1, iy1, 0.004), P(ix0, iy0, 0.004),
                    P(ox0, oy0, 0.018), P(ox1, oy1, 0.018), P(ix1, iy1, 0.027), P(ix0, iy0, 0.027)])
    box(wood, pc + pb3.col[2] * 0.004, (2 * A - 0.01, 2 * Bh - 0.01, 0.006), pb3)            # backing board
    photo = B.bm("M_LL_Photo")
    quad_uv(photo, B.uv(photo), pc + pb3.col[2] * 0.0085, pb3, pw, ph, (0, 0, 1, 1))
    box(B.bm("M_LL_Glass", "SM_PhotoGlass"), pc + pb3.col[2] * 0.0165, (pw + 0.02, ph + 0.02, 0.0015), pb3)


def logbook(B, c, b3, pw=0.28, pd=0.196):
    """Open ledger: leather boards and spine, two curved page blocks (rising from the gutter, flattening
    toward the fore-edge) whose top sheet carries the log texture; a red ribbon marker."""
    P = lambda x, y, z: c + b3 @ Vector((x, y, z))
    lea = B.bm("M_LL_Leather", "SM_RoomLog")
    # Stage 1 iteration 5: quarter-bound ledger - cloth boards, leather spine and corner protectors
    for s in (-1, 1):
        solid(B, "cloth_red", lambda bm, s=s: box(bm, P(s * (pw / 2 + 0.006), 0, 0.0025), (pw + 0.012, pd + 0.014, 0.004), b3, bevel=0.0))
        for sy in (-1, 1):
            X, Y, L = s * (pw + 0.012), sy * (pd / 2 + 0.007), 0.032
            pts = [(X, Y), (X - s * L, Y), (X, Y - sy * L)]
            hexa(lea, [P(x, y, 0.0004) for x, y in pts] + [P(pts[0][0], pts[0][1], 0.0004)] +
                 [P(x, y, 0.0048) for x, y in pts] + [P(pts[0][0], pts[0][1], 0.0048)])
    cyl(lea, P(0, 0, 0.004), 0.011, 0.011, pd + 0.014, 12, b3 @ basis_z(Vector((0, 1, 0))))
    paper = B.bm("M_LL_Paper", "SM_RoomLog")
    tex = B.bm("M_LL_Logbook")
    uvl = B.uv(tex)
    N = 12

    def zt(t):
        return 0.006 + 0.012 * math.sin(min(1.0, t * 1.25) * math.pi / 2) - 0.002 * t
    for s in (-1, 1):
        for i in range(N):
            t0, t1 = i / N, (i + 1) / N
            x0, x1 = s * pw * t0, s * pw * t1
            h0, h1 = zt(t0), zt(t1)
            hexa(paper, [P(x0, -pd / 2, 0.004), P(x1, -pd / 2, 0.004), P(x1, pd / 2, 0.004), P(x0, pd / 2, 0.004),
                         P(x0, -pd / 2, h0 - 0.0008), P(x1, -pd / 2, h1 - 0.0008), P(x1, pd / 2, h1 - 0.0008), P(x0, pd / 2, h0 - 0.0008)])
            (xa, ha, ua), (xb, hb, ub) = sorted(((x0, h0, 0.5 + s * 0.5 * t0), (x1, h1, 0.5 + s * 0.5 * t1)))
            vs = [tex.verts.new(P(xa, -pd / 2, ha)), tex.verts.new(P(xb, -pd / 2, hb)),
                  tex.verts.new(P(xb, pd / 2, hb)), tex.verts.new(P(xa, pd / 2, ha))]
            f = tex.faces.new(vs)          # CCW seen from +Z (textured buckets keep their winding)
            for loop, uvv in zip(f.loops, ((ua, 0.0), (ub, 0.0), (ub, 1.0), (ua, 1.0))):
                loop[uvl].uv = uvv
    box(B.bm("M_LL_Red", "SM_RoomLog"), P(0.012, -pd / 2 - 0.02, 0.0045), (0.007, 0.05, 0.0008), b3)   # ribbon
    # printed page edges on the reader's side and the fore-edges (the paper slabs alone read as one block)
    pm = B.bm("M_LL_Props")
    puv = B.uv(pm)
    for s in (-1, 1):
        for i in range(N):
            t0, t1 = i / N, (i + 1) / N
            x0, x1 = s * pw * t0, s * pw * t1
            h0, h1 = zt(t0) - 0.0008, zt(t1) - 0.0008
            q = [(x0, 0.004, t0), (x1, 0.004, t1), (x1, h1, t1), (x0, h0, t0)]
            if s < 0:
                q = [q[1], q[0], q[3], q[2]]
            f = pm.faces.new([pm.verts.new(P(x, -pd / 2 - 0.0003, z)) for x, z, _ in q])
            for lp, (x, z, t) in zip(f.loops, q):
                lp[puv].uv = region_uv("page_edge", t, (z - 0.004) / 0.012)
        xe, he = s * (pw + 0.0003), zt(1.0) - 0.0008
        q = [(-pd / 2, 0.004), (pd / 2, 0.004), (pd / 2, he), (-pd / 2, he)]
        if s < 0:
            q = [q[1], q[0], q[3], q[2]]
        f = pm.faces.new([pm.verts.new(P(xe, y, z)) for y, z in q])
        for lp, (y, z) in zip(f.loops, q):
            lp[puv].uv = region_uv("page_edge", y / pd + 0.5, (z - 0.004) / 0.012)


def well_glass(B, i, base, r, o, u):
    """Cast well-glass bulkhead fitting at `base` on a surface whose normal points along -o (into the
    room): backplate, neck, glass globe, brass guard. Creates LMP_wall_<i> and LIGHT_wall_<i>."""
    fb3 = basis(r, u, -o)
    brass = B.bm("M_LL_Brass", "SM_WallLamps")
    cyl(brass, base - o * 0.015, 0.085, 0.08, 0.03, 24, fb3)                          # cast backplate
    cyl(B.bm("M_LL_Iron", "SM_WallLamps"), base - o * 0.05, 0.035, 0.03, 0.05, 16, fb3)  # neck
    g = base - o * 0.135
    sphere(B.bm("M_LL_Glass", "SM_WallLampGlass"), g, 0.072, 18, 12)
    torus(brass, g, 0.079, 0.0045, 28, 5, basis_z(r))                                 # meridian
    torus(brass, g, 0.079, 0.0045, 28, 5, basis_z(u))                                 # equator
    torus(brass, g, 0.079, 0.0045, 28, 5, basis_z(o))                                 # front ring
    cyl(brass, g - o * 0.075, 0.02, 0.02, 0.012, 12, fb3)                             # guard boss
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    sphere(bm, g, 0.032)
    B.mesh_obj(f"LMP_wall_{i}", bm, "M_LL_Lamp")
    B.empty(f"LIGHT_wall_{i}", g, (0.05, 0.05, 0.05), kind="SPHERE")


def build_wall_lamps(B):
    """Cast well-glass bulkhead fittings (Stage 1 iteration 2). SM_WallLamps casts no shadows
    (station.gd), so the guard throws no stripes. A fifth one hangs over the stair door (build_stair)."""
    for i, b in enumerate(R["wall_lamps"]):
        z = 2.15 if abs(b) < 120 else 2.25
        r, o, u = wall_frame(b)
        well_glass(B, i, dp(b, 0, z, R_IN - 0.02), r, o, u)


def conduit(B, b0, b1, z, dist=None, r=0.013, step=4.0):
    """Surface steel conduit along the wall from bearing b0 to b1 at height z, with saddle clips."""
    dist = dist if dist is not None else R_IN - 0.045
    bm = B.bm("M_LL_Iron", "SM_RoomConduit")
    n = max(1, int(abs(b1 - b0) / step))
    pts = [dp(b0 + (b1 - b0) * k / n, 0, z, dist) for k in range(n + 1)]
    for p0, p1 in zip(pts, pts[1:]):
        seg_cyl(bm, p0, p1, r, 8)
    for k in range(0, n + 1, 3):
        bb = b0 + (b1 - b0) * k / n
        box(bm, dp(bb, 0, z, dist + 0.012), (0.035, 0.02, 0.04), wb(bb))


def build_conduits(B):
    """The power chain made visible (REFERENCE_SPEC Stage 1 review): generator -> charger -> batteries ->
    distribution -> the room / lamp / radar circuits (the ring mains at 2.78 m)."""
    gen, chg, bat, dist = R["generator"], R["charger"], R["batteries"], R["distribution"]
    d = R_IN - 0.045
    conduit(B, gen, chg, 2.35)                                  # generator output to the charger
    drop(B, gen, 0.25, 2.35, 1.72, d, 0.013)
    drop(B, chg, -0.18, 2.35, 1.82, d, 0.013)
    conduit(B, chg, bat, 2.45)                                  # charger to the battery bank
    drop(B, chg, 0.0, 2.45, 1.82, d, 0.013)
    drop(B, bat, -0.3, 2.45, 0.95, d, 0.013)
    conduit(B, bat, dist, 2.55)                                 # battery bank to the distribution board
    drop(B, bat, 0.3, 2.55, 0.95, d, 0.013)
    drop(B, dist, 0.2, 2.55, 1.85, d, 0.013)
    drop(B, dist, -0.2, 2.78, 1.85, d, 0.016)                   # distribution up to the ring mains


def build_props(B):
    """Stage 1 iteration 4: the approved story and lived-in props (REFERENCE_SPEC props table).
    Each one says why it is here: story (S), realism (R), composition (C)."""
    # (S/R) NLB calendar, November 1971, the 14th ringed: on the pier between the west and centre windows
    cb = -18.0
    cr, co, cu = wall_frame(cb)
    cc = dp(cb, 0, 1.55, R_IN - 0.012)
    fb3 = basis(cr, cu, -co)
    pm = B.bm("M_LL_Props")
    A = 2048.0
    px = lambda x0, y0, x1, y1: (x0 / A, 1 - y1 / A, x1 / A, 1 - y0 / A)                    # image px -> UV rect
    quad_uv(pm, B.uv(pm), cc, fb3, 0.25, 0.357, px(0, 0, 700, 1000))
    sphere(B.bm("M_LL_Iron"), cc + cu * 0.19 - co * 0.004, 0.006, 6, 4)                          # the nail
    # (R/S) the station wiring diagram, framed under glass, between the distribution board and the charger
    db = -67.0
    dr, do_, du = wall_frame(db)
    dc = dp(db, 0, 2.02, R_IN - 0.02)
    db3 = basis(dr, du, -do_)
    box(B.bm("M_LL_WoodDark", "SM_Props"), dc + do_ * 0.006, (0.47, 0.35, 0.012), db3)
    quad_uv(pm, B.uv(pm), dc - do_ * 0.001, db3, 0.42, 0.305, px(720, 0, 1820, 800))
    box(B.bm("M_LL_Glass", "SM_PropsGlass"), dc - do_ * 0.004, (0.43, 0.315, 0.002), db3, bevel=0.0)
    for sx in (-1, 1):                                  # mirror-plate screws (iteration 5: it floated on the wall)
        for sy in (-1, 1):
            cyl(B.bm("M_LL_Brass", "SM_Props"), dc + dr * (sx * 0.222) + du * (sy * 0.162) - do_ * 0.0005, 0.006, 0.0055, 0.003, 10, basis_z(-do_))
    # (R/S) aneroid barometer, falling tonight: on the pier between the centre and east windows
    bb = 18.0
    br, bo, bu = wall_frame(bb)
    bc = dp(bb, 0, 1.62, R_IN - 0.02)
    bb3 = basis(br, bu, -bo)
    cyl(B.bm("M_LL_Brass", "SM_Props"), bc + bo * 0.006, 0.125, 0.12, 0.03, 40, bb3)
    disc_uv(pm, B.uv(pm), bc - bo * 0.0095, bb3, 0.105, 48, 4, cell_px=1024, atlas_px=2048)        # cell 4 = (0, 1024)
    na = math.radians(-135 + (975 - 950) / 100 * 270)                                           # 975 mb: storm
    nd = br * math.sin(na) + bu * math.cos(na)
    seg_cyl(B.bm("M_LL_Iron", "SM_Props"), bc - bo * 0.013 - nd * 0.02, bc - bo * 0.013 + nd * 0.09, 0.0025, 6)
    cyl(B.bm("M_LL_Brass", "SM_Props"), bc - bo * 0.014, 0.01, 0.01, 0.006, 12, bb3)
    torus(B.bm("M_LL_Brass", "SM_Props"), bc + bu * 0.14 + bo * 0.004, 0.016, 0.0025, 16, 6, basis_z(br))   # hanging ring
    cyl(B.bm("M_LL_Iron", "SM_Props"), bc + bu * 0.152 - bo * 0.002, 0.004, 0.004, 0.012, 8, basis_z(-bo))  # its screw
    # (S) Admiralty Tide Tables on the top storage shelf, the half bottle of Grant's hidden behind them
    sb_ = R["storage"]
    sbs = wb(sb_)
    sc = back_dist(1.4) - 0.25
    for k in range(3):
        box(B.bm("M_LL_ClothBlue", "SM_Props"), dp(sb_, -0.6 + k * 0.035, 1.24, sc - 0.06), (0.03, 0.2, 0.25), sbs)
    bot = dp(sb_, -0.56, 1.113, sc + 0.12)
    cyl(B.bm("M_LL_Whisky", "SM_Props"), bot + Vector((0, 0, 0.075)), 0.035, 0.035, 0.15, 16)
    cyl(B.bm("M_LL_Whisky", "SM_Props"), bot + Vector((0, 0, 0.175)), 0.012, 0.02, 0.05, 12)
    cyl(B.bm("M_LL_Red", "SM_Props"), bot + Vector((0, 0, 0.205)), 0.013, 0.013, 0.012, 12)
    box(B.bm("M_LL_Paper", "SM_Props"), dp(sb_, -0.56, 1.19, sc + 0.084), (0.05, 0.002, 0.06), sbs)   # label
    # (S) the old vapour-burner kit from before electrification, and a box of spare lamp bulbs
    vb = dp(sb_, 0.55, 0.613, sc)
    cyl(B.bm("M_LL_Brass", "SM_Props"), vb + Vector((0, 0, 0.06)), 0.05, 0.06, 0.12, 20)
    sphere(B.bm("M_LL_Paper", "SM_Props"), vb + Vector((0, 0, 0.16)), 0.045, 12, 8)               # spare mantle
    seg_cyl(B.bm("M_LL_Brass", "SM_Props"), vb + Vector((0.0, 0.0, 0.1)), dp(sb_, 0.45, 0.85, sc), 0.008, 8)
    box(B.bm("M_LL_Paper", "SM_Props"), dp(sb_, 0.02, 1.17, sc - 0.02), (0.16, 0.14, 0.11), sbs)    # bulb box
    build_coat_rack(B)                                              # cabin pass (IMG_3137)
    # (C) kettle on an electric ring and a mug on the west window sill: the keeper's long night
    kb = -42.0
    kr, ko, ku = wall_frame(kb)
    ks = dp(kb, 0, 0.95, R_IN - 0.06)
    cyl(B.bm("M_LL_Iron", "SM_Props"), ks + ku * 0.015, 0.1, 0.1, 0.03, 20)
    lathe(B.bm("M_LL_EngineGreen", "SM_Props"), ks + ku * 0.03, Matrix.Identity(3),
          [(0.0, 0.0), (0.09, 0.0), (0.1, 0.05), (0.085, 0.13), (0.03, 0.16), (0.0, 0.16)], 24)
    seg_cyl(B.bm("M_LL_EngineGreen", "SM_Props"), ks + ku * 0.09 + kr * 0.08, ks + ku * 0.15 + kr * 0.15, 0.012, 8)   # spout
    torus(B.bm("M_LL_Bakelite", "SM_Props"), ks + ku * 0.2, 0.06, 0.008, 16, 5, basis_z(kr))                       # handle
    mug = dp(kb + 4.5, 0, 0.95, R_IN - 0.04)
    cyl(B.bm("M_LL_Ceramic", "SM_Props"), mug + Vector((0, 0, 0.045)), 0.035, 0.035, 0.09, 16)
    torus(B.bm("M_LL_Ceramic", "SM_Props"), mug + Vector((0, 0, 0.05)) + kr * 0.04, 0.022, 0.006, 12, 5, basis_z(ko))
    # cabin pass (IMG_3136): the rubber torch LIES on the top shelf by the stair door; it is a real object the
    # keeper can take in a blackout, so it has its own meshes (PROP_torch*: station hides them) and IA_torch.
    # A 1970s two-D-cell rubber torch: knurled body, flared head, chrome bezel, reflector, glass, slide switch.
    tr_, to_, tu_ = wall_frame(sb_)
    tax = (tr_ * math.cos(math.radians(18)) - to_ * math.sin(math.radians(18))).normalized()   # slightly turned to the room
    tilt = math.asin((0.031 - 0.0195) / 0.205)                     # head and tail both touch the board
    tdir = (tax * math.cos(tilt) + tu_ * math.sin(tilt)).normalized()
    tail = dp(sb_, 0.3, 1.4925 + 0.0195, sc - 0.12)
    tb3 = basis_z(tdir, tu_)
    prof = [(0.0, 0.0), (0.0165, 0.0), (0.0195, 0.004), (0.0195, 0.152), (0.021, 0.158), (0.029, 0.19),
            (0.031, 0.203), (0.031, 0.206)]
    solid(B, "rubber", lambda bm: lathe(bm, tail, tb3, prof, 24), prefix="PROP_torch")
    for zk in (0.03, 0.045, 0.06, 0.075, 0.09, 0.105):              # moulded grip rings
        solid(B, "rubber", lambda bm, zk=zk: torus(bm, tail + tdir * zk, 0.0196, 0.0012, 24, 4, tb3), prefix="PROP_torch")
    solid(B, "chrome", lambda bm: lathe(bm, tail + tdir * 0.206, tb3, [(0.0335, 0.0), (0.0335, 0.012), (0.03, 0.014), (0.029, 0.012),
                                                                    (0.029, 0.002), (0.0, 0.002)], 28), prefix="PROP_torch")
    solid(B, "chrome", lambda bm: lathe(bm, tail + tdir * 0.196, tb3, [(0.004, 0.0), (0.006, 0.003), (0.027, 0.0185), (0.0, 0.0185)], 24),
          prefix="PROP_torch")                                        # parabolic reflector behind the glass
    cyl(B.bm("M_LL_Glass", "PROP_torchGlass"), tail + tdir * 0.2185, 0.0285, 0.0285, 0.0012, 28, tb3)
    up_side = (tu_ - tdir * tdir.dot(tu_)).normalized()             # the switch faces up
    solid(B, "chrome", lambda bm: box(bm, tail + tdir * 0.128 + up_side * 0.0198, (0.009, 0.004, 0.024),
                                      basis(up_side.cross(tdir), up_side, tdir), bevel=0.0), prefix="PROP_torch")
    solid(B, "chrome", lambda bm: torus(bm, tail - tdir * 0.004, 0.009, 0.0018, 16, 5, basis_z(up_side)), prefix="PROP_torch")  # lanyard ring
    B.empty("IA_torch", tail + tdir * 0.105, (0.04, 0.04, 0.13), tb3)
    # (C) cabin pass (IMG_3138): a tartan shortbread tin on the west sill, its lid off and lying beside it
    # (the old lid floated, tilted, above the rim and the tin read as a plain red disc)
    bt = dp(-30.0, 0, 0.95, R_IN - 0.05)
    tr_, to_, tu_ = wall_frame(-30.0)
    pm = B.bm("M_LL_Props")
    lathe_uv(pm, B.uv(pm), bt, basis(tr_, -to_, tu_), [(0.0, 0.0, 0.0), (0.082, 0.0, 0.0), (0.084, 0.003, 0.0), (0.084, 0.064, 1.0),
             (0.082, 0.066, 1.0), (0.078, 0.066, 1.0), (0.078, 0.008, 1.0), (0.0, 0.008, 1.0)], 40,
             lambda uu, vv: region_uv("tin_band", uu * 3.0 % 1.0, vv))                 # printed tartan band
    solid(B, "tin_gold", lambda bm: torus(bm, bt + tu_ * 0.066, 0.083, 0.0022, 40, 5))   # rolled rim
    for k in range(3):
        solid(B, "wood_raw", lambda bm, k=k: box(bm, bt + tu_ * 0.058 + tr_ * (-0.03 + k * 0.026),
                                                 (0.022, 0.07, 0.014), wb(-30.0) @ rot_about((0, 0, 1), 8.0 * (k - 1)), bevel=0.0))
    lid = bt - tr_ * 0.18 - to_ * 0.0                                                 # lid lying on the sill beside it
    solid(B, "tin_red", lambda bm: cyl(bm, lid + tu_ * 0.007, 0.088, 0.088, 0.014, 40))
    quad_uv(pm, B.uv(pm), lid + tu_ * 0.0142, basis(tr_, -to_, tu_), 0.15, 0.15, region_rect("tin_band", 0.0, 0.0, 0.33, 1.0))
    solid(B, "tin_gold", lambda bm: torus(bm, lid + tu_ * 0.0135, 0.086, 0.0018, 40, 5))
    # (R) touched-up paint at hand height, a slightly different cream (maintained, not new)
    for tb, tz, tw, th in ((-96.0, 1.45, 0.2, 0.14), (101.0, 1.3, 0.16, 0.12), (158.0, 1.55, 0.22, 0.16), (-19.0, 1.12, 0.1, 0.08)):
        assert not in_window(tb), f"touch-up patch at {tb} would float in a window bay"
        tr, to, tu = wall_frame(tb)
        box(B.bm("M_LL_Paper", "SM_Props"), dp(tb, 0, tz, R_IN - 0.0015), (tw, 0.002, th), basis(tr, to, tu), bevel=0.0)



def drape(bm, top, b3, rings, segs=28, ys=0.6, fold=None, hem=None):
    """A hanging garment: rings of (z, r) from the collar down (z negative), squashed front to back by ys,
    with vertical folds fold(theta, t) -> radius factor (t = 0 at the collar, 1 at the hem). Capped at the
    collar; the hem is turned in so it never shows a razor edge."""
    rows = []
    n = len(rings)
    for j, (z, r) in enumerate(rings):
        t = j / (n - 1)
        row = []
        for i in range(segs):
            th = 2 * math.pi * i / segs
            rr = r * (fold(th, t) if fold else 1.0)
            zz = z + (hem(th) * t ** 4 if hem else 0.0)          # uneven hem, fading out toward the collar
            row.append(bm.verts.new(top + b3 @ Vector((rr * math.cos(th), rr * math.sin(th) * ys, zz))))
        rows.append(row)
    z_h, r_h = rings[-1]
    inner = [bm.verts.new(top + b3 @ Vector((r_h * 0.9 * math.cos(2 * math.pi * i / segs), r_h * 0.9 * math.sin(2 * math.pi * i / segs) * ys,
                                              z_h + 0.04 + (hem(2 * math.pi * i / segs) if hem else 0.0)))) for i in range(segs)]
    rows.append(inner)
    for a, b_ in zip(rows, rows[1:]):
        for i in range(segs):
            bm.faces.new((a[i], a[(i + 1) % segs], b_[(i + 1) % segs], b_[i]))
    cap = bm.verts.new(top + b3 @ Vector((0, 0, rings[0][0] + 0.01)))
    for i in range(segs):
        bm.faces.new((cap, rows[0][(i + 1) % segs], rows[0][i]))


def build_coat_rack(B):
    """Cabin pass (IMG_3137): a freestanding oak coat stand left of the stair door, the keeper's oilskin
    hanging from its front hook by the collar, the sou'wester on the finial. The coat: collar, sloped
    shoulders, folds that deepen toward the hem, sleeves hanging forward with turned cuffs, two flapped
    pockets (a folded stores note in the right one: IA_coat_note), the storm flap with toggles."""
    ob = R["stair"] - 21.0                                   # 149: 13 cm clear of the storage rack, 14 of the bulkhead
    orr, oo, ou = wall_frame(ob)
    front = -oo                                              # toward the room
    base = dp(ob, 0, 0, R_IN - 0.55)
    oak = B.bm("M_LL_WoodDark", "SM_CoatRack")
    lathe(oak, base, Matrix.Identity(3), [(0.0, 0.32), (0.034, 0.32), (0.03, 0.36), (0.024, 0.4), (0.022, 1.55), (0.026, 1.6),
                                         (0.022, 1.64), (0.02, 1.78), (0.0, 1.78)], 16)
    sphere(oak, base + ou * 1.80, 0.032, 14, 10)              # finial
    for k in range(3):                                       # tripod legs, splayed, with a turned foot
        a = 2 * math.pi * k / 3 + math.pi / 6
        dvec = (orr * math.cos(a) + oo * math.sin(a)).normalized()
        legs = bezier(base + ou * 0.36, base + ou * 0.22 + dvec * 0.08, base + ou * 0.06 + dvec * 0.2, base + dvec * 0.25 + ou * 0.012, 10)
        sweep(oak, legs, 0.016, 8)
        sphere(oak, base + dvec * 0.25 + ou * 0.012, 0.018, 10, 6)
    brass = B.bm("M_LL_Brass", "SM_CoatRack")
    for k in range(4):                                       # four double hooks at 1.62 m
        a = 2 * math.pi * k / 4 + math.pi / 4
        hd = (orr * math.cos(a) + front * math.sin(a)).normalized()
        h0 = base + ou * 1.62 + hd * 0.02
        sweep(brass, bezier(h0, h0 + hd * 0.05, h0 + hd * 0.09 - ou * 0.01, h0 + hd * 0.095 + ou * 0.04, 8), 0.005, 6)
        sphere(brass, h0 + hd * 0.095 + ou * 0.042, 0.008, 8, 6)
    # the oilskin hangs by its collar loop from the front-RIGHT hook, beside the post (centred in front of it,
    # it read as a mannequin, cp2): no body inside, so the shoulders fall narrow and it hangs flat, the
    # folds deepening toward the hem, the sleeves hanging into its sides
    hdir = (orr + front).normalized()
    hook = base + ou * 1.62 + hdir * 0.095
    cfront = (front * 0.75 + orr * 0.25).normalized()       # it turns a little toward the room as it hangs
    cside = ou.cross(cfront).normalized() * -1.0
    cb3 = basis(cside, cfront, ou)
    top = hook + hdir * 0.02 + cfront * 0.075 + ou * 0.01   # collar loop on the hook, the coat's back toward the post
    oil = B.bm("M_LL_Oilskin", "SM_CoatRack")
    YS = 0.42
    rings = [(-0.02, 0.026), (-0.06, 0.05), (-0.12, 0.092), (-0.2, 0.138), (-0.3, 0.168), (-0.45, 0.176),
             (-0.62, 0.18), (-0.78, 0.196), (-0.9, 0.212), (-0.98, 0.224)]
    drape(oil, top, cb3, rings, 36, YS,
          lambda th, t: 1.0 + t * (0.075 * math.sin(4 * th + 1.1) + 0.045 * math.sin(7 * th + 0.3)) + 0.02 * math.sin(11 * th) * t * t,
          lambda th: 0.03 * math.sin(th) - 0.018 * math.cos(2 * th))     # front a little shorter, the sides dip
    for sx in (-1, 1):                                       # sleeves: from inside the shoulder, a soft bend at the elbow
        pts = bezier(top + cb3 @ Vector((sx * 0.11, 0.0, -0.16)), top + cb3 @ Vector((sx * 0.165, 0.01, -0.32)),
                     top + cb3 @ Vector((sx * 0.175, 0.035, -0.5)), top + cb3 @ Vector((sx * 0.16, 0.03, -0.71)), 9)
        for k in range(len(pts) - 1):                        # tapering segments (sweep has one radius)
            rk = 0.047 - 0.008 * k / (len(pts) - 2)
            dv = pts[k + 1] - pts[k]
            cyl(oil, (pts[k] + pts[k + 1]) / 2, rk, rk + 0.0015, dv.length + 0.01, 14, basis_z(-dv))
        cdv = pts[-1] - pts[-2]
        torus(oil, pts[-1] + cdv.normalized() * 0.004, 0.039, 0.007, 14, 5, basis_z(cdv))   # turned cuff
    lathe(oil, top - ou * 0.035, cb3, [(0.05, -0.02), (0.058, 0.0), (0.06, 0.035), (0.052, 0.04), (0.046, 0.0)], 18)   # collar
    dark = B.bm("M_LL_Bakelite", "SM_CoatRack")
    fy = 0.178 * YS + 0.004                                  # front surface at chest height
    box(dark, top + cb3 @ Vector((0.0, fy, -0.56)), (0.012, 0.007, 0.8), cb3, bevel=0.0)           # storm flap seam
    for zt in (0.24, 0.4, 0.56, 0.72):
        cyl(B.bm("M_LL_WoodDark", "SM_CoatRack"), top + cb3 @ Vector((0.01, fy + 0.007, -zt)), 0.007, 0.007, 0.028, 8, basis_z(cside))
    for sx in (-1, 1):                                       # pocket flaps, slightly proud
        pc = top + cb3 @ Vector((sx * 0.1, 0.185 * YS + 0.006, -0.63))
        box(oil, pc, (0.14, 0.012, 0.055), cb3 @ rot_about((0, 1, 0), sx * 4.0), bevel=0.003)
    # the stores note, folded twice, poking out of the right pocket (IA_coat_note opens it)
    nc = top + cb3 @ Vector((0.1, 0.185 * YS + 0.0, -0.585))
    nb3 = cb3 @ rot_about((0, 1, 0), -14.0)
    pm = B.bm("M_LL_Props")
    solid(B, "page_cream", lambda bm: box(bm, nc, (0.07, 0.003, 0.055), nb3, bevel=0.0), prefix="SM_CoatRack")
    quad_uv(pm, B.uv(pm), nc + nb3.col[1] * 0.0017, basis(nb3.col[0], nb3.col[2], nb3.col[1]), 0.068, 0.053, region_rect("note_fold"))
    B.empty("IA_coat_note", nc + cfront * 0.02, (0.06, 0.05, 0.05), cb3)
    # the sou'wester hangs by its brim from the front-LEFT hook, crown out, brim near vertical
    hk2 = base + ou * 1.62 + (front - orr).normalized() * 0.095
    hax = (front * 0.85 - orr * 0.3 - ou * 0.42).normalized()            # crown toward the room and a little down
    hc = hk2 + ou * 0.04 - (front - orr).normalized() * 0.02 - ou * 0.17   # the brim's top edge rests on the hook
    lathe(oil, hc, basis_z(hax, ou), [(0.0, 0.15), (0.062, 0.14), (0.09, 0.105), (0.098, 0.05), (0.1, 0.012), (0.16, -0.004),
                                      (0.178, -0.02), (0.176, -0.028), (0.155, -0.014), (0.096, 0.004), (0.088, 0.03), (0.0, 0.118)], 28)
    B.collider("coat_rack", base + ou * 0.9 + front * 0.1, (0.6, 0.62, 1.8), basis(orr, front, ou))


def build_storm_lantern(B, base, frame):
    """Cabin pass (IMG_3135): a hurricane lantern standing on the storage shelf (base = shelf top): tin fount
    with a wick knob, glass globe in a wire guard, vented cap and bail handle. 0.3 m tall, 5 cm under the
    top board (it used to float 10 cm above its shelf with the cap through the board above)."""
    r_, o_, u_ = frame
    brass = B.bm("M_LL_Brass", "SM_Storage")
    iron = B.bm("M_LL_Iron", "SM_Storage")
    I3 = Matrix.Identity(3)
    lathe(brass, base, I3, [(0.0, 0.0), (0.06, 0.0), (0.066, 0.008), (0.067, 0.042), (0.058, 0.055), (0.032, 0.062), (0.0, 0.062)], 24)
    cyl(iron, base + u_ * 0.048 + r_ * 0.072, 0.009, 0.009, 0.016, 10, basis_z(r_))       # wick knob
    lathe(B.bm("M_LL_Glass", "SM_StorageGlass"), base + u_ * 0.062, I3,
          [(0.03, 0.0), (0.046, 0.03), (0.053, 0.07), (0.049, 0.11), (0.031, 0.135)], 24)
    for k in range(4):                                       # guard wires following the globe
        a = 2 * math.pi * k / 4 + math.pi / 4
        dv = Vector((math.cos(a), math.sin(a), 0))
        pts = [base + u_ * (0.062 + z) + dv * (rr + 0.006) for z, rr in ((0.0, 0.032), (0.03, 0.048), (0.07, 0.055), (0.11, 0.051), (0.137, 0.033))]
        sweep(iron, pts, 0.0016, 5)
    torus(iron, base + u_ * 0.132, 0.058, 0.0018, 20, 4)
    lathe(brass, base + u_ * 0.197, I3, [(0.0, 0.0), (0.042, 0.0), (0.056, 0.006), (0.047, 0.034), (0.022, 0.048), (0.0, 0.05)], 24)
    cyl(brass, base + u_ * 0.255, 0.018, 0.016, 0.018, 12)  # chimney
    arc = [base + u_ * 0.205 + r_ * (0.058 * math.cos(math.radians(t))) + u_ * (0.075 * math.sin(math.radians(t))) for t in range(0, 181, 15)]
    sweep(iron, arc, 0.0022, 6)                              # bail handle, top at 0.28 m


def build_extinguisher(B):
    """Cabin pass (IMG_3134): a 2-gallon water (soda-acid) extinguisher of the period on its wall bracket.
    Drawn body with rolled shoulders and a foot ring, brass head with a squeeze lever over a carrying handle,
    safety pin and pull ring, a pressure gauge, hose to a horn held in a clip, a wrapped printed label, a
    strap band and wall plate, chips at hand height. Satin red (the old sphere top read as two glowing eyes)."""
    e = R["extinguisher"]
    er, eo, eu = wall_frame(e)
    fr = -eo                                                 # toward the room
    ep = dp(e, 0, 0.34, R_IN - 0.115)                        # foot of the body (it hangs on the bracket)
    red = B.bm("M_LL_Red", "SM_Extinguisher")
    lathe(red, ep, Matrix.Identity(3), [(0.0, 0.0), (0.079, 0.0), (0.086, 0.008), (0.088, 0.03), (0.088, 0.47), (0.086, 0.495),
                                        (0.077, 0.52), (0.057, 0.538), (0.035, 0.546), (0.0, 0.547)], 32)
    iron = B.bm("M_LL_Iron", "SM_Extinguisher")
    torus(iron, ep + eu * 0.004, 0.083, 0.006, 32, 6)        # foot ring
    brass = B.bm("M_LL_Brass", "SM_Extinguisher")
    hd = ep + eu * 0.547
    cyl(brass, hd + eu * 0.016, 0.034, 0.03, 0.032, 24)      # screw cap
    cyl(brass, hd + eu * 0.048, 0.021, 0.021, 0.034, 16)     # valve body
    hb = basis(er, eo, eu)
    box(iron, hd + eu * 0.05 + eo * 0.062, (0.026, 0.1, 0.009), hb, bevel=0.002)                       # carrying handle
    box(iron, hd + eu * 0.074 + eo * 0.055, (0.026, 0.1, 0.008), hb @ rot_about((1, 0, 0), -11.0), bevel=0.002)   # squeeze lever
    seg_cyl(iron, hd + eu * 0.06 - er * 0.03, hd + eu * 0.06 + er * 0.03, 0.0022, 6)                        # safety pin
    torus(iron, hd + eu * 0.06 + er * 0.042, 0.012, 0.0018, 14, 4, basis_z(eo))                          # pull ring
    g = hd + eu * 0.046 + fr * 0.024
    cyl(brass, g, 0.017, 0.017, 0.012, 20, basis_z(fr))       # pressure gauge
    cyl(B.bm("M_LL_Ceramic", "SM_Extinguisher"), g + fr * 0.0062, 0.0145, 0.0145, 0.0008, 20, basis_z(fr))
    seg_cyl(iron, g + fr * 0.0068, g + fr * 0.0068 + (er * 0.7 + eu * 0.7).normalized() * 0.011, 0.0011, 4)   # needle in the green
    hose = bezier(hd + eu * 0.04 - er * 0.022, hd - er * 0.07 + eu * 0.0, ep + eu * 0.42 - er * 0.105, ep + eu * 0.2 - er * 0.1, 14)
    solid(B, "rubber", lambda bm: sweep(bm, hose, 0.008, 8), prefix="SM_Extinguisher")                    # hose
    solid(B, "rubber", lambda bm: cyl(bm, ep + eu * 0.15 - er * 0.1, 0.012, 0.007, 0.1, 10), prefix="SM_Extinguisher")   # horn
    box(iron, ep + eu * 0.24 - er * 0.094, (0.02, 0.03, 0.025), basis(er, eo, eu), bevel=0.0)           # hose clip
    torus(iron, ep + eu * 0.32, 0.0905, 0.004, 32, 4)       # strap band
    box(iron, dp(e, 0, 0.62, R_IN - 0.008), (0.06, 0.012, 0.36), wb(e), bevel=0.002)                    # wall plate
    box(iron, ep + eu * 0.53 + eo * 0.06, (0.03, 0.06, 0.01), basis(er, eo, eu))                        # hook under the shoulder
    for k in range(4):                                       # wall plate screws
        cyl(brass, dp(e, 0, 0.47 + k * 0.1, R_IN - 0.0146), 0.005, 0.005, 0.002, 8, basis_z(fr))
    # wrapped label (props atlas "ext_label"): a 70 degree band of the body's own radius, 13 cm tall
    pm = B.bm("M_LL_Props")
    uvl = B.uv(pm)
    rows = []
    for j, vz in enumerate((0.0, 1.0)):
        row = []
        for i in range(9):
            th = math.radians(-35 + 70 * i / 8)
            pt = ep + eu * (0.22 + 0.13 * vz) + (fr * math.cos(th) + er * math.sin(th)) * 0.0887
            row.append((pm.verts.new(pt), (i / 8, vz)))
        rows.append(row)
    for i in range(8):
        f = pm.faces.new((rows[0][i][0], rows[0][i + 1][0], rows[1][i + 1][0], rows[1][i][0]))
        for lp, uvv in zip(f.loops, (rows[0][i][1], rows[0][i + 1][1], rows[1][i + 1][1], rows[1][i][1])):
            lp[uvl].uv = region_uv("ext_label", *uvv)
    for th_d, zc in ((48, 0.62), (-60, 0.5), (75, 0.14), (12, 0.07)):                     # chips at hand height and at the foot
        th = math.radians(th_d)
        nrm = fr * math.cos(th) + er * math.sin(th)
        cyl(iron, ep + eu * zc + nrm * 0.0884, 0.005 + 0.002 * (th_d % 3), 0.004, 0.0009, 8, basis_z(nrm))


def build_anchors(B):
    """Story anchors (non-interactive empties; Godot ignores them): positions reserved now so later
    story stages never force an architectural rebuild."""
    B.empty("ANCHOR_calendar", dp(-18.0, 0, 1.55, R_IN - 0.02), (0.15, 0.2, 0.01), wb(-18.0))
    B.empty("ANCHOR_diagram", dp(-67.0, 0, 2.0, R_IN - 0.02), (0.3, 0.2, 0.01), wb(-67.0))
    B.empty("ANCHOR_telephone", dp(R["desk"], 0.95, 0.8, 2.75), (0.12, 0.1, 0.08), wb(R["desk"]))
    B.empty("ANCHOR_tide_tables", dp(R["storage"], -0.2, 1.05, R_IN - 0.3), (0.15, 0.1, 0.12), wb(R["storage"]))
    B.empty("ANCHOR_oilskins", dp(R["stair"] - 19.0, 0, 1.7, R_IN - 0.05), (0.2, 0.4, 0.1), wb(R["stair"] - 19.0))   # left of the door
    B.empty("ANCHOR_gear_046", dp(R["optic_drive"], 0, 1.2, 2.78 - 0.3), (0.06, 0.06, 0.06), wb(R["optic_drive"]), kind="SPHERE")


def build_room(B):
    build_shell(B)
    build_desk(B)
    build_power(B)
    build_generator(B)
    build_stair(B)
    build_storage(B)
    build_console(B)
    build_optic_drive(B)
    build_wall_lamps(B)
    build_photo(B)
    build_conduits(B)
    build_anchors(B)
    build_props(B)


# ------------------------------------------------------------------ lighthouse exterior

def ring_slab(bm, r_in, r_out, z0, z1, segs, rot=0.0):
    rings = []
    for (rr, z) in ((r_in, z0), (r_out, z0), (r_out, z1), (r_in, z1)):
        rings.append([bm.verts.new((rr * math.sin(math.radians(rot) + 2 * math.pi * i / segs),
                                    rr * math.cos(math.radians(rot) + 2 * math.pi * i / segs), z)) for i in range(segs)])
    if r_in <= 0.0:
        bm.faces.new(list(reversed(rings[1])))
        bm.faces.new(rings[2])
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[1][i], rings[1][j], rings[2][j], rings[2][i]))
        return
    for k in range(4):
        a, b2 = rings[k], rings[(k + 1) % 4]
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b2[j], b2[i]))


def railing(bm, radius, z0, h, posts):
    for i in range(posts):
        a = 2 * math.pi * i / posts
        cyl(bm, Vector((radius * math.sin(a), radius * math.cos(a), z0 + h / 2)), 0.022, 0.022, h, 6)
    for zz, rr in ((h, 0.03), (h * 0.5, 0.016)):
        n = posts * 2
        for i in range(n):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            seg_cyl(bm, Vector((radius * math.sin(a0), radius * math.cos(a0), z0 + zz)),
                    Vector((radius * math.sin(a1), radius * math.cos(a1), z0 + zz)), rr, 6)


def build_lighthouse(B):
    T = S["tower"]
    conc = B.bm("M_LL_ConcreteExt", "SM_Tower")
    segs = T["segments"]
    cyl(conc, (0, 0, (T["base_z"] + T["top_z"]) / 2), T["radius_base"], T["radius_top"], T["top_z"] - T["base_z"], segs)
    stone = B.bm("M_LL_Stone", "SM_Tower")
    cyl(stone, (0, 0, T["base_z"] + 0.3), T["radius_base"] + 0.5, T["radius_base"] + 0.35, 0.8, segs)
    cyl(stone, (0, 0, T["base_z"] - 1.0), T["radius_base"] + 0.9, T["radius_base"] + 0.6, 2.2, segs)
    for z in (8.0, 14.0):
        rr = T["radius_base"] + (T["radius_top"] - T["radius_base"]) * (z - T["base_z"]) / (T["top_z"] - T["base_z"])
        cyl(conc, (0, 0, z), rr + 0.08, rr + 0.08, 0.25, segs)
    D = T["door"]
    r, o, u = wall_frame(D["bearing"])
    rb = T["radius_base"]
    porch = o * (rb + 0.5) + u * (T["base_z"] + 1.4)
    box(conc, porch, (D["width"] + 1.0, 1.4, 2.8), basis(r, o, u))
    box(B.bm("M_LL_Iron", "SM_Tower"), porch + u * 1.55, (D["width"] + 1.3, 1.6, 0.18), basis(r, o, u))
    box(B.bm("M_LL_SteelPaint", "SM_Tower"), o * (rb + 1.21) + u * (T["base_z"] + D["height"] / 2), (D["width"], 0.04, D["height"]), basis(r, o, u))
    for bearing, zc in T["stair_windows"]:
        rr = rb + (T["radius_top"] - rb) * (zc - T["base_z"]) / (T["top_z"] - T["base_z"])
        r2, o2, u2 = wall_frame(bearing)
        box(B.bm("M_LL_Iron", "SM_Tower"), o2 * (rr - 0.05) + u2 * zc, (0.45, 0.3, 0.8), basis(r2, o2, u2))
    for i in range(32):
        a = 2 * math.pi * i / 32
        d = Vector((math.sin(a), math.cos(a), 0))
        box(conc, d * (R_OUT - 0.25) + Vector((0, 0, CEIL + 0.36)), (0.62, 0.62, 0.32), basis_z(Vector((0, 0, 1)), d.cross(Vector((0, 0, 1)))))
    ring_slab(B.bm("M_LL_Concrete", "SM_Lantern"), 0.0, R_OUT, CEIL + 0.18, CEIL + 0.22, 48)
    G = T["gallery"]
    iron = B.bm("M_LL_Iron", "SM_Gallery")
    ring_slab(iron, R_OUT - 0.05, G["radius"], G["z"] - 0.12, G["z"] - 0.06, 64)
    for i in range(48):
        a = 2 * math.pi * i / 48
        d = Vector((math.sin(a), math.cos(a), 0))
        box(iron, d * (R_OUT + 0.5) + Vector((0, 0, G["z"] - 0.4)), (0.06, 1.0, 0.5), basis_z(Vector((0, 0, 1)), d.cross(Vector((0, 0, 1)))))
    railing(iron, G["radius"] - 0.05, G["z"] - 0.06, G["rail_h"], G["posts"])
    r3, o3, u3 = wall_frame(T["exhaust_bearing"])
    sb = o3 * (R_OUT + 0.1) + r3 * (-0.25) + u3 * (F + 1.4)
    seg_cyl(B.bm("M_LL_SteelRust", "SM_Tower"), sb, sb + o3 * 0.35, 0.08, 14)
    seg_cyl(B.bm("M_LL_SteelRust", "SM_Tower"), sb + o3 * 0.35, sb + o3 * 0.35 + u3 * 2.6, 0.11, 14)
    cyl(B.bm("M_LL_SteelRust", "SM_Tower"), sb + o3 * 0.35 + u3 * 2.7, 0.18, 0.13, 0.2, 14)
    L = S["lantern"]
    lr, sides = L["radius"], L["sides"]
    cyl(B.bm("M_LL_ConcreteExt", "SM_Lantern"), (0, 0, (L["base_z"] + L["glass_z"][0]) / 2), lr, lr, L["glass_z"][0] - L["base_z"], sides)
    ring_slab(B.bm("M_LL_Iron", "SM_Lantern"), lr - 0.05, L["gallery_radius"], L["base_z"] - 0.12, L["base_z"], 32)
    railing(B.bm("M_LL_Iron", "SM_Lantern"), L["gallery_radius"] - 0.05, L["base_z"], 0.95, 24)
    g0, g1 = L["glass_z"]
    lan = B.bm("M_LL_Iron", "SM_Lantern")
    for i in range(sides):
        a = 2 * math.pi * (i + 0.5) / sides
        d = Vector((math.sin(a), math.cos(a), 0))
        box(lan, d * lr + Vector((0, 0, (g0 + g1) / 2)), (0.07, 0.07, g1 - g0), basis_z(Vector((0, 0, 1)), d.cross(Vector((0, 0, 1)))))
    for z in (g0, (g0 + g1) / 2, g1):
        ring_slab(lan, lr - 0.04, lr + 0.04, z - 0.03, z + 0.03, sides)
    gb = bmesh.new()
    gb.loops.layers.uv.new("UVMap")
    cyl(gb, (0, 0, (g0 + g1) / 2), lr - 0.01, lr - 0.01, g1 - g0, sides, caps=False)
    B.mesh_obj("GLS_lantern", gb, "M_LL_Glass")
    copper = B.bm("M_LL_Copper", "SM_Lantern")
    prev = None
    for k in range(7):
        t = k / 6
        rr = (lr + 0.12) * math.cos(t * math.pi / 2)
        z = g1 + L["dome_h"] * math.sin(t * math.pi / 2)
        if prev is not None:
            cyl(copper, (0, 0, (prev[1] + z) / 2), prev[0], max(rr, 0.05), max(z - prev[1], 0.01), 24, caps=False)
        prev = (rr, z)
    cyl(copper, (0, 0, g1 + 0.03), lr + 0.18, lr + 0.12, 0.06, 24)
    sphere(copper, (0, 0, g1 + L["dome_h"] + 0.22), 0.28, 16, 10)
    cyl(B.bm("M_LL_Iron", "SM_Lantern"), (0, 0, g1 + L["dome_h"] + 1.0), 0.02, 0.01, 1.4, 6)
    cyl(B.bm("M_LL_Brass", "SM_Lantern"), (0, 0, (L["base_z"] + L["optic_z"] - 0.6) / 2), 0.25, 0.32, L["optic_z"] - 0.6 - L["base_z"], 16)

    def optic(bm, uv):
        cyl(bm, (0, 0, 0), 0.62, 0.62, 1.1, 16)
        for i in range(8):
            a = 2 * math.pi * i / 8
            dv = Vector((math.cos(a), math.sin(a), 0))
            box(bm, dv * 0.63, (0.04, 0.05, 1.12), basis_z(Vector((0, 0, 1)), Vector((-dv.y, dv.x, 0))))
        for z in (-0.3, 0.0, 0.3):
            bmesh.ops.create_cone(bm, cap_ends=False, segments=16, radius1=0.65, radius2=0.65, depth=0.025, matrix=m4(Vector((0, 0, z))))
    B.part("PT_optic", "M_LL_Lens", (0, 0, L["optic_z"]), Matrix.Identity(3), optic)
    B.empty("LIGHT_lamp", (0, 0, L["optic_z"]), (0.1, 0.1, 0.1), kind="SPHERE")


# ------------------------------------------------------------------ main

def reset(name):
    coll = bpy.data.collections.get(name)
    if coll:
        for o in list(coll.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
    return get_collection(name)


def build():
    set_metric_units()
    room = reset("ASSET_watch_room")
    B = Builder(room)
    build_room(B)
    B.flush()
    lh = reset("ASSET_lighthouse")
    B2 = Builder(lh)
    build_lighthouse(B2)
    B2.flush()
    stats = {}
    for c in (room, lh):
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in c.objects if o.type == "MESH")
        stats[c.name] = {"objects": len(c.objects), "tris": tris}
    return stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--new", action="store_true")
    ap.add_argument("--save", action="store_true")
    args = parse(ap)
    if args.new:
        if not bpy.app.background:
            raise SystemExit("--new is refused in a live GUI session")
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    stats = build()
    if args.save:
        stats["saved"] = save_versioned(HERE, "last_light")
    print("BUILD_RESULT " + json.dumps(stats))


if __name__ == "__main__":
    main()
