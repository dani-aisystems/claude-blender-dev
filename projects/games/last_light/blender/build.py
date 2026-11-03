"""Build THE LAST LIGHT's lighthouse exterior and watch room procedurally from spec.py.

Headless:  tools/bl -P projects/games/last_light/blender/build.py -- --new --save
Collections (only these are replaced):
  ASSET_lighthouse   tower, gallery, watch-room roof, lantern, dome, PT_optic
  ASSET_watch_room   interior: walls (inner+outer faces), floor, furniture, devices, hooks
Hook naming (Godot binds by name, see DESIGN.md):
  PT_/NDL_ articulated parts: pivot at origin, rotation axis = local Z (Godot local Y)
  LMP_ lamps, SCR_ screens, GLS_ glass, COL_*-convcolonly collision, IA_/FOCUS_/SPAWN_/LIGHT_/LBL_ empties
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
A_IN = R["apothem_in"]
A_OUT = A_IN + R["wall"]
SIDE_IN = 2 * A_IN * math.tan(math.pi / 8)

# ------------------------------------------------------------------ materials

MATS = {
    # name: (base hex, roughness, metallic, extra)
    "M_LL_Plaster": ("#C9C0AA", 0.85, 0.0, {}),
    "M_LL_PaintWhite": ("#D9D6CE", 0.7, 0.0, {}),
    "M_LL_Stone": ("#6E6A63", 0.9, 0.0, {}),
    "M_LL_Wood": ("#5A3E28", 0.65, 0.0, {}),
    "M_LL_WoodDark": ("#3A2A1E", 0.6, 0.0, {}),
    "M_LL_SteelPaint": ("#3C4A44", 0.55, 0.3, {}),
    "M_LL_Iron": ("#1E2022", 0.5, 0.7, {}),
    "M_LL_Brass": ("#A8823C", 0.32, 1.0, {}),
    "M_LL_Bakelite": ("#141212", 0.35, 0.0, {}),
    "M_LL_Glass": ("#A9BCC4", 0.04, 0.0, {"alpha": 0.18}),
    "M_LL_Lens": ("#D8E4E0", 0.02, 0.0, {"alpha": 0.35}),
    "M_LL_Copper": ("#4F7A6C", 0.6, 0.6, {}),
    "M_LL_Paper": ("#E3DCC6", 0.9, 0.0, {}),
    "M_LL_Leather": ("#5B1F18", 0.55, 0.0, {}),
    "M_LL_Lamp": ("#FFE2B0", 0.4, 0.0, {"emission_hex": "#FFB45C", "emission_strength": 2.0}),
    "M_LL_LampRed": ("#8A1A12", 0.4, 0.0, {"emission_hex": "#FF2A1A", "emission_strength": 0.0}),
    "M_LL_LampGreen": ("#1A5A2A", 0.4, 0.0, {"emission_hex": "#40FF70", "emission_strength": 0.0}),
    "M_LL_LampAmber": ("#6A4810", 0.4, 0.0, {"emission_hex": "#FFAA20", "emission_strength": 0.0}),
    "M_LL_Screen": ("#06140C", 0.2, 0.0, {}),
    "M_LL_Collision": ("#FF00FF", 1.0, 0.0, {}),
}


def textured_material(name, image_path):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(str(image_path), check_existing=True)
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def material(name):
    if name in ("M_LL_Atlas", "M_LL_Chart"):
        return textured_material(name, HERE / "tex" / ("T_LL_Atlas.png" if name == "M_LL_Atlas" else "T_LL_Chart.png"))
    base, rough, metal, extra = MATS[name]
    return principled_material(name, base, roughness=rough, metallic=metal, **extra)


# ------------------------------------------------------------------ frames + primitives

def wall_frame(bearing_deg):
    """Columns: right (along the wall, seen from inside), outward, up."""
    b = math.radians(bearing_deg)
    right = Vector((math.cos(b), -math.sin(b), 0.0))
    out = Vector((math.sin(b), math.cos(b), 0.0))
    return right, out, Vector((0, 0, 1))


def wp(bearing, along, z, depth_from_wall=0.0, apothem=A_IN):
    """World point on a wall face: `along` metres to the right, `z` above the floor, pulled inward."""
    r, o, u = wall_frame(bearing)
    return o * (apothem - depth_from_wall) + r * along + u * (F + z)


def basis(x, y, z):
    return Matrix((x, y, z)).transposed()   # columns


def basis_z(z_axis, hint=Vector((0, 0, 1))):
    z = z_axis.normalized()
    if abs(z.dot(hint.normalized())) > 0.95:
        hint = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))
    x = hint.cross(z).normalized()
    y = z.cross(x).normalized()
    return basis(x, y, z)


def m4(loc, b3=None):
    m = (b3 or Matrix.Identity(3)).to_4x4()
    m.translation = loc
    return m


def box(bm, loc, size, b3=None):
    mat = m4(Vector(loc), b3) @ Matrix.Diagonal((*size, 1.0))
    return bmesh.ops.create_cube(bm, size=1.0, matrix=mat)["verts"]


def cyl(bm, loc, r1, r2, depth, segs, b3=None, caps=True):
    """Cylinder/cone along the frame's local Z, centred at loc."""
    return bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=segs, radius1=r1, radius2=r2,
                                 depth=depth, matrix=m4(Vector(loc), b3))["verts"]


def hexa(bm, pts):
    """Arbitrary hexahedron from 8 points (bottom 4 ccw, top 4 ccw)."""
    v = [bm.verts.new(p) for p in pts]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    for f in faces:
        bm.faces.new([v[i] for i in f])
    return v


def disc_uv(bm, uv, center, b3, radius, segs, cell, cell_px=512, atlas_px=2048):
    """Flat disc in the frame's XY plane (normal = local Z), UV-mapped to an atlas cell."""
    cx = (cell % 4) * cell_px
    cy = (cell // 4) * cell_px
    rim = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        p = Vector(center) + b3 @ Vector((radius * math.cos(a), radius * math.sin(a), 0))
        rim.append((bm.verts.new(p), a))
    c = bm.verts.new(Vector(center))
    def uv_of(a, rr):
        px = cx + cell_px / 2 + rr * math.cos(a) * (cell_px / 2 - 8)
        py = cy + cell_px / 2 - rr * math.sin(a) * (cell_px / 2 - 8)
        return (px / atlas_px, 1.0 - py / atlas_px)
    for i in range(segs):
        (v0, a0), (v1, a1) = rim[i], rim[(i + 1) % segs]
        f = bm.faces.new((c, v0, v1))
        f.loops[0][uv].uv = uv_of(0, 0)
        f.loops[1][uv].uv = uv_of(a0, 1)
        f.loops[2][uv].uv = uv_of(a1, 1)


def quad_uv(bm, uv, center, b3, w, h, uv_rect):
    """Flat rectangle (normal = local Z) with UVs = uv_rect (u0, v0, u1, v1) in 0..1."""
    u0, v0, u1, v1 = uv_rect
    corners = [(-w / 2, -h / 2, u0, v0), (w / 2, -h / 2, u1, v0), (w / 2, h / 2, u1, v1), (-w / 2, h / 2, u0, v1)]
    vs = [bm.verts.new(Vector(center) + b3 @ Vector((x, y, 0))) for x, y, _, _ in corners]
    f = bm.faces.new(vs)
    for loop, (_, _, u, v) in zip(f.loops, corners):
        loop[uv].uv = (u, v)


def atlas_cell_rect(cell, sub_row=None):
    c = S["atlas"]["cell"]
    N = S["atlas"]["size"]
    x0 = (cell % 4) * c
    y0 = (cell // 4) * c
    if sub_row is None:
        return (x0 / N, 1 - (y0 + c) / N, (x0 + c) / N, 1 - y0 / N)
    ys = y0 + sub_row * 128
    return (x0 / N, 1 - (ys + 128) / N, (x0 + c) / N, 1 - ys / N)


def label_rect(text):
    labels = S["atlas"]["labels"]
    i = labels.index(text)
    cell = S["atlas"]["cells"]["labels_" + "abcd"[i // 4]]
    return atlas_cell_rect(cell, i % 4)


# ------------------------------------------------------------------ scene plumbing

class Builder:
    def __init__(self, coll):
        self.coll = coll
        self.buckets = {}   # (prefix, material) -> bmesh

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
        out = []
        for (prefix, mat), bm in self.buckets.items():
            name = f"{prefix}_{mat.replace('M_LL_', '')}"
            out.append(self.mesh_obj(name, bm, mat, keep_uv=mat in ("M_LL_Atlas", "M_LL_Chart")))
        self.buckets = {}
        return out

    def mesh_obj(self, name, bm, mat, matrix=None, keep_uv=False):
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        if not keep_uv and mat not in ("M_LL_Glass",):
            # closed solids: make every face point outward (slab/hexa winding varies)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if not keep_uv:
            box_project_uvs(bm)
        me = bpy.data.meshes.new(name)
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        me.materials.append(material(mat))
        obj = bpy.data.objects.new(name, me)
        self.coll.objects.link(obj)
        if matrix is not None:
            obj.matrix_world = matrix
        return obj

    def part(self, name, mat, loc, b3, build_fn, keep_uv=False):
        """Articulated part: geometry built in local space by build_fn(bm, uv) with pivot at origin."""
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        build_fn(bm, uvl)
        return self.mesh_obj(name, bm, mat, matrix=m4(Vector(loc), b3), keep_uv=keep_uv)

    def empty(self, name, loc, half_size=(0.1, 0.1, 0.1), b3=None, kind="CUBE"):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = kind
        e.matrix_world = m4(Vector(loc), b3) @ Matrix.Diagonal((*half_size, 1.0))
        self.coll.objects.link(e)
        return e

    def collider(self, name, loc, size, b3=None):
        bm = bmesh.new()
        bm.loops.layers.uv.new("UVMap")
        box(bm, (0, 0, 0), size)
        obj = self.mesh_obj(f"COL_{name}-convcolonly", bm, "M_LL_Collision")
        obj.matrix_world = m4(Vector(loc), b3)
        # bake the rotation so transforms stay applied (validator rule)
        obj.data.transform(obj.matrix_basis)
        obj.matrix_basis = Matrix.Identity(4)
        return obj


# ------------------------------------------------------------------ watch room

def wall_block(bm, bearing, u0, u1, z0, z1, a_in=A_IN, a_out=A_OUT):
    """Block of wall between along-positions u0..u1 (metres from face centre at inner apothem)."""
    r, o, up = wall_frame(bearing)
    k = a_out / a_in   # corner rays: outer face is the inner face scaled from the centre
    def P(u, a, z):
        return o * a + r * (u * (a / a_in)) + up * (F + z)
    pts = [P(u0, a_in, z0), P(u0, a_out, z0), P(u1, a_out, z0), P(u1, a_in, z0),
           P(u0, a_in, z1), P(u0, a_out, z1), P(u1, a_out, z1), P(u1, a_in, z1)]
    del k
    return hexa(bm, pts)


def build_room(B):
    half = SIDE_IN / 2
    W = R["window"]
    wall_h = CEIL - F
    plaster = B.bm("M_LL_Plaster")
    white_out = B.bm("M_LL_PaintWhite", "SM_RoomShell")
    for i in range(8):
        b = i * 45.0
        bb = ((b + 180) % 360) - 180
        bm = plaster
        if any(abs(((bb - w + 180) % 360) - 180) < 1 for w in R["windows"]):
            ww = W["width"] / 2
            wall_block(bm, b, -half, -ww, 0, wall_h)
            wall_block(bm, b, ww, half, 0, wall_h)
            wall_block(bm, b, -ww, ww, 0, W["sill"])
            wall_block(bm, b, -ww, ww, W["top"], wall_h)
            build_window(B, b)
        elif abs(abs(bb) - 180) < 1:
            dw = 0.48
            wall_block(bm, b, -half, -dw, 0, wall_h)
            wall_block(bm, b, dw, half, 0, wall_h)
            wall_block(bm, b, -dw, dw, 2.08, wall_h)
            build_door(B, b, dw)
        else:
            wall_block(bm, b, -half, half, 0, wall_h)
        # wall collision proxy (slightly thicker than the wall)
        r, o, u = wall_frame(b)
        B.collider(f"wall_{i}", o * (A_IN + 0.25) + u * (F + wall_h / 2), (SIDE_IN + 0.6, 0.5, wall_h), basis(r, o, u))
        # exterior plinth band + cornice on the outside (white paint)
        build_wall_trim(B, white_out, b)
    # floor + ceiling (octagon slabs)
    wood = B.bm("M_LL_Wood")
    octagon_slab(wood, A_OUT + 0.02, F - 0.22, F)
    plank_seams(B, F)
    octagon_slab(B.bm("M_LL_Plaster"), A_OUT, CEIL, CEIL + 0.18)
    B.collider("floor", (0, 0, F - 0.25), (8, 8, 0.5))
    B.collider("ceiling", (0, 0, CEIL + 0.25), (8, 8, 0.5))
    # dado (wood panelling) on solid walls below the sill
    dark = B.bm("M_LL_WoodDark")
    for i in range(8):
        b = i * 45.0
        bb = ((b + 180) % 360) - 180
        if abs(abs(bb) - 180) < 1:
            continue
        r, o, u = wall_frame(b)
        c = wp(b, 0, 0.47, 0.012)
        box(dark, c, (SIDE_IN - 0.06, 0.024, 0.94), basis(r, o, u))
        box(dark, wp(b, 0, 0.955, 0.025), (SIDE_IN - 0.04, 0.05, 0.04), basis(r, o, u))   # dado rail
        box(dark, wp(b, 0, 0.06, 0.03), (SIDE_IN - 0.04, 0.06, 0.12), basis(r, o, u))    # skirting
    build_column(B)
    build_console(B)
    build_radio_desk(B)
    build_chart_table(B)
    build_generator_panel(B)
    build_power_cabinet(B)
    build_ceiling_details(B)
    build_props(B)
    B.empty("SPAWN_player", wp(180, 0.0, 0.0, 1.55), (0.2, 0.2, 0.2), kind="ARROWS")


def octagon_slab(bm, apothem, z0, z1):
    R8 = apothem / math.cos(math.pi / 8)
    ring0, ring1 = [], []
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        p = Vector((R8 * math.sin(a), R8 * math.cos(a), 0))
        ring0.append(bm.verts.new(p + Vector((0, 0, z0))))
        ring1.append(bm.verts.new(p + Vector((0, 0, z1))))
    bm.faces.new(list(reversed(ring0)))
    bm.faces.new(ring1)
    for i in range(8):
        j = (i + 1) % 8
        bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))


def plank_seams(B, z):
    seam = B.bm("M_LL_WoodDark")
    for k in range(-14, 15):
        x = k * 0.21
        L = 2 * math.sqrt(max(0.0, (A_IN + 0.1) ** 2 - x * x))
        if L > 0.2:
            box(seam, (x, 0, z + 0.001), (0.008, L * 0.97, 0.004))


def build_window(B, b):
    W = R["window"]
    r, o, u = wall_frame(b)
    fr = W["frame"]
    ww = W["width"] / 2
    z0, z1 = W["sill"], W["top"]
    zc = (z0 + z1) / 2
    hgt = z1 - z0
    iron = B.bm("M_LL_PaintWhite", "SM_WinFrame")
    dep = A_IN + R["wall"] * 0.55
    bs = basis(r, o, u)
    def at(along, z):
        return o * dep + r * along + u * (F + z)
    box(iron, at(-ww + fr / 2, zc), (fr, W["depth"], hgt), bs)
    box(iron, at(ww - fr / 2, zc), (fr, W["depth"], hgt), bs)
    box(iron, at(0, z0 + fr / 2), (2 * ww, W["depth"], fr), bs)
    box(iron, at(0, z1 - fr / 2), (2 * ww, W["depth"], fr), bs)
    box(iron, at(0, zc), (fr * 0.7, W["depth"] * 0.8, hgt), bs)                 # mullion
    box(iron, at(0, z0 + hgt * 0.68), (2 * ww, W["depth"] * 0.8, fr * 0.6), bs)  # transom
    # glass pane (its own object so Godot can put the rain shader on it)
    gb = bmesh.new()
    gb.loops.layers.uv.new("UVMap")
    box(gb, at(0, zc), (2 * ww - 0.02, 0.012, hgt - 0.02), bs)
    B.mesh_obj(f"GLS_window_{int(b) % 360:03d}", gb, "M_LL_Glass")
    # sill board (wood, inside)
    box(B.bm("M_LL_Wood"), wp(b, 0, z0 + 0.02, -0.02), (2 * ww + 0.16, 0.2, 0.04), bs)


def build_door(B, b, dw):
    r, o, u = wall_frame(b)
    bs = basis(r, o, u)
    wood = B.bm("M_LL_WoodDark")
    box(wood, wp(b, 0, 1.03, -0.14), (2 * dw - 0.04, 0.05, 2.04), bs)
    for z in (0.5, 1.5):
        box(B.bm("M_LL_Wood"), wp(b, 0, z, -0.11), (2 * dw - 0.2, 0.02, 0.7), bs)   # panels
    frame = B.bm("M_LL_PaintWhite", "SM_RoomTrim")
    box(frame, wp(b, -dw - 0.03, 1.04, -0.02), (0.07, 0.36, 2.08), bs)
    box(frame, wp(b, dw + 0.03, 1.04, -0.02), (0.07, 0.36, 2.08), bs)
    box(frame, wp(b, 0, 2.11, -0.02), (2 * dw + 0.13, 0.36, 0.07), bs)
    brass = B.bm("M_LL_Brass")
    box(brass, wp(b, dw - 0.12, 1.0, 0.0), (0.05, 0.06, 0.03), bs)
    cyl(brass, wp(b, dw - 0.12, 1.0, 0.04), 0.025, 0.025, 0.06, 12, basis_z(-o))


def build_wall_trim(B, bm, b):
    r, o, u = wall_frame(b)
    bs = basis(r, o, u)
    side_out = 2 * A_OUT * math.tan(math.pi / 8)
    box(bm, o * (A_OUT + 0.04) + u * (F + 0.1), (side_out + 0.04, 0.1, 0.2), bs)            # plinth band
    box(bm, o * (A_OUT + 0.06) + u * (CEIL + 0.05), (side_out + 0.06, 0.14, 0.12), bs)      # cornice


def build_column(B):
    brass = B.bm("M_LL_Brass")
    iron = B.bm("M_LL_Iron")
    cr = R["column_radius"]
    cyl(brass, (0, 0, (F + CEIL) / 2), cr, cr, CEIL - F, 24)
    cyl(iron, (0, 0, F + 0.06), 0.32, 0.28, 0.12, 24)
    cyl(iron, (0, 0, F + 0.15), 0.2, 0.2, 0.08, 24)
    cyl(iron, (0, 0, CEIL - 0.14), 0.44, 0.44, 0.24, 32)     # gear housing
    cyl(brass, (0, 0, CEIL - 0.27), 0.2, 0.24, 0.04, 24)
    B.collider("column", (0, 0, F + 1.4), (0.62, 0.62, 2.8))

    def gear(bm, uv):
        n = 36
        for i in range(n):
            a = 2 * math.pi * i / n
            box(bm, (0.36 * math.cos(a), 0.36 * math.sin(a), 0), (0.06, 0.035, 0.06), basis_z(Vector((0, 0, 1)), Vector((math.cos(a), math.sin(a), 0))))
        cyl(bm, (0, 0, 0), 0.34, 0.34, 0.07, 36)
        for k in range(6):
            a = 2 * math.pi * k / 6
            box(bm, (0.17 * math.cos(a), 0.17 * math.sin(a), 0), (0.3, 0.04, 0.03), basis_z(Vector((0, 0, 1)), Vector((-math.sin(a), math.cos(a), 0))))
    B.part("PT_optic_gear", "M_LL_Brass", (0, 0, CEIL - 0.33), Matrix.Identity(3), gear)


# ---- controls -------------------------------------------------------------

def knob_fn(radius, height, pointer=True):
    def f(bm, uv):
        cyl(bm, (0, 0, height / 2), radius, radius * 0.85, height, 20)
        cyl(bm, (0, 0, height * 0.12), radius * 1.15, radius * 1.15, height * 0.24, 20)
        if pointer:
            box(bm, (0, radius * 0.55, height + 0.004), (radius * 0.18, radius * 1.0, 0.008))
    return f


def needle_fn(length, width=0.006):
    def f(bm, uv):
        box(bm, (0, length * 0.38, 0.004), (width, length, 0.004))
        cyl(bm, (0, 0, 0.006), width * 2.2, width * 2.2, 0.012, 12)
    return f


def gauge(B, name, center, b3, radius, cell, needle_len=None):
    """Bezel + atlas dial face + needle NDL_<name> (rotation axis = face normal = b3 Z)."""
    z = b3.col[2]
    brass = B.bm("M_LL_Brass")
    cyl(brass, Vector(center) - z * 0.012, radius * 1.12, radius * 1.08, 0.028, 32, b3)
    atlas = B.bm("M_LL_Atlas")
    disc_uv(atlas, B.uv(atlas), Vector(center) + z * 0.003, b3, radius, 40, cell)
    B.part(f"NDL_{name}", "M_LL_Bakelite", Vector(center) + z * 0.004, b3, needle_fn(needle_len or radius * 0.85))
    glass = B.bm("M_LL_Glass", "SM_GaugeGlass")
    cyl(glass, Vector(center) + z * 0.016, radius * 1.02, radius * 1.02, 0.004, 32, b3)


def lamp(B, name, center, b3, color, r=0.018):
    z = b3.col[2]
    cyl(B.bm("M_LL_Brass"), Vector(center) - z * 0.004, r * 1.5, r * 1.5, 0.01, 16, b3)
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=r, matrix=m4(Vector(center) + z * 0.006))
    B.mesh_obj(f"LMP_{name}", bm, {"red": "M_LL_LampRed", "green": "M_LL_LampGreen", "amber": "M_LL_LampAmber"}[color])


def label(B, text, center, b3, w=0.16):
    atlas = B.bm("M_LL_Atlas")
    quad_uv(atlas, B.uv(atlas), Vector(center) + b3.col[2] * 0.002, b3, w, w / 4, label_rect(text))


def panel_frame(b, along, z, out_dist, tilt_deg=0.0):
    """Frame on a device face: X = right, Y = up-along-surface, Z = surface normal (toward the room)."""
    r, o, u = wall_frame(b)
    t = math.radians(tilt_deg)
    n = (-o) * math.cos(t) + u * math.sin(t)   # tilt 90 => facing up
    y = n.cross(r).normalized()
    return basis(r, y, n), wp(b, along, z, out_dist)


def build_console(B):
    b = 0.0
    r, o, u = wall_frame(b)
    bs = basis(r, o, u)
    steel = B.bm("M_LL_SteelPaint")
    depth = 0.62
    box(steel, wp(b, 0, 0.4, depth / 2), (1.3, depth, 0.8), bs)
    box(B.bm("M_LL_Iron"), wp(b, 0, 0.04, depth / 2 - 0.02), (1.26, depth - 0.06, 0.08), bs)   # kick plinth
    # sloped top: from front edge (z .80, depth .62) up to back (z .98, depth .05)
    tilt = math.degrees(math.atan2(0.18, 0.57))
    top_b3, top_c = panel_frame(b, 0, 0.89, 0.335, 90 - tilt)
    box(steel, top_c - top_b3.col[2] * 0.02, (1.3, math.hypot(0.18, 0.57) + 0.02, 0.04), top_b3)
    # side cheeks
    for s in (-1, 1):
        pts = []
        for (d, z) in [(depth, 0.0), (0.0, 0.0), (0.0, 0.98), (depth, 0.80)]:
            pts.append(wp(b, s * 0.66, z, d))
        th = r * (0.02 * s)
        hexa(steel, [p - th for p in pts] + [p + th for p in pts])
    B.collider("console", wp(b, 0, 0.5, depth / 2), (1.36, depth + 0.04, 1.0), bs)
    # controls on the sloped panel (panel coords: x along r, y up the slope)
    def on_top(x, y):
        return top_c + top_b3.col[0] * x + top_b3.col[1] * y
    atlas = B.bm("M_LL_Atlas")
    C = S["atlas"]["cells"]
    for key, x in (("mode", -0.44), ("intensity", -0.16)):
        c = on_top(x, 0.04)
        disc_uv(atlas, B.uv(atlas), c + top_b3.col[2] * 0.002, top_b3, 0.105, 40, C[f"{key}_plate"])
        B.part(f"PT_{key}", "M_LL_Bakelite", c + top_b3.col[2] * 0.003, top_b3, knob_fn(0.038, 0.045))
        B.empty(f"IA_{key}", c + top_b3.col[2] * 0.03, (0.07, 0.07, 0.05), top_b3)
    gauge(B, "bearing", on_top(0.17, 0.06), top_b3, 0.115, C["bearing"])
    gauge(B, "motor", on_top(0.45, 0.06), top_b3, 0.09, C["motor"])
    lamp(B, "motor_fault", on_top(0.45, -0.12), top_b3, "amber")
    lamp(B, "console_power", on_top(0.3, -0.13), top_b3, "green")
    label(B, "LIGHT CONTROL", on_top(-0.3, -0.16), top_b3, 0.3)
    label(B, "BEARING", on_top(0.17, -0.1), top_b3, 0.12)
    label(B, "MOTOR LOAD", on_top(0.45, -0.045), top_b3, 0.12)
    # handwheel on the vertical front face, axis = toward the room
    front_b3, front_c = panel_frame(b, 0.0, 0.52, depth + 0.005, 0.0)

    def wheel(bm, uv):
        rr = 0.17
        n = 28
        for i in range(n):
            a0 = 2 * math.pi * i / n
            a1 = 2 * math.pi * (i + 1) / n
            mid = (a0 + a1) / 2
            box(bm, (rr * math.cos(mid), rr * math.sin(mid), 0.06), (0.026, rr * (a1 - a0) * 1.08, 0.026),
                basis_z(Vector((0, 0, 1)), Vector((-math.sin(mid), math.cos(mid), 0))))
        for k in range(5):
            a = 2 * math.pi * k / 5
            box(bm, (rr * 0.5 * math.cos(a), rr * 0.5 * math.sin(a), 0.045), (rr, 0.018, 0.016),
                basis_z(Vector((0, 0, 1)), Vector((-math.sin(a), math.cos(a), 0))))
        cyl(bm, (0, 0, 0.03), 0.035, 0.035, 0.06, 16)
        cyl(bm, (rr * 0.85, 0, 0.12), 0.015, 0.015, 0.11, 10)   # spinner handle
    B.part("PT_wheel", "M_LL_Brass", front_c, front_b3, wheel)
    cyl(B.bm("M_LL_Iron"), front_c + front_b3.col[2] * 0.01, 0.05, 0.05, 0.03, 16, front_b3)
    B.empty("IA_wheel", front_c + front_b3.col[2] * 0.07, (0.2, 0.2, 0.08), front_b3)
    label(B, "HANDWHEEL", front_c - front_b3.col[1] * 0.25, front_b3, 0.16)
    B.empty("IA_console", wp(b, 0, 0.75, 0.32), (0.66, 0.32, 0.32), bs)
    B.empty("FOCUS_console", wp(b, 0, 1.45, 1.35), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_console_at", wp(b, 0, 0.85, 0.25), (0.05, 0.05, 0.05), kind="SPHERE")


def build_radio_desk(B):
    b = -90.0
    r, o, u = wall_frame(b)
    bs = basis(r, o, u)
    wood = B.bm("M_LL_Wood")
    dark = B.bm("M_LL_WoodDark")
    d = 0.66
    top_z = 0.76
    box(wood, wp(b, 0, top_z - 0.02, d / 2), (1.6, d, 0.04), bs)
    for s in (-1, 1):
        box(dark, wp(b, s * 0.76, top_z / 2 - 0.02, d / 2), (0.05, d - 0.04, top_z - 0.04), bs)
    box(dark, wp(b, 0.48, 0.42, d / 2), (0.5, d - 0.06, 0.62), bs)          # drawer unit
    for z in (0.58, 0.3):
        box(B.bm("M_LL_Wood"), wp(b, 0.48, z, d - 0.015), (0.44, 0.02, 0.22), bs)
        box(B.bm("M_LL_Brass"), wp(b, 0.48, z + 0.05, d + 0.005), (0.1, 0.02, 0.015), bs)
    box(dark, wp(b, 0, 0.12, 0.04), (1.5, 0.02, 0.2), bs)                     # modesty board
    B.collider("radio_desk", wp(b, 0, 0.45, d / 2), (1.64, d + 0.04, 0.9), bs)
    steel = B.bm("M_LL_SteelPaint")
    # transceiver
    rx_c = wp(b, -0.32, top_z + 0.13, 0.22)
    box(steel, rx_c, (0.56, 0.32, 0.26), bs)
    fb3, fc = panel_frame(b, -0.32, top_z + 0.13, 0.38 + 0.002)
    atlas = B.bm("M_LL_Atlas")
    C = S["atlas"]["cells"]
    rect = atlas_cell_rect(C["radio_dial"])
    rect = (rect[0], rect[1] + (rect[3] - rect[1]) * 0.29, rect[2], rect[1] + (rect[3] - rect[1]) * 0.71)
    quad_uv(atlas, B.uv(atlas), fc + fb3.col[1] * 0.055 + fb3.col[2] * 0.001, fb3, 0.3, 0.13, rect)
    gauge(B, "signal", fc + fb3.col[0] * 0.21 + fb3.col[1] * 0.055, fb3, 0.045, C["signal"])
    for key, x in (("volume", -0.18), ("channel", 0.0)):
        B.part(f"PT_{key}", "M_LL_Bakelite", fc + fb3.col[0] * x - fb3.col[1] * 0.07, fb3, knob_fn(0.028, 0.03))
        label(B, key.upper(), fc + fb3.col[0] * x - fb3.col[1] * 0.115, fb3, 0.08)
    lamp(B, "radio_rx", fc + fb3.col[0] * 0.15 - fb3.col[1] * 0.07, fb3, "green", 0.012)
    lamp(B, "radio_tx", fc + fb3.col[0] * 0.21 - fb3.col[1] * 0.07, fb3, "red", 0.012)
    label(B, "VHF  CH 16", fc + fb3.col[0] * 0.18 - fb3.col[1] * 0.11, fb3, 0.12)
    # speaker grille on top-left of the desk wall
    spk = wp(b, -0.32, top_z + 0.45, 0.1)
    box(B.bm("M_LL_WoodDark"), spk, (0.3, 0.16, 0.22), bs)
    sb3, sc = panel_frame(b, -0.32, top_z + 0.45, 0.181)
    for k in range(7):
        box(B.bm("M_LL_Iron"), sc + sb3.col[1] * (-0.08 + k * 0.027), (0.24, 0.008, 0.006), sb3)
    # handset on its hook (moves when transmitting)

    def handset(bm, uv):
        box(bm, (0, 0, 0.0), (0.05, 0.2, 0.035))
        box(bm, (0, 0.11, 0.025), (0.06, 0.06, 0.05))
        box(bm, (0, -0.11, 0.025), (0.06, 0.06, 0.05))
    hb3 = basis(r, o, u)
    B.part("PT_handset", "M_LL_Bakelite", wp(b, -0.66, top_z + 0.04, 0.22), basis_z(u, o), handset)
    # radar scope
    rd = wp(b, 0.36, top_z + 0.22, 0.24)
    box(steel, rd, (0.44, 0.44, 0.44), bs)
    pb3, pc = panel_frame(b, 0.36, top_z + 0.24, 0.462)
    cyl(B.bm("M_LL_Iron"), pc + pb3.col[2] * 0.03, 0.185, 0.17, 0.06, 32, pb3)   # hood
    sbm = bmesh.new()
    uvl = sbm.loops.layers.uv.new("UVMap")
    # screen disc with full 0..1 UVs
    segs = 48
    rim = []
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
    label(B, "RADAR", pc - pb3.col[1] * 0.2 + pb3.col[2] * 0.0, pb3, 0.1)
    # desk lamp
    lb = wp(b, 0.72, top_z, 0.2)
    iron = B.bm("M_LL_Iron")
    cyl(iron, lb + u * 0.015, 0.08, 0.075, 0.03, 20)
    arm_top = lb + u * 0.42 - o * 0.12
    seg = arm_top - (lb + u * 0.03)
    cyl(iron, (lb + u * 0.03 + arm_top) / 2, 0.01, 0.01, seg.length, 8, basis_z(seg))
    shade_dir = (-o * 0.6 - u * 0.8).normalized()
    cyl(B.bm("M_LL_SteelPaint", "SM_RoomShade"), arm_top + shade_dir * 0.06, 0.03, 0.09, 0.12, 20, basis_z(shade_dir))
    bulb = bmesh.new()
    bulb.loops.layers.uv.new("UVMap")
    bmesh.ops.create_uvsphere(bulb, u_segments=12, v_segments=8, radius=0.028, matrix=m4(arm_top + shade_dir * 0.1))
    B.mesh_obj("LMP_desk", bulb, "M_LL_Lamp")
    B.empty("LIGHT_desk", arm_top + shade_dir * 0.14, (0.05, 0.05, 0.05), basis_z(shade_dir), kind="SINGLE_ARROW")
    B.empty("IA_radio", wp(b, -0.15, top_z + 0.2, 0.25), (0.48, 0.25, 0.25), bs)
    B.empty("IA_radar", pc + pb3.col[2] * 0.05, (0.2, 0.2, 0.08), pb3)
    B.empty("FOCUS_radio", wp(b, 0.0, 1.38, 1.2), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_radio_at", wp(b, 0.02, 0.95, 0.15), (0.05, 0.05, 0.05), kind="SPHERE")


def build_chart_table(B):
    b = 90.0
    r, o, u = wall_frame(b)
    bs = basis(r, o, u)
    wood = B.bm("M_LL_Wood")
    dark = B.bm("M_LL_WoodDark")
    d = 0.74
    box(dark, wp(b, 0, 0.42, d / 2), (1.36, d - 0.06, 0.8), bs)          # chart drawers cabinet
    for k in range(4):
        z = 0.15 + k * 0.18
        box(wood, wp(b, 0, z, d - 0.03), (1.26, 0.02, 0.15), bs)
        box(B.bm("M_LL_Brass"), wp(b, 0, z + 0.02, d - 0.015), (0.14, 0.02, 0.02), bs)
    tilt = 10.0
    tb3, tc = panel_frame(b, 0, 0.88, d / 2 + 0.02, 90 - tilt)
    box(wood, tc - tb3.col[2] * 0.02, (1.44, d + 0.04, 0.04), tb3)
    box(dark, tc - tb3.col[1] * (d / 2 + 0.03) + tb3.col[2] * 0.01, (1.44, 0.03, 0.05), tb3)   # pencil lip
    chart = B.bm("M_LL_Chart")
    quad_uv(chart, B.uv(chart), tc + tb3.col[2] * 0.002 + tb3.col[1] * 0.02, tb3, 1.0, 0.75, (0, 0, 1, 1))
    B.collider("chart_table", wp(b, 0, 0.47, d / 2), (1.48, d + 0.04, 0.95), bs)
    # logbook (closed book on the right of the chart)
    lb3 = tb3
    book_c = tc + tb3.col[0] * 0.6 + tb3.col[1] * 0.05 + tb3.col[2] * 0.02
    box(B.bm("M_LL_Leather"), book_c, (0.2, 0.28, 0.035), lb3)
    box(B.bm("M_LL_Paper"), book_c + lb3.col[0] * 0.005, (0.19, 0.27, 0.028), lb3)
    B.empty("IA_logbook", book_c + lb3.col[2] * 0.03, (0.13, 0.16, 0.06), lb3)
    # parallel rule + dividers
    box(B.bm("M_LL_Brass"), tc - tb3.col[0] * 0.25 - tb3.col[1] * 0.22 + tb3.col[2] * 0.006, (0.42, 0.05, 0.008), tb3)
    for s in (-1, 1):
        leg = tb3.col[0] * (s * 0.03) + tb3.col[1] * 0.07
        cyl(B.bm("M_LL_Iron"), tc + tb3.col[0] * 0.25 + leg * 0.5 + tb3.col[2] * 0.01, 0.004, 0.002, 0.14, 6, basis_z(leg))
    B.empty("IA_chart", tc + tb3.col[2] * 0.05, (0.5, 0.38, 0.06), tb3)
    B.empty("FOCUS_chart", wp(b, 0, 1.7, 1.05), (0.05, 0.05, 0.05), kind="SPHERE")
    B.empty("FOCUS_chart_at", wp(b, 0, 0.85, 0.36), (0.05, 0.05, 0.05), kind="SPHERE")


def toggle_fn(length=0.08):
    def f(bm, uv):
        cyl(bm, (0, 0, 0), 0.018, 0.018, 0.04, 12)                         # hinge barrel (axis Z)
        box(bm, (0, length / 2, 0), (0.016, length, 0.016))               # lever along +Y
        cyl(bm, (0, length, 0), 0.016, 0.016, 0.03, 12)
    return f


def build_generator_panel(B):
    b = -135.0
    r, o, u = wall_frame(b)
    bs = basis(r, o, u)
    steel = B.bm("M_LL_SteelPaint")
    box(steel, wp(b, 0, 1.4, 0.08), (1.0, 0.16, 0.9), bs)
    fb3, fc = panel_frame(b, 0, 1.4, 0.161)
    def at(x, y):
        return fc + fb3.col[0] * x + fb3.col[1] * y
    C = S["atlas"]["cells"]
    label(B, "GENERATOR", at(0, 0.38), fb3, 0.3)
    label(B, "ENGINE HOUSE", at(0, 0.31), fb3, 0.16)
    gauge(B, "fuel", at(-0.27, 0.16), fb3, 0.1, C["fuel"])
    gauge(B, "temp", at(0.27, 0.16), fb3, 0.1, C["temp"])
    lamp(B, "gen_run", at(0.0, 0.18), fb3, "green", 0.02)
    lamp(B, "gen_hot", at(0.0, 0.08), fb3, "amber", 0.02)

    def valve(bm, uv):
        cyl(bm, (0, 0, 0.02), 0.025, 0.025, 0.04, 14)
        box(bm, (0, 0.06, 0.035), (0.03, 0.14, 0.018))
    B.part("PT_fuel_valve", "M_LL_Brass", at(-0.3, -0.18), fb3, valve)
    cyl(B.bm("M_LL_Iron"), at(-0.3, -0.18), 0.045, 0.045, 0.01, 20, fb3)
    label(B, "FUEL VALVE", at(-0.3, -0.33), fb3, 0.14)
    B.empty("IA_fuel_valve", at(-0.3, -0.16) + fb3.col[2] * 0.05, (0.09, 0.1, 0.07), fb3)

    def button(bm, uv):
        cyl(bm, (0, 0, 0.018), 0.035, 0.032, 0.036, 20)
    cyl(B.bm("M_LL_Brass"), at(0.0, -0.18), 0.05, 0.05, 0.016, 24, fb3)
    B.part("PT_start", "M_LL_Bakelite", at(0.0, -0.18) + fb3.col[2] * 0.006, fb3, button)
    label(B, "START", at(0.0, -0.33), fb3, 0.1)
    B.empty("IA_start", at(0.0, -0.18) + fb3.col[2] * 0.05, (0.07, 0.07, 0.07), fb3)
    # charge toggle: hinge axis = panel X (right), lever points up at rest
    tb3 = basis(fb3.col[1], fb3.col[2], fb3.col[0])
    box(B.bm("M_LL_Iron"), at(0.3, -0.18), (0.07, 0.11, 0.02), fb3)
    B.part("PT_charge", "M_LL_Bakelite", at(0.3, -0.18) + fb3.col[2] * 0.02, tb3, toggle_fn(0.08))
    lamp(B, "charge", at(0.3, -0.05), fb3, "green", 0.016)
    label(B, "CHARGE", at(0.3, -0.33), fb3, 0.12)
    B.empty("IA_charge", at(0.3, -0.14) + fb3.col[2] * 0.05, (0.07, 0.1, 0.07), fb3)
    B.collider("gen_panel", wp(b, 0, 1.4, 0.09), (1.02, 0.2, 0.92), bs)
    # conduits from the panel top up to the ceiling, one fuel line down through the floor
    iron = B.bm("M_LL_Iron")
    for x in (-0.35, -0.2, 0.25):
        cyl(iron, wp(b, x, 2.37, 0.05), 0.018, 0.018, 1.06, 10)
    cyl(B.bm("M_LL_Brass"), wp(b, -0.42, 0.48, 0.05), 0.012, 0.012, 0.96, 8)
    B.empty("IA_gen_panel", wp(b, 0, 1.4, 0.25), (0.5, 0.45, 0.1), bs)


def build_power_cabinet(B):
    b = 135.0
    r, o, u = wall_frame(b)
    bs = basis(r, o, u)
    steel = B.bm("M_LL_SteelPaint")
    d = 0.42
    box(steel, wp(b, -0.25, 0.95, d / 2), (0.92, d, 1.9), bs)
    fb3, fc = panel_frame(b, -0.25, 0.95, d + 0.002)
    def at(x, z):
        return fc + fb3.col[0] * x + fb3.col[1] * (z - 0.95)
    C = S["atlas"]["cells"]
    gauge(B, "battery", at(-0.18, 1.55), fb3, 0.14, C["battery"])
    gauge(B, "charge_amps", at(0.22, 1.58), fb3, 0.1, C["charge"])
    for key, x, lab in (("brk_main", -0.27, "MAIN"), ("brk_lights", 0.02, "ROOM LIGHTS"), ("brk_radar", 0.27, "RADAR")):
        c = at(x, 1.08)
        box(B.bm("M_LL_Iron"), c, (0.12, 0.2, 0.03), fb3)
        tb3 = basis(fb3.col[1], fb3.col[2], fb3.col[0])
        B.part(f"PT_{key}", "M_LL_Bakelite", c + fb3.col[2] * 0.025, tb3, toggle_fn(0.1 if key == "brk_main" else 0.075))
        label(B, lab, at(x, 0.88), fb3, 0.17 if key != "brk_main" else 0.12)
        B.empty(f"IA_{key}", c + fb3.col[2] * 0.06 + fb3.col[1] * 0.03, (0.08, 0.12, 0.08), fb3)
    lamp(B, "main", at(-0.27, 1.27), fb3, "red", 0.016)
    label(B, "DANGER  415 V", at(0, 0.5), fb3, 0.3)
    for x in (-0.42, 0.42):          # door hinges / seams
        box(B.bm("M_LL_Iron"), at(x, 0.95), (0.012, 1.8, 0.012), fb3)
    B.collider("cabinet", wp(b, -0.25, 0.95, d / 2), (0.96, d + 0.04, 1.9), bs)
    # battery bank (6 cells on a low rack)
    rack = B.bm("M_LL_WoodDark")
    box(rack, wp(b, 0.72, 0.12, 0.25), (0.62, 0.46, 0.04), bs)
    for k in range(6):
        cx = 0.52 + (k % 3) * 0.2
        cz = 0.25
        dd = 0.13 + (k // 3) * 0.2
        box(B.bm("M_LL_Bakelite", "SM_RoomCells"), wp(b, cx, cz, dd), (0.17, 0.17, 0.22), bs)
        for t in (-0.04, 0.04):
            cyl(B.bm("M_LL_Brass"), wp(b, cx + t, cz + 0.125, dd), 0.012, 0.012, 0.03, 8)
    B.collider("batteries", wp(b, 0.72, 0.2, 0.25), (0.66, 0.5, 0.4), bs)
    B.empty("IA_power_panel", wp(b, -0.25, 1.4, d + 0.08), (0.46, 0.5, 0.1), bs)
    # conduit up the wall to the ceiling
    iron = B.bm("M_LL_Iron")
    for x in (-0.55, -0.6):
        cyl(iron, wp(b, x, 1.9, 0.04), 0.02, 0.02, 2.0, 10)


def build_ceiling_details(B):
    # pendant light near the door side
    p = wp(180, 0.0, 2.9, 1.4)
    iron = B.bm("M_LL_Iron")
    cyl(iron, p - Vector((0, 0, 0.2)), 0.008, 0.008, 0.4, 6)
    cyl(B.bm("M_LL_SteelPaint", "SM_RoomShade"), p - Vector((0, 0, 0.45)), 0.2, 0.06, 0.12, 24)
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.045, matrix=m4(p - Vector((0, 0, 0.5))))
    B.mesh_obj("LMP_ceiling", bm, "M_LL_Lamp")
    B.empty("LIGHT_ceiling", p - Vector((0, 0, 0.56)), (0.05, 0.05, 0.05), kind="SPHERE")
    # emergency lamp above the door
    lamp_b3, lamp_c = panel_frame(180, 0.0, 2.3, 0.0)
    cyl(iron, lamp_c, 0.06, 0.06, 0.05, 16, lamp_b3)
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.05, matrix=m4(lamp_c + lamp_b3.col[2] * 0.04))
    B.mesh_obj("LMP_emergency", bm, "M_LL_LampRed")
    B.empty("LIGHT_emergency", lamp_c + lamp_b3.col[2] * 0.2, (0.05, 0.05, 0.05), kind="SPHERE")
    # roof beams radiating from the column
    dark = B.bm("M_LL_WoodDark")
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        d = Vector((math.sin(a), math.cos(a), 0))
        box(dark, d * (A_IN / 2 + 0.25) + Vector((0, 0, CEIL - 0.06)), (0.1, A_IN - 0.4, 0.12),
            basis_z(Vector((0, 0, 1)), d.cross(Vector((0, 0, 1)))))


def build_props(B):
    # wall clock above the door
    cb3, cc = panel_frame(180, 0.0, 2.6, 0.0)
    gauge_clock = S["atlas"]["cells"]["clock"]
    cyl(B.bm("M_LL_WoodDark"), cc + cb3.col[2] * 0.02, 0.2, 0.2, 0.04, 32, cb3)
    atlas = B.bm("M_LL_Atlas")
    disc_uv(atlas, B.uv(atlas), cc + cb3.col[2] * 0.042, cb3, 0.18, 40, gauge_clock)
    B.part("NDL_clock_h", "M_LL_Iron", cc + cb3.col[2] * 0.045, cb3, needle_fn(0.1, 0.01))
    B.part("NDL_clock_m", "M_LL_Iron", cc + cb3.col[2] * 0.05, cb3, needle_fn(0.15, 0.007))
    # keeper's orders notice right of the door; photographs left of the door
    nb3, nc = panel_frame(180, 0.85, 1.55, 0.0)
    quad_uv(atlas, B.uv(atlas), nc + nb3.col[2] * 0.004, nb3, 0.34, 0.34, atlas_cell_rect(S["atlas"]["cells"]["notice"]))
    for k, (x, z, w, h) in enumerate([(-0.9, 1.7, 0.26, 0.2), (-0.78, 1.38, 0.2, 0.26)]):
        pb3, pc = panel_frame(180, x, z, 0.0)
        box(B.bm("M_LL_WoodDark"), pc + pb3.col[2] * 0.01, (w + 0.04, h + 0.04, 0.02), pb3)
        box(B.bm("M_LL_Paper", "SM_RoomPhoto"), pc + pb3.col[2] * 0.021, (w, h, 0.002), pb3)
    # oilskin coat on a hook (simple drape) next to the door
    hb3, hc = panel_frame(180, -0.62, 1.8, 0.0)
    cyl(B.bm("M_LL_Brass"), hc + hb3.col[2] * 0.05, 0.012, 0.012, 0.1, 8, hb3)
    coat = B.bm("M_LL_LampAmber", "SM_RoomCoat")   # yellow oilskin (emission 0)
    cyl(coat, hc + hb3.col[2] * 0.1 - hb3.col[1] * 0.42, 0.13, 0.2, 0.8, 10)
    # binoculars on the NE sill
    bb3, bc = panel_frame(45, 0.3, 1.06, -0.02)
    for s in (-1, 1):
        cyl(B.bm("M_LL_Bakelite"), bc + Vector((0, 0, 0.04)) + bb3.col[0] * (s * 0.04), 0.03, 0.035, 0.14, 14,
            basis_z(bb3.col[1]))
    # mug + loose papers on the radio desk
    mb3, mc = panel_frame(-90, 0.05, 0.76 + 0.05, 0.5)
    cyl(B.bm("M_LL_PaintWhite", "SM_RoomMug"), wp(-90, 0.05, 0.81, 0.5), 0.04, 0.04, 0.1, 16)
    r, o, u = wall_frame(-90)
    for k, (x, dd, rot) in enumerate([(0.15, 0.48, 0.3), (0.22, 0.42, -0.2)]):
        pb = basis_z(u, r * math.cos(rot) + o * math.sin(rot))
        box(B.bm("M_LL_Paper"), wp(-90, x, 0.762 + k * 0.001, dd), (0.21, 0.297, 0.001), pb)


# ------------------------------------------------------------------ lighthouse exterior

def build_lighthouse(B):
    T = S["tower"]
    white = B.bm("M_LL_PaintWhite", "SM_Tower")
    segs = T["segments"]
    # tower shaft (open-ended frustum; the room sits on top)
    cyl(white, (0, 0, (T["base_z"] + T["top_z"]) / 2), T["radius_base"], T["radius_top"],
        T["top_z"] - T["base_z"], segs)
    stone = B.bm("M_LL_Stone", "SM_Tower")
    cyl(stone, (0, 0, T["base_z"] + 0.3), T["radius_base"] + 0.5, T["radius_base"] + 0.35, 0.8, segs)
    cyl(stone, (0, 0, T["base_z"] - 1.0), T["radius_base"] + 0.9, T["radius_base"] + 0.6, 2.2, segs)
    # entrance porch + door
    D = T["door"]
    db = D["bearing"]
    r, o, u = wall_frame(db)
    rb = T["radius_base"]
    porch = o * (rb + 0.5) + u * (T["base_z"] + 1.4)
    box(white, porch, (D["width"] + 1.0, 1.4, 2.8), basis(r, o, u))
    box(B.bm("M_LL_Iron", "SM_Tower"), porch + u * 1.55, (D["width"] + 1.3, 1.6, 0.18), basis(r, o, u))
    box(B.bm("M_LL_WoodDark", "SM_Tower"), o * (rb + 1.21) + u * (T["base_z"] + D["height"] / 2), (D["width"], 0.04, D["height"]), basis(r, o, u))
    # small stair windows (dark recesses)
    for bearing, zc in T["stair_windows"]:
        rr = rb + (T["radius_top"] - rb) * (zc - T["base_z"]) / (T["top_z"] - T["base_z"])
        r2, o2, u2 = wall_frame(bearing)
        box(B.bm("M_LL_Iron", "SM_Tower"), o2 * (rr - 0.05) + u2 * zc, (0.45, 0.3, 0.8), basis(r2, o2, u2))
        box(white, o2 * (rr + 0.05) + u2 * (zc - 0.45), (0.65, 0.25, 0.08), basis(r2, o2, u2))
    # gallery deck on corbels + railing
    G = T["gallery"]
    deck_top = G["z"] - 0.02
    iron = B.bm("M_LL_Iron", "SM_Gallery")
    ring_slab(B.bm("M_LL_Stone", "SM_Gallery"), T["radius_top"] - 0.1, G["radius"], deck_top - G["thickness"], deck_top, 48)
    for i in range(24):
        a = 2 * math.pi * i / 24
        d = Vector((math.sin(a), math.cos(a), 0))
        box(white, d * (T["radius_top"] + 0.45) + Vector((0, 0, deck_top - G["thickness"] - 0.35)), (0.22, 0.9, 0.5),
            basis_z(Vector((0, 0, 1)), d.cross(Vector((0, 0, 1)))))
    railing(iron, G["radius"] - 0.08, deck_top, G["rail_h"], G["posts"])
    # watch-room roof (eaves) and lantern
    L = S["lantern"]
    ring_slab(B.bm("M_LL_Iron", "SM_Lantern"), 0.0, A_OUT + 0.45, CEIL + 0.18, L["base_z"], 8, rot=22.5)
    lr = L["radius"]
    sides = L["sides"]
    cyl(B.bm("M_LL_PaintWhite", "SM_Lantern"), (0, 0, (L["base_z"] + L["glass_z"][0]) / 2), lr, lr,
        L["glass_z"][0] - L["base_z"], sides)
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
    # dome, ventilator ball, lightning rod
    copper = B.bm("M_LL_Copper", "SM_Lantern")
    dome_rings = 6
    prev = None
    for k in range(dome_rings + 1):
        t = k / dome_rings
        rr = (lr + 0.12) * math.cos(t * math.pi / 2)
        z = g1 + L["dome_h"] * math.sin(t * math.pi / 2)
        prev = (rr, z) if prev is None else prev
        if k > 0:
            cyl(copper, (0, 0, (prev[1] + z) / 2), prev[0], max(rr, 0.05), max(z - prev[1], 0.01), 24, caps=False)
        prev = (rr, z)
    cyl(copper, (0, 0, g1 + 0.03), lr + 0.18, lr + 0.12, 0.06, 24)
    bmesh.ops.create_uvsphere(copper, u_segments=16, v_segments=10, radius=0.28, matrix=m4(Vector((0, 0, g1 + L["dome_h"] + 0.22))))
    cyl(B.bm("M_LL_Iron", "SM_Lantern"), (0, 0, g1 + L["dome_h"] + 1.0), 0.02, 0.01, 1.4, 6)
    # optic: pedestal (static) + rotating lens drum PT_optic
    cyl(B.bm("M_LL_Brass", "SM_Lantern"), (0, 0, (L["base_z"] + L["optic_z"] - 0.6) / 2), 0.25, 0.32, L["optic_z"] - 0.6 - L["base_z"], 16)

    def optic(bm, uv):
        cyl(bm, (0, 0, 0), 0.62, 0.62, 1.1, 16, caps=True)
        for i in range(8):
            a = 2 * math.pi * i / 8
            d = Vector((math.cos(a), math.sin(a), 0))
            box(bm, d * 0.63, (0.04, 0.05, 1.12), basis_z(Vector((0, 0, 1)), Vector((-d.y, d.x, 0))))
        for z in (-0.3, 0.0, 0.3):
            ring = bmesh.ops.create_cone(bm, cap_ends=False, segments=16, radius1=0.65, radius2=0.65, depth=0.025,
                                         matrix=m4(Vector((0, 0, z))))
            del ring
    B.part("PT_optic", "M_LL_Lens", (0, 0, L["optic_z"]), Matrix.Identity(3), optic)
    B.empty("LIGHT_lamp", (0, 0, L["optic_z"]), (0.1, 0.1, 0.1), kind="SPHERE")


def ring_slab(bm, r_in, r_out, z0, z1, segs, rot=0.0):
    rings = []
    for (r, z) in ((r_in, z0), (r_out, z0), (r_out, z1), (r_in, z1)):
        ring = []
        for i in range(segs):
            a = math.radians(rot) + 2 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.sin(a), r * math.cos(a), z)))
        rings.append(ring)
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
        p = Vector((radius * math.sin(a), radius * math.cos(a), z0 + h / 2))
        cyl(bm, p, 0.022, 0.022, h, 6)
    for zz, rr in ((h, 0.03), (h * 0.5, 0.016)):
        n = posts * 2
        for i in range(n):
            a0 = 2 * math.pi * i / n
            a1 = 2 * math.pi * (i + 1) / n
            p0 = Vector((radius * math.sin(a0), radius * math.cos(a0), z0 + zz))
            p1 = Vector((radius * math.sin(a1), radius * math.cos(a1), z0 + zz))
            seg = p1 - p0
            cyl(bm, (p0 + p1) / 2, rr, rr, seg.length + 0.01, 6, basis_z(seg))


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
