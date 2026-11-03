"""Render fixed review stills of the watch room interior (player eye height) for render-review.

  tools/bl projects/games/last_light/blender/last_light_vNNN.blend -P projects/games/last_light/blender/review_views.py \
      -- --out renders/last_light/blender_vNNN --res 960

Views: one per wall from the room centre-ish at eye height, plus a top-down plan. Uses a neutral
work-light rig (not the game's lighting): this is a geometry/proportion/material check.
"""

import argparse
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[3] / "scripts"))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from lib.bl_args import parse  # noqa: E402
from lib.safe_paths import ensure_allowed  # noqa: E402

F = 20.0
EYE = F + 1.65


def look(cam, frm, to):
    cam.location = frm
    cam.rotation_euler = (Vector(to) - Vector(frm)).to_track_quat("-Z", "Y").to_euler()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--res", type=int, default=960)
    ap.add_argument("--exterior", action="store_true")
    a = parse(ap)
    out = ensure_allowed(a.out)
    out.mkdir(parents=True, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    sc.render.resolution_x = a.res
    sc.render.resolution_y = int(a.res * 9 / 16)
    sc.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.get("Review") or bpy.data.worlds.new("Review")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.08, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.world = world
    cam_data = bpy.data.cameras.new("ReviewCam")
    cam = bpy.data.objects.new("ReviewCam", cam_data)
    for o in bpy.data.objects:
        if o.name.startswith("COL_"):
            o.hide_render = True
    sc.collection.objects.link(cam)
    sc.camera = cam
    # work lights: warm room fill + sun outside
    for name, kind, energy, loc in (("RevFill", "POINT", 220.0, (0.6, -0.8, F + 2.6)), ("RevFill2", "POINT", 140.0, (-1.0, 1.0, F + 2.4))):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.shadow_soft_size = 0.5
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        sc.collection.objects.link(lo)
    sun = bpy.data.lights.new("RevSun", "SUN")
    sun.energy = 2.5
    so = bpy.data.objects.new("RevSun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(so)
    if a.exterior:
        cam_data.lens = 35
        views = {
            "ext_front": ((0, -42, 14), (0, 0, 15)),
            "ext_gallery": ((10, -14, 24), (0, 0, 22)),
            "ext_top": ((30, -30, 40), (0, 0, 18)),
        }
        bpy.data.collections["ASSET_watch_room"].hide_render = False
    else:
        cam_data.lens = 16
        views = {}
        for name, bearing in (("n_console", 0), ("ne", 45), ("e_chart", 90), ("se_power", 135),
                              ("s_door", 180), ("sw_gen", -135), ("w_radio", -90), ("nw", -45)):
            b = math.radians(bearing)
            d = Vector((math.sin(b), math.cos(b), 0))
            frm = -d * 2.0 + Vector((0, 0, EYE)) + Vector((-d.y, d.x, 0)) * 0.55
            views[name] = (tuple(frm), tuple(d * 3.0 + Vector((0, 0, F + 1.15))))
        # hide the ceiling for the plan view only
    for name, (frm, to) in views.items():
        look(cam, frm, to)
        if name == "plan":
            cam_data.lens = 10
            for o in bpy.data.objects:
                if o.type == "MESH" and ("Plaster" in o.name or o.name.startswith("SM_Lantern")) and o.location.z < 1:
                    pass
        sc.render.filepath = str(out / f"{name}.png")
        bpy.ops.render.render(write_still=True)
    print("REVIEW_RESULT", out)


if __name__ == "__main__":
    main()
