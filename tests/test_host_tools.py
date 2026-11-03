"""Fast tests for host-side tools (no Blender needed)."""

import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

WS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WS / "scripts"))

from lib.bl_args import frames_to_ranges, parse_frame_ranges, script_argv  # noqa: E402
from lib.safe_paths import UnsafePathError, ensure_allowed, next_version_path, no_overwrite  # noqa: E402
from render import contact_sheet  # noqa: E402
from validation import pixel_check, scan_frames  # noqa: E402


def test_frame_ranges_roundtrip():
    frames = parse_frame_ranges("105-110, 1, 3-4,285-287")
    assert frames == [1, 3, 4, 105, 106, 107, 108, 109, 110, 285, 286, 287]
    assert frames_to_ranges(frames) == "1,3-4,105-110,285-287"
    assert script_argv(["blender", "-b", "--", "--x", "1"]) == ["--x", "1"]


def test_paths_guard_and_versioning(tmp_path):
    with pytest.raises(UnsafePathError):
        ensure_allowed(Path.home() / "Desktop" / "x.blend")
    assert next_version_path(tmp_path, "a").name == "a_v001.blend"
    (tmp_path / "a_v001.blend").write_text("x")
    (tmp_path / "a_v007.blend").write_text("x")
    (tmp_path / "ab_v050.blend").write_text("x")  # other asset, ignored
    assert next_version_path(tmp_path, "a").name == "a_v008.blend"
    with pytest.raises(FileExistsError):
        no_overwrite(tmp_path / "a_v001.blend")


def _img(path, value, noise=True):
    rng = np.random.default_rng(0)
    a = np.full((32, 48, 3), value, np.float32)
    if noise:
        a += rng.normal(0, 20, a.shape)
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(path)


def test_scan_frames_finds_bad_frames(tmp_path):
    for f in range(1, 7):
        _img(tmp_path / f"f_{f:04d}.png", 120)
    _img(tmp_path / "f_0002.png", 0, noise=False)        # black
    (tmp_path / "f_0004.png").write_bytes(b"not a png")   # corrupt
    (tmp_path / "f_0005.png").unlink()                    # missing
    bad = scan_frames.scan(tmp_path, range(1, 7))
    assert set(bad) == {2, 4, 5}
    assert frames_to_ranges(bad) == "2,4-5"


def test_pixel_check_and_contact_sheet(tmp_path):
    p = tmp_path / "c.png"
    Image.new("RGB", (40, 40), (196, 112, 58)).save(p)
    assert pixel_check.measure(p, 20, 20) == (196, 112, 58)
    assert pixel_check.main([str(p), "--at", "20,20", "--target", "#C4703A"]) == 0
    assert pixel_check.main([str(p), "--at", "20,20", "--target", "#FFFFFF"]) == 1
    out = contact_sheet.build([p, p, p], tmp_path / "sheet.png", cols=2, thumb=50)
    assert Image.open(out).size[0] > 100
