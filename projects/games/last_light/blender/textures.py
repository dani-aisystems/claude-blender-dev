"""Generate THE LAST LIGHT's in-room textures (host Python + Pillow, no downloads).

  tools/py projects/games/last_light/blender/textures.py

Writes blender/tex/T_LL_Atlas.png (gauges, selector plates, label plates, notice) and
blender/tex/T_LL_Chart.png (coastal chart drawn from layout.json, so it matches the world).
Text uses macOS system fonts rendered to pixels (nothing bundled).
"""

import importlib.util
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE / "tex"
LAYOUT = HERE.parent / "godot" / "assets" / "data" / "layout.json"
SUP = Path("/System/Library/Fonts/Supplemental")


def font(name, size):
    for cand in (SUP / name, Path("/System/Library/Fonts") / name):
        if cand.exists():
            return ImageFont.truetype(str(cand), size)
    return ImageFont.load_default()


def load_spec():
    s = importlib.util.spec_from_file_location("ll_spec", HERE / "spec.py")
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m.SPEC


IVORY = (233, 226, 207)
INK = (28, 26, 24)
RED = (176, 42, 32)
AMBER = (214, 140, 40)
GREEN = (52, 120, 70)


def cell_origin(idx, cell):
    return (idx % 4) * cell, (idx // 4) * cell


def aged(img, seed, amount=9):
    """Subtle grime + vignette so dials don't look like vector art."""
    rnd = random.Random(seed)
    w, h = img.size
    noise = Image.new("L", (w // 8, h // 8))
    noise.putdata([rnd.randint(128 - amount, 128 + amount) for _ in range(noise.width * noise.height)])
    noise = noise.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(3))
    base = img.convert("RGB")
    dark = Image.new("RGB", (w, h), (80, 70, 55))
    mask = noise.point(lambda v: max(0, v - 128) * 2)
    return Image.composite(dark, base, mask)


def gauge(label, ticks, red=None, amber=None, sweep=270.0, sub=None, seed=0, face=IVORY):
    S = 512
    img = Image.new("RGB", (S, S), (20, 20, 22))
    d = ImageDraw.Draw(img)
    c = S / 2
    R = 236
    d.ellipse([c - R, c - R, c + R, c + R], fill=face)
    start = -90 - sweep / 2  # PIL angles: 0 = east, clockwise; needle 0 = straight up
    def arc_band(f0, f1, col, r0=200, r1=226):
        a0 = start + sweep * f0
        a1 = start + sweep * f1
        d.arc([c - r1, c - r1, c + r1, c + r1], a0, a1, fill=col, width=r1 - r0)
    if amber:
        arc_band(*amber, AMBER)
    if red:
        arc_band(*red, RED)
    n = len(ticks)
    fnt = font("DIN Condensed Bold.ttf", 46)
    for i, t in enumerate(ticks):
        f = i / (n - 1)
        a = math.radians(start + sweep * f)
        for k in range(5 if i < n - 1 else 1):
            ff = f + k / (n - 1) / 5
            aa = math.radians(start + sweep * ff)
            r0 = 196 if k == 0 else 210
            d.line([c + r0 * math.cos(aa), c + r0 * math.sin(aa), c + 228 * math.cos(aa), c + 228 * math.sin(aa)],
                   fill=INK, width=6 if k == 0 else 3)
        tx, ty = c + 158 * math.cos(a), c + 158 * math.sin(a)
        d.text((tx, ty), t, font=fnt, fill=INK, anchor="mm")
    d.text((c, c + 92), label, font=font("DIN Condensed Bold.ttf", 52), fill=INK, anchor="mm")
    if sub:
        d.text((c, c + 140), sub, font=font("DIN Condensed Bold.ttf", 34), fill=(90, 84, 76), anchor="mm")
    d.ellipse([c - R, c - R, c + R, c + R], outline=(60, 58, 54), width=8)
    return aged(img, seed)


def compass(seed=0):
    S = 512
    img = Image.new("RGB", (S, S), (15, 15, 18))
    d = ImageDraw.Draw(img)
    c = S / 2
    d.ellipse([c - 238, c - 238, c + 238, c + 238], fill=(24, 30, 36))
    fnt = font("DIN Condensed Bold.ttf", 44)
    for deg in range(0, 360, 5):
        a = math.radians(deg - 90)
        r0 = 196 if deg % 30 == 0 else (210 if deg % 10 == 0 else 218)
        d.line([c + r0 * math.cos(a), c + r0 * math.sin(a), c + 230 * math.cos(a), c + 230 * math.sin(a)],
               fill=IVORY, width=5 if deg % 30 == 0 else 2)
        if deg % 30 == 0:
            txt = {0: "N", 90: "E", 180: "S", 270: "W"}.get(deg, f"{deg:03d}")
            d.text((c + 160 * math.cos(a), c + 160 * math.sin(a)), txt, font=fnt,
                   fill=AMBER if deg % 90 == 0 else IVORY, anchor="mm")
    d.text((c, c + 70), "BEARING", font=font("DIN Condensed Bold.ttf", 40), fill=(150, 150, 150), anchor="mm")
    return aged(img, seed, 10)


def clock(seed=0):
    S = 512
    img = Image.new("RGB", (S, S), (20, 20, 20))
    d = ImageDraw.Draw(img)
    c = S / 2
    d.ellipse([c - 240, c - 240, c + 240, c + 240], fill=(238, 232, 214))
    fnt = font("Georgia Bold.ttf", 46)
    for h in range(12):
        a = math.radians(h * 30 - 90)
        num = ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"][h]
        d.text((c + 166 * math.cos(a), c + 166 * math.sin(a)), num, font=fnt, fill=INK, anchor="mm")
    for m in range(60):
        a = math.radians(m * 6 - 90)
        r0 = 214 if m % 5 else 205
        d.line([c + r0 * math.cos(a), c + r0 * math.sin(a), c + 228 * math.cos(a), c + 228 * math.sin(a)], fill=INK,
               width=4 if m % 5 == 0 else 2)
    # Iteration A: period fix, North Point is a Northern Lighthouse Board station (Trinity House is English)
    d.text((c, c - 92), "NORTHERN", font=font("Georgia.ttf", 20), fill=(90, 84, 76), anchor="mm")
    d.text((c, c - 68), "LIGHTHOUSE BOARD", font=font("Georgia.ttf", 20), fill=(90, 84, 76), anchor="mm")
    return aged(img, seed, 14)


def selector_plate(title, positions, angles, seed=0):
    S = 512
    img = Image.new("RGB", (S, S), (30, 31, 33))
    d = ImageDraw.Draw(img)
    c = S / 2
    d.ellipse([c - 240, c - 240, c + 240, c + 240], fill=(40, 42, 44), outline=(90, 90, 92), width=6)
    fnt = font("DIN Condensed Bold.ttf", 50)
    for txt, ang in zip(positions, angles):
        a = math.radians(ang - 90)
        # index marks start outside the knob skirt (r 0.049 m of the 0.1 m plate = 125 px) so they stay visible
        d.line([c + 128 * math.cos(a), c + 128 * math.sin(a), c + 158 * math.cos(a), c + 158 * math.sin(a)], fill=IVORY, width=8)
        d.text((c + 186 * math.cos(a), c + 186 * math.sin(a)), txt, font=font("DIN Condensed Bold.ttf", 44 if len(txt) > 4 else 50), fill=IVORY, anchor="mm")
    d.text((c, c + 200), title, font=font("DIN Condensed Bold.ttf", 34), fill=(160, 160, 160), anchor="mm")
    return aged(img, seed, 8)


def label_cell(texts, seed=0):
    img = Image.new("RGB", (512, 512), (24, 24, 26))
    d = ImageDraw.Draw(img)
    for i, t in enumerate(texts):
        y0 = i * 128
        d.rectangle([6, y0 + 8, 506, y0 + 120], fill=(26, 28, 30), outline=(150, 145, 130), width=4)
        size = 72 if len(t) < 12 else 56
        d.text((256, y0 + 64), t, font=font("DIN Condensed Bold.ttf", size), fill=IVORY, anchor="mm")
        for sx in (24, 488):  # screw heads
            d.ellipse([sx - 9, y0 + 55, sx + 9, y0 + 73], fill=(120, 116, 106))
    return aged(img, seed, 10)


def radio_dial(seed=0):
    img = Image.new("RGB", (512, 512), (10, 10, 8))
    d = ImageDraw.Draw(img)
    d.rectangle([10, 150, 502, 362], fill=(250, 196, 110))
    fnt = font("DIN Condensed Bold.ttf", 40)
    for i, ch in enumerate(range(6, 18, 2)):
        x = 40 + i * 86
        d.line([x, 170, x, 210], fill=INK, width=4)
        d.text((x, 240), str(ch), font=fnt, fill=INK, anchor="mm")
    d.text((256, 320), "MARINE VHF  156-162 MHz", font=font("DIN Condensed Bold.ttf", 36), fill=INK, anchor="mm")
    return aged(img, seed, 8).filter(ImageFilter.GaussianBlur(0.6))


def notice(seed=0):
    img = Image.new("RGB", (512, 512), (226, 220, 200))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 512, 90], fill=(170, 40, 30))
    d.text((256, 46), "KEEPER'S ORDERS", font=font("DIN Condensed Bold.ttf", 60), fill=(245, 240, 225), anchor="mm")
    lines = ["1. THE LIGHT SHALL BE KEPT", "    FROM SUNSET TO SUNRISE.", "2. RUN THE ENGINE TO CHARGE",
             "    BEFORE THE BATTERY FALLS", "    BELOW ONE QUARTER.", "3. A TRIPPED MAIN BREAKER", "    MAY BE RESET ONCE THE",
             "    FAULT IS CLEARED.", "4. ANSWER EVERY CALL", "    ON CHANNEL 16."]
    f = font("Courier New Bold.ttf", 30)
    for i, l in enumerate(lines):
        d.text((24, 112 + i * 38), l, font=f, fill=INK)
    return aged(img, seed, 20)


def build_atlas(spec):
    A = spec["atlas"]
    cell = A["cell"]
    atlas = Image.new("RGB", (A["size"], A["size"]), (20, 20, 20))
    C = A["cells"]
    tiles = {
        "battery": gauge("BATTERY", ["0", "20", "40", "60", "80", "100"], red=(0, 0.2), amber=(0.2, 0.3), sub="PERCENT", seed=1),
        "fuel": gauge("FUEL", ["E", "1/4", "1/2", "3/4", "F"], red=(0, 0.12), sub="DAY TANK", seed=2),
        "temp": gauge("TEMP", ["C", "", "", "", "H"], amber=(0.7, 0.85), red=(0.85, 1.0), sub="ENGINE", seed=3),
        "motor": gauge("MOTOR", ["0", "2", "4", "6", "8", "10"], red=(0.7, 1.0), sub="AMPERES", seed=4),
        "charge": gauge("CHARGE", ["0", "10", "20", "30", "40", "50"], sub="AMPERES", seed=5),
        "signal": gauge("SIGNAL", ["0", "3", "6", "9", "+20"], seed=6, face=(250, 214, 150)),
        "bearing": compass(7),
        "clock": clock(8),
        "mode_plate": selector_plate("MODE", ["OFF", "AUTO", "MANUAL"], [-60, 0, 60], 9),
        "intensity_plate": selector_plate("LAMP", ["LOW", "NORM", "HIGH"], [-60, 0, 60], 10),
        "radio_dial": radio_dial(11),
        "notice": notice(12),
    }
    labels = A["labels"]
    for k in range(4):
        tiles[f"labels_{'abcd'[k]}"] = label_cell(labels[k * 4:(k + 1) * 4], 20 + k)
    for key, idx in C.items():
        tile = tiles.get(key)
        if tile is not None:
            atlas.paste(tile, cell_origin(idx, cell))
    return atlas


def build_chart(spec):
    lay = json.loads(LAYOUT.read_text())
    W, H = 2048, 1536
    img = Image.new("RGB", (W, H), (226, 216, 188))
    d = ImageDraw.Draw(img)
    S = 4.8  # px per metre
    cx, cz = W / 2, H * 0.78   # island near the bottom, sea to the north (up)
    P = lambda x, z: (cx + x * S, cz + z * S)
    # depth contours (shallow water around island and reef)
    for r, col in [(230, (205, 214, 206)), (150, (196, 210, 205)), (90, (186, 205, 202))]:
        d.ellipse([cx - r * S, cz - r * S, cx + r * S, cz + r * S], fill=col)
    # bearing rings + rays from the light
    for r in (50, 100, 150, 200):
        d.ellipse([cx - r * S, cz - r * S, cx + r * S, cz + r * S], outline=(120, 110, 95), width=2)
        d.text(P(-(r + 4) * math.sin(math.radians(8)), -(r + 4) * math.cos(math.radians(8))), f"{r} m", font=font("Georgia Italic.ttf", 26), fill=(90, 80, 70), anchor="mb")
    for deg in range(-75, 76, 15):
        a = math.radians(deg)
        x, z = 230 * math.sin(a), -230 * math.cos(a)
        d.line([P(0, 0), P(x, z)], fill=(150, 140, 120), width=1)
        d.text(P(x * 1.04, z * 1.04), f"{deg % 360:03d}", font=font("Georgia.ttf", 26), fill=(80, 70, 60), anchor="mm")
    # island
    isl = lay["island"]["radius"]
    pts = []
    rnd = random.Random(5)
    for i in range(40):
        a = 2 * math.pi * i / 40
        r = isl * (0.95 + 0.12 * rnd.random())
        pts.append(P(r * math.cos(a), r * math.sin(a)))
    d.polygon(pts, fill=(196, 170, 120), outline=(90, 70, 50))
    d.text(P(0, 14), "NORTH POINT", font=font("Georgia Bold.ttf", 30), fill=(70, 50, 30), anchor="mm")
    # reefs (hatched dangers)
    for r in lay["reefs"]:
        x, z, rr = r["x"], r["z"], r["r"]
        box = [P(x - rr, z - rr), P(x + rr, z + rr)]
        d.ellipse(box, fill=(120, 110, 100), outline=(60, 50, 45), width=2)
        d.text(P(x, z), "+", font=font("Georgia Bold.ttf", 28), fill=(40, 30, 25), anchor="mm")
    # channels: dashed leading lines + names
    names = {-46.0: "WEST GUT", 0.0: "NORTH SOUND", 46.0: "EAST GUT"}
    for c in lay["channels"]:
        b = math.radians(c["bearing"])
        p0 = (150 * math.sin(b), -150 * math.cos(b))
        p1 = (40 * math.sin(b), -40 * math.cos(b))
        for k in range(14):
            t0, t1 = k / 14, (k + 0.55) / 14
            a = (p0[0] + (p1[0] - p0[0]) * t0, p0[1] + (p1[1] - p0[1]) * t0)
            bb = (p0[0] + (p1[0] - p0[0]) * t1, p0[1] + (p1[1] - p0[1]) * t1)
            d.line([P(*a), P(*bb)], fill=(150, 40, 30), width=5)
        lx, lz = 165 * math.sin(b), -165 * math.cos(b)
        d.text(P(lx, lz), names.get(c["bearing"], "CHANNEL"), font=font("Georgia Bold Italic.ttf", 40), fill=(150, 40, 30), anchor="mm")
        d.text(P(lx, lz + 9), f"leading line {int(c['bearing']) % 360:03d}°",
               font=font("Georgia Italic.ttf", 24), fill=(120, 40, 30), anchor="mm")
    # harbour exits
    d.text(P(-175, 40), "to Sound of Harris", font=font("Georgia Italic.ttf", 28), fill=(60, 50, 40), anchor="mm")
    d.text(P(175, 40), "to Leverburgh", font=font("Georgia Italic.ttf", 28), fill=(60, 50, 40), anchor="mm")
    # compass rose
    rx, ry = W - 230, 220
    for deg in range(0, 360, 10):
        a = math.radians(deg - 90)
        r0 = 120 if deg % 90 else 80
        d.line([rx + r0 * math.cos(a), ry + r0 * math.sin(a), rx + 150 * math.cos(a), ry + 150 * math.sin(a)], fill=(90, 70, 50), width=2)
    d.polygon([(rx, ry - 140), (rx + 22, ry), (rx, ry + 30), (rx - 22, ry)], fill=(150, 40, 30))
    d.text((rx, ry - 175), "N", font=font("Georgia Bold.ttf", 44), fill=(90, 70, 50), anchor="mm")
    # title cartouche
    d.rectangle([60, 60, 760, 250], fill=(226, 216, 188), outline=(80, 60, 40), width=4)
    d.text((410, 120), "NORTH POINT", font=font("Georgia Bold.ttf", 72), fill=(60, 40, 25), anchor="mm")
    d.text((410, 190), "and approaches  ·  soundings in metres", font=font("Georgia Italic.ttf", 34), fill=(80, 60, 40), anchor="mm")
    d.rectangle([0, 0, W - 1, H - 1], outline=(90, 70, 50), width=12)
    keeper_marks(img, spec, P)
    img = aged(img, 40, 7)
    return img


def keeper_marks(img, spec, P):
    """Stage 1 iteration 5: the keeper's own work on the chart, in pencil, plus tea rings. Nothing here
    may show tonight's events (the chart is on screen from the first beat of ch1): clearing bearings
    for the guts, yesterday's 2100 fix, an old line half rubbed out."""
    W, H = img.size
    d = ImageDraw.Draw(img, "RGBA")
    pen = (78, 78, 84, 150)
    hand = font("Bradley Hand Bold.ttf", 30)
    for brg, txt in ((-24.0, "clear 336°"), (22.0, "clear 022°")):          # clearing bearings off the reefs
        a = math.radians(brg)
        d.line([P(30 * math.sin(a), -30 * math.cos(a)), P(205 * math.sin(a), -205 * math.cos(a))], fill=pen, width=2)
        lx, lz = 120 * math.sin(a) + (14 if brg > 0 else -14), -120 * math.cos(a)
        d.text(P(lx, lz), txt, font=hand, fill=pen, anchor="lm" if brg > 0 else "rm")
    fx, fz = 120 * math.sin(math.radians(10)), -120 * math.cos(math.radians(10))   # yesterday's fix
    x, y = P(fx, fz)
    d.line([x - 12, y - 12, x + 12, y + 12], fill=pen, width=3)
    d.line([x - 12, y + 12, x + 12, y - 12], fill=pen, width=3)
    d.ellipse([x - 22, y - 22, x + 22, y + 22], outline=pen, width=2)
    d.text((x + 30, y - 4), "13/11  2100", font=hand, fill=pen, anchor="lm")
    a0, a1 = P(-150, -60), P(-40, -130)                                     # an old line, rubbed out
    d.line([a0, a1], fill=(78, 78, 84, 40), width=3)
    mx, my = (a0[0] + a1[0]) / 2, (a0[1] + a1[1]) / 2
    d.ellipse([mx - 120, my - 50, mx + 120, my + 50], fill=(240, 232, 210, 40))
    # tea rings (the mug, 80 mm = ~205 px at 2560 px/m): broken arcs, darkest where the tea dried at the rim
    for k, (u, v) in enumerate(spec["desk_chart"]["ring_uv"]):
        cx, cy, r = u * W, (1 - v) * H, 101
        a = 95 if k == 0 else 55
        for j in range(3):
            d.arc([cx - r - j, cy - r - j, cx + r + j, cy + r + j], 30 + 70 * k, 330 + 70 * k, fill=(130, 88, 50, a - 25 * j), width=3)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(160, 120, 80, 14 if k == 0 else 9))


def compass_rose():
    S = 1024
    img = Image.new("RGB", (S, S), (40, 38, 34))
    d = ImageDraw.Draw(img)
    c = S / 2
    brass, dark = (176, 138, 70), (58, 52, 44)
    d.ellipse([20, 20, S - 20, S - 20], outline=brass, width=14)
    d.ellipse([70, 70, S - 70, S - 70], outline=brass, width=5)
    for k in range(32):
        a = math.radians(k * 11.25 - 90)
        r0 = 440 if k % 2 else 420
        d.line([c + r0 * math.cos(a), c + r0 * math.sin(a), c + 470 * math.cos(a), c + 470 * math.sin(a)], fill=brass, width=4)
    for k, L in enumerate([400, 260, 400, 260, 400, 260, 400, 260]):
        a = math.radians(k * 45 - 90)
        w = math.radians(9 if k % 2 == 0 else 12)
        tip = (c + L * math.cos(a), c + L * math.sin(a))
        l = (c + 60 * math.cos(a - math.pi / 2 + 0.0), c + 60 * math.sin(a - math.pi / 2))
        r = (c + 60 * math.cos(a + math.pi / 2), c + 60 * math.sin(a + math.pi / 2))
        d.polygon([tip, l, (c, c)], fill=brass)
        d.polygon([tip, r, (c, c)], fill=dark)
        del w
    f = font("Georgia Bold.ttf", 90)
    for txt, ang in (("N", -90), ("E", 0), ("S", 90), ("W", 180)):
        a = math.radians(ang)
        d.text((c + 360 * math.cos(a), c + 360 * math.sin(a)), txt, font=f, fill=brass, anchor="mm")
    d.ellipse([c - 30, c - 30, c + 30, c + 30], fill=brass)
    return aged(img, 50, 10)


def rug():
    W, H = 1024, 704
    rnd = random.Random(9)
    img = Image.new("RGB", (W, H), (92, 30, 26))
    d = ImageDraw.Draw(img)
    navy, cream, ochre, red = (30, 36, 58), (196, 176, 140), (160, 112, 52), (120, 36, 30)
    for k, col in enumerate([navy, cream, red, ochre, navy]):
        m = 18 + k * 22
        d.rectangle([m, m, W - m, H - m], outline=col, width=12)
    for x in range(140, W - 140, 48):
        for y in range(140, H - 140, 48):
            col = [navy, ochre, cream][(x // 48 + y // 48) % 3]
            d.polygon([(x, y - 18), (x + 18, y), (x, y + 18), (x - 18, y)], outline=col, width=4)
    d.ellipse([W / 2 - 150, H / 2 - 110, W / 2 + 150, H / 2 + 110], fill=navy, outline=cream, width=8)
    d.polygon([(W / 2, H / 2 - 80), (W / 2 + 100, H / 2), (W / 2, H / 2 + 80), (W / 2 - 100, H / 2)], fill=red, outline=ochre, width=6)
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    return aged(img, 60, 22)


def main():
    spec = load_spec()
    OUT.mkdir(exist_ok=True)
    atlas = build_atlas(spec)
    atlas.save(OUT / "T_LL_Atlas.png")
    build_chart(spec).save(OUT / "T_LL_Chart.png")
    compass_rose().save(OUT / "T_LL_Rose.png")
    rug().save(OUT / "T_LL_Rug.png")
    print("TEXTURES_RESULT", json.dumps({"atlas": str(OUT / "T_LL_Atlas.png"), "chart": str(OUT / "T_LL_Chart.png")}))


if __name__ == "__main__":
    main()
