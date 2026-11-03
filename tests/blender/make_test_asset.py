"""Test fixture: build a tiny game-ready crate (1 mesh, 1 material, UVs) and save it to --out."""

import argparse
import sys
from pathlib import Path

WS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(WS / "scripts"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

from lib.bl_args import parse  # noqa: E402
from lib.scene_utils import box_project_uvs, get_collection, mesh_object_from_bmesh, principled_material  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--bad", action="store_true", help="leave unapplied scale + 2 materials (should FAIL roblox)")
args = parse(ap)

bpy.ops.wm.read_factory_settings(use_empty=True)
coll = get_collection("ASSET_test_crate")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0, 0.5)))
box_project_uvs(bm)
mat = principled_material("M_TestCrate", "#8A5A35", roughness=0.7)
obj = mesh_object_from_bmesh("SM_TestCrate", bm, coll, mat)
bm.free()
if args.bad:
    obj.scale = (2, 2, 2)
    obj.data.materials.append(principled_material("M_Extra", "#FF0000"))
bpy.ops.wm.save_as_mainfile(filepath=args.out)
print("TEST_ASSET_SAVED", args.out)
