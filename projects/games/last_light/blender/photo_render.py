"""Render the raw "keepers" photograph (Iain & Callum Mackay, North Point, May 1952) in Cycles.

  tools/bl -P projects/games/last_light/blender/photo_render.py -- [--samples 64] [--res 1100x800]

Story source: godot/assets/docs/docs.json "photo_keepers" and NARRATIVE.md (Iain, principal keeper, ~48;
Callum, assistant keeper, ~22). No AI imagery (CLAUDE.md): the two men are Blender Studio's CC0 Human Base
Meshes (assets/models/human_base_meshes, licence logged in assets/ASSET_LICENSES.md), dressed procedurally
in NLB keeper's uniform (reefer jacket, trousers, peaked cap with brass badge) and stood at the tower door
of ASSET_lighthouse from the latest versioned .blend. documents.py turns this raw render into the aged
silver print (grey tone, soft focus, grain, fade, mount, pencilled caption).
Writes blender/tex/src/photo_keepers_raw.png. Headless only (it clears the scene).
"""

import argparse
import math
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WS = HERE.parents[3]
sys.path.insert(0, str(WS / "scripts"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from lib.bl_args import parse  # noqa: E402

BUNDLE = WS / "assets/models/human_base_meshes/bundle/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend"
OUT = HERE / "tex" / "src" / "photo_keepers_raw.png"
BODY = "GEO-body_male_realistic"
TOWER_BASE_Z = 3.5      # spec.py tower.base_z
MATS = {}


def latest_blend():
    best, n = None, -1
    for f in HERE.glob("last_light_v*.blend"):
        m = re.match(r"last_light_v(\d+)$", f.stem)
        if m and int(m.group(1)) > n:
            best, n = f, int(m.group(1))
    return best


def mat(name, hexc, rough, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = tuple(int(hexc[i:i + 2], 16) / 255 for i in (1, 3, 5))
    b.inputs["Base Color"].default_value = (*[x ** 2.2 for x in c], 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def clear():
    if not bpy.app.background:
        raise SystemExit("photo_render.py clears the scene: headless only")
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def append_lighthouse():
    with bpy.data.libraries.load(str(latest_blend()), link=False) as (src, dst):
        dst.collections = [c for c in src.collections if c == "ASSET_lighthouse"]
    for c in dst.collections:
        bpy.context.scene.collection.children.link(c)


def body_mesh():
    """Evaluated (multires level 1; a Subsurf modifier smooths it at render) copy of the CC0 male body, centred on its own feet, facing -Y."""
    with bpy.data.libraries.load(str(BUNDLE), link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n == BODY]
    o = dst.objects[0]
    bpy.context.scene.collection.objects.link(o)
    for m in o.modifiers:
        if m.type == "MULTIRES":
            m.levels = 1
            m.render_levels = 1
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))   # object-local coordinates
    bpy.data.objects.remove(o, do_unlink=True)
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    me.transform(Matrix.Translation((-(min(xs) + max(xs)) / 2, 0, -min(zs))))   # centre on x, feet on z = 0
    return me


def smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def dress(src_me, name, skin, wool, girth=1.0, arm_in_deg=9.0, height=1.0):
    """Region-based uniform on one mesh: skin above the collar and at the hands; everything else is cloth,
    inflated along the normal (jacket 2.6 cm, trousers 1.3 cm, flared hem). Arms rotate in about the shoulders."""
    me = src_me.copy()
    me.name = name
    bm = bmesh.new()
    bm.from_mesh(me)
    sk, jk, tr = 0, 1, 2
    cloth_w = {}
    for v in bm.verts:
        x, y, z = v.co
        hand = smooth(0.3, 0.34, abs(x)) * (1 - smooth(0.85, 0.9, z))
        neck = smooth(1.43, 1.48, z)
        cloth_w[v.index] = (1 - hand) * (1 - neck)
    # cloth hides anatomy: relax the clothed surface (muscle, navel, crotch) before inflating it
    cloth = [v for v in bm.verts if cloth_w[v.index] > 0.95]
    for _ in range(40):
        bmesh.ops.smooth_vert(bm, verts=cloth, factor=0.75, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts:
        x, y, z = v.co
        w = cloth_w[v.index]
        coat = smooth(0.62, 0.72, z)
        boot = 1 - smooth(0.1, 0.16, z)
        off = 0.016 + 0.016 * coat + 0.018 * boot
        hem = smooth(0.6, 0.66, z) * (1 - smooth(0.74, 0.9, z)) * 0.025     # reefer jacket skirt
        horiz = Vector((x, y + 0.01, 0))
        v.co += v.normal * off * w + (horiz.normalized() * hem * w if horiz.length > 1e-4 else Vector())
    for v in bm.verts:   # arms in towards the body about the shoulder pivot
        x, y, z = v.co
        k = smooth(0.17, 0.235, abs(x)) * (1 - smooth(1.42, 1.5, z))
        if k <= 0:
            continue
        s = 1 if x > 0 else -1
        piv = Vector((s * 0.19, 0, 1.41))
        rot = Matrix.Rotation(math.radians(arm_in_deg * k) * s, 3, "Y")
        v.co = piv + rot @ (v.co - piv)
    for v in bm.verts:
        g = girth + (girth - 1.0) * 1.5 * smooth(0.85, 1.05, v.co.z) * (1 - smooth(1.15, 1.3, v.co.z))   # belly
        v.co.x *= g
        v.co.y *= g
        v.co.z *= height
    for f in bm.faces:
        if sum(cloth_w[v.index] for v in f.verts) / len(f.verts) <= 0.5:
            f.material_index = sk
        else:
            zc = sum(v.co.z for v in f.verts) / len(f.verts) / height
            f.material_index = jk if zc > 0.66 else (tr if zc > 0.13 else 3)
        f.smooth = True
    bm.to_mesh(me)
    bm.free()
    for m in (skin, wool, MATS["trousers"], MATS["boots"]):
        me.materials.append(m)
    return me


def cap(bm, head_top, head_xy, tilt=0.0):
    """NLB peaked cap: band, slightly wider crown, black visor, brass badge (returns badge verts)."""
    base = Vector((head_xy.x, head_xy.y, head_top - 0.075))
    rot = Matrix.Rotation(math.radians(tilt), 4, "X")
    m = Matrix.Translation(base) @ rot
    band = bmesh.ops.create_cone(bm, cap_ends=True, segments=28, radius1=0.098, radius2=0.1, depth=0.05,
                                 matrix=m @ Matrix.Translation((0, 0, 0.025)))["verts"]
    crown = bmesh.ops.create_cone(bm, cap_ends=True, segments=28, radius1=0.1, radius2=0.118, depth=0.035,
                                  matrix=m @ Matrix.Translation((0, 0.005, 0.068)))["verts"]
    visor = bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.085, radius2=0.08, depth=0.008,
                                  matrix=m @ Matrix.Translation((0, -0.07, 0.006)) @ Matrix.Rotation(math.radians(-14), 4, "X")
                                  @ Matrix.Diagonal((1.0, 0.7, 1.0, 1.0)))["verts"]
    badge = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.016,
                                      matrix=m @ Matrix.Translation((0, -0.1, 0.035)) @ Matrix.Diagonal((1.2, 0.4, 1.0, 1.0)))["verts"]
    return band + crown, visor, badge


def figure(src_me, name, at, yaw, skin, wool, black, brass, girth, cap_tilt, arm_in, height=1.0, moustache=False):
    me = dress(src_me, name, skin, wool, girth, arm_in, height)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.modifiers.new("smooth", "SUBSURF").render_levels = 1
    vs = [v.co for v in me.vertices]
    top = max(v.z for v in vs)
    hv = [v for v in vs if v.z > top - 0.12]
    hxy = Vector((sum(v.x for v in hv) / len(hv), sum(v.y for v in hv) / len(hv), 0))
    bm = bmesh.new()

    def tag(verts, k):
        for v in verts:
            for f in v.link_faces:
                f.material_index = k
                f.smooth = True
    cloth_v, visor_v, badge_v = cap(bm, top, hxy, cap_tilt)
    tag(cloth_v, 0)
    tag(visor_v, 1)
    tag(badge_v, 2)
    bpy.context.view_layer.update()
    for zb in (1.28, 1.16, 1.04, 0.92):    # double-breasted reefer: two columns of brass buttons
        for xb in (-0.06, 0.06):
            hit, loc, nor, _ = ob.ray_cast(Vector((xb, -1.0, zb * height)), Vector((0, 1, 0)))
            if hit:
                tag(bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=0.011,
                                              matrix=Matrix.Translation(loc + nor * 0.004))["verts"], 2)
    if moustache:   # Iain: a clipped moustache under the nose
        nose = min((v for v in vs if v.z > top - 0.3 and abs(v.x - hxy.x) < 0.03), key=lambda v: v.y)
        tag(bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=6, radius=0.03,
                                      matrix=Matrix.Translation(nose + Vector((0, 0.016, -0.019)))
                                      @ Matrix.Diagonal((1.2, 0.4, 0.28, 1)))["verts"], 3)
    acc = bpy.data.meshes.new(name + "_cap")
    bm.to_mesh(acc)
    bm.free()
    for m in (wool, black, brass, MATS["grey"]):
        acc.materials.append(m)
    co = bpy.data.objects.new(name + "_cap", acc)
    bpy.context.scene.collection.objects.link(co)
    co.parent = ob
    ob.matrix_world = Matrix.Translation(at) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    return ob


def ground(stone, grass):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=120, y_segments=120, size=30.0)
    for v in bm.verts:
        r = math.hypot(v.co.x, v.co.y)
        v.co.z = TOWER_BASE_Z - 0.02 - 0.03 * math.sin(v.co.x * 1.7) * math.cos(v.co.y * 2.3) - max(0.0, r - 14.0) * 0.35
    me = bpy.data.meshes.new("ground")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(grass)
    g = bpy.data.objects.new("ground", me)
    bpy.context.scene.collection.objects.link(g)
    mod = g.modifiers.new("tex", "DISPLACE")
    t = bpy.data.textures.new("tuft", "CLOUDS")
    t.noise_scale = 0.25
    mod.texture = t
    mod.strength = 0.06
    bm = bmesh.new()   # flagstone path to the door
    for k in range(9):
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0.04 * ((k * 7) % 3 - 1), -6.25 - k * 0.62, TOWER_BASE_Z + 0.005))
                              @ Matrix.Diagonal((1.0 + 0.1 * (k % 2), 0.52, 0.06, 1)))
    me = bpy.data.meshes.new("path")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(stone)
    p = bpy.data.objects.new("path", me)
    bpy.context.scene.collection.objects.link(p)
    bm = bmesh.new()   # the sea, far below
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=600.0)
    me = bpy.data.meshes.new("sea")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat("M_Photo_Sea", "#5E6468", 0.25))
    s = bpy.data.objects.new("sea", me)
    bpy.context.scene.collection.objects.link(s)


def world_and_sun():
    w = bpy.data.worlds.new("overcast")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.75, 0.78, 0.82, 1)
    bg.inputs["Strength"].default_value = 1.1
    bpy.context.scene.world = w
    sd = bpy.data.lights.new("sun", "SUN")
    sd.energy = 2.2
    sd.angle = math.radians(18)        # hazy May sun: soft-edged shadows
    sun = bpy.data.objects.new("sun", sd)
    sun.rotation_euler = (math.radians(52), 0, math.radians(-35))
    bpy.context.scene.collection.objects.link(sun)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--res", default="1100x800")
    args = parse(ap)
    clear()
    append_lighthouse()
    skin = mat("M_Photo_Skin", "#B58E74", 0.55)
    wool = mat("M_Photo_Wool", "#20242E", 0.85)
    MATS["trousers"] = mat("M_Photo_Serge", "#262A33", 0.75)
    MATS["boots"] = mat("M_Photo_Boots", "#0E0D0C", 0.35)
    MATS["grey"] = mat("M_Photo_Moustache", "#6E6A66", 0.9)
    black = mat("M_Photo_Visor", "#0C0C0E", 0.25)
    brass = mat("M_Photo_Brass", "#B08A45", 0.3, 1.0)
    ground(mat("M_Photo_Stone", "#77736A", 0.8), mat("M_Photo_Grass", "#5D6A48", 0.9))
    src = body_mesh()
    z0 = TOWER_BASE_Z
    # Iain (48, stockier, square to the camera) and Callum (22, slimmer, turned a little toward his father)
    figure(src, "Iain", Vector((-0.44, -7.05, z0)), 5.0, skin, wool, black, brass, 1.1, 0.0, 14.0, 0.985, moustache=True)
    figure(src, "Callum", Vector((0.42, -7.2, z0)), -10.0, skin, wool, black, brass, 0.97, -4.0, 12.0, 1.03)
    world_and_sun()
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 42
    cam = bpy.data.objects.new("cam", cam_d)
    bpy.context.scene.collection.objects.link(cam)
    frm, to = Vector((0.35, -12.6, z0 + 1.45)), Vector((0.0, -6.5, z0 + 1.55))
    cam.location = frm
    cam.rotation_euler = (to - frm).to_track_quat("-Z", "Y").to_euler()
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.engine = "CYCLES"
    sc.cycles.samples = args.samples
    sc.cycles.use_denoising = True
    try:
        sc.cycles.device = "GPU"
    except Exception:
        pass
    w, h = (int(x) for x in args.res.split("x"))
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "PNG"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sc.render.filepath = str(OUT)
    bpy.ops.render.render(write_still=True)
    print("PHOTO_RESULT", OUT)


if __name__ == "__main__":
    main()
