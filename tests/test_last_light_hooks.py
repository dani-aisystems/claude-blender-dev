"""THE LAST LIGHT: structural checks on the exported room GLB (no Godot, no Blender needed).

The game binds everything interactive by node-name prefix (IA_, PT_, NDL_, LMP_, LIGHT_, FOCUS_, GLS_,
SCR_, SPAWN_ - see godot/scripts/fp/station.gd). A remodel that drops or renames one of those breaks
gameplay silently, so the v006 hook set is frozen in tests/fixtures/last_light_hooks_v006.json.
Also guards Godot's import-hint suffixes (a node ending in "_wheel" became a VehicleWheel3D once),
normals, and the interior budgets from docs/ROADMAP.md (guardrails, not performance proof).
"""

import json
import struct
from pathlib import Path

import pytest

WS = Path(__file__).resolve().parents[1]
MODELS = WS / "projects/games/last_light/godot/assets/models"
FIXTURE = WS / "tests/fixtures/last_light_hooks_v006.json"

# Godot 4 scene-import name hints (matched case-insensitively at the END of a node name).
IMPORT_HINTS = ("-col", "_col", "-colonly", "_colonly", "-convcol", "_convcol", "-convcolonly", "_convcolonly",
                "-rigid", "_rigid", "-vehicle", "_vehicle", "-wheel", "_wheel", "-navmesh", "_navmesh",
                "-occ", "_occ", "-occonly", "_occonly", "-noimp", "_noimp", "-loop", "_loop", "-cycle", "_cycle")

BUDGET = {"tris_total": 200_000, "tris_per_mesh": 100_000, "meshes": 220, "materials": 32}

GL_TRIANGLES = 4


def load_glb(path: Path) -> dict:
    data = path.read_bytes()
    if data[:4] != b"glTF":
        pytest.skip(f"{path.name} is not a binary glTF (LFS pointer not pulled?)")
    (chunk_len,) = struct.unpack("<I", data[12:16])
    assert data[16:20] == b"JSON"
    return json.loads(data[20:20 + chunk_len])


@pytest.fixture(scope="module")
def room() -> dict:
    return load_glb(MODELS / "watch_room.glb")


@pytest.fixture(scope="module")
def lighthouse() -> dict:
    return load_glb(MODELS / "lighthouse.glb")


def node_names(gltf: dict) -> list[str]:
    return [n.get("name", "") for n in gltf.get("nodes", [])]


def mesh_tris(gltf: dict, mesh: dict) -> int:
    tris = 0
    for prim in mesh["primitives"]:
        if prim.get("mode", GL_TRIANGLES) != GL_TRIANGLES:
            continue
        if "indices" in prim:
            tris += gltf["accessors"][prim["indices"]]["count"] // 3
        else:
            tris += gltf["accessors"][prim["attributes"]["POSITION"]]["count"] // 3
    return tris


def test_v006_hooks_preserved(room):
    frozen = json.loads(FIXTURE.read_text())
    present = set(node_names(room))
    missing = sorted(set(frozen["hooks"]) - present)
    assert not missing, f"gameplay hooks missing from watch_room.glb: {missing}"


def test_colliders_present(room):
    frozen = json.loads(FIXTURE.read_text())
    cols = [n for n in node_names(room) if n.startswith("COL_")]
    # The remodel may merge or split colliders, but the room must not lose most of its collision.
    assert len(cols) >= 0.6 * frozen["col_count"], f"only {len(cols)} COL_ nodes (v006 had {frozen['col_count']})"


COLLIDER_HINTS = ("-colonly", "-convcolonly")


@pytest.mark.parametrize("which", ["room", "lighthouse"])
def test_import_hint_suffixes(which, request):
    """COL_ nodes must carry a collision-only hint (intended); nothing else may end in any hint."""
    gltf = request.getfixturevalue(which)
    names = node_names(gltf)
    bad = [n for n in names if not n.startswith("COL_") and n.lower().endswith(IMPORT_HINTS)]
    assert not bad, f"node names that Godot would treat as import hints: {bad}"
    cols_without = [n for n in names if n.startswith("COL_") and not n.lower().endswith(COLLIDER_HINTS)]
    assert not cols_without, f"COL_ nodes without a collision-only hint (would render): {cols_without}"


@pytest.mark.parametrize("which", ["room", "lighthouse"])
def test_all_primitives_have_normals(which, request):
    gltf = request.getfixturevalue(which)
    bad = [m.get("name", "?") for m in gltf.get("meshes", [])
           if any("NORMAL" not in p["attributes"] for p in m["primitives"])]
    assert not bad, f"meshes without normals: {bad}"


def test_room_budgets(room):
    per_mesh = {}
    total = 0
    for node in room["nodes"]:
        if "mesh" in node:
            mesh = room["meshes"][node["mesh"]]
            t = mesh_tris(room, mesh)
            per_mesh[node.get("name", "?")] = t
            total += t
    worst = max(per_mesh.items(), key=lambda kv: kv[1])
    print(f"room: {total} tris, {len(per_mesh)} mesh nodes, {len(room.get('materials', []))} materials, "
          f"largest {worst[0]}={worst[1]}")
    assert total <= BUDGET["tris_total"], f"{total} tris > {BUDGET['tris_total']}"
    assert worst[1] <= BUDGET["tris_per_mesh"], f"{worst[0]} has {worst[1]} tris"
    assert len(per_mesh) <= BUDGET["meshes"]
    assert len(room.get("materials", [])) <= BUDGET["materials"]
