"""Single source of truth for the hero lantern (playbook: one file every piece reads).

Change a number here, re-run build.py, re-render the preview. Units: metres, Z up, base at z=0.
Brief: stylized realism; warm amber reads as "safe and still". A hand lantern a
character could carry or hang; must read clearly at night.
"""

SPEC = {
    "name": "hero_lantern",
    "collection": "ASSET_hero_lantern",
    "dress_collection": "DRESS_hero_lantern",   # preview-only dressing (glow light); never exported
    "style": "stylized realism",
    "targets": ["roblox", "gltf", "unity", "unreal"],
    "tri_budget_total": 4000,

    "sides": 6,
    "foot":   {"radius": 0.097, "height": 0.012},
    "base":   {"radius": 0.088, "height": 0.022},
    "posts":  {"radius": 0.079, "width": 0.009, "height": 0.238},
    "glass":  {"radius": 0.074, "inset": 0.002},
    "top_ring": {"radius": 0.091, "height": 0.014},
    "roof":   {"radius_bottom": 0.100, "radius_top": 0.030, "height": 0.072},
    "chimney": {"radius": 0.022, "height": 0.030, "segments": 12,
                "cap_radius": 0.031, "cap_height": 0.007},
    "handle": {"major_radius": 0.050, "minor_radius": 0.0055, "major_segments": 28, "minor_segments": 8},
    "candle": {"radius": 0.021, "height": 0.080, "segments": 16},
    "flame":  {"radius": 0.0125, "stretch": 2.3, "taper": 0.75, "lift": 0.006, "u": 16, "v": 12},  # Round 3: 12x8 showed facets
    "bevel":  {"offset": 0.0018, "segments": 2, "min_angle_deg": 35},

    "materials": {
        "M_Lantern_Iron":  {"base_hex": "#2E2A26", "roughness": 0.52, "metallic": 0.85},
        # Round 1 (v001 -> v002): glass alpha 0.32 -> 0.22 (read milky beige).
        "M_Lantern_Glass": {"base_hex": "#F3CE93", "roughness": 0.06, "metallic": 0.0, "alpha": 0.22},
        # Round 3: subsurface 0.15 -> 0 (default red-biased SSS radius painted a pink band on the candle).
        "M_Lantern_Wax":   {"base_hex": "#EADBBE", "roughness": 0.45, "metallic": 0.0, "subsurface": 0.0},
        # Round 1: flame measured #FEE5CF vs target #FFB347 (AgX washes bright emission to white):
        # strength 14 -> 4, emission #FFA733 -> #FF8A1F.
        # Round 2 (v002 -> v003): still #FCD4BC (dist 122) -> strength 4 -> 2, emission #FF8A1F -> #FF7A10.
        "M_Lantern_Flame": {"base_hex": "#FFB347", "roughness": 0.5, "metallic": 0.0,
                            "emission_hex": "#FF9020", "emission_strength": 1.6},  # Round 3: salmon #FACCB1 -> #FF9020 @ 1.6
    },
    # Round 1: 6 W -> 30 W so the flame throws a visible warm pool (brief: warm amber = safe).
    "glow_light": {"energy_w": 60.0,  # Round 3: 30 -> 60 W, pool still weak
                   "color_hex": "#FFB45C", "radius": 0.01},

    "preview": {"angles": 8, "elevation": 16, "res": 640, "engine": "eevee", "samples": 48},
}
