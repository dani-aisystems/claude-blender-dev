"""Deterministic world layout for THE LAST LIGHT (pure Python: host and Blender both import it).

compute(spec) -> dict in GODOT coordinates (x, z on the sea plane, north = -z).
Blender positions are (x, y) with north = +y, so godot_z = -blender_y.

Conventions shared with the game (godot/scripts/core/geo.gd):
  bearing 0 = north, +90 = east (clockwise seen from above), in degrees here, radians in GDScript.
  bearing b at radius r -> Godot (x, z) = (r*sin b, -r*cos b).
"""

import math
import random

MAX_SHIP_RADIUS = 5.0     # steamer collision radius (game_config.gd must not exceed this)
ROUTE_MARGIN = 1.0        # extra free water required around every safe route


def polar(bearing_deg, radius):
    b = math.radians(bearing_deg)
    return (radius * math.sin(b), -radius * math.cos(b))


def blender_to_godot(x, y):
    return (x, -y)


def godot_to_blender(x, z):
    return (x, -z)


def _ring(spec, rng, ring, gaps, kind, every=1):
    R = ring["radius"]
    a0, a1 = (math.radians(v) for v in spec["layout"]["reef_ring"]["arc_deg"])
    rmin, rmax = ring["rock_radius"]
    overlap = spec["layout"]["reef_ring"]["overlap"]
    jit = spec["layout"]["reef_ring"].get("jitter_radial", 0.0) if kind == "ring" else 1.0
    rocks = []
    a = a0
    prev_r = rmax
    i = 0
    while a <= a1 + 1e-9:
        r = rng.uniform(rmin, rmax)
        moved = False
        for g_bearing, g_half in gaps:
            g = math.radians(g_bearing)
            # rock edge must stay outside the gap's free water
            need = (g_half + r) / R
            if abs(a - g) < need:
                a = g + need
                moved = True
        if a > a1 + 1e-9:
            break
        if i % every == 0 or kind == "ring":
            rr = R + rng.uniform(-jit, jit)
            x, z = polar(math.degrees(a), rr)
            rocks.append({"x": round(x, 3), "z": round(z, 3), "r": round(r, 3), "kind": kind,
                          "variant": rng.randrange(3), "rot": round(rng.uniform(0, 360), 1),
                          "height": round(rng.uniform(0.55, 1.0), 3)})
        i += 1
        step_chord = overlap * (prev_r + r) if not moved else overlap * 2 * r
        prev_r = r
        a += step_chord / R
    return rocks


def _arc(b0, b1, radius, max_step_deg=40.0):
    n = max(1, math.ceil(abs(b1 - b0) / max_step_deg))
    return [polar(b0 + (b1 - b0) * k / n, radius) for k in range(1, n)]


def route(spec, channel, side):
    L = spec["layout"]
    s = 1.0 if side == "east" else -1.0
    b = channel["bearing"]
    pts = [polar(b, L["channel_approach_radius"]), polar(b, L["channel_outer_radius"]),
           polar(b, L["channel_inner_radius"])]
    lag_b = s * L["lagoon_point"]["bearing"]
    pts += _arc(b, lag_b, (L["channel_inner_radius"] + L["lagoon_point"]["radius"]) / 2)
    pts.append(polar(lag_b, L["lagoon_point"]["radius"]))
    ex = L["exit_point"]
    pts.append(blender_to_godot(s * ex["x"], ex["y"]))
    return [[round(x, 3), round(z, 3)] for x, z in pts]


def compute(spec):
    L = spec["layout"]
    rng = random.Random(L["seed"])
    gaps = [(c["bearing"], c["width"] / 2.0) for c in L["channels"]]
    reefs = _ring(spec, rng, L["reef_ring"], gaps, "ring")
    reefs += _ring(spec, rng, L["back_row"], gaps, "back", every=L["back_row"]["every"])
    for bearing, radius, rr in L["outer_reefs"]:
        x, z = polar(bearing, radius)
        reefs.append({"x": round(x, 3), "z": round(z, 3), "r": rr, "kind": "outer",
                      "variant": rng.randrange(3), "rot": round(rng.uniform(0, 360), 1),
                      "height": round(rng.uniform(0.75, 1.0), 3)})
    channels = []
    for c in L["channels"]:
        sides = ["west", "east"] if c["exit"] == "auto" else [c["exit"]]
        channels.append({"bearing": c["bearing"], "width": c["width"], "exit": c["exit"],
                         "routes": {side: route(spec, c, side) for side in sides}})
    return {
        "version": 1,
        "coords": "godot: x east, z south (north = -z); bearing 0 = north, clockwise",
        "island": {"radius": L["island_radius"]},
        "spawn": {"radius": L["spawn_radius"], "arc_deg": L["spawn_arc_deg"]},
        "reefs": reefs,
        "channels": channels,
    }


# ---------------- checks (used by tests and the exporter) ----------------

def _seg_point_dist(a, b, p):
    ax, az = a
    bx, bz = b
    px, pz = p
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    cx, cz = ax + t * dx, az + t * dz
    return math.hypot(px - cx, pz - cz)


def check(layout, spec):
    """Return a list of problems (empty = OK)."""
    problems = []
    L = spec["layout"]
    need_island = layout["island"]["radius"] + MAX_SHIP_RADIUS + ROUTE_MARGIN
    for c in layout["channels"]:
        for side, pts in c["routes"].items():
            for a, b in zip(pts, pts[1:]):
                if _seg_point_dist(a, b, (0.0, 0.0)) < need_island:
                    problems.append(f"route {c['bearing']}/{side} grazes the island at {a}->{b}")
                for r in layout["reefs"]:
                    d = _seg_point_dist(a, b, (r["x"], r["z"]))
                    if d < r["r"] + MAX_SHIP_RADIUS + ROUTE_MARGIN:
                        problems.append(f"route {c['bearing']}/{side} hits reef {r} (d={d:.1f})")
    for r in layout["reefs"]:
        if r["kind"] != "outer":
            continue
        b = math.degrees(math.atan2(r["x"], -r["z"]))
        for c in L["channels"]:
            if abs(b - c["bearing"]) < L["channel_clearance_deg"]:
                problems.append(f"outer reef at bearing {b:.1f} blocks channel {c['bearing']}")
    # ring must be closed outside the gaps: no gap wider than a small ship between neighbours
    ring = sorted((r for r in layout["reefs"] if r["kind"] == "ring"),
                  key=lambda r: math.atan2(r["x"], -r["z"]))
    gap_bearings = [c["bearing"] for c in L["channels"]]
    for r1, r2 in zip(ring, ring[1:]):
        free = math.hypot(r1["x"] - r2["x"], r1["z"] - r2["z"]) - r1["r"] - r2["r"]
        mid = math.degrees(math.atan2((r1["x"] + r2["x"]) / 2, -(r1["z"] + r2["z"]) / 2))
        is_channel = any(abs(mid - g) < 12 for g in gap_bearings)
        if is_channel and free < 2 * MAX_SHIP_RADIUS + 2 * ROUTE_MARGIN:
            problems.append(f"channel near {mid:.1f} too narrow ({free:.1f} m)")
        if not is_channel and free > 2.0:
            problems.append(f"leak in reef ring near bearing {mid:.1f} ({free:.1f} m free)")
    return problems
