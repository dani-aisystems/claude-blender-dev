"""Turn an asset .blend into an animated turntable film scene (camera orbits the asset).

  tools/bl projects/models/x/x_v005.blend -P scripts/render/turntable_scene.py -- \
      --collection ASSET_x --frames 120 --out-dir projects/films/x_turntable --name x_turntable

Saves a NEW versioned .blend in --out-dir (the source asset file is not modified).
Then render with scripts/render/render.py (chunked, resumable) and encode with scripts/film/encode.py.
"""

import argparse
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from lib.bl_args import parse  # noqa: E402
from lib.scene_utils import get_collection, hex_to_linear, look_at, save_versioned, world_bounds  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--collection", required=True)
    ap.add_argument("--frames", type=int, default=120)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--elevation", type=float, default=14.0)
    ap.add_argument("--res", default="1920x1080")
    ap.add_argument("--background", default="#14161A")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--name", required=True)
    args = parse(ap)

    scene = bpy.context.scene
    coll = bpy.data.collections.get(args.collection)
    if coll is None:
        raise SystemExit(f"Collection not found: {args.collection}")
    lo, hi = world_bounds([o for o in coll.all_objects if o.type == "MESH"])
    centre = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.05)

    rig = get_collection("RIG_turntable")
    pivot = bpy.data.objects.new("RIG_Pivot", None)
    rig.objects.link(pivot)
    pivot.location = centre

    cam_data = bpy.data.cameras.new("CAM_Turntable")
    cam_data.lens = 50
    cam = bpy.data.objects.new("CAM_Turntable", cam_data)
    rig.objects.link(cam)
    w, h = (int(v) for v in args.res.split("x"))
    vfov = 2 * math.atan(math.tan(cam_data.angle / 2) * h / w)
    dist = radius / math.sin(vfov / 2) * 1.05
    el = math.radians(args.elevation)
    cam.parent = pivot
    cam.location = Vector((0, -dist * math.cos(el), dist * math.sin(el)))
    bpy.context.view_layer.update()  # playbook: update before parenting-dependent maths
    direction = Vector((0, 0, 0)) - cam.location  # aim at the pivot (local origin)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    for name, energy, offset, color, glossy in (
            ("KEY", 450, (3, -3, 4), "#FFF3E2", True),
            ("FILL", 70, (-4, -2, 1.5), "#DCE6FF", True),
            ("RIM", 160, (0, 4, 3), "#FFFFFF", False)):
        ld = bpy.data.lights.new("LGT_TT_" + name, "AREA")
        ld.energy = energy * radius ** 2
        ld.size = radius * 2.5
        ld.color = hex_to_linear(color)[:3]
        lo_ = bpy.data.objects.new("LGT_TT_" + name, ld)
        rig.objects.link(lo_)
        lo_.location = centre + Vector(offset) * radius
        look_at(lo_, centre)
        lo_.visible_glossy = glossy

    world = bpy.data.worlds.new("WORLD_Turntable")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = hex_to_linear(args.background)
    scene.world = world

    prefs = bpy.context.preferences.edit
    old_interp = prefs.keyframe_new_interpolation_type
    prefs.keyframe_new_interpolation_type = "LINEAR"
    try:
        scene.frame_start, scene.frame_end = 1, args.frames
        pivot.rotation_euler = (0, 0, 0)
        pivot.keyframe_insert("rotation_euler", index=2, frame=1)
        pivot.rotation_euler = (0, 0, 2 * math.pi * args.frames / (args.frames + 1))  # seamless loop
        pivot.keyframe_insert("rotation_euler", index=2, frame=args.frames)
    finally:
        prefs.keyframe_new_interpolation_type = old_interp

    r = scene.render
    r.resolution_x, r.resolution_y, r.resolution_percentage = w, h, 100
    r.fps = args.fps
    r.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 64

    path = save_versioned(args.out_dir, args.name)
    print("TURNTABLE_RESULT " + json.dumps({"saved": path, "frames": args.frames, "fps": args.fps,
                                            "res": [w, h], "camera_distance_m": round(dist, 3)}))


if __name__ == "__main__":
    main()
