# Session handoff: 2026-11-03 → 2026-11-04 (session 1)

Read this together with `docs/PROJECT_STATE.md`, which describes what exists, and `docs/ROADMAP.md`, which sets out what's next.

## How the brief evolved (all of these are Daniel's requests, in order)
1. Build a small top-down beam-steering game, THE LAST LIGHT. Godot was chosen and installed. → commit `fe0d387`.
2. A visual-realism overhaul (art direction, PBR, ocean, weather). CC0 textures approved.
3. **Pivot to a first-person keeper simulator** in one room: generator and battery, lighthouse controls, radio, ships. → `48becde`, `98c570e`.
4. **Rebuild the room from 4 reference images.** Only 3 arrived; R4 duplicated R3, and Daniel said to proceed without it. → `REFERENCE_SPEC.md`.
5. **Two-hour narrative mystery:** story, dialogue system, cinematic menu, options, save/load, documents, the visitor sequence. Daniel chose story A, voices as text plus radio sound. → uncommitted.
6. **Three fixes:**
   - rain inside the room (✅ fixed, partly verified);
   - character portraits with faces (⬜ approved method: Blender CC0 base-mesh busts);
   - photoreal interior textures (⬜ eight 2k CC0 sets downloaded, not yet wired in).
7. This handoff.

## What changed this session (uncommitted since `98c570e`)
- **Story layer:**
  - `scripts/story/` holds the dialogue DB, runner, StoryState, StoryDirector and presenter;
  - `scripts/ui/dialogue_ui.gd`;
  - `data/story/ch1–ch6.dlg` and `chapters.json`;
  - `data/credits.txt`.
- **Station and gameplay hooks for the story:**
  - `keeper_sim.gd`: story mode, `spawn_story_ship` (fixed routes, unlit or protected ships), `trigger_fault`, `to_dict`/`from_dict`;
  - `fleet_ship.gd`: `unlit`, `docked`, `story_route`, `protected`, serialisation;
  - `keeper_bot2.gd`: confirms positions first; raises the lamp from LOW; fixed target selection.
- **Room (Blender `build.py`):**
  - a hinged closed stair door (`PT_stair_door`, `IA_door`);
  - an archive cabinet (`IA_archive`);
  - `IA_drawer`, `IA_battery`, `IA_photo`, `IA_note`, `IA_forecast`;
  - wall lamps by the door raised to 2.25 m;
  - rebuilt as `last_light_v006.blend`, GLB v004.
- **Game:**
  - `game_fp.gd` rewritten to run the story mode (director, presenter, documents, door, visitor, player tracking, save/restore);
  - `main_fp.gd` rewritten: menu, loading, options, load and credits panels;
  - autoloads `Settings` (`scripts/settings.gd`) and `SaveSystem` (`scripts/save_system.gd`);
  - `audio_director.gd`, `visitor_figure.gd`;
  - a jetty in `outside.gd`;
  - the radar phantom echo;
  - a dusk sky.
- **Audio:** `projects/games/last_light/audio/synth.py` writes 37 WAV files to `godot/assets/audio/` (never listened to).
- **Documents:** `blender/documents.py` writes 8 PNGs plus `docs.json` to `godot/assets/docs/`.
- **Build:** `export_presets.cfg` (macOS universal, ad-hoc), ETC2/ASTC import enabled; `.app` exported to `projects/games/last_light/build/` (before the rain fix).
- **Rain fix (latest edit):** `outside.gd::_rain()` now uses a ring emitter (inner radius 6.5 m) plus a `GPUParticlesCollisionHeightField3D` (76×44×76 m, 512 px) with `COLLISION_HIDE_ON_CONTACT`. In the capture `renders/last_light/rainfix_*.png` (watch mode, t≈280–290 s), no streaks show indoors and rain is visible outside.
- **Downloads (approved):**
  - 8 Poly Haven 2k sets in `assets/textures/`: `oak_veneer_01`, `dark_wooden_planks`, `old_wood_floor`, `green_metal_rust`, `rusty_metal_02`, `metal_plate_02`, `plastered_wall_02`, `concrete_floor_worn_001`;
  - Blender Studio *Human Base Meshes v1.4.1* (CC0) in `assets/models/human_base_meshes/`, extracted to `bundle/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend`;
  - all logged in `assets/ASSET_LICENSES.md`, where `concrete_floor_worn_001` appears twice because of a download race.

## Portrait groundwork (measured in the bundle, Blender world coordinates)
| Object | Bounds / position | Notes |
|---|---|---|
| `GEO-head_animation_realistic` (3242 verts, MULTIRES level 1, no shape keys, no materials) | x 1.326–1.600, y −0.169–0.078, z 0.509–0.880 | Faces **−Y** (nose tip about (1.463, −0.169, 0.729)) |
| Its eyes: `.sclera.L` / `.sclera.R` | centres (1.495, −0.126, 0.767) and (1.430, −0.126, 0.767) | Also has `.iris.L` / `.iris.R` |
| Mouth (estimate) | z ≈ 0.69; corners at x = centre ± 0.025 | |
| `GEO-body_female_realistic` (MULTIRES 3) | eyes at z 1.534, x ≈ −1.307 / −1.34 | Crop above the shoulders for women's busts |
| `GEO-body_male_realistic` | exists; not measured | |

No expressions exist in the bundle, so build them as regional deformations: inner brow up = worry; brow down and in = tension; mouth corners down = sorrow.

## Exact next steps
1. **Commit the session's work.** Ask Daniel, since this handoff request said not to commit without authorisation, even though milestone commits were authorised earlier. Suggested commands:
   ```
   git add projects/games/last_light docs CLAUDE.md assets/ASSET_LICENSES.md
   git commit -m "THE LAST LIGHT: narrative campaign, dialogue, menu/options/saves, audio, rain fix"
   ```
   Do **not** add `assets/textures/*` (709 MB) or the base-mesh bundle without discussing LFS.
2. Wire the new textures into the interior materials (ROADMAP P1 item 4), then capture and review.
3. Build the portraits (ROADMAP P1 item 5).
4. Re-export the `.app` and run the smoke test; ask Daniel to playtest Chapter 1 and measure fps.

## Workspace cleanup candidates (NOT deleted; ask Daniel)
- `projects/games/last_light/godot/tests/debug_station.gd`: debug harness, safe to remove.
- v1 top-down code and tests: obsolete, but tests still pass. See ROADMAP P3.
- `assets/models/human_base_meshes/human-base-meshes-bundle-v1.4.1.zip`: redundant after extraction (50 MB).
- `projects/games/last_light/build/TheLastLight.zip` plus the `.app` (gitignored, 292 MB): stale until re-exported.
- `renders/` and `exports/`: gitignored and reproducible.
- Scratchpad (outside the repo): a 1.2 GB Godot export-template download, `godot_docs/` (useful offline API reference; regenerate with `godot --headless --doctool <dir>`).

## Gotchas learned
- **Godot's glTF import treats name suffixes as hints.** `_wheel` made a VehicleWheel3D, so the handwheel is now `PT_handwheel`. Avoid node names ending in `_col`, `_wheel`, `_rigid`, `_navmesh` and similar.
- **The Blender empty convention:** `IA_*` empties' scale is the half-size of the interaction box. Articulated `PT_`/`NDL_` parts rotate about Blender local Z, which is Godot local Y.
- **Typed GDScript:** `int != bool` errors at runtime. `var x := <untyped expr>` is a parse error, so annotate types explicitly.
- **`--check-only` false errors:** it reports "GameState/Settings/SaveSystem not found" because autoloads aren't loaded in that mode. Ignore those.
- **Capture fps** is unreliable when the window isn't frontmost (see PROJECT_STATE §5).
- **Headless story bot:** dialogue advances in 0.05 s and waits are ×0.02. Captures use 2.6 s per line (`game_fp.gd` sets this when `--capture` is passed).
- **Saves** are taken only between beats (`game_fp.can_save()`), so loading restores the beat start and never replays half a scene.
- **`tools/fetch_cc0.py`** logs the licence even on a re-run that skips existing files, which caused the duplicate line.
