"""Single source of truth for <ASSET NAME>. Copy to projects/<type>/<name>/spec.py.

Brief: <who uses it, where, style, how it must read>. Units: metres, Z up, base at z=0.
Record every review round as a comment on the value it changed:  # Round N: old -> new because <measured/seen>.
"""

SPEC = {
    "name": "<name>",
    "collection": "ASSET_<name>",
    "dress_collection": "DRESS_<name>",      # preview-only lights/props, never exported
    "style": "stylized realism",
    "targets": ["roblox", "gltf"],
    "tri_budget_total": 2000,

    # --- dimensions (m) ---
    # "body": {"width": 0.5, "depth": 0.5, "height": 0.5},

    # --- materials: one per mesh for Roblox; names start with M_ ---
    "materials": {
        # "M_<Name>_Wood": {"base_hex": "#8A5A35", "roughness": 0.7, "metallic": 0.0},
    },

    "preview": {"angles": 8, "elevation": 16, "res": 640, "engine": "eevee", "samples": 48},
}
