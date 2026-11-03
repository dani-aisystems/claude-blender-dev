"""Tile rendered stills into one labelled grid for review (playbook Step 3: look at them as one grid).

  tools/py scripts/render/contact_sheet.py renders/x/preview_v001 -o renders/x/preview_v001_sheet.png [--cols 4] [--thumb 400]
Accepts a directory (all .png inside, sorted) or explicit files.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw


def build(files, out, cols=4, thumb=400, label=True):
    imgs = [Image.open(f).convert("RGB") for f in files]
    if not imgs:
        raise SystemExit("no images")
    ar = imgs[0].height / imgs[0].width
    tw, th = thumb, int(thumb * ar)
    pad, lab = 6, 18 if label else 0
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + lab + pad) + pad), (14, 15, 18))
    draw = ImageDraw.Draw(sheet)
    for i, (img, f) in enumerate(zip(imgs, files)):
        r, c = divmod(i, cols)
        x, y = pad + c * (tw + pad), pad + r * (th + lab + pad)
        sheet.paste(img.resize((tw, th), Image.LANCZOS), (x, y + lab))
        if label:
            draw.text((x + 2, y + 2), Path(f).stem, fill=(200, 200, 200))
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--thumb", type=int, default=400)
    a = ap.parse_args(argv)
    files = []
    for p in map(Path, a.inputs):
        files += sorted(p.glob("*.png")) if p.is_dir() else [p]
    out = build(files, a.out, a.cols, a.thumb)
    print(f"CONTACT_SHEET {out} ({len(files)} images)")


if __name__ == "__main__":
    sys.exit(main())
