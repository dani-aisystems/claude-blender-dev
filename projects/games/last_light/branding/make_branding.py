"""THE LAST LIGHT branding: cut the game's icon, title logotype and boot splash out of Daniel's brand sheet.

  tools/py projects/games/last_light/branding/make_branding.py

Source: branding/source/brand_sheet.png (supplied by Daniel, 2026-11-05; 1672x941). Outputs go to
godot/assets/branding/ and are reproducible from the sheet:
  icon.png        1024x1024 macOS app icon: the painted rounded icon (top right of the sheet) on Apple's
                  icon grid (824 px body, transparent margin and corners). Also the window/Dock icon.
  icon.icns       every macOS size (iconutil): painted art from 64 px, the flat icon at 16 and 32 px
  icon_flat.png   the flat line-art icon (bottom right): reads better at very small sizes
  logo_title.png  the "THE LAST LIGHT" logotype with a transparent background (main menu title)
  keyart.png      the full key art (lighthouse circle + logotype): boot splash
Pixel rects were measured on the sheet (the painted icon's gold border spans x 1198-1595, y 46-439).
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
SHEET = HERE / "source" / "brand_sheet.png"
OUT = HERE.parent / "godot" / "assets" / "branding"

ICON_RECT = (1206, 54, 1588, 432)        # painted icon, just inside its gold border (the mask is the edge)
FLAT_RECT = (1209, 500, 1578, 876)       # flat icon, just inside its border
LOGO_RECT = (112, 612, 1068, 888)        # rules, THE, LAST LIGHT, the small lighthouse ornament
KEYART_RECT = (140, 30, 1080, 900)       # circle art + logotype


def rounded_mask(size, radius, scale=4):
    """Anti-aliased rounded-rect mask (drawn at 4x, then downsampled)."""
    w, h = size
    m = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius * scale, fill=255)
    return m.resize(size, Image.LANCZOS)


def app_icon(sheet, rect, out_png):
    """Apple icon grid: 1024 canvas, 824 body (100 px margin), corner radius ~22.4 % of the body."""
    body = sheet.crop(rect).convert("RGB").resize((824, 824), Image.LANCZOS)
    body = body.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))   # upscaled ~2x: crisp it
    rgba = body.convert("RGBA")
    rgba.putalpha(rounded_mask((824, 824), 185))
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    canvas.alpha_composite(rgba, (100, 100))
    canvas.save(out_png)
    return canvas


def logotype(sheet, rect, out_png):
    """Key the warm cream/gold lettering off the near-black, blue-tinted background (and the waves)."""
    a = np.asarray(sheet.crop(rect).convert("RGB")).astype(np.float32) / 255.0
    lum = a @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    warm = a[..., 0] - a[..., 2]                                # lettering is warm, sea and sky are blue
    alpha = np.clip((lum - 0.12) / 0.30, 0, 1) * np.clip((warm + 0.02) / 0.10, 0, 1)
    bg = np.array([0.024, 0.04, 0.05], np.float32)              # sheet background (measured)
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - bg * (1 - alpha[..., None])) / safe, 0, 1)   # un-blend: no dark fringe on the menu
    img = np.dstack([rgb, alpha]) * 255.0
    Image.fromarray(img.astype(np.uint8), "RGBA").save(out_png)


def icns(png_1024, flat_1024, out_icns):
    """Painted art from 64 px up; the flat line art at 16 and 32 px, where the painting turns into a dark blob."""
    with tempfile.TemporaryDirectory() as td:
        iconset = Path(td) / "icon.iconset"
        iconset.mkdir()
        src = Image.open(png_1024)
        flat = Image.open(flat_1024)
        for s in (16, 32, 128, 256, 512):
            for px, name in ((s, f"icon_{s}x{s}.png"), (s * 2, f"icon_{s}x{s}@2x.png")):
                (flat if px <= 32 else src).resize((px, px), Image.LANCZOS).save(iconset / name)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(out_icns)], check=True)


def main():
    if not SHEET.exists():
        sys.exit(f"missing {SHEET}")
    sheet = Image.open(SHEET)
    if sheet.size != (1672, 941):
        sys.exit(f"unexpected sheet size {sheet.size}: re-measure the rects in this script")
    OUT.mkdir(parents=True, exist_ok=True)
    app_icon(sheet, ICON_RECT, OUT / "icon.png")
    app_icon(sheet, FLAT_RECT, OUT / "icon_flat.png")
    logotype(sheet, LOGO_RECT, OUT / "logo_title.png")
    sheet.crop(KEYART_RECT).convert("RGB").save(OUT / "keyart.png")
    if shutil.which("iconutil"):
        icns(OUT / "icon.png", OUT / "icon_flat.png", OUT / "icon.icns")
    for f in sorted(OUT.glob("*")):
        if f.suffix in (".png", ".icns"):
            print("BRAND", f.name, Image.open(f).size if f.suffix == ".png" else f.stat().st_size)


if __name__ == "__main__":
    main()
