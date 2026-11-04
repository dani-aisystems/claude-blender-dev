# Roadmap: THE LAST LIGHT

Priorities are ordered by player impact and the risk of building on unverified ground. Each item lists its acceptance check.

## P0: verify what exists
1. **Human playtest of Chapter 1** at the desk, windowed and fullscreen. Fix anything that blocks progress.
   - Accept when: chapter 1 completes by hand; dialogue is readable; radio choices unlock at the desk; the generator tutorial works.
2. **Performance measurement** with the window frontmost: `tools/godot --path projects/games/last_light/godot -- --capture=perf --shots=40@fp_desk,60@fp_window --bot=expert`. Read the `PERF` lines.
   - Accept when: 60 fps at 1080p High on the M3, or a Medium preset that reaches it.
3. **Listen to the audio** (`godot/assets/audio/*.wav`). Rebalance or regenerate in `audio/synth.py`.

## P1: the requested visual upgrades (in progress at handoff)
4. **Interior materials** using the 8 new 2k CC0 sets:
   - add them to `blender/sync_assets.py` (`CC0` list), then remap `LLMaterials.GRADES`:

     | Material | Texture set |
     |---|---|
     | Wood | `oak_veneer_01` |
     | WoodDark | `dark_wooden_planks` |
     | SteelPaint | `green_metal_rust` |
     | SteelRust | `rusty_metal_02` |
     | Iron | `metal_plate_02` |
     | Concrete | `plastered_wall_02` |
     | Floor | `concrete_floor_worn_001` |

   - add a second, macro-scale sample against tiling;
   - add a dust term on up-facing surfaces;
   - add an interior `ReflectionProbe` (interior mode, sized to the room);
   - optionally use VoxelGI on High only.
   - Accept when: captures `fp_desk`, `fp_power` and `fp_console` show real grain and rust and no sky reflections indoors; fps holds.
5. **Character portraits** (approved method: Blender 3D busts):
   - write `blender/portraits.py` to:
     - append `GEO-head_animation_realistic` plus its iris and sclera (male), or crop `GEO-body_female_realistic` / `GEO-body_male_realistic` at the neck;
     - shape six characters (Callum, Morag, Rory, Hector, Elspeth, Ross);
     - add particle hair, stubble and beards, collars and hats;
     - make three expressions (neutral, tense, sorrow) by regional deformation of brows and mouth corners;
     - render with Cycles at 512×640 with a 1970s photo grade;
     - output to `godot/assets/portraits/<id>_<expr>.png`;
   - extend the `.dlg` speaker syntax to `MORAG(tense): …`;
   - show portraits in `dialogue_ui.gd`: in the radio card, and in-person for Ross after he's revealed. Keep the Visitor silhouetted until his name is known.
   - Accept when: the contact sheet is reviewed; each character is consistent across their expressions; the dialogue capture looks clean.
6. Re-export the `.app` and rerun the smoke test.

## P2: content and polish toward the 2-hour target
7. Optional content that adds meaning, not padding:
   - more documents (the Board's 1954 reply to Ross; Morag's notebook page; a maintenance ledger);
   - optional radio conversations (Morag check-ins, Rory banter);
   - examinable objects tied to clues.

   Then playtest and time a full run.
8. Model in Blender the island terrain, reef rocks, three ship hulls plus the launch, and a proper jetty and path (replacing the Godot stand-ins). Add a sound for the visitor's boat docking.
9. Lighting pass: reduce the black ceiling-beam triangles (add ceiling fill and lighten the beam material), tune the floor wetness, make the lamps flicker and react to power events.
10. Accessibility and options QA: click every option and confirm it changes something; test controller support.

## P3: housekeeping
11. Decide whether to delete the v1 top-down code (`scripts/main.gd`, `game_world.gd`, `ui/hud.gd`, `core/sim_world.gd`, `beam_model.gd`, `ship_model.gd`, `keeper_bot.gd`, `wave_schedule.gd`, `scenes/main.tscn`, `tests/run_tests.gd`, `tests/sim.gd`) and the debug harness `tests/debug_station.gd`. **Ask Daniel first.**
12. Put the Godot-side PNG textures and docs under Git LFS (`projects/games/**/*.png`), and remove the redundant `human-base-meshes-bundle-v1.4.1.zip` (**ask first**).
13. A CI job for the headless suites.
