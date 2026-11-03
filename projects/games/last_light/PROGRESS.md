# THE LAST LIGHT: progress

| Milestone | Status | Evidence |
|---|---|---|
| M0 Setup | DONE | Godot 4.7.2 installed, macOS template SHA-512 verified, `tools/godot`, DECISIONS Q9/Q10 |
| M1 Playable greybox slice | DONE | 95/95 unit tests; sims pass all gates (see TEST_RESULTS.md); screenshots `renders/last_light/m1*_*.png` viewed |
| M2 Blender art pass | TODO | |
| M3 Atmosphere | TODO | |
| M4 UI and feedback polish | TODO | |
| M5 Audio | TODO | |
| M6 Tuning and QA | TODO | |
| M7 Build and delivery | TODO | |

## Tuning log
- Tune 1: beam range 140 → 185 m. Ships were lightable for only about 8 s before the reef, so the expert bot lost.
- Tune 1: new rule, lit ships slow to 70% speed.
- Tune 2: waypoints replaced with pure pursuit (20 m look-ahead, 15 m capture). Locked ships had cut corners into the reef.
- Tune 2: locked ships are now immune to collision, making the rule "fill the ring before impact" learnable.
- Bot fix: the expert bot dithered between ships on opposite sides; it now commits to a target unless finishing it would doom another ship.
