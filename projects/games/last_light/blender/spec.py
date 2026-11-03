"""Single source of truth for THE LAST LIGHT's world geometry and art.

Units: metres, Blender Z up, +Y = north (toward the storm), camera to the south (-Y).
The island and lighthouse base sit at the world origin.

Godot conversion (glTF +Y up): Blender (x, y, z) -> Godot (x, z, -y). layout.py converts
gameplay positions to Godot's XZ plane so the game never has to.

Gameplay tuning (speeds, energy, timing) lives in godot/scripts/core/game_config.gd.
Only geometry and art that both Blender and the game must agree on lives here.
Record review rounds as comments on the value they change:  # Round N: old -> new because ...
"""

SPEC = {
    "name": "last_light",
    "style": "stylized low-poly, flat shaded, cinematic night storm",

    # ---------------- gameplay geometry (shared with Godot through layout.json) ----------------
    "layout": {
        "seed": 7,
        "island_radius": 21.0,          # ships collide with this circle too
        "spawn_radius": 170.0,
        "spawn_arc_deg": [-80.0, 80.0],  # bearings: 0 = north, +90 = east (clockwise)
        "reef_ring": {
            "radius": 62.0,
            "arc_deg": [-78.0, 78.0],
            "rock_radius": [3.6, 5.6],
            "overlap": 0.78,            # chord between neighbours = overlap * (r1 + r2): no leaks
            "jitter_radial": 2.5,
        },
        "back_row": {"radius": 69.0, "every": 2, "rock_radius": [2.6, 4.0]},  # visual depth
        # channels = gaps in the ring. width is the free water between rock edges (m).
        "channels": [
            {"bearing": -46.0, "width": 19.0, "exit": "west"},
            {"bearing": 0.0, "width": 19.0, "exit": "auto"},
            {"bearing": 46.0, "width": 19.0, "exit": "east"},
        ],
        "channel_approach_radius": 132.0,  # ships line up on the channel axis from here
        "channel_outer_radius": 88.0,
        "channel_inner_radius": 46.0,
        "lagoon_point": {"radius": 40.0, "bearing": 97.0},   # +/- for east/west
        "exit_point": {"x": 175.0, "y": -32.0},             # Blender coords; mirrored for west
        "outer_reefs": [  # isolated hazards further out: bearing, radius, rock radius
            [-64.0, 104.0, 4.6],
            [-24.0, 112.0, 4.2],
            [23.0, 100.0, 4.8],
            [66.0, 110.0, 4.4],
        ],
        "channel_clearance_deg": 13.0,  # no outer reef within this many degrees of a channel
    },
}
