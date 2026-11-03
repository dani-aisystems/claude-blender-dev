"""THE LAST LIGHT: world layout rules (host only, no Blender)."""

import importlib.util
import math
from pathlib import Path

WS = Path(__file__).resolve().parents[1]
BL = WS / "projects/games/last_light/blender"


def _load(name, path):
    s = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m


SPEC = _load("ll_spec", BL / "spec.py").SPEC
LAYOUT = _load("ll_layout", BL / "layout.py")


def test_layout_has_no_problems_and_is_deterministic():
    a = LAYOUT.compute(SPEC)
    assert LAYOUT.check(a, SPEC) == []
    assert a == LAYOUT.compute(SPEC)
    assert len(a["channels"]) == 3 and len(a["reefs"]) > 15


def test_coordinate_conventions():
    # bearing 0 = north = -z in Godot, +y in Blender; bearing 90 = east = +x
    x, z = LAYOUT.polar(0, 10)
    assert abs(x) < 1e-9 and abs(z + 10) < 1e-9
    x, z = LAYOUT.polar(90, 10)
    assert abs(x - 10) < 1e-9 and abs(z) < 1e-9
    assert LAYOUT.blender_to_godot(3, 4) == (3, -4)
    assert LAYOUT.godot_to_blender(*LAYOUT.blender_to_godot(3, 4)) == (3, 4)


def test_routes_end_at_side_exits():
    lay = LAYOUT.compute(SPEC)
    for c in lay["channels"]:
        for side, pts in c["routes"].items():
            assert (pts[-1][0] > 100) == (side == "east")
            # first waypoint is outside the reef ring, on the channel bearing
            b = math.degrees(math.atan2(pts[0][0], -pts[0][1]))
            assert abs(b - c["bearing"]) < 1e-3  # coords rounded to mm


def test_check_catches_a_blocked_route():
    lay = LAYOUT.compute(SPEC)
    p = lay["channels"][1]["routes"]["east"][1]
    lay["reefs"].append({"x": p[0], "z": p[1], "r": 4.0, "kind": "outer"})
    assert any("hits reef" in s for s in LAYOUT.check(lay, SPEC))
