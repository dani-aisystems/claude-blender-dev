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
    "M_LL_Lamp": ("#FFE2B0", 0.4, 0.0, {"emission_hex": "#FFB45C", "emission_strength": 2.0}),
    "M_LL_LampRed": ("#8A1A12", 0.4, 0.0, {"emission_hex": "#FF2A1A", "emission_strength": 0.0}),
    "M_LL_LampGreen": ("#1A5A2A", 0.4, 0.0, {"emission_hex": "#40FF70", "emission_strength": 0.0}),
    "M_LL_LampAmber": ("#6A4810", 0.4, 0.0, {"emission_hex": "#FFAA20", "emission_strength": 0.0}),
    "M_LL_Screen": ("#06140C", 0.2, 0.0, {}),
    "M_LL_Collision": ("#FF00FF", 1.0, 0.0, {}),
}
TEXTURED = {"M_LL_Atlas": "T_LL_Atlas.png", "M_LL_Chart": "T_LL_Chart.png", "M_LL_Rose": "T_LL_Rose.png",
            "M_LL_Rug": "T_LL_Rug.png",
            "M_LL_Photo": "T_LL_Photo.png", "M_LL_Logbook": "T_LL_Logbook.png"}   # documents.py (Iteration A)


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


def box(bm, loc, size, b3=None, bevel=None):
    """Box; every box thicker than 12 mm gets a small chamfer (min(6 mm, 20 % of its thinnest side)).
    bevel=0 disables it (colliders); a number forces that width."""
    mat = m4(Vector(loc), b3) @ Matrix.Diagonal((*size, 1.0))
    verts = bmesh.ops.create_cube(bm, size=1.0, matrix=mat)["verts"]
    thin = min(abs(v) for v in size)
    w = bevel if bevel is not None else (min(BEVEL["max"], 0.2 * thin) if BEVEL["on"] and thin >= 0.012 else 0.0)
    if w <= 0.0:
        return verts
    faces = list({f for v in verts for f in v.link_faces})
    edges = list({e for v in verts for e in v.link_edges})
    out = bmesh.ops.bevel(bm, geom=edges, offset=w, offset_type="OFFSET", segments=1, profile=0.5,
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
    box(B.bm("M_LL_Wood"), dp(b, 0, top - 0.025, c), (w, d, 0.05), bs)
    box(B.bm("M_LL_WoodDark"), dp(b, 0, top - 0.06, c - d / 2 + 0.02), (w - 0.04, 0.03, 0.04), bs)
    for s in (-1, 1):
        px = s * (w / 2 - 0.27)
        box(B.bm("M_LL_SteelPaint"), dp(b, px, (top - 0.05) / 2, c), (0.5, d - 0.06, top - 0.05), bs)
        for k in range(3):
            z = 0.12 + k * 0.22
            box(B.bm("M_LL_SteelPaint"), dp(b, px, z + 0.08, c - d / 2 + 0.03), (0.46, 0.02, 0.19), bs)
            box(B.bm("M_LL_Brass"), dp(b, px, z + 0.14, c - d / 2 + 0.015), (0.12, 0.02, 0.018), bs)
    B.collider("desk", dp(b, 0, 0.42, c), (w + 0.04, d + 0.04, 0.84), bs)
    B.empty("IA_drawer", dp(b, -(w / 2 - 0.27), 0.2, c - d / 2 - 0.02), (0.24, 0.06, 0.11), bs)
    # teleprinter forecast sheet beside the radar
    fs = basis_z(u, r * math.cos(-0.25) + o * math.sin(-0.25))
    box(B.bm("M_LL_Paper"), dp(b, 0.82, top + 0.003, c - 0.25), (0.21, 0.28, 0.002), fs)
    B.empty("IA_forecast", dp(b, 0.82, top + 0.03, c - 0.25), (0.12, 0.15, 0.04), fs)
    # transceiver (left of centre, R3)
    steel = B.bm("M_LL_SteelPaint")
    rx_d = back - 0.2
    box(steel, dp(b, -0.38, top + 0.14, rx_d), (0.56, 0.34, 0.28), bs)
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

    def mic(bm, uv):
        cyl(bm, (0, 0, 0.012), 0.06, 0.07, 0.024, 20)
        seg_cyl(bm, (0, 0, 0.02), (0, 0, 0.2), 0.008)
        cyl(bm, (0, 0, 0.24), 0.03, 0.03, 0.08, 14, basis_z(Vector((0, 1, 0))))
    B.part("PT_handset", "M_LL_Bakelite", dp(b, -0.02, top, back - 0.45), Matrix.Identity(3), mic)
    # radar (right of centre, R1)
    rd = back - 0.24
    box(steel, dp(b, 0.42, top + 0.22, rd), (0.44, 0.44, 0.44), bs)
    pb3, pc = face_frame(b, 0.42, top + 0.24, rd - 0.22 - 0.002)
    cyl(B.bm("M_LL_Iron"), pc + pb3.col[2] * 0.03, 0.185, 0.17, 0.06, 32, pb3, caps=False)
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
    quad_uv(B.bm("M_LL_Chart"), B.uv(B.bm("M_LL_Chart")), dp(b, 0.1, top + 0.002, c - 0.12), top_b3, 0.8, 0.6, (0, 0, 1, 1))
    # Station log (IMG_3119): open NLB ledger with the real 13/14 Nov entries (documents.py -> T_LL_Logbook).
    # Before: two blank paper boxes, and basis_z(u, ~r) turned the book 90 degrees (spine across the reader).
    lr = (r * math.cos(0.12) + o * math.sin(0.12)).normalized()
    lb3 = basis(lr, u.cross(lr), u)
    lbc = dp(b, -0.6, top, c - 0.16)
    logbook(B, lbc, lb3)
    B.empty("IA_logbook", lbc + u * 0.05, (0.3, 0.12, 0.06), lb3)
    B.empty("IA_chart", dp(b, 0.1, top + 0.05, c - 0.12), (0.42, 0.32, 0.06), top_b3)
    cc = dp(b, 0.45, top + 0.02, c - 0.2)
    cyl(B.bm("M_LL_Brass"), cc, 0.07, 0.07, 0.04, 24)
    disc_uv(B.bm("M_LL_Atlas"), B.uv(B.bm("M_LL_Atlas")), cc + u * 0.021, Matrix.Identity(3), 0.06, 32, CELLS["bearing"])
    for s in (-1, 1):
        cyl(B.bm("M_LL_Bakelite"), dp(b, 0.85 + s * 0.045, top + 0.04, back - 0.3), 0.032, 0.038, 0.15, 14, basis_z(-o))
    for k, (hgt, col) in enumerate(((0.26, "M_LL_Leather"), (0.24, "M_LL_WoodDark"), (0.27, "M_LL_Leather"), (0.22, "M_LL_SteelPaint"))):
        box(B.bm(col, "SM_RoomBooks"), dp(b, 0.66 + k * 0.045, top + hgt / 2, back - 0.12), (0.04, 0.18, hgt), bs)
    mug = dp(b, -0.25, top + 0.05, c - 0.3)
    cyl(B.bm("M_LL_Ceramic"), mug, 0.042, 0.04, 0.1, 18)
    torus(B.bm("M_LL_Ceramic"), mug + r * 0.05, 0.028, 0.008, 12, 6, basis(r, u, -o))
    pc2 = dp(b, -0.75, top + 0.06, back - 0.42)
    cyl(B.bm("M_LL_SteelRust"), pc2, 0.035, 0.035, 0.12, 14)
    for k in range(5):
        seg_cyl(B.bm("M_LL_Wood"), pc2 + r * (0.01 * (k - 2)) + u * 0.02, pc2 + r * (0.03 * (k - 2)) + u * 0.14 - o * (0.01 * k), 0.004, 6)
    # chair + rug (R1/R3)
    chair_d = c - d / 2 - 0.45
    ch = B.bm("M_LL_Wood")
    seat = dp(b, 0.05, 0.46, chair_d)
    box(ch, seat, (0.44, 0.42, 0.04), bs)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(ch, seat + r * (sx * 0.19) + o * (sy * 0.18) - u * 0.23, (0.035, 0.035, 0.46), bs)
    for k in range(5):
        box(ch, seat + r * (-0.16 + k * 0.08) - o * 0.19 + u * 0.24, (0.025, 0.025, 0.44), bs)
    box(ch, seat - o * 0.19 + u * 0.46, (0.44, 0.04, 0.06), bs)
    B.collider("chair", seat - u * 0.05, (0.48, 0.48, 0.9), bs)
    quad_uv(B.bm("M_LL_Rug"), B.uv(B.bm("M_LL_Rug")), dp(b, 0.0, 0.006, chair_d + 0.05), basis(r, o, u), 2.1, 1.45, (0, 0, 1, 1))
    B.empty("IA_radio", dp(b, -0.2, top + 0.2, back - 0.25), (0.42, 0.3, 0.26), bs)
    B.empty("IA_radar", pc + pb3.col[2] * 0.05, (0.2, 0.2, 0.08), pb3)
    B.empty("FOCUS_radio", dp(b, 0.0, 1.32, chair_d + 0.05), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_radio_at", dp(b, 0.0, top + 0.18, back - 0.32), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_chart", dp(b, 0.1, 1.55, c - 0.62), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_chart_at", dp(b, 0.1, top, c - 0.05), (0.05, 0.05, 0.05), kind="SPHERE")
    drop(B, b, -1.06, 2.78, top, back - 0.02)


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
            for t in (-0.1, 0.1):
                cyl(B.bm("M_LL_Red"), dp(b, cx, z + 0.335, back - d / 2 + t), 0.018, 0.018, 0.03, 10)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(rack, dp(b, sx * (w / 2 - 0.02), 0.47, back - d / 2 + sy * (d / 2 - 0.02)), (0.03, 0.03, 0.94), bs)
    for k in range(5):
        cx = -w / 2 + 0.11 + k * 0.196
        seg_cyl(B.bm("M_LL_Red"), dp(b, cx, 0.86, back - d / 2 + 0.1), dp(b, cx + 0.196, 0.86, back - d / 2 - 0.1), 0.007, 6)
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
    box(B.bm("M_LL_Wood", "SM_Storage"), dp(b, -0.38, 0.27, c), (0.5, 0.42, 0.36), bs)
    for k in range(3):
        box(B.bm("M_LL_WoodDark", "SM_Storage"), dp(b, -0.38, 0.12 + k * 0.13, c - 0.212), (0.5, 0.01, 0.03), bs)
    box(B.bm("M_LL_Red"), dp(b, 0.25, 0.73, c), (0.5, 0.25, 0.24), bs)
    seg_cyl(B.bm("M_LL_Iron"), dp(b, 0.1, 0.88, c), dp(b, 0.4, 0.88, c), 0.012)
    for k in range(2):
        box(B.bm("M_LL_SteelPaint", "SM_Storage"), dp(b, -0.45 + k * 0.28, 0.72, c), (0.24, 0.32, 0.22), bs)
    torus(B.bm("M_LL_Rope"), dp(b, 0.3, 0.17, c), 0.17, 0.06, 20, 8)
    torus(B.bm("M_LL_Rope"), dp(b, 0.3, 0.27, c), 0.13, 0.05, 20, 8)
    lan = dp(b, -0.25, 1.23, c)
    cyl(B.bm("M_LL_Brass"), lan, 0.08, 0.08, 0.04, 16)
    cyl(B.bm("M_LL_Glass", "SM_StorageGlass"), lan + Vector((0, 0, 0.12)), 0.065, 0.065, 0.18, 16)
    cyl(B.bm("M_LL_Brass"), lan + Vector((0, 0, 0.25)), 0.07, 0.03, 0.08, 16)
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
    e = R["extinguisher"]
    ep = dp(e, 0, 0.62, R_IN - 0.11)
    cyl(B.bm("M_LL_Red"), ep, 0.08, 0.08, 0.5, 18)
    sphere(B.bm("M_LL_Red"), ep + Vector((0, 0, 0.25)), 0.08)
    cyl(B.bm("M_LL_Iron"), ep + Vector((0, 0, 0.35)), 0.025, 0.025, 0.08, 10)
    box(B.bm("M_LL_Iron"), dp(e, 0, 0.75, R_IN - 0.02), (0.06, 0.03, 0.2), wb(e))
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
    cyl(cast, c + off + u * (F + 0.72), 0.1, 0.1, 0.26, 24, basis_z(r_))                     # motor body
    for k in range(5):
        torus(cast, c + off + r_ * (-0.09 + k * 0.045) + u * (F + 0.72), 0.102, 0.008, 24, 4, basis_z(r_))   # cooling fins
    cyl(B.bm("M_LL_Iron", "SM_OpticDrive"), c + off + r_ * 0.15 + u * (F + 0.72), 0.06, 0.06, 0.04, 16, basis_z(r_))
    box(cast, c - r_ * 0.05 + u * (F + 0.7), (0.2, 0.22, 0.26), basis(r_, o, u))             # gearbox
    lamp(B, "optic_motor", c + off + u * (F + 0.83) - o * 0.05, basis(r_, -o, u), "green", 0.01)

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
        cyl(bm, (0, 0, 0.0), 0.03, 0.03, 1.36, 12)
        tag(red, 1)
    B.part("PT_optic_drive", "M_LL_Brass", c + u * (F + 1.28), Matrix.Identity(3), drum, extra_mats=("M_LL_Red",))

    def governor(bm, uv):
        # fly-ball governor: spindle, two arms, two brass balls (spins while the motor runs)
        cyl(bm, (0, 0, 0), 0.012, 0.012, 0.3, 10)
        cyl(bm, (0, 0, -0.06), 0.03, 0.03, 0.03, 12)
        for sx in (-1, 1):
            seg_cyl(bm, Vector((0, 0, 0.12)), Vector((sx * 0.1, 0, -0.02)), 0.005, 6)
            sphere(bm, Vector((sx * 0.11, 0, -0.04)), 0.03, 12, 8)
    B.part("PT_optic_governor", "M_LL_Brass", c - r_ * 0.16 + o * 0.05 + u * (F + 1.75), Matrix.Identity(3), governor)
    # revolution counter (brass drum with a white figure band) on the gearbox
    rc = c - r_ * 0.05 - o * 0.12 + u * (F + 0.9)
    cyl(brass, rc, 0.04, 0.04, 0.1, 16, basis_z(r_))
    cyl(B.bm("M_LL_Ceramic", "SM_OpticDrive"), rc, 0.042, 0.042, 0.05, 16, basis_z(r_))
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
    for s in (-1, 1):
        box(lea, P(s * (pw / 2 + 0.006), 0, 0.0025), (pw + 0.012, pd + 0.014, 0.004), b3)
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


def build_anchors(B):
    """Story anchors (non-interactive empties; Godot ignores them): positions reserved now so later
    story stages never force an architectural rebuild."""
    B.empty("ANCHOR_calendar", dp(-18.0, 0, 1.55, R_IN - 0.02), (0.15, 0.2, 0.01), wb(-18.0))
    B.empty("ANCHOR_diagram", dp(-67.0, 0, 2.0, R_IN - 0.02), (0.3, 0.2, 0.01), wb(-67.0))
    B.empty("ANCHOR_telephone", dp(R["desk"], 0.95, 0.8, 2.75), (0.12, 0.1, 0.08), wb(R["desk"]))
    B.empty("ANCHOR_tide_tables", dp(R["storage"], -0.2, 1.05, R_IN - 0.3), (0.15, 0.1, 0.12), wb(R["storage"]))
    B.empty("ANCHOR_oilskins", dp(R["stair"] + 17.0, 0, 1.7, R_IN - 0.05), (0.2, 0.4, 0.1), wb(R["stair"] + 17.0))   # right of the door
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
