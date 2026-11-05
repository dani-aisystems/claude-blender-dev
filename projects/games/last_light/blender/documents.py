"""Readable story documents for THE LAST LIGHT (host Python + Pillow, macOS system fonts).

  tools/py projects/games/last_light/blender/documents.py

Writes godot/assets/docs/<id>.png plus docs.json (id -> title + plain transcription for accessibility).
Hands: Callum = Bradley Hand (small square "clerk's hand"), Iain = Snell Roundhand (copperplate),
Morag = Noteworthy (pencil), official = American Typewriter / Courier New.
The 1953 log entry and the 1971 log are deliberately in the SAME hand: that is the chapter-2 clue.
"""

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "godot" / "assets" / "docs"
SUP = Path("/System/Library/Fonts/Supplemental")
SYS = Path("/System/Library/Fonts")


def F(name, size):
    for d in (SUP, SYS):
        p = d / name
        if p.exists():
            return ImageFont.truetype(str(p), size)
    raise FileNotFoundError(name)


CALLUM = lambda s: F("Bradley Hand Bold.ttf", s)
IAIN = lambda s: F("SnellRoundhand.ttc", s)
MORAG = lambda s: F("Noteworthy.ttc", s)
TYPE = lambda s: F("AmericanTypewriter.ttc", s)
PRINT = lambda s: F("Georgia.ttf", s)
PRINTB = lambda s: F("Georgia Bold.ttf", s)
INK = (34, 36, 58)
PENCIL = (70, 70, 72)
PAPER = (232, 222, 196)


def paper(w, h, seed, tone=PAPER, stains=3):
    rnd = random.Random(seed)
    img = Image.new("RGB", (w, h), tone)
    noise = Image.effect_noise((w // 4, h // 4), 18).resize((w, h), Image.BICUBIC).convert("RGB")
    img = Image.blend(img, noise, 0.06)
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(stains):
        x, y, r = rnd.randint(0, w), rnd.randint(0, h), rnd.randint(40, 160)
        d.ellipse([x - r, y - r, x + r, y + r], outline=(150, 120, 80, 40), width=rnd.randint(2, 6))
    for _ in range(4):   # fold shadows
        if rnd.random() < 0.5:
            y = rnd.randint(h // 4, 3 * h // 4)
            d.line([0, y, w, y + rnd.randint(-6, 6)], fill=(0, 0, 0, 18), width=3)
    return img


def jitter_text(d, xy, text, font, fill, seed=0, slope=0.0):
    """Hand-written look: per-word tiny baseline/rotation jitter."""
    rnd = random.Random(seed + len(text))
    x, y = xy
    for word in text.split(" "):
        dy = rnd.uniform(-1.6, 1.6) + slope * x
        d.text((x, y + dy), word, font=font, fill=fill)
        x += d.textlength(word + " ", font=font)


def log_page(year, rows, seed, title_month):
    W, H = 1500, 1050
    img = paper(W, H, seed)
    d = ImageDraw.Draw(img)
    d.text((W // 2, 46), "NORTHERN LIGHTHOUSE BOARD", font=PRINTB(30), fill=(60, 50, 40), anchor="mm")
    d.text((W // 2, 86), f"NORTH POINT LIGHT  ·  STATION LOG  ·  {title_month} {year}", font=PRINT(24), fill=(60, 50, 40), anchor="mm")
    cols = [(60, "Date"), (170, "Time"), (270, "Wind"), (430, "Weather"), (620, "Remarks")]
    y0 = 130
    d.line([40, y0, W - 40, y0], fill=(120, 90, 70), width=2)
    for x, t in cols:
        d.text((x, y0 + 10), t, font=PRINTB(20), fill=(90, 70, 55))
        d.line([x - 10, y0, x - 10, H - 50], fill=(170, 130, 110), width=1)
    for k in range(18):
        y = y0 + 46 + k * 47
        d.line([40, y, W - 40, y], fill=(170, 150, 140), width=1)
    y = y0 + 52
    for r in rows:
        hand, date, time, wind, wx, remark = r
        f = hand(27)
        jitter_text(d, (60, y), date, f, INK, seed)
        jitter_text(d, (170, y), time, f, INK, seed + 1)
        jitter_text(d, (270, y), wind, f, INK, seed + 2)
        jitter_text(d, (430, y), wx, f, INK, seed + 3)
        lines = wrap(d, remark, f, W - 680)
        for i, line in enumerate(lines):
            jitter_text(d, (620, y + i * 47), line, f, INK, seed + 4 + i)
        y += 47 * max(1, len(lines))
    return img.filter(ImageFilter.GaussianBlur(0.4))


def wrap(d, text, font, width):
    out, cur = [], ""
    for w in text.split(" "):
        t = (cur + " " + w).strip()
        if d.textlength(t, font=font) > width and cur:
            out.append(cur)
            cur = w
        else:
            cur = t
    if cur:
        out.append(cur)
    return out


def letter(lines, hand, size, seed, w=1100, h=1500, color=INK, line_h=None):
    img = paper(w, h, seed, (236, 228, 205), 4)
    d = ImageDraw.Draw(img)
    f = hand(size)
    y = 110
    lh = line_h or int(size * 1.55)
    for para in lines:
        if para == "":
            y += lh // 2
            continue
        for line in wrap(d, para, f, w - 200):
            jitter_text(d, (100, y), line, f, color, seed + y)
            y += lh
    return img.filter(ImageFilter.GaussianBlur(0.35))


def clipping():
    W, H = 1000, 1300
    img = paper(W, H, 77, (214, 205, 180), 2)
    d = ImageDraw.Draw(img)
    d.text((W // 2, 70), "STORNOWAY GAZETTE", font=PRINTB(48), fill=(30, 30, 30), anchor="mm")
    d.text((W // 2, 120), "Thursday, 18th March 1954", font=PRINT(22), fill=(50, 50, 50), anchor="mm")
    d.line([60, 145, W - 60, 145], fill=(40, 40, 40), width=3)
    d.text((W // 2, 200), "MARY ELLEN INQUIRY:", font=PRINTB(44), fill=(20, 20, 20), anchor="mm")
    d.text((W // 2, 252), "MASTER TO BLAME", font=PRINTB(44), fill=(20, 20, 20), anchor="mm")
    body = ("The formal inquiry into the loss of the Stornoway trawler Mary Ellen (SY 214) on the East Gut rocks off "
            "North Point on the morning of 15th November last, with the loss of seven lives, concluded at Inverness "
            "yesterday. The court found that the master, Alasdair Ross of Leverburgh, who is presumed drowned, \"failed "
            "to keep a proper lookout and stood into danger despite the light being exhibited.\" Evidence from the "
            "station log of North Point Light, kept by Principal Keeper Iain Mackay, showed that the light was "
            "extinguished for approximately two minutes only, at 2.10 a.m., some twelve minutes after the vessel struck. "
            "A wireless message received at Stornoway shortly before the stranding was described by the court as "
            "\"confused and unreliable.\" The sole survivor of the crew, deckhand Kenneth Bain, was below at the time "
            "and could give no evidence as to the light.")
    y = 310
    for line in wrap(d, body, PRINT(25), W - 140):
        d.text((70, y), line, font=PRINT(25), fill=(30, 30, 30))
        y += 37
    return img.filter(ImageFilter.GaussianBlur(0.5))


def note_046():
    W, H = 900, 640
    img = paper(W, H, 46, (238, 230, 200), 1)
    d = ImageDraw.Draw(img)
    jitter_text(d, (60, 60), "GEAR RACE - worn tooth at 046°.", IAIN(44), INK, 1)
    jitter_text(d, (60, 130), "Sticks in heavy weather. Free by hand.", IAIN(38), INK, 2)
    jitter_text(d, (60, 190), "Reported to Board 1949.   I.M.", IAIN(38), INK, 3)
    d.line([50, 270, W - 50, 270], fill=(150, 120, 100), width=2)
    jitter_text(d, (60, 300), "Reported again 1953.  C.M.", CALLUM(36), INK, 4)
    jitter_text(d, (60, 360), "Reported again 1961.  Engineer says", CALLUM(36), INK, 5)
    jitter_text(d, (60, 410), "\"next refit\".  C.M.", CALLUM(36), INK, 6)
    d.rectangle([W // 2 - 70, 0, W // 2 + 70, 30], fill=(200, 190, 150))   # tape
    return img


def forecast():
    W, H = 1000, 900
    img = paper(W, H, 9, (240, 238, 228), 0)
    d = ImageDraw.Draw(img)
    lines = ["GALE WARNING  ISSUED 1600 GMT 14 NOV 1971", "",
             "HEBRIDES MINCHES  SOUTHWESTERLY SEVERE GALE 9",
             "INCREASING STORM 10 IMMINENT  VEERING WESTERLY LATER", "",
             "MALIN  SOUTHWESTERLY GALE 8 TO SEVERE GALE 9", "",
             "SEA AREA FORECASTS  RAIN  VISIBILITY POOR", "",
             "STORNOWAY COASTGUARD  CH 16  CH 67", "",
             "-- TELEPRINTER NORTH POINT LT --"]
    y = 80
    for l in lines:
        d.text((60, y), l, font=TYPE(28), fill=(40, 40, 70))
        y += 50
    return img


RAW_KEEPERS = HERE / "tex" / "src" / "photo_keepers_raw.png"   # blender/photo_render.py (CC0 base meshes)


def silver_print(raw, seed):
    """Raw Cycles render -> 1950s silver gelatin snapshot: grey tone, soft lens, compressed and lifted
    tonal range, warm-grey toning, vignette, film grain, a few soft creases."""
    rnd = random.Random(seed)
    W, H = raw.size
    g = raw.convert("L").filter(ImageFilter.GaussianBlur(1.1))
    # S-curve, then lift the blacks / dull the whites (faded print)
    g = g.point(lambda v: int(14 + 222 * (0.5 - 0.5 * math.cos(math.pi * (v / 255.0) ** 1.05))))
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    for k in range(40):
        t = k / 40
        vd.ellipse([-W * 0.25 + t * W * 0.2, -H * 0.3 + t * H * 0.22, W * 1.25 - t * W * 0.2, H * 1.3 - t * H * 0.22],
                   fill=int(255 * t))
    vig = vig.filter(ImageFilter.GaussianBlur(60))
    g = Image.composite(g, g.point(lambda v: int(v * 0.72)), vig)
    grain = Image.effect_noise((W, H), 34).filter(ImageFilter.GaussianBlur(0.6))
    g = Image.blend(g, grain, 0.12)
    img = Image.merge("RGB", (g, g.point(lambda v: int(v * 0.965)), g.point(lambda v: int(v * 0.885))))
    d2 = ImageDraw.Draw(img, "RGBA")
    for _ in range(3):
        x, y = rnd.randint(0, W), rnd.randint(0, H)
        pts = [(x, y)]
        for _ in range(10):
            x += rnd.randint(10, 60)
            y += rnd.randint(-14, 14)
            pts.append((x, y))
        d2.line(pts, fill=(240, 232, 214, 70), width=1)
    return img


def photo(kind):
    W, H = 1100, 800
    rnd = random.Random(5 if kind == "keepers" else 8)
    if kind == "keepers" and RAW_KEEPERS.exists():
        img = silver_print(Image.open(RAW_KEEPERS).convert("RGB").resize((W, H), Image.LANCZOS), 5)
        framed = Image.new("RGB", (W + 80, H + 160), (236, 229, 212))
        framed.paste(img, (40, 40))
        fd = ImageDraw.Draw(framed)
        jitter_text(fd, (60, H + 70), "Iain & Callum Mackay, North Point, May 1952", MORAG(34), PENCIL, 3)
        return framed
    img = Image.new("RGB", (W, H), (120, 100, 75))
    d = ImageDraw.Draw(img)
    # sky / sea gradient in sepia
    for y in range(H):
        t = y / H
        c = int(200 - 90 * t)
        d.line([0, y, W, y], fill=(c, int(c * 0.86), int(c * 0.66)))
    if kind == "keepers":
        d.polygon([(560, 120), (640, 120), (680, 700), (520, 700)], fill=(200, 188, 160))   # tower
        d.rectangle([555, 90, 645, 125], fill=(70, 60, 50))
        d.rectangle([590, 560, 625, 700], fill=(70, 60, 50))                                   # door
        figs = [(470, 1.0), (735, 0.88)]
        caption = "Iain & Callum Mackay, North Point, May 1952"
    else:
        d.rectangle([0, 560, W, H], fill=(105, 90, 70))                                        # pier
        d.polygon([(80, 470), (1020, 470), (960, 560), (140, 560)], fill=(60, 52, 44))        # hull
        d.rectangle([620, 360, 760, 470], fill=(80, 70, 58))                                   # wheelhouse
        d.line([400, 470, 400, 180], fill=(60, 52, 44), width=8)
        figs = [(180 + i * 100, 0.62 + rnd.uniform(-0.05, 0.05)) for i in range(8)]
        caption = "Mary Ellen, Leverburgh, July 1953"
    for x, s in figs:
        # head, shoulders, coat, legs: a person, not a pillar
        hgt = (300 if kind == "keepers" else 150) * s
        base = 700 if kind == "keepers" else 470
        u = hgt / 7.0
        col = (48, 40, 33)
        d.ellipse([x - 0.55 * u, base - hgt, x + 0.55 * u, base - hgt + 1.1 * u], fill=col)                       # head
        if kind != "keepers":
            d.rectangle([x - 0.75 * u, base - hgt - 0.1 * u, x + 0.75 * u, base - hgt + 0.35 * u], fill=col)       # cap
        d.polygon([(x - 1.25 * u, base - hgt + 1.4 * u), (x + 1.25 * u, base - hgt + 1.4 * u),
                   (x + 1.05 * u, base - 2.6 * u), (x - 1.05 * u, base - 2.6 * u)], fill=col)                      # coat
        d.rectangle([x - 0.85 * u, base - 2.7 * u, x - 0.15 * u, base], fill=col)                                   # legs
        d.rectangle([x + 0.15 * u, base - 2.7 * u, x + 0.85 * u, base], fill=col)
        d.line([x + 1.2 * u, base - hgt + 1.6 * u, x + 1.6 * u, base - 3.2 * u], fill=col, width=max(2, int(0.4 * u)))
    img = img.filter(ImageFilter.GaussianBlur(2.2))
    noise = Image.effect_noise((W, H), 40).convert("RGB")
    img = Image.blend(img, noise, 0.12)
    d = ImageDraw.Draw(img)
    d2 = ImageDraw.Draw(img, "RGBA")
    for _ in range(3):   # a few soft creases
        x, y = rnd.randint(0, W), rnd.randint(0, H)
        pts = [(x, y)]
        for _ in range(10):
            x += rnd.randint(10, 60)
            y += rnd.randint(-14, 14)
            pts.append((x, y))
        d2.line(pts, fill=(240, 230, 205, 90), width=1)
    framed = Image.new("RGB", (W + 80, H + 160), (238, 230, 210))
    framed.paste(img, (40, 40))
    fd = ImageDraw.Draw(framed)
    jitter_text(fd, (60, H + 70), caption, MORAG(34) if kind == "keepers" else CALLUM(34), PENCIL, 3)
    return framed


TEX = HERE / "tex"


def logbook_spread(left, right):
    """The open station log on the desk: a wide NLB ledger, two landscape pages side by side
    (2048 x 716, each page 1024 x 716 = the 1500 x 1050 log page; left page = u 0..0.5).
    Left = 13 Nov, right = 14 Nov (the readable log_1971 document). A darker gutter marks the binding."""
    W, H = 2048, 716
    out = Image.new("RGB", (W, H), PAPER)
    for k, pg in enumerate((left, right)):
        out.paste(pg.resize((W // 2, H), Image.LANCZOS), (k * W // 2, 0))
    # aged ledger stock is darker than the reading copy: at the full cream (albedo ~0.9) the desk lamp
    # blew the pages out to white (iA_after cu_logbook); x0.78 keeps the hot spot below clipping
    out = out.point(lambda v: int(v * 0.78))
    d = ImageDraw.Draw(out, "RGBA")
    for i in range(60):   # gutter shading into the binding
        a = int(110 * (1 - i / 60) ** 2)
        d.line([W // 2 - i, 0, W // 2 - i, H], fill=(60, 45, 30, a))
        d.line([W // 2 + i, 0, W // 2 + i, H], fill=(60, 45, 30, a))
    # Stage 1 iteration 5: an old tea ring in the left page's lower margin (the mug, 80 mm = ~290 px across;
    # a broken arc, darker at the rim where the tea dried)
    cx, cy, r = 190, 610, 145
    for k in range(3):
        d.arc([cx - r - k, cy - r - k, cx + r + k, cy + r + k], 200, 520, fill=(120, 80, 45, 70 - 20 * k), width=3)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(150, 110, 70, 10))
    return out


DOCS = {}


def add(doc_id, title, img, text):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{doc_id}.png", optimize=True)
    DOCS[doc_id] = {"title": title, "text": text}


# ------------------------------------------------------------------ in-world prop faces (Stage 1 iteration 4)

def calendar():
    """Northern Lighthouse Board wall calendar, November 1971, Sunday-first grid; the 14th ringed in red pencil."""
    W, H = 700, 1000
    img = paper(W, H, 1971, tone=(236, 228, 206), stains=1)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 0, W, 210], fill=(38, 62, 52))
    d.text((W // 2, 70), "NORTHERN LIGHTHOUSE BOARD", font=PRINTB(34), fill=(226, 214, 180), anchor="mm")
    d.text((W // 2, 140), "84 George Street, Edinburgh", font=PRINT(24), fill=(200, 190, 160), anchor="mm")
    d.text((W // 2, 280), "NOVEMBER  1971", font=PRINTB(58), fill=(30, 30, 34), anchor="mm")
    cols = ["S", "M", "T", "W", "T", "F", "S"]
    x0, y0, cw, rh = 40, 360, (W - 80) / 7, 105
    for i, c in enumerate(cols):
        d.text((x0 + cw * (i + 0.5), y0), c, font=PRINTB(30), fill=(150, 40, 30) if i == 0 else (40, 40, 44), anchor="mm")
    day, col = 1, 1               # 1 November 1971 was a Monday
    row = 0
    while day <= 30:
        cx, cy = x0 + cw * (col + 0.5), y0 + 70 + row * rh
        d.text((cx, cy), str(day), font=PRINT(40), fill=(150, 40, 30) if col == 0 else (34, 34, 38), anchor="mm")
        if day == 14:
            for k in range(3):    # red pencil ring, drawn twice like a hand would
                d.ellipse([cx - 44 + k, cy - 36 - k, cx + 46 - k, cy + 38 + k], outline=(176, 40, 32, 200), width=4)
        day += 1
        col += 1
        if col == 7:
            col, row = 0, row + 1
    for r in range(7):
        y = y0 + 25 + r * rh
        d.line([x0, y, W - x0, y], fill=(0, 0, 0, 40), width=2)
    return img


def wiring_diagram():
    """Station power-chain diagram (as the room is built): generator -> charger -> batteries -> distribution."""
    W, H = 1100, 800
    img = paper(W, H, 49, tone=(222, 226, 222), stains=2)
    d = ImageDraw.Draw(img, "RGBA")
    ink = (32, 46, 86)
    d.text((W // 2, 60), "NORTH POINT LIGHT  -  STATION ELECTRICAL SUPPLY", font=TYPE(34), fill=ink, anchor="mm")
    d.text((W // 2, 105), "Watch room.  Drg. No. NP/E/7   (revised 1962)", font=TYPE(24), fill=ink, anchor="mm")
    boxes = {"AUX. SET No.2\n(diesel)": (150, 300, 110), "CHARGER": (420, 300, 110), "BATTERY\n12 cells": (690, 300, 110),
             "DISTRIBUTION": (950, 300, 110), "LAMP": (590, 600, 95), "ROOM LIGHTS": (800, 600, 95), "RADAR / W.T.": (1000, 600, 95)}
    for name, (x, y, hw) in boxes.items():
        d.rectangle([x - hw, y - 55, x + hw, y + 55], outline=ink, width=4)
        d.multiline_text((x, y), name, font=TYPE(24), fill=ink, anchor="mm", align="center")
    for a, b in (((260, 300), (310, 300)), ((530, 300), (580, 300)), ((800, 300), (840, 300))):
        d.line([a, b], fill=ink, width=5)
        d.polygon([(b[0], b[1]), (b[0] - 18, b[1] - 10), (b[0] - 18, b[1] + 10)], fill=ink)
    d.line([(950, 355), (950, 450)], fill=ink, width=4)
    d.line([(590, 450), (1000, 450)], fill=ink, width=4)              # the three circuits off the board
    for x in (590, 800, 1000):
        d.line([(x, 450), (x, 545)], fill=ink, width=4)
    d.text((150, 420), "MAIN ENGINES\n(engine room)\nDISCONNECTED", font=TYPE(22), fill=(150, 40, 30), anchor="mm", align="center")
    d.line([(150, 355), (150, 380)], fill=(150, 40, 30), width=3)
    d.text((60, H - 60), "Initialled  C.M.  4.6.62", font=CALLUM(30), fill=INK)
    return img


def barometer_dial():
    """Aneroid barometer face in millibars (the station log reads the barometer in mb)."""
    S = 1024
    img = Image.new("RGB", (S, S), (234, 226, 204))
    d = ImageDraw.Draw(img, "RGBA")
    c, R = S / 2, S / 2 - 30
    d.ellipse([c - R, c - R, c + R, c + R], outline=(60, 50, 40), width=6)
    ink = (36, 32, 30)
    for mb in range(950, 1051, 5):            # 950..1050 mb over 270 degrees, 1000 mb at the top
        a = math.radians(-135 + (mb - 950) / 100 * 270)
        L = 60 if mb % 10 == 0 else 32
        x0, y0 = c + (R - 20) * math.sin(a), c - (R - 20) * math.cos(a)
        x1, y1 = c + (R - 20 - L) * math.sin(a), c - (R - 20 - L) * math.cos(a)
        d.line([x0, y0, x1, y1], fill=ink, width=5 if mb % 10 == 0 else 3)
        if mb % 20 == 10 or mb in (950, 1050):
            d.text((c + (R - 130) * math.sin(a), c - (R - 130) * math.cos(a)), str(mb), font=PRINT(40), fill=ink, anchor="mm")
    for word, mb in (("STORMY", 960), ("RAIN", 985), ("CHANGE", 1000), ("FAIR", 1015), ("VERY DRY", 1040)):
        a = math.radians(-135 + (mb - 950) / 100 * 270)
        d.text((c + (R - 250) * math.sin(a), c - (R - 250) * math.cos(a)), word, font=PRINTB(44), fill=ink, anchor="mm")
    d.text((c, c + 200), "MILLIBARS", font=PRINT(36), fill=ink, anchor="mm")
    d.text((c, c + 260), "NEGRETTI & ZAMBRA", font=PRINT(30), fill=(90, 80, 70), anchor="mm")
    return img


# ------------------------------------------------------------------ small-prop atlas (Stage 1 iteration 5)

def load_props_atlas():
    import importlib.util
    s = importlib.util.spec_from_file_location("ll_spec", HERE / "spec.py")
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m.SPEC["props_atlas"]


def _chip(d, rd, cx, cy, r, seed):
    """Enamel chip: an irregular patch of dark iron with a faint rust halo (albedo d, roughness rd)."""
    rnd = random.Random(seed)
    pts = []
    for i in range(11):
        a = 2 * math.pi * i / 11
        rr = r * (0.55 + 0.6 * rnd.random())
        pts.append((cx + rr * math.cos(a) * 1.3, cy + rr * math.sin(a)))
    halo = [(cx + (x - cx) * 1.35, cy + (y - cy) * 1.35) for x, y in pts]
    d.polygon(halo, fill=(130, 84, 52, 70))
    d.polygon(pts, fill=(38, 34, 32, 255))
    rd.polygon(pts, fill=180)


def mug_wrap(w, h, mv, seed=31):
    """White enamel mug with a blue rolled rim (UK camp/works mug, Falcon-type 8 x 8 cm). Rows follow
    build.py's lathe profile: v = 0 (outer base) at the bottom row, v = 1 (inside the bottom) at the top."""
    img = Image.new("RGB", (w, h), (236, 234, 226))
    noise = Image.effect_noise((w // 2, h // 2), 10).resize((w, h), Image.BICUBIC).convert("RGB")
    img = Image.blend(img, noise, 0.03)
    rough = Image.new("L", (w, h), int(0.16 * 255))
    d = ImageDraw.Draw(img, "RGBA")
    rd = ImageDraw.Draw(rough)
    row = lambda v: h - v * h
    d.rectangle([0, row(mv["rim_v1"]), w, row(mv["rim_v0"])], fill=(30, 54, 104, 255))
    rd.rectangle([0, row(mv["rim_v1"]), w, row(mv["rim_v0"])], fill=int(0.18 * 255))
    for i in range(14):                                   # handling grime toward the base
        v = 0.12 * (1 - i / 14)
        d.line([0, row(v), w, row(v)], fill=(120, 112, 98, 4 + i), width=int(h * 0.01) + 1)
    z0, z1 = mv["inner_z"]
    it, ib = mv["inner_top"], mv["inner_bottom"]
    vz = lambda z: it + (z0 - z) / (z0 - z1) * (ib - it)  # inner-wall z -> v
    d.rectangle([0, row(1.0), w, row(ib)], fill=(110, 70, 40, 255))   # stained inside bottom
    rd.rectangle([0, row(1.0), w, row(ib)], fill=int(0.3 * 255))
    newest = mv["tide_z"][-1]
    d.rectangle([0, row(ib), w, row(vz(newest))], fill=(150, 110, 75, 170))
    for k, z in enumerate(mv["tide_z"]):                  # tide lines from earlier, fuller mugs
        y = row(vz(z))
        a = 90 if z == newest else 50 - 12 * k
        d.line([0, y, w, y], fill=(120, 80, 48, a), width=2)
        d.rectangle([0, y, w, y + 3], fill=(150, 112, 78, a // 3))
    for k, (u, v, r) in enumerate(((0.70, 0.78, 9), (0.79, 0.46, 7), (0.56, 0.05, 6), (0.33, 0.60, 4), (0.90, 0.80, 5))):
        _chip(d, rd, u * w, row(v), r, seed + k)
    return img, rough


def sked_card(w, h):
    img = paper(w, h, 44, (226, 218, 196), 0)
    d = ImageDraw.Draw(img, "RGBA")
    y = 14
    for line, size in (("STORNOWAY C.G.", 30), ("Ch 16  /  2182 kc/s", 26), ("Radio check 2100", 26), ("& as required.", 26)):
        jitter_text(d, (16, y), line, CALLUM(size), INK, seed=y)
        y += size + 14
    d.rectangle([0, 0, w - 1, h - 1], outline=(150, 135, 110), width=2)
    for x in range(0, w, 3):                              # thumb-grime along the bottom edge
        d.point((x, h - 4 - (x * 7) % 5), fill=(90, 70, 50, 60))
    return img


def tin_lid(w, h):
    """A made-up tobacco brand (no real trade dress)."""
    img = Image.new("RGB", (w, h), (118, 30, 28))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([6, 6, w - 7, h - 7], radius=18, outline=(164, 124, 54), width=5)
    d.rounded_rectangle([16, 16, w - 17, h - 17], radius=12, outline=(164, 124, 54), width=2)
    d.text((w / 2, h * 0.38), "SKERRY", font=PRINTB(44), fill=(196, 160, 84), anchor="mm")
    d.text((w / 2, h * 0.62), "FLAKE", font=PRINTB(34), fill=(196, 160, 84), anchor="mm")
    d.text((w / 2, h * 0.82), "ready rubbed  ·  1 oz", font=PRINT(16), fill=(196, 160, 84), anchor="mm")
    rnd = random.Random(8)
    for _ in range(60):                                   # worn edges show the tinplate
        x, y = rnd.choice([(rnd.randint(0, w), rnd.choice([rnd.randint(0, 10), h - rnd.randint(1, 10)])),
                           (rnd.choice([rnd.randint(0, 10), w - rnd.randint(1, 10)]), rnd.randint(0, h))])
        d.line([x, y, x + rnd.randint(-8, 8), y + rnd.randint(-3, 3)], fill=(190, 186, 176, 160), width=1)
    return img


def spines(w, h):
    """Four 60 px spines: Admiralty List of Lights, the West Coast pilot, the NLB keepers' instructions,
    and a 1971 almanac (generic titles; no publisher's trade dress)."""
    img = Image.new("RGB", (w, h), (30, 30, 30))
    books = (((30, 40, 70), "ADMIRALTY LIST OF LIGHTS  VOL. A"), ((38, 58, 44), "WEST COAST OF SCOTLAND PILOT"),
             ((104, 30, 26), "N.L.B.  INSTRUCTIONS TO LIGHTKEEPERS"), ((26, 25, 24), "NAUTICAL ALMANAC  1971"))
    for k, (col, title) in enumerate(books):
        sp = Image.new("RGB", (h, 60), col)
        sd = ImageDraw.Draw(sp, "RGBA")
        sd.text((h / 2, 30), title, font=PRINTB(19), fill=(196, 164, 92), anchor="mm")
        for x in (14, 20, h - 20, h - 14):
            sd.line([x, 6, x, 54], fill=(196, 164, 92, 200), width=2)
        noise = Image.effect_noise((h // 2, 30), 22).resize((h, 60)).convert("RGB")
        sp = Image.blend(sp, noise, 0.08)
        sd = ImageDraw.Draw(sp, "RGBA")
        for x in range(0, 12):                            # rubbed head and tail
            sd.line([x, 0, x, 60], fill=(200, 190, 170, 70 - 5 * x))
            sd.line([h - 1 - x, 0, h - 1 - x, 60], fill=(200, 190, 170, 70 - 5 * x))
        img.paste(sp.rotate(-90, expand=True), (k * 60, 0))   # English spines read top to bottom
    return img


def stores_note(w, h):
    img = paper(w, h, 46, (226, 220, 202), 1)
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(70, h, 26):                            # ruled foolscap
        d.line([0, y, w, y], fill=(120, 140, 170, 90), width=1)
    d.line([34, 0, 34, h], fill=(170, 80, 80, 90), width=1)
    lines = ["Stores - wk 46", "Gas oil  2 drums", "Bulbs 1000W  x 2", "Mantles (spare) x 6", "Paraffin  5 gal",
             "Batts - S.G. low", "  cells 7, 9", "Wick trimmer"]
    y = 44
    for i, line in enumerate(lines):
        jitter_text(d, (42, y), line, CALLUM(24), PENCIL if i else INK, seed=i)
        y += 26 * (2 if i == 0 else 1) - (0 if i else 0)
    return img


def page_edge(w, h):
    img = Image.new("RGB", (w, h), (222, 210, 182))
    d = ImageDraw.Draw(img, "RGBA")
    rnd = random.Random(12)
    for y in range(h):
        if rnd.random() < 0.45:
            d.line([0, y, w, y], fill=(150, 135, 105, rnd.randint(30, 90)))
    for x in range(0, w, 7):                              # thumbed fore-edge
        d.line([x, 0, x + 2, h], fill=(120, 100, 70, rnd.randint(0, 25)))
    return img


def knit(w, h):
    """Navy wool gansey rib."""
    img = Image.new("RGB", (w, h), (56, 66, 94))       # iteration 5: (30, 36, 54) read as black under one lamp
    d = ImageDraw.Draw(img, "RGBA")
    for x in range(0, w, 10):
        for y in range(0, h, 8):
            d.line([x, y, x + 5, y + 7], fill=(84, 96, 128, 200), width=2)
            d.line([x + 10, y, x + 5, y + 7], fill=(72, 84, 114, 200), width=2)
        d.line([x, 0, x, h], fill=(30, 36, 52, 160), width=1)
    noise = Image.effect_noise((w, h), 30).convert("RGB")
    return Image.blend(img, noise, 0.06)


def props_extras(props, pa):
    """Paint the iteration-5 regions into the props atlas and return its roughness map (same layout)."""
    rg = pa["regions"]
    rough = Image.new("L", props.size, int(0.8 * 255))
    rdr = ImageDraw.Draw(rough)
    for name, r in (("calendar", 0.85), ("diagram", 0.85), ("barometer", 0.45), ("forecast", 0.85), ("sked", 0.82),
                    ("tin", 0.32), ("spines", 0.75), ("note", 0.86), ("page_edge", 0.9), ("knit", 1.0)):
        rdr.rectangle(rg[name], fill=int(r * 255))
    box = lambda n: rg[n]
    size = lambda n: (rg[n][2] - rg[n][0], rg[n][3] - rg[n][1])
    mug, mug_r = mug_wrap(*size("mug"), pa["mug_v"])
    props.paste(mug, box("mug")[:2])
    rough.paste(mug_r, box("mug")[:2])
    props.paste(forecast().resize(size("forecast"), Image.LANCZOS), box("forecast")[:2])
    props.paste(sked_card(*size("sked")), box("sked")[:2])
    props.paste(tin_lid(*size("tin")), box("tin")[:2])
    props.paste(spines(*size("spines")), box("spines")[:2])
    props.paste(stores_note(*size("note")), box("note")[:2])
    props.paste(page_edge(*size("page_edge")), box("page_edge")[:2])
    props.paste(knit(*size("knit")), box("knit")[:2])
    sw = pa["swatch"]
    for i, (name, (rgb, r)) in enumerate(pa["swatches"].items()):
        x = sw["x0"] + (i % sw["cols"]) * sw["px"]
        y = sw["y0"] + (i // sw["cols"]) * sw["px"]
        ImageDraw.Draw(props).rectangle([x, y, x + sw["px"] - 1, y + sw["px"] - 1], fill=tuple(rgb))
        rdr.rectangle([x, y, x + sw["px"] - 1, y + sw["px"] - 1], fill=int(r * 255))
    return rough


def main():
    C = CALLUM
    rows71 = [
        (C, "14.11", "16.22", "SW 6", "Overcast, rain", "Light exhibited. Lamp normal."),
        (C, "", "16.40", "SW 6", "Rain", "Engine started. Batteries on charge, 41%."),
        (C, "", "18.30", "SW 7", "Heavy rain", "Kittiwake (SY 37) brought in by North Sound on radio bearings."),
        (C, "", "23.25", "SW 7", "Heavy rain", "Radio check Stornoway CG. Gale 9 forecast. All well."),
    ]
    add("log_1971", "Station log, 14 November 1971", log_page(1971, rows71, 71, "NOVEMBER"),
        "14.11 16.22 SW6 Overcast, rain: Light exhibited. Lamp normal. / 16.40 Engine started. Batteries on charge, 41%. / "
        "18.30 Kittiwake (SY 37) brought in by North Sound on radio bearings. / 23.25 Radio check Stornoway CG. Gale 9 forecast. All well.  (Hand: C. Mackay)")
    rows53 = [
        (C, "14.11", "23.30", "SW 8", "Heavy rain", "I. Mackay on watch. Light good."),
        (C, "15.11", "01.30", "SW 9", "Rain, poor vis.", "Trawler observed standing in too close to East Gut. No response to light."),
        (C, "", "02.10", "SW 9", "Rain", "Light extinguished approx. 2 min (mantle failure). Relit 02.12."),
        (C, "", "02.30", "SW 9", "Rain", "Wreckage reported East Gut by Stornoway W/T. Mary Ellen (SY 214) believed lost."),
        (IAIN, "", "", "", "", "I. Mackay, P.K."),
    ]
    add("log_1953", "Station log, 14-15 November 1953", log_page(1953, rows53, 53, "NOVEMBER"),
        "14.11 23.30: I. Mackay on watch. Light good. / 15.11 01.30: Trawler observed standing in too close to East Gut. No response to light. / "
        "02.10: Light extinguished approx. 2 min (mantle failure). Relit 02.12. / 02.30: Wreckage reported East Gut by Stornoway W/T. "
        "Mary Ellen (SY 214) believed lost. / Signed I. Mackay, P.K.  (The entries are in the same small square hand as tonight's log.)")
    letter_text = ["Christmas 1957", "", "Callum,", "",
                   "I made you write it. I made a boy of twenty-three put his name to my lie, because I was asleep in this chair with the bottle, and the clockwork stuck on the bad tooth, and the light was out, and I could not face it.",
                   "",
                   "The girl at Stornoway had it right. Ten minutes to two. I heard the wireless in my sleep and thought I was dreaming.",
                   "",
                   "Ross was a better man than me. If you ever have the courage I did not, put it right.",
                   "", "Your father,", "Iain Mackay"]
    add("letter_1957", "Unsent letter, Christmas 1957", letter(letter_text, IAIN, 42, 57), "\n".join(letter_text))
    add("note_046", "Maintenance note, light console", note_046(),
        "GEAR RACE - worn tooth at 046°. Sticks in heavy weather. Free by hand. Reported to Board 1949. I.M. / "
        "Reported again 1953. C.M. / Reported again 1961. Engineer says \"next refit\". C.M.")
    add("clipping_1954", "Stornoway Gazette, 18 March 1954", clipping(),
        "MARY ELLEN INQUIRY: MASTER TO BLAME. ... the master, Alasdair Ross of Leverburgh, who is presumed drowned, \"failed to keep a "
        "proper lookout and stood into danger despite the light being exhibited.\" Evidence from the station log of North Point Light "
        "... showed that the light was extinguished for approximately two minutes only, at 2.10 a.m. ... A wireless message received at "
        "Stornoway shortly before the stranding was described by the court as \"confused and unreliable.\" The sole survivor of the crew, "
        "deckhand Kenneth Bain, was below at the time ...")
    add("forecast", "Teleprinter, 1600 GMT", forecast(),
        "GALE WARNING ISSUED 1600 GMT 14 NOV 1971. HEBRIDES MINCHES SOUTHWESTERLY SEVERE GALE 9 INCREASING STORM 10 IMMINENT.")
    keepers = photo("keepers")
    add("photo_keepers", "Photograph on the wall", keepers, "Iain & Callum Mackay, North Point, May 1952.")
    # in-world textures (build.py TEXTURED): the framed print on the wall and the open logbook on the desk
    TEX.mkdir(exist_ok=True)
    keepers.save(TEX / "T_LL_Photo.png", optimize=True)
    rows13 = [   # routine entries the day before (no story facts beyond NARRATIVE.md: same hand, same station)
        (C, "13.11", "07.58", "W 4", "Fair", "Light extinguished. Lamp and lens cleaned."),
        (C, "", "10.15", "W 4", "Fair", "Engine run 1 hr. Batteries 92%. Fuel day tank topped up."),
        (C, "", "14.00", "SW 5", "Cloudy", "Barometer 1004 mb, falling."),
        (C, "", "16.24", "SW 5", "Cloudy", "Light exhibited. Lamp normal."),
        (C, "", "21.00", "SW 6", "Showers", "Radio check Stornoway CG. All well."),
    ]
    logbook_spread(log_page(1971, rows13, 70, "NOVEMBER"), log_page(1971, rows71, 71, "NOVEMBER")).save(
        TEX / "T_LL_Logbook.png", optimize=True)
    add("photo_1953", "Photograph slid under the door", photo("crew"),
        "Eight men on a deck at Leverburgh pier. On the back, in pencil: \"Mary Ellen, July 1953. A. Ross, master.\"")
    # one 2048 atlas for the three prop faces (one material, not three): calendar top-left (700x1000),
    # wiring diagram top-right (1100x800 at x 720), barometer dial bottom-left (1024x1024 at y 1024)
    props = Image.new("RGB", (2048, 2048), (230, 226, 214))
    props.paste(calendar(), (0, 0))
    props.paste(wiring_diagram(), (720, 0))
    props.paste(barometer_dial(), (0, 1024))
    rough = props_extras(props, load_props_atlas())       # Stage 1 iteration 5: small-prop regions + swatches
    props.save(TEX / "T_LL_Props.png", optimize=True)
    rough.save(TEX / "T_LL_Props_rough.png", optimize=True)
    (OUT / "docs.json").write_text(json.dumps(DOCS, indent=1))
    print("DOCS_RESULT", json.dumps(sorted(DOCS)))


if __name__ == "__main__":
    main()
