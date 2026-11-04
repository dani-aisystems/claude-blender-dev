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


def photo(kind):
    W, H = 1100, 800
    rnd = random.Random(5 if kind == "keepers" else 8)
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


DOCS = {}


def add(doc_id, title, img, text):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{doc_id}.png", optimize=True)
    DOCS[doc_id] = {"title": title, "text": text}


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
    add("photo_keepers", "Photograph on the wall", photo("keepers"), "Iain & Callum Mackay, North Point, May 1952.")
    add("photo_1953", "Photograph slid under the door", photo("crew"),
        "Eight men on a deck at Leverburgh pier. On the back, in pencil: \"Mary Ellen, July 1953. A. Ross, master.\"")
    (OUT / "docs.json").write_text(json.dumps(DOCS, indent=1))
    print("DOCS_RESULT", json.dumps(sorted(DOCS)))


if __name__ == "__main__":
    main()
