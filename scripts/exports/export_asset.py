"""Export an asset collection for one or more engine targets.

Usage (headless):
  tools/bl projects/models/hero_lantern/hero_lantern_v001.blend -P scripts/exports/export_asset.py -- \
      --collection ASSET_hero_lantern --name hero_lantern --targets roblox,gltf,unity,unreal \
      --out exports/hero_lantern

Never overwrites: if a target file exists, a new versioned file is written instead
(name_vNNN.ext) unless --version is given and that file does not exist.
Prints one JSON line prefixed EXPORT_RESULT.
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bpy  # noqa: E402

from exports.presets import PRESETS  # noqa: E402
from lib.bl_args import parse  # noqa: E402
from lib.safe_paths import ensure_allowed, next_version_path, no_overwrite  # noqa: E402


def collect_objects(collection_name):
    coll = bpy.data.collections.get(collection_name)
    if coll is None:
        raise SystemExit(f"Collection not found: {collection_name}")
    return [o for o in coll.all_objects if o.type in {"MESH", "EMPTY", "ARMATURE"}]


def select_only(objs):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active = objs[0]


def export_one(target, objs, out_dir, name, version):
    preset = PRESETS[target]
    tdir = ensure_allowed(Path(out_dir) / target)
    if version:
        path = no_overwrite(tdir / f"{name}_{version}{preset['ext']}")
    else:
        path = next_version_path(tdir, name, preset["ext"])
    select_only(objs)
    if preset["format"] == "fbx":
        bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True,
                                 object_types={"MESH", "EMPTY", "ARMATURE"}, **preset["fbx"])
    else:
        bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, **preset["gltf"])
    return {"target": target, "path": str(path), "bytes": path.stat().st_size,
            "expected_scale": preset["expected_scale"], "notes": preset["notes"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--collection", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--targets", default="roblox,gltf")
    ap.add_argument("--out", required=True)
    ap.add_argument("--version", default="", help="e.g. v001 (fails if it already exists)")
    args = parse(ap)
    objs = collect_objects(args.collection)
    if not objs:
        raise SystemExit("No exportable objects in collection")
    results = [export_one(t.strip(), objs, args.out, args.name, args.version)
               for t in args.targets.split(",") if t.strip()]
    print("EXPORT_RESULT " + json.dumps(results))


if __name__ == "__main__":
    main()
