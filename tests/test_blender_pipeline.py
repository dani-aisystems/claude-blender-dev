"""End-to-end headless Blender smoke test: build -> validate -> export -> reimport.

Run: tools/py -m pytest            (all)     tools/py -m pytest -m "not blender"   (fast, no Blender)
"""

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

WS = Path(__file__).resolve().parents[1]
BL = WS / "tools" / "bl"
BLENDER = os.environ.get("BLENDER_PATH", "/Applications/Blender.app/Contents/MacOS/Blender")

pytestmark = [pytest.mark.blender,
              pytest.mark.skipif(not Path(BLENDER).exists(), reason="Blender not installed")]


def bl(*args, check=True):
    p = subprocess.run([str(BL), *map(str, args)], capture_output=True, text=True, cwd=WS, timeout=300)
    if check and p.returncode != 0:
        raise AssertionError(f"blender failed ({p.returncode}):\n{p.stdout[-3000:]}\n{p.stderr[-2000:]}")
    return p


def marker(out, prefix):
    for line in out.splitlines():
        if line.startswith(prefix + " "):
            return json.loads(line[len(prefix) + 1:])
    raise AssertionError(f"{prefix} not found in output:\n{out[-2000:]}")


@pytest.fixture(scope="module")
def work(tmp_path_factory):
    d = tmp_path_factory.mktemp("bl")
    yield d
    shutil.rmtree(d, ignore_errors=True)


def test_good_asset_validates_exports_and_reimports(work):
    blend = work / "crate.blend"
    bl("-P", WS / "tests/blender/make_test_asset.py", "--", "--out", blend)
    vjson = work / "val.json"
    v = marker(bl(blend, "-P", WS / "scripts/validation/validate_asset.py", "--",
                  "--collection", "ASSET_test_crate", "--target", "roblox", "--json", vjson, "--strict").stdout,
               "VALIDATION_RESULT")
    assert v["overall"] == "PASS", v
    assert v["summary"]["total_tris"] == 12

    exp = marker(bl(blend, "-P", WS / "scripts/exports/export_asset.py", "--", "--collection", "ASSET_test_crate",
                    "--name", "crate", "--targets", "roblox,gltf", "--out", work / "exports").stdout, "EXPORT_RESULT")
    assert {e["target"] for e in exp} == {"roblox", "gltf"}
    for e in exp:
        assert Path(e["path"]).stat().st_size > 0
        r = marker(bl("-P", WS / "scripts/validation/reimport_check.py", "--", "--file", e["path"],
                      "--source-json", vjson, "--expected-scale", e["expected_scale"]).stdout, "REIMPORT_RESULT")
        assert r["ok"], r


def test_bad_asset_fails_roblox_rules(work):
    blend = work / "bad.blend"
    bl("-P", WS / "tests/blender/make_test_asset.py", "--", "--out", blend, "--bad")
    p = bl(blend, "-P", WS / "scripts/validation/validate_asset.py", "--",
           "--collection", "ASSET_test_crate", "--target", "roblox", "--strict", check=False)
    v = marker(p.stdout, "VALIDATION_RESULT")
    assert v["overall"] == "FAIL"
    assert "transforms_applied" in p.stdout and "materials_per_mesh" in p.stdout
    assert p.returncode != 0


def test_export_never_overwrites(work):
    blend = work / "crate.blend"
    out = work / "exports_v"
    args = ("-P", WS / "scripts/exports/export_asset.py", "--", "--collection", "ASSET_test_crate",
            "--name", "crate", "--targets", "gltf", "--out", out)
    first = marker(bl(blend, *args).stdout, "EXPORT_RESULT")[0]["path"]
    second = marker(bl(blend, *args).stdout, "EXPORT_RESULT")[0]["path"]
    assert first != second and Path(first).exists() and Path(second).exists()
    assert first.endswith("crate_v001.glb") and second.endswith("crate_v002.glb")
