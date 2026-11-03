"""Turntable preview stills of an asset, for visual review (contact sheet afterwards).

Adds a temporary camera, studio lights, ground and world; renders N angles; removes
everything it added and restores render settings. It never saves the .blend.

Usage:
  tools/bl file.blend -P scripts/render/preview.py -- --collection ASSET_x --out renders/x/preview_v001 \
      [--angles 8] [--elevation 18] [--res 640] [--engine eevee|cycles] [--samples 32]
Live (MCP): runpy.run_path(abs_path, run_name="__main__") after setting sys.argv = ["blender", "--", ...].

Prints PREVIEW_RESULT {"files": [...]}.
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
from lib.safe_paths import ensure_allowed  # noqa: E402
from lib.scene_utils import hex_to_linear, look_at, orbit_position, world_bounds  # noqa: E402

TAG = "PREVIEW_"


def engine_id(name):
    return "CYCLES" if name == "cycles" else "BLENDER_EEVEE"


def add_light(coll, name, kind, energy, loc, target, size=1.0, color="#FFFFFF", glossy=True):
    data = bpy.data.lights.new(TAG + name, kind)
    data.energy = energy
    data.color = hex_to_linear(color)[:3]
    if kind == "AREA":
        data.size = size
    obj = bpy.data.objects.new(TAG + name, data)
    coll.objects.link(obj)
    obj.location = loc
    look_at(obj, target)
    obj.visible_glossy = glossy
    return obj


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--collection", default="")
    ap.add_argument("--out", required=True)
    ap.add_argument("--angles", type=int, default=8)
    ap.add_argument("--elevation", type=float, default=18.0)
    ap.add_argument("--res", type=int, default=640)
    ap.add_argument("--engine", default="eevee", choices=["eevee", "cycles"])
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--exposure", type=float, default=0.0)
    ap.add_argument("--background", default="#1E2126")
    ap.add_argument("--no-ground", action="store_true")
    ap.add_argument("--keep", action="store_true", help="leave the preview rig in the scene")
    args = parse(ap)

    scene = bpy.context.scene
    out = ensure_allowed(args.out)
    out.mkdir(parents=True, exist_ok=True)

    if args.collection:
        coll = bpy.data.collections.get(args.collection)
        if coll is None:
            raise SystemExit(f"Collection not found: {args.collection}")
        targets = [o for o in coll.all_objects if o.type == "MESH"]
    else:
        targets = [o for o in scene.objects if o.type == "MESH" and not o.name.startswith(TAG)]
    lo, hi = world_bounds(targets)
    centre = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.05)

    # --- save state ---
    r = scene.render
    saved = dict(engine=r.engine, x=r.resolution_x, y=r.resolution_y, pct=r.resolution_percentage,
                 path=r.filepath, camera=scene.camera, world=scene.world,
                 exposure=scene.view_settings.exposure, film_transparent=r.film_transparent)

    rig = bpy.data.collections.new(TAG + "RIG")
    scene.collection.children.link(rig)
    try:
        cam_data = bpy.data.cameras.new(TAG + "CAM")
        cam_data.lens = 60
        cam = bpy.data.objects.new(TAG + "CAM", cam_data)
        rig.objects.link(cam)
        dist = radius / math.sin(cam_data.angle / 2) * 1.12

        key_pos = centre + Vector((radius * 3, -radius * 3, radius * 4))
        add_light(rig, "KEY", "AREA", 450 * radius ** 2, key_pos, centre, size=radius * 2.5, color="#FFF3E2")
        add_light(rig, "FILL", "AREA", 70 * radius ** 2, centre + Vector((-radius * 4, -radius * 2, radius * 1.5)),
                  centre, size=radius * 3, color="#DCE6FF")
        add_light(rig, "RIM", "AREA", 160 * radius ** 2, centre + Vector((0, radius * 4, radius * 3)),
                  centre, size=radius * 2, color="#FFFFFF", glossy=False)

        if not args.no_ground:
            import bmesh
            me = bpy.data.meshes.new(TAG + "GROUND")
            bm = bmesh.new()
            bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=radius * 60)  # no visible horizon edge
            bm.to_mesh(me)
            bm.free()
            ground = bpy.data.objects.new(TAG + "GROUND", me)
            ground.location = (centre.x, centre.y, lo.z)
            gm = bpy.data.materials.new(TAG + "GROUND_MAT")
            gm.use_nodes = True
            b = gm.node_tree.nodes.get("Principled BSDF")
            b.inputs["Base Color"].default_value = hex_to_linear("#2A2D33")
            b.inputs["Roughness"].default_value = 0.8
            me.materials.append(gm)
            rig.objects.link(ground)

        world = bpy.data.worlds.new(TAG + "WORLD")
        world.use_nodes = True
        bg = world.node_tree.nodes.get("Background")
        bg.inputs["Color"].default_value = hex_to_linear(args.background)
        bg.inputs["Strength"].default_value = 1.0
        scene.world = world

        r.engine = engine_id(args.engine)
        if args.engine == "cycles":
            from render.gpu import enable_gpu  # noqa: E402
            enable_gpu()
            scene.cycles.samples = args.samples
        else:
            scene.eevee.taa_render_samples = args.samples
        r.resolution_x = r.resolution_y = args.res
        r.resolution_percentage = 100
        r.film_transparent = False
        scene.view_settings.exposure = args.exposure
        scene.camera = cam

        files = []
        for i in range(args.angles):
            az = 360.0 * i / args.angles + 30.0
            cam.location = orbit_position(centre, dist, az, args.elevation)
            look_at(cam, centre)
            f = out / f"angle_{i:02d}.png"
            r.filepath = str(f)
            bpy.ops.render.render(write_still=True)
            files.append(str(f))
        print("PREVIEW_RESULT " + json.dumps({"files": files, "engine": r.engine,
                                              "size_m": [round(v, 4) for v in (hi - lo)]}))
    finally:
        r.engine, r.resolution_x, r.resolution_y = saved["engine"], saved["x"], saved["y"]
        r.resolution_percentage, r.filepath = saved["pct"], saved["path"]
        r.film_transparent = saved["film_transparent"]
        scene.camera, scene.world = saved["camera"], saved["world"]
        scene.view_settings.exposure = saved["exposure"]
        if not args.keep:
            for o in list(rig.objects):
                data = o.data
                bpy.data.objects.remove(o, do_unlink=True)
                if data is not None and data.users == 0:
                    if isinstance(data, bpy.types.Mesh):
                        bpy.data.meshes.remove(data)
                    elif isinstance(data, bpy.types.Light):
                        bpy.data.lights.remove(data)
                    elif isinstance(data, bpy.types.Camera):
                        bpy.data.cameras.remove(data)
            bpy.data.collections.remove(rig)
            for m in [m for m in bpy.data.materials if m.name.startswith(TAG) and m.users == 0]:
                bpy.data.materials.remove(m)
            for w in [w for w in bpy.data.worlds if w.name.startswith(TAG) and w.users == 0]:
                bpy.data.worlds.remove(w)


if __name__ == "__main__":
    main()
