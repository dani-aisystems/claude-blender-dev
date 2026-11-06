# Roadmap: THE LAST LIGHT (living stage tracker)

## ⚠ Parallel sessions and file ownership (Daniel, 2026-11-04)
**Update (2026-11-05, Stage 2 plan): split by file with the "Stage 1 iteration 5" desk-detail session.**
- **Iteration 5 owns:** Blender (`build.py`, `documents.py`, `textures.py`, `spec.py`, `review_views.py`, `tex/`), the GLB and `godot/assets/docs`, the `station.gd` material and lighting sections (`_swap_materials` and above), and its own `capture_fp.gd` views (`cu_desk_l/r`, `cu_chart`, `cu_chair`).
- **Stage 2 owns:** `player.gd`, `fp_ui.gd`, `game_fp.gd`, `input_setup.gd`, `dialogue_ui.gd`, `style.gd`, `settings.gd`, `chapters.json`, the `station.gd` interaction API section (`DEVICES` and `describe()` / `use()` and below), its own capture views, and the Stage 2 tests.
- Neither session stages the other's files.

**Update (1b checkpoint): Daniel handed `build.py` (all geometry) to the staged-polish session.** The geometry session's open items (optic drive, generator, stair door, storage, windows) are folded into Stage 1 iterations 2–3. Its Iteration A was **committed with Daniel's OK** in `5f22e63` (iteration 2 checkpoint).

Two sessions worked on the cabin in parallel. **Daniel decided to split the work by layer.**

**Geometry: the "cabin repair" session (`CABIN_REPAIR.md`, Iterations A–D) owns:**
- `blender/build.py`, `documents.py`, `textures.py`, `photo_render.py`, `pipeline.sh`;
- the generated GLB and textures;
- the geometry repairs: optic drive, generator, stair door, storage, windows.

**Godot materials and lighting: the "staged polish" session (Stage 1 in `docs/ROADMAP.md`) owns:**
- `godot/scripts/fp/materials.gd`;
- `godot/shaders/room_pbr.gdshader` (new) and `rain_glass.gdshader`;
- `blender/sync_assets.py`, `settings.gd`, `outside.gd`;
- the lighting, probe and window-light functions in `station.gd`.

**Shared files (keep edits narrow):**
- `station.gd`: the material and texture list in `_swap_materials` belongs to geometry.
- `capture_fp.gd`: each session adds its own views.

**Names the lighting code depends on (keep them):** `GLS_window*`, `NDL_bearing`, `NDL_battery`, `NDL_temp`, `PT_brk_lights`, `LMP_cage`, `LIGHT_*`, `SM_CeilBeams`, `SM_WallLamps*`. New runtime interior meshes must use render layer 2 (`station.gd` `LAYER_INTERIOR`).

**After a geometry change, run both** `tests/test_last_light_hooks.py` and `godot/tests/interaction_test.gd`.

**Commits:** `4aff7b0` holds only Stage 1 steps 1.0 and 1a. The cabin-repair Iteration A is **still uncommitted** in the working tree, awaiting Daniel's review.

The staged-polish session won't edit `build.py` (needed for bevels, smooth shading and metric UVs in 1b) until the geometry session's iterations land.


Development runs as a **staged polish programme**. Each stage follows the same loop:

1. inspect;
2. propose;
3. agree with Daniel (AskUserQuestion);
4. implement;
5. validate;
6. **get Daniel's explicit approval**.

A stage is complete only when Daniel says so. A build that compiles, or Claude's own judgement, does not count. The full approved plan for this session is at `~/.claude/plans/pasted-content-id-5a42-the-staged-crown.md` (revision 2).

## Current position
| | |
|---|---|
| **Stage** | 3, dialogue, characters and story pacing |
| **Iteration** | **3A approved by Daniel 2026-11-06** (local commit). 3B is waiting on his read of the master script |
| **Next actionable task** | Wait for Daniel's notes on, or approval of, `projects/games/last_light/STAGE3_NARRATIVE_MASTER.md`. Then 3B: transcribe the script into `.dlg` / `chapters.json` / `docs.json`; ch1 at 11 beats; the ch2/ch6 jam (sim S1–S5); transitions; ending cards; optional content; the tests in §18.4. **Approved plan (revision 2, with Daniel's 2026-11-05 decisions):** `~/.claude/plans/the-last-light-stage3-plan-r2.md`. No `.dlg` / `chapters.json` rewrite until Daniel approves the master script |

## Stages
| # | Stage | Status |
|---|---|---|
| 0 | Critical fixes and regression baseline | ✅ **approved by Daniel 2026-11-04** (iteration 0.2) |
| 1 | Cabin lighting, materials and architecture | ✅ **approved by Daniel 2026-11-05** (iterations 1.0, 1a, 1b, 2, 3, 3b, 4, 1p) |
| 2 | First-person interactions and gameplay | ✅ **approved by Daniel 2026-11-05** (iterations 2A–2D) |
| 3 | Dialogue, characters and story pacing | 🟡 plan revision 2 approved 2026-11-05; 3A in progress |
| 4 | Outside world and major story events | ⬜ |
| 5 | Sound and cinematic presentation | ⬜ |
| 6 | Menus, effects and final polish | ⬜ |

## Approved decisions (Daniel, 2026-11-04)
| Topic | Decision |
|---|---|
| Order | The stage order above. Gameplay blockers come first; story needs decide which exterior assets get built |
| Cabin condition | **Maintained but aged.** A 1971 Northern Lighthouse Board station: polished brass, gloss paint and varnished oak, showing 20+ years of wear (chips at hand height, worn traffic paths, rubbed brass, patched repairs) |
| Lighting | **Cinematic but readable.** Warm low-key pools, shadows deep but not black, cold window spill, lightning through the glass, gauges always readable |
| Palette | **Period green and cream.** Grey-green machinery, cream gloss walls over a dark-green dado, varnished oak, brass, dark-green window frames |
| Scope | **Full room remodel.** Keep the REFERENCE_SPEC layout and bearings, and every gameplay hook |
| Floor | Dark polished concrete, bevelled brass compass rose, rug, traffic wear |
| Optic drive | An electric rotation motor and reduction gearbox, with the weight-driven clockwork kept as standby (fly-ball governor, revolution counter). No lens parts in the room. The console handwheel is the manual fallback |
| Generator | Stays in the watch room as a small **auxiliary standby set** (exhaust through the wall, extractor fan, fuel day-tank). The main engine room is downstairs and out of action |
| Platform | **macOS only for now.** Performance is measured on Daniel's M3 |
| Retina rendering | **1080p-equivalent 3D by default** on HiDPI displays: upscaled, with the UI kept pixel-sharp, plus a "Render resolution" option to go native. Implement in Stage 1a with the presets |
| Branding (2026-11-05) | Daniel's brand sheet (`branding/source/brand_sheet.png`) is the game's identity. `branding/make_branding.py` cuts it into:<br>• the app and window icon (`icon.png`, `icon.icns`, using the flat art at 16 and 32 px);<br>• the main-menu logotype;<br>• the boot-splash key art.<br>Supplied by Daniel directly: this is his explicit choice, overriding the general "no AI-generated images" rule for this asset if it is AI-made |
| Git | Generated 2k texture copies in `godot/assets/textures` are gitignored, **only after** regeneration is shown to be reproducible and documented |

## Working rules for every stage
- **Checkpoint format** (exactly four parts):
  1. a matched before/after contact sheet (same shots, forced states and preset);
  2. a short change summary;
  3. test results, each marked PASS / PARTIAL / FAIL / NOT TESTED: the suites, the interaction checklist, and median and 95th-percentile frame time against the last baseline;
  4. 2–4 decisions for Daniel.
- **Interaction checklist** for the primary workstations (radio, generator, power panel, light console, door):
  - checks 1–3, 5, 6 and 8 are automated in `godot/tests/interaction_test.gd`;
  - check 4 (believable animation) and check 7 (readable instruments) are judged from captures;
  - check 6: whether the audio *sounds* right is Daniel's call.
- **Performance:** frame-time budget of 16.7 ms for both median and 95th percentile on High, in the worst-case bench. Investigate any checkpoint regression above +10 % median or +15 % 95th percentile. Triangle, mesh and material counts are guardrails only (`tests/test_last_light_hooks.py`).
- **Asset priority tiers** (Stage 1 onward):

  | Tier | Assets | Treatment |
  |---|---|---|
  | P0 | Radio, generator controls, power panel, console, door | Highest detail plus the full checklist |
  | P1 | Windows, desk, optic drive, stair, main lamps | High quality |
  | P2 | Storage, conduits, furniture | Modular |
  | P3 | Bolts, clutter | Cheap: decals and texture detail |

  Every new object states what it adds: gameplay, realism, story or composition.
- Local milestone commits only after approval. **Never push.**
- **Machine load (Daniel, 2026-11-04):**
  - logic tests run headless at background priority: `taskpolicy -b tools/godot --headless …`;
  - **ask Daniel before opening any Godot window**;
  - batch captures into one run per checkpoint, at Auto resolution;
  - **previews are silent** (Daniel, 2026-11-05): `tools/godot_bg` uses the Dummy audio driver, and capture runs mute the master bus unless `--audio` is passed;
  - **windowed runs go through `tools/godot_bg`** (Daniel, 2026-11-05: don't pull him out of his current window). It launches in the background, hands focus back after Godot's ~0.3 s startup activation, and capture runs never capture the mouse;
  - no benchmarks unless Daniel says the Mac is free.

## Stage 0: critical fixes and regression baseline (2026-11-04)
**Done:**
- **Checkpoint commit** `51cc8b9` (local), and the duplicate licence line removed.
- **Blockers fixed:**
  1. **Mouse look restored after a dialogue reply.** game_fp now has a single `mouse_should_capture()` / `refresh_mouse()`, also used by pause, document close and focus changes. As a result, unpausing with replies on screen no longer re-captures the mouse.
  2. **Replies no longer overlap the radio command panel.** They sit lower-left, stacked above the speech panel. While replies are open, the number keys belong to them and no longer also send a radio order.
  3. **Pause:** input under the pause menu no longer advances dialogue, picks replies, runs the typewriter, or sends radio orders. That last one was found during the work.
  4. **Found by the new interaction test:** START, all three breakers, and the console mode/intensity knobs **could not be targeted by the crosshair**. They sit inside their cabinet's bigger info/focus volume, and the furniture collider occluded them. `player.pick()` now prefers the specific control and ignores the focused device's own volume. Furniture colliders no longer hide controls mounted on them; walls, floor, ceiling and stair still block.
- **Tooling:**
  - `capture_fp.gd` gained:
    - views `fp_ceiling`, `cu_lamp`, `cu_optic`, `cu_console`, `cu_power`, `cu_window`, `cu_door`;
    - states `!dark`, `!flash`, `!gen_off`, `!dawn`;
    - flags `--quality=`, `--nohud`, `--bench`;
    - a plan view that clips at the ceiling and no longer hides the battery rack.
  - The same views are in `blender/review_views.py`.
  - New `tests/test_last_light_hooks.py` (pytest, with the frozen v006 hook fixture), `godot/tests/regress_test.gd` and `godot/tests/interaction_test.gd`.
- **Baselines:**
  - captures `renders/last_light/s0_*` (sheets `s0_sheet_a.png`, `s0_sheet_b.png`);
  - bench JSON `renders/last_light/s0_q{0,1,2}_bench.json`;
  - results in `docs/PROJECT_STATE.md` §4.

**Daniel's feedback log:**
- 2026-11-04: reviewed plan revision 1 and asked for six changes:
  - blockers first;
  - iteration 1 split;
  - prototype VoxelGI, light culling and the probe before relying on them;
  - asset tiers;
  - the interaction checkpoint;
  - frame-time budgets;
  - a period-accuracy review;
  - story-ready placements;
  - the four-part checkpoint format;
  - reproducible ignored assets.

  All are folded into revision 2.
- 2026-11-04: Stage 0 checkpoint (iteration 0.1) presented. Daniel chose **"Another iteration"** and picked 1080p-equivalent Retina rendering. For iteration 0.2 he selected all four areas (UI nits, Retina fix, a sweep of play issues across controls / dialogue / visual-performance / menus-saves-audio, and more coverage). He gave no specific bug, so it was read as **"do a thorough QA sweep yourself"**.

**Iteration 0.2 (2026-11-04):**
- **Retina:** `Settings.render_scale()` and `apply_render_scale()` render 3D at 1080p-equivalent, upscaled with FSR 1.0. A new Options entry, "Render resolution", offers Auto or Native. It's re-applied on window resize, and `--scale3d` overrides it.
- **UI nits:** the chapter card moved to about 37 % of screen height, clear of the prompt. Buttons got 16 px horizontal padding.
- **Dialogue at large text sizes (found by the sweep):**
  - at the Options maximum (1.5×), 23 radio lines grew **off the bottom of the screen**;
  - long ch4 replies stretched to 908 px.

  Now the speech panel and subtitles grow upwards, replies follow the top of the speech block (`_layout_choices`), and reply text wraps within its 700 px column.
- **Options:** text size and text speed now apply live (`game_fp._on_settings_changed`). The radio panel's italic text size is scaled too.
- **Coverage:**
  - `interaction_test.gd` gained a walkability flood-fill from spawn and the desk workstation (chart, radar, logbook, drawer, forecast, photo, note, archive), with open and close checked for each document;
  - new `godot/tests/qa_sweep_test.gd` (dialogue fit for all 546 line renders and 142 replies at two text sizes, plus options live-apply);
  - new `audio/analyze.py`;
  - a true before/after image of the reply layout: `renders/last_light/s0_reply_before_after.png`.

**Logged for later stages (not blockers):**
- Documents open with **no sound**. `paper_slide.wav` exists → Stage 5.
- UIStyle uses the hover style for keyboard focus too, which causes the double highlight in the main menu → Stage 6.
- `horn_fishing.wav` is mastered hot (RMS −9.3 dBFS, though it plays at −14 dB). `click_button.wav` has a tiny DC offset → Stage 5.
- At 1.0× the tallest radio line exactly fills its 222 px slot; at 1.5× the panel grows to 349 px → Stage 3 (consider a shorter line length).
- 2026-11-04: **Daniel approved Stage 0** (iteration 0.2) and kept **High as the default preset** until Stage 1a reworks shadows and GI.

## Stage 1 log
- **1.0 (2026-11-04):** period-accuracy and story-readiness review added to `REFERENCE_SPEC.md`. It covers the finish, the power chain, the generator as an auxiliary set, the optic as motor plus clockwork, story anchors (the 046 worn tooth, the Grant's bottle behind the Tide Tables, the door gap for the slid photograph), the P0–P3 tiers and the props table.
- **1a (2026-11-04):**
  - Exterior lights (lantern glow, lightning, moon, beam) no longer light the room (`EXTERIOR_ONLY` cull mask, interior on render layer 2).
  - Three cold window lights carry the night spill, the dawn, and lightning weighted by the strike direction.
  - Wall-lamp light moved inside the glass; cage and glass shadows off; soft shadows (`light_size`).
  - Instrument lights on the console, charger, generator and breaker panel; a real light for the generator cage bulb.
  - ReflectionProbe (box-projected, interior, warm ambient that follows the room lights). A/B tested: mode B (re-capture on lighting state changes) is the default.
  - SSAO and SSIL from Medium, half size; ≤ 8 shadowed interior lights on High.
  - The I-beams are now one manifold profile (no z-fight) in their own `SM_CeilBeams` bucket.
  - Textures import VRAM-compressed with mipmaps (`sync_assets.import_params`).
  - Build: `last_light_v007.blend`, GLB v005.
  - Evidence: `renders/last_light/s1a_vs_s0_desk.png`, `s1a_vs_s0_b.png`, `s1a2_sheet.png`, `s1a_probe_ab.png`, `s1a_ext.png`.
  - Performance at High (Auto resolution) regressed from about 19 to about 29 ms at the desk in noisy runs. SSAO and SSIL were moved to half size; the remaining cause is unresolved because the machine was throttling.
  - **Daniel's 1a decisions (2026-11-04):** continue to 1b; the light level is about right; faint indoor haze only (a negative-density `FogVolume` removes 75 % of the storm fog inside, with ambient raised to keep the approved level: desk mean 0.144 vs 0.134); all step 1.0 proposals approved.
- **1b (2026-11-04), code done, not yet reviewed or committed:**
  - **New `godot/shaders/room_pbr.gdshader`:**
    - colour comes from the palette, the scan adds normalised detail only (grain colour for wood), with ARM maps;
    - an interim cream-over-green dado with skirting and an oak rail line, on wall faces by height;
    - hand-height paint chips and clearcoat;
    - still world-triplanar.
  - **`materials.gd`:**
    - `PALETTE` (the agreed hexes) and interior-only `ROOM` looks via `get_room_mat()`, so the lighthouse exterior keeps its old looks;
    - brass is part-diffuse (metallic 0.75, roughness 0.45);
    - a `--noroom` bisect flag.
  - **`sync_assets.py`:** per-set resolution; the 6 interior sets come in at 2k (diffuse, GL normal, ARM). The copies are verified byte-identical to their sources, licences are logged, and they're gitignored (Daniel's condition met).
  - **Rain glass rewritten:**
    - lit, premultiplied alpha, transparent where clear (so the beam and rain show through);
    - drops refract the background;
    - condensation band at the sill, cleared by drop trails;
    - `render_priority` 1.
  - **Seen so far:** one frame (`renders/last_light/s1b_t060_fp_desk.png`, before the brass and plate tweaks). It reads as a period station: cream and green dado, grey-green machinery, varnished oak, polished floor. Still to fix there: black brass at the top of the optic column, and tile-like plate seams on the console (both tuned since, but not yet seen).
  - **Performance note:** the runs at about 1–5 fps with GPU fence timeouts were **machine load, not 1b**. An A/B with `--noroom` was just as slow, with the same primitive count.
  - **Queued capture** (needs Daniel's OK):

    ```
    tools/godot --path projects/games/last_light/godot -- --capture=s1b --nohud --bot=expert --shots=60@fp_desk,60@fp_console,60@fp_power,60@fp_gen,60@fp_window,60@cu_console,60@cu_power,60@cu_optic,60@cu_window,60@fp_ceiling,60@fp_desk!dark,60@fp_desk!flash
    ```
- **1b verification (2026-11-04)**, with Daniel's OK for each window:
  - **Captures:** `s1b`, `s1b2`, `s1b3`, `s1b4` (0 GPU fence errors; about 40 fps at Auto resolution once the Mac was free). Sheets: `s1b_checkpoint_a.png`, `s1b_checkpoint_b.png`, `s1b4_walls.png`.
  - **Fixes found by looking:**
    - the "boards" on the wall were the 96 flat facets *plus* `plastered_wall_02` being plasterboard with vertical joints. Fixed with radial normals on the round wall, and the walls now use `concrete_floor_worn_001` at low strength as painted render;
    - fill-light specular hot spots: instrument lights `light_specular` 0, window lights 0.25;
    - calmer varnish and enamel, rougher brass.
  - **Brightness, a decision for Daniel:** desk mean 0.199 vs 0.144 approved in 1a; shadows (10th percentile) 0.046 vs 0.020. The rise comes from the correct palette albedo (cream walls, real floor and oak), not from extra light: ambient 0.8 → 0.45 and wall lamps 1.35 → 0.85 were already cut.
  - **Daniel's 1b decisions (2026-11-04):** 1b approved; keep the brighter palette-driven look (desk mean about 0.20); `build.py` handed over (see the ownership note at the top).
  - **Deferred to after the geometry session lands:** bevels, smooth shading, metric UVs and the vertex wear mask, because they need `build.py`. The VoxelGI spike stays optional.
- **Iteration 2 (2026-11-04), architecture, now in `build.py` (the session owns it since the 1b checkpoint):**
  - **Mesh quality:** smooth shading split at 35° (`mesh_obj`); every box thicker than 12 mm chamfered (`box(bevel=)`); colliders and the floor slab unbevelled. Without that, the floor showed a 25 cm tile grid.
  - **Walls and windows:**
    - dark skirting and an oak dado rail at the paint line;
    - a stepped crown cornice;
    - raised oak panelling under the windows (rails plus 5 stiles per bay);
    - a brass casement handle and stay per window.
  - **Ceiling and power:** grey-green riveted beams and a riveted boss plate; power-chain conduits (`build_conduits`: generator → charger → batteries → distribution → ring mains).
  - **Lamps and door:**
    - well-glass bulkhead lamps (globe plus brass guard; bulb emission 1.5, since 4.0 bloomed into a blob and a ghost disc in the glass);
    - stair door with a 20 mm light gap and lever dogs.
  - **Story anchors:** `ANCHOR_door_photo`, `ANCHOR_door_audio`, `ANCHOR_calendar`, `ANCHOR_diagram`, `ANCHOR_telephone`, `ANCHOR_tide_tables`, `ANCHOR_logbook_shelf`, `ANCHOR_oilskins`, `ANCHOR_gear_046`.
  - **Build:** v011 `.blend`, GLB v009, 75.1k tris (was about 52k), 0 validation FAIL.
  - **Tests:** hooks, budgets, interaction (134) and story all pass.
  - **Evidence:** `renders/last_light/s12_vs_s1b_a.png`, `s12_rest.png`, `s12b_lamps.png`.
  - **Not yet done:** splayed window reveals. The stair door and housing still read as a near-black slab; that's P0 iteration-3 work.
- **Iteration 3 (2026-11-04), devices, plus Daniel's layout changes:**
  - **Stair door (P0):**
    - panelled leaf with raised flange and mid rail, hinge knuckles, a brass handwheel (`made()` + `tag()`: a second material inside a part), lever dogs, a 20 mm light gap;
    - its own well-glass lamp over the door (`LIGHT_wall_4`), since the wall lamps sat behind the housing face;
    - grey-green housing with dark-green trim.
  - **Daniel's layout changes:**
    - the door moved **180° → 170°** (it was 4 cm from the generator cage and 3 cm from the archive). Storage moved to 128°, the extinguisher to 106°, the wall lamp to 148°;
    - **shallow bulkhead** (`STAIR_DEPTH` 0.62 m; it stuck out 1.2 m) with a **steep ship's stair** dropping along the wall (it was a spiral);
    - **oak archive cabinet removed.** The 1953 logs are now in an oak log box on the storage shelf (`IA_archive` name kept; the prompt, the ch2 line, the objective and the hint updated).
  - **Generator (P0):**
    - open guard cage (was a dense wire grid);
    - spoked flywheel and drip tray;
    - wall-mounted fuel day-tank with sight glass, fed by the fuel line;
    - extractor grille;
    - an **"AUX. SET No.2"** brass plate (the label slot that said "ENGINE HOUSE");
    - a capped, red-flanged pipe for the main engines, with a tag.
  - **Optic drive (P1):**
    - grey-green cast pedestal and top (the black-brass issue);
    - an octagonal glazed cabinet with flat panes;
    - motor with cooling fins, gearbox and lit indicator;
    - brass crown wheel with the **red-marked worn tooth (046)**;
    - standby clockwork wheels and winding crank, the weight tube through the floor;
    - a **fly-ball governor** (`PT_optic_governor`, spun by station.gd while the motor runs);
    - a revolution counter.
  - **Fixes found by looking:**
    - the stair light now casts shadows on Medium and High (its red glow leaked through the housing and tinted the room pink);
    - the door coaming hid the gap (removed);
    - the floor-hatch cells stuck out into the room (hatch now cut inside the bulkhead only);
    - the door gap was too bright (stair light 0.6 → 0.3);
    - the bulbs are kept out of the reflection probe (`LAMP_LAYER`; it smeared globes into discs);
    - glass specular 0.9 → 0.5 and condensation blur 0.45 → 0.2.
  - **Audio:** stair footsteps now follow the door's bearing, not a hard-coded "+0.6 m south".
  - **Build:** v015 `.blend`, 78.8k tris, 0 validation FAIL; interaction 134/134, all suites pass.
  - **Evidence:** `renders/last_light/s13_checkpoint_a.png`, `s13_checkpoint_b.png`, `s13d_check.png`.
  - **Daniel (2026-11-04):** iteration 3 approved; next, finish the device detail pass (3b), then iteration 4.
  - **Not yet done in iteration 3:** a detail pass on the console, radio and power chain. They already have the other session's gauges and selectors (Iteration A).
- **Iteration 3b (2026-11-04), device detail pass:**
  - **Radio:** ventilation louvres on the case top. **Radar:** a solid rubber viewing hood (`lathe`; an open tube is single-sided and vanished from inside).
  - **Power chain:** louvres along the charger base; cable glands where the conduits enter the cabinets; a black ebonite switch panel behind the breakers (kept clear of the labels, so no z-fighting); the battery cells in steel crates with vent caps and lead inter-cell connectors on both tiers.
  - **Console:** no extra geometry beyond Iteration A's gauges and selectors (deliberately: it already reads well in `cu_console`).
- **Iteration 4 (2026-11-04), story-ready props at the anchors.** Tags: S = story, R = realism, C = composition.
  - **Calendar (S/R):** NLB, November 1971, the 14th ringed, on the pier between the west and centre windows.
  - **Wiring diagram (R/S):** framed under glass between the distribution board and the charger; 12 cells, a fixed layout.
  - **Aneroid barometer (R/S):** reads 975 mb, "falling tonight", on the pier between the centre and east windows.
  - **Tide Tables (S):** Admiralty Tide Tables on the top storage shelf, with the half bottle of Grant's hidden behind them (a story anchor).
  - **Spares (R):** the old vapour-burner kit from before electrification, with a spare mantle, and a box of spare lamp bulbs.
  - **Oilskins (C):** oilskin coat and sou'wester on a hook **left** of the stair door (stair − 19°), echoing the Visitor's look. At + 17° they hid behind the generator cage.
  - **Kettle and mug (C):** a kettle on an electric ring and a mug on the west window sill: the keeper's long night.
  - **Touch-ups (R):** hand-height paint touch-ups in a slightly different cream.
  - **Texture budget:** the calendar, diagram and barometer dial are packed into one 2048² atlas, `T_LL_Props.png` (`documents.py`), so the room stays at **32 materials**. New flat materials: `M_LL_ClothBlue`, `M_LL_Whisky`, `M_LL_Oilskin`.
  - **Build:** v019 `.blend`, GLB v017, **82.6k tris, 187 meshes, 32 materials**, 0 validation FAIL. pytest 18/18, interaction 134/134, story, regress, qa_sweep, sim_v2 and run_tests all pass.
  - **Evidence:** `renders/last_light/s14_*` (props), then the stage-end matched capture `s1f_*` against `s0_*`.
  - **Found in the stage-end capture `s1f`:** the oilskins read as a tan bottle with a top hat floating above it. Rebuilt with:
    - a shaped coat (collar, sloped shoulders, flared hem) and two sleeves;
    - the sou'wester on its own hook (stair − 27.5°, 1.68 m) as a wide brim with a domed crown;
    - the Visitor's waxed-olive colour (#52451F, roughness 0.3).

    The first rebuild (v020) still read as a bottle with side panels, so the sleeves now hang in front of the body and there's a dark storm-flap seam with four toggles. Build **v021, 83.3k tris**, 0 validation FAIL. Geometry checked in `renders/last_light/blender_v021/cu_door.png`; **not yet seen in a Godot capture**.
  - **Stage-end performance (`s1f_q2_bench.json`, window focused, Mac free):**
    - High at Auto resolution: fp_desk 27.4 / 28.1 ms, fp_window 28.3 / 29.0 ms, fp_gen 28.7 / 29.9 ms (median / 95th percentile);
    - Medium (the run stopped after 2 shots, exit 0): fp_desk 24.8 / 26.3 ms, fp_window 25.6 / 26.8 ms;
    - Low not measured.

    **Over the 16.7 ms budget, and a regression against Stage 0.2** (High fp_desk was 18.9 / 20.7 ms). Primitives went 1.18M → 2.33M, draw calls 545 → 1080, VRAM 854 → 1251 MB. The 95th percentile sits only about 1 ms above the median, so this is a steady GPU cost, not hitches. The cause isn't isolated yet. Candidates: shadow passes (up to 8 shadowed lights on High), the 9-sample triplanar `room_pbr`, SSAO and SSIL, the reflection probe, and the 2k textures.
  - **Found by looking at `s1f`, logged for Stage 3:** narration lines (`~`) inside radio conversations (15 lines across ch1, 2, 3, 5 and 6) appear in the radio panel with a **blank identity card, no name and a live signal meter**, so the keeper's thoughts look like an empty transmission. Fix: show speakerless radio lines as italic thought subtitles.
  - **Daniel's decisions at the Stage 1 report (2026-11-05):**
    - **another iteration: performance**, plus a 2-shot check of the oilskins in the game;
    - **fix the thought lines now**: done in `dialogue_ui.gd`. The display look (`line_look`) is now separate from the conversation mode, so reply gating is unchanged. New regress R4 adds 6 checks, including a data check that no radio reply follows narration directly;
    - **delete the stale textures**: done.
- **Iteration 1p (2026-11-05), performance. In progress.**
  - **Tooling:**
    - bench flags `--novsync`, `--msaa=N`, `--probe=off`;
    - `--bench_toggle` freezes one node at a time, with per-second series, primitives, draw calls and per-script ms;
    - process time and render-thread CPU time added to the bench report;
    - `tools/godot_bg` for windowed runs that don't take focus.
  - **Findings, High, fp_desk:**
    - GPU-bound: process time (which includes the wait for the GPU) ≈ frame time; render-thread CPU about 1.9 ms; game scripts below 0.3 ms per frame;
    - 4× MSAA is on for **every preset** (`project.godot` `msaa_3d=2`): off 23.3 ms, 2× 26.2 ms, 4× 27.5 ms;
    - everything off: 14.7 ms.
  - **Shadow cache fixed:** every shadow map was re-rendered every frame (constant 2.34M primitives). Three causes:
    - the rain `GPUParticles3D` cast shadows with an AABB around the room;
    - `_set_angle` rewrote settled part transforms every frame;
    - the continuously moving optic parts and needles cast shadows.

    Now 1.57M primitives and 910 draw calls, **but no frame-time gain**, so the limit is per-pixel work.
  - **Daniel's decisions (2026-11-05):**
    - **60 fps on Medium**, which is now the default; High is the quality preset with a 25 ms budget;
    - **FXAA on Low and Medium, 2× MSAA on High.**

    Implemented in `settings.gd` (`q_msaa`, `q_screen_aa`, `settings_rev` 2 moves old High-default files to Medium once), with checks in qa_sweep (948/948). The Options hint text was updated.
  - **Clean bench `s1p_q{0,1,2}_bench.json`** (quiet Mac, no vsync, worst case), median / 95th percentile in ms:

    | Preset | fp_desk | fp_window | fp_gen | Budget |
    |---|---|---|---|---|
    | Medium | 17.4 / 19.0 | 18.0 / 19.5 | 16.6 / 18.9 | 16.7: about 1 ms over |
    | High | 26.0 / 30.6 | 27.0 / 30.7 | 28.4 / 31.6 | 25: 1–3 ms over |
    | Low | 12.3 / 19.2 | 12.8 / 22.1 | 14.4 / 21.3 | none |

    Medium was 24.8 ms at the desk in `s1f` (−30 %).
  - **Trials not usable:** Medium without SSIL, and High with 6 shadowed lights (`s1p_q1_nossil`, `s1p_q2_6sh`). They ran while the Mac was busy: slower than the baseline, 95th percentile 41–54 ms.
  - **Oilskins in the game:** `s1p_t060_cu_door.png`, `s1p_t060_fp_stair.png`. They read as a hanging coat with toggles and a sou'wester (PASS).
  - **Daniel (2026-11-05): Stage 1 approved.** The remaining gap (Medium about 1 ms over 16.7 ms, High 1–3 ms over 25 ms) is **tracked for Stage 6** final optimisation. Untested trims: softer shadow filtering, SSIL off on Medium, 6 shadowed lamps on High, plus the exterior costs (ocean, rain, fog).
  - **Ruled out:** the radar SubViewport. A 7 ms reading appeared only when the window was occluded; with the window visible the frame was unchanged at 28.0 ms.
  - **Stale files (deleted 2026-11-05 with Daniel's OK):** `blender/tex/T_LL_Calendar.png`, `T_LL_Diagram.png` and `T_LL_Barometer.png`. They were superseded by the atlas and nothing references them.
- **Iteration 5 (2026-11-05), cabin micro-detail. Plan approved** (`~/.claude/plans/pasted-content-id-17d5-stage-virtual-thompson.md`; the 16-row audit is there).
  - **Daniel's decisions:**
    - tea in a white enamel mug;
    - the pipe set: yes;
    - checkpoints mid (after the desk) and final;
    - `godot_bg` captures pre-approved; no bench without his OK.
  - **Runs in parallel with Stage 2;** the file split is in the top note.
  - **Groups A+B (the desk)** ended in the mid checkpoint. **Daniel (2026-11-05): continue to C–E**, a "worn satin" desk varnish, and ask about the bench at the end.
  - **Groups C–E are done** (details below). **Daniel (2026-11-05): iteration 5 approved and committed locally**; the floor's satin pass is deferred ("leave it for now").
  - **Method (the room is at its 32-material cap):**
    - small props are one material (`M_LL_Props`) coloured from flat swatches in the `T_LL_Props` atlas (`spec.py` `props_atlas`, painted by `documents.py`);
    - **new `T_LL_Props_rough.png`** carries per-texel roughness (glTF metallicRoughness; `station.gd` sets the multiplier to 1.0);
    - new `build.py` helpers: `solid`, `lathe_uv`, `sweep`, `coil`, `bezier`, `pencil`, `fountain_pen`, `pen_cap`, `build_chart_sheet`, `build_desk_detail`.
  - **Built:**
    - enamel mug (Falcon-type, 80 × 84 mm, blue rolled rim, chips, cold tea, older tide lines) beside its newest ring;
    - tea rings printed on the chart and the ledger margin;
    - the chart as folded paper (3° skew, two lifted corners, edge band) with keeper pencil work (clearing bearings, yesterday's 2100 fix, a rubbed-out line; nothing about tonight);
    - Captain Field's parallel rule, brass dividers, a pencil stub;
    - brass shell-case pot with hex pencils, chinagraph, ballpoint and steel rule;
    - ledger with cloth boards, leather corners and printed page edges, an uncapped fountain pen and its cap, folded reading glasses;
    - desk mic (cast base, chrome yoke) with a coiled cord to the radio socket;
    - radio bezel and screws, the coastguard card tucked in the bezel, radar louvres;
    - cables to a junction box; lamp switch and flex;
    - titled book spines (the radar case is the bookend; the almanac leans);
    - 7x50 binoculars with strap;
    - torn, curling teleprinter forecast (readable text); foolscap stores note half under the radio;
    - pipe in a brass ashtray; "Skerry Flake" tin (made-up brand).
  - **Interaction change:** `PT_handset` is now the mic's press-to-talk bar. Its press is 4 mm (it was the whole mic, sinking 3 cm into the desk). Agreed with the Stage 2 session; the hunk is owned by this iteration.
  - **Fixes found by looking:**
    - the reading glasses showed dashed rims, because the page height was 0.8 mm low (the top sheet is `zt`): fixed;
    - the parallel rule read as two loose slabs: closed the blades, added the scale strips, kept it 10 cm clear of the compass;
    - the stalled capture was the Stage 2 session's `fp_ui.gd` parse error (since fixed).
  - **Build:** v024 `.blend`, GLB v022. Room 98.1k tris (+14.8k), 182 mesh nodes (was 187), 32 materials, validation 0 FAIL, reimport OK.
  - **Tests (headless):**

    | Suite | Result |
    |---|---|
    | pytest | 18/18 |
    | interaction | 134/134, 6 known warnings (`PT_handset` moved: PASS) |
    | story | 0 failures |
    | regress | 60/60 |
    | run_tests | 95/95 |
    | sim_v2 | no gate failures |
    | qa_sweep | 948/948 |
  - **Captures:** `s15a_*` (before, v021) and `s15m_*` (after); sheets `renders/last_light/s15m_vs_s15a_{a,b}.png`.
    - Draw calls went down in 8 of 9 shots (e.g. fp_desk 552 → 524).
    - Primitives went up about 0.1M (+10–12 %).
    - cu_radio draw calls rose 434 → 570, unexplained so far.
    - No bench (Mac not confirmed free).
  - **C: furniture.**
    - **Varnish (`materials.gd` `M_LL_Wood`):** rough 0.35–0.55 → 0.5–0.72; coat 0.35 → 0.1 at roughness 0.5; normal 0.5. The white grazing streaks are gone. This affects every `M_LL_Wood` surface.
    - **Desk:** rounded oak top; drawer fronts with 6 mm reveals (they had 3 cm gaps); brass bar pulls on posts; locks on the top drawers; black kick strips.
    - **`build_chair`:** turned, splayed legs; H-stretchers; rounded seat; tapered spindles; bowed top rail; turned 8° (the collider is unchanged); the keeper's navy gansey over the back.
    - **Fix found by looking:** the gansey first read as a black cloth with an X (navy too dark, crossed sleeves). Lightened to #384260 and the sleeves hang straight.
    - `box(segs=)` added for rounded edges.
  - **D: personal items.**
    - A rubber torch on the storage rack's top shelf by the stair door.
    - A shortbread tin with its lid ajar on the west sill beside the kettle. The plan said "desk corner"; the desk had no room left, and the sill reads as part of the keeper's tea corner.
  - **E: architectural detail.**
    - Glazing beads round every pane and two hinges per casement.
    - Saddle clips on every vertical conduit drop, reaching the wall (`drop()`).
    - Mirror-plate screws on the wiring diagram; a hanging ring and screw on the barometer.
    - **Not done:** the sill condensation stain (it needs a decal or alpha, which the material cap and the no-alpha rule exclude).
  - **Final build:** v026 `.blend`, GLB v024. Room 104,060 tris (+20.7k against 83.3k), 183 mesh nodes, 32 materials, validation 0 FAIL, reimport OK.
  - **Final tests (headless):**

    | Suite | Result |
    |---|---|
    | pytest | 18/18 |
    | interaction | 134/134, 6 known warnings |
    | story | 0 failures |
    | regress | 66/66 (includes Stage 2's new checks) |
    | run_tests | 95/95 |
    | sim_v2 | no gate failures |
    | qa_sweep | 948/948 |
  - **Final captures:** `s15f_*`. Sheets:
    - `s15f_vs_s15a_{a,b}.png`, matched against the v021 baseline;
    - `s15f_vs_s1_c.png`, the window, stair, power and shelf views against `s1f`, `s1p` and `s14`.
  - **Render counts against `s15a`:**
    - draw calls down in every matched shot (fp_desk 552 → 534; cu_chair 634 → 495);
    - primitives +0.18–0.26M (+17–21 %);
    - the cu_radio 570 at the mid checkpoint was transient (final: 426).
  - **Bench (Daniel: Mac free), `s15f_q{1,2}_bench.json` against `s1p`:** median / p95 in ms; same flags (`godot_bg`, novsync, 30 s, worst case).

    | Preset | fp_desk | fp_window | fp_gen |
    |---|---|---|---|
    | Medium | 18.0 / 21.0 (+3 % / +11 %) | 18.6 / 21.6 (+4 % / +11 %) | 16.6 / 19.0 (0 % / +1 %) |
    | High | 29.0 / 33.6 (**+11 %** / +10 %) | 28.0 / 34.7 (+4 % / +13 %) | 26.7 / 33.6 (−6 % / +7 %) |

    - Medium is inside the investigate thresholds (+10 % median, +15 % p95).
    - High fp_desk is 1 % over the median threshold. Run noise is about ±5 % (the unchanged fp_gen view moved −6 %).
    - The likely cost is the desk lamp's shadow pass over the new small props. Suggested trim for Stage 6: a no-shadow bucket for P3 props (cables, pencils, screws, pens).
    - The first Medium run overlapped a Stage 2 capture and was re-run clean.

## Cabin pass (2026-11-05, before Stage 3; Daniel's brief with 8 photos)
- **Plan and diagnostic matrix:** `~/.claude/plans/the-last-light-cabin-pass.md`. Photos: `projects/games/last_light/cabin-photos/IMG_3134..3141.HEIC`, shot off the monitor; the reflections are not defects.
- **Daniel's decisions:**
  - run this pass first, with 4 checkpoints;
  - **replies keep mouse look in free walk** (1-4, or the wheel and E); radio replies only at the handset;
  - **the torch:** E picks it up in a blackout, F switches it (pad: A and LT; the d-pad belongs to replies);
  - Stage 3 owns the Blender files;
  - new writing (the coat-pocket note, the chart transcription) needs his script review.
- **Checkpoint 1 (reliability). Done, awaiting the checkpoint:**
  - **The cursor (IMG_3140):**
    - root cause: `dialogue_ui` and `story_presenter` set `Input.mouse_mode` themselves (second and third owners), and replies stayed up away from the radio while freeing the pointer;
    - fix: one owner (`player.capture_mouse`, called only by `game_fp.refresh_mouse`); replies are answered by keys with a focus highlight and a one-time hint (`Settings` tip "replies"); radio replies hide away from the handset.
  - **Viewer (documents and the chart):**
    - zoom (wheel, LB/RB) and pan (drag, WASD, sticks);
    - closes only on E, Esc, B or right click, with a 3-frame open guard;
    - handled in `_input`, because its shade swallowed mouse buttons before `_unhandled_input`;
    - dialogue ignores input while a document is open;
    - the radio panel's number keys are blocked while reading.
  - **The chart (IMG_3139):**
    - `chart` is now a `doc` (full-screen inspection using `watch_room_T_LL_Chart.png`; `BUILTIN_DOCS` in `story_presenter.gd`);
    - the mic is off the paper (between the radio and the radar), with its coiled cord re-routed;
    - the mug moved off the chart (its printed rings stay);
    - the parallel rule, dividers and pencil moved to the margins.
  - **The torch (IMG_3136):**
    - rebuilt lying on its side on the top storage shelf (`PROP_torch*` meshes, `IA_torch`);
    - a `pickup` kind is available only when the room lights are out;
    - `player.give_torch()` adds a warm SpotLight (shadows, 11 m, 22°) on the camera;
    - saved in the save file;
    - capture state `!torch`.
  - **Build:** v027 `.blend`, GLB v025, room 106k tris, 0 validation FAIL.
  - **regress 101/101 headless:**
    - new R8 (17 checks, including 4 rounds of radio, chart, pause and console);
    - R1 and R5 updated to the new reply and chart rules (Daniel's decisions).

- **Daniel (2026-11-05): checkpoint 1 approved; committed `91faeb1`.** The pocket-note and chart-transcription texts were approved as drafted.
- **Checkpoint 2 (major visual fixes). Done, awaiting the checkpoint:**
  - **Extinguisher (IMG_3134):** `build_extinguisher`, a period 2-gallon water (soda-acid) unit with:
    - a lathed body with rolled shoulders and a foot ring;
    - a brass head, carrying handle, squeeze lever, safety pin and pull ring;
    - a pressure gauge, and a hose to a horn in a clip;
    - a strap band, wall plate and screws;
    - a wrapped label (props atlas `ext_label`) and chips.

    The old sphere top was the "glowing eyes".
  - **Shelf lamp (IMG_3135):** `build_storm_lantern`, a hurricane lantern **standing on** the 1.1125 m shelf, 0.28 m tall and 5 cm under the top board. It used to float 10 cm above its shelf with its cap through the board above. The storage boards also got angle-iron lips and bolt heads.
  - **Coat and hat (IMG_3137):** `build_coat_rack`, a freestanding oak stand at 149° (tripod legs, finial, 4 brass hooks) carrying:
    - the oilskin, hung by its collar from a side hook (`drape()`: steep shoulders, folds deepening toward the hem, an uneven hem, bent sleeves with cuffs, pocket flaps, toggles);
    - the sou'wester, hung by its brim on another hook;
    - the stores note in the right pocket (`IA_coat_note` → document `coat_note`, Callum's hand).
  - **Tin and the floating square (IMG_3138):**
    - the shortbread tin has a tartan band (`tin_band`), rolled rim and shortbread, with its lid lying beside it;
    - the floating square was a paint touch-up at −30°, inside the west window bay. It moved to the pier at −19°, and `build_props` now asserts that no patch is in a bay.
  - **Optic drive (IMG_3141):**
    - the revolution counter sat at the crown wheel's height, inside it; it moved to the gearbox face, 8 cm below;
    - the governor's spindle went through the upper wheel and its balls swept the shaft; it now hangs from the top plate, 0.17 m off-axis;
    - the motor (9 cm) and gearbox (4 cm) floated above the pedestal; they now sit on it;
    - the drive shaft extended into the top plate;
    - **Blender BVH clearance check** (scratch script, drive at 24 angles × governor at 12): the governor is clear everywhere, and the drive touches only its seats (gearbox, top plate).
  - **Viewer:** the document viewer moved to its own CanvasLayer 30 (HUD chatter drew over it).
  - **Build:** v031 `.blend`, GLB v029, room about 114k tris, 0 validation FAIL.
  - **Suites:** regress 101/101, interaction 134/134 (7 known warnings), qa_sweep 948/948, story 0 failures, sim_v2 no gate failures, run_tests 95/95, pytest 18/18.
  - **Evidence:** `renders/last_light/cp2_vs_photos.png` (Daniel's photos vs after), `cp2_sheet_{a,b}.png`, `cp2b_sheet.png`, `cp2c_t066_cu_coat.png`.

- **Daniel (2026-11-05): checkpoint 2 approved; committed `9e0eeef`.** The reference photos stay untracked; tone the floor down.
- **Checkpoint 3 (full cabin audit). Approved by Daniel (2026-11-05); the in-between saves stay untracked:**
  - **Contact scan (Blender, scratch `float_scan.py`):**
    - method: one BVH of every room mesh; every connected island (1,616) must come within 8 mm of a different island or object;
    - 63 islands were flagged before the fixes and 45 after;
    - the 45 left are explained false positives: sparse-vertex faces (stool seat, drawer pulls, plate on the cage bars, flange), parts embedded in others (exhaust rings, wheel hubs, lineshaft, kettle spout), bulbs inside globes, glass inside beads, conduits on spacer saddles.
  - **Real defects fixed:**
    - generator: base on the drip tray (−2.4 cm), radiator against the block, fins on its face, flywheel hub on the block, maker plate and FUEL VALVE label onto the cage bars (on a tag plate), control box back on the bars, the capped-pipe flange seated with its tag tied on, a lampholder and cross rail for the cage bulb;
    - radio: carrying handles on the case edges with posts (they hung 2 cm beyond the sides);
    - lampholders for the desk-lamp and stair-lamp bulbs;
    - wall-lamp backplates seated, including the −48° lamp on the bay's recessed lintel (moving it to −54° put it on the frame, so that was reverted);
    - the red box handle on posts;
    - extinguisher: hook reaching the plate, chips on the drum;
    - the tin lid print within the lid;
    - the coat seam, toggles, pockets and note following the folded surface (`surf()`).
  - **Small props:** storage spares boxes (lid lip, handle, hasp, stencil plate); the red cantilever toolbox (seam, latches); a real rope coil (sweep, 3 layers); a turned-down coat collar.
  - **Floor (Daniel):** rough 0.25–0.6 → 0.4–0.72, clearcoat 0.45 @ 0.25 → 0.16 @ 0.45. Still dark polished concrete, now a soft sheen.
  - **Regression caught in review:** deepening the generator control box (0.14 → 0.15 m) without moving its centre pushed its face 5 mm past the gauges and the GENERATOR plate (striped z-fight, plate hidden; `cp3_t068_cu_gen.png`). The centre moved to front − 0.075 so the face stays in the gauge plane; re-checked in `cp3c_t068_cu_gen.png`.
  - **Build:** v035 `.blend`, GLB v033. Evidence: `renders/last_light/cp3_sheet_{a,b}.png`, `cp3b_t070_cu_lamp.png`, `cp3c_t068_cu_gen.png`.


- **Daniel (2026-11-05): checkpoint 3 approved; committed `11b92d2`.** The in-between `.blend` saves v028–v030 and v032–v034 stay untracked (not deleted).
- **Checkpoint 4 (final QA and handoff). Approved by Daniel (2026-11-05) and committed:**
  - **Suites on the final build (v035, GLB v033), headless:** regress 101/101, interaction 134/134 (7 known warnings: documents, now including the chart, open with no sound → Stage 5), qa_sweep 948/948, story 0 failures, sim_v2 no gate failures, run_tests 95/95, pytest 18/18.
  - **Windowed regress: 105/105, no skips (twice, after a test-harness fix):**
    - first run (Daniel at the Mac) and a re-run with the Mac idle both failed the same 12 R6/R7 checks, all passing headless, so live input was ruled out;
    - a state dump at the start of R6/R7 plus a 30-frame wait made every check pass, which pointed at timing;
    - **root cause (test, not game):** `leave_focus()` starts a time-based 0.45 s ease, and during it the camera, and so the crosshair ray, is blended toward the old device pose. The test waited a fixed 40 frames, which windowed on the 120 Hz display can end inside the ease, so R7 began with the camera 1.97 m off the eye (`hovered=radio`). R6 had the same problem entering the radio view;
    - **fix:** `_settle_focus()` in `regress_test.gd` waits for the ease to finish (plus one physics tick) after all 17 focus enters and leaves. Headless stays 101/101.
  - **Matched captures (one batched run, 26 frames, `renders/last_light/cp4_sheet_{a,b}.png`):** room overviews, every photo issue (extinguisher, lantern, coat and note, sill and tin, chart pose and viewer, the radio view, the optic, the generator, the wall lamp, the desk) and the torch in a blackout (`pp_torch-dark`, the beam on the chart and the generator).
  - **Capture-tool fix:** close-up (`cu_*`) shots drew the prompt of wherever the last `pp_` pose left the player, because the player kept raycasting from its own body. Capture-camera views now mute the player (`_player_muted` in `capture_fp.gd`) and restore it afterwards. Checked in `cp4b_sheet.png`. The game itself was never affected: there the prompt and the view are the same camera.
  - **Performance:** not benchmarked (Mac not confirmed free). The capture's PERF lines are unfocused-window numbers and not valid as a bench. Room is about 114k tris after the pass; a clean Medium/High bench belongs to Stage 6 or whenever Daniel says the Mac is free.
- **Cabin pass summary (for the next session):**

  | # | Issue (photo) | Root cause | Fix | Main files |
  |---|---|---|---|---|
  | 1 | Extinguisher read as "glowing eyes" (IMG_3134) | sphere-topped placeholder | period soda-acid unit, `build_extinguisher` | `build.py`, `documents.py` (`ext_label`) |
  | 2 | Shelf lamp through the shelf (IMG_3135) | lamp floated 10 cm high, cap through the board above | storm lantern standing on the board | `build.py` |
  | 3 | Torch upright, no use (IMG_3136) | decorative prop | lying on its side; E picks it up in a blackout, F/LT toggles a shadowed spot | `build.py`, `player.gd`, `station.gd`, `game_fp.gd`, `input_setup.gd` |
  | 4 | No coat rack (IMG_3137) | missing | oak stand, oilskin, sou'wester, readable pocket note | `build.py`, `documents.py` |
  | 5 | Red object, floating square (IMG_3138) | touch-up patch inside the window bay | patch moved to the pier and asserted; tartan tin | `build.py`, `spec.py` |
  | 6 | Chart covered, not readable (IMG_3139) | props on the paper; chart was a focus view | props to the margins; full-screen zoom/pan inspection | `build.py`, `story_presenter.gd`, `station.gd` |
  | 7 | Cursor stuck or free (IMG_3140) | three writers of `Input.mouse_mode`; replies freed the pointer away from the radio | one owner (`refresh_mouse`); key/wheel replies; viewer in `_input` | `game_fp.gd`, `dialogue_ui.gd`, `story_presenter.gd`, `player.gd` |
  | 8 | Optic parts intersecting (IMG_3141) | governor, counter, motor and shaft misplaced | re-seated; BVH clearance check | `build.py` |

  - **Known limitations left:** the coat collar reads a little like a domed cap; the START tag under the generator knob is partly hidden by the knob rim; an older conduit-clip shadow streak near the −48° lamp; 45 explained false-positive contact flags; documents have no open/close sound (Stage 5); the torch has no battery (by design, the brief allowed none).
  - **Manual playtest for Daniel (feel is NOT TESTED by a human):**
    1. walk to the radio, answer two replies with 1–4 and with the wheel + E; mouse-look should never stop in free walk;
    2. walk away mid-conversation: the replies hide, and come back at the handset;
    3. open the chart (E on the desk): wheel zoom at the pointer, drag to pan, T transcription, right click / E / Esc close; the HUD and subtitles must not draw over it;
    4. switch the room lights off at the power panel: "Pick up the torch" on the top storage shelf; F on and off; the beam should feel like a hand torch, not a floodlight;
    5. read the note in the coat pocket; check the coat and hat from the door side;
    6. pause and resume (Esc) inside the radio view, the console and the chart, 4 times each: the pointer must always come back captured in free walk;
    7. save in a blackout with the torch on, load: the torch is carried and on, and the shelf copy is gone.

## Stage 3 log

### Plan (2026-11-05)
- **Approved plan:** revision 2 at `~/.claude/plans/the-last-light-stage3-plan-r2.md`.
- **Daniel's decisions:**
  - targeted-fill lore scope;
  - script written alongside 3A;
  - about 90 min, measured in Stage 6;
  - portraits on the radio plus Ross in person after the reveal.

### Iteration 3A: dialogue and typography foundation (2026-11-05/06, awaiting the checkpoint)
| Issue | Root cause | Change | Files |
|---|---|---|---|
| Thoughts never italic | The italics font was mapped to the upright serif. The game used system fonts | Bundled OFL Libre Baskerville, Source Sans 3, Courier Prime and Cedarville (licences logged), with a real italic face | `ui/style.gd`, `assets/fonts/*`, `assets/ASSET_LICENSES.md` |
| Text size reached only the dialogue | Fixed `font_size` overrides everywhere | Every UIStyle label, button and rich text is registered and scaled (titles at half rate). The identity line moved from a 9–10 px drawing to a 15 px label | `ui/style.gd`, `settings.gd`, `dialogue_ui.gd`, `fp_ui.gd`, `main_fp.gd`, `story_presenter.gd` |
| The objective and hint could overlap | The hint sat at a fixed y | Both share one VBox. Objectives resolve `{tokens}` (no more hard-coded WASD) | `story_presenter.gd`, `chapters.json` (ch1 objective text only) |
| Ross named early; in-room lines shown as transmissions; named lines in thought scenes looked like Callum's | Fixed per-speaker cards; the look came only from the conversation mode | `Speakers` resolver (hidden until `knows_name`) and look rules (`where`, `@room` / `@radio`). History stores the label as shown, with chapter and conversation; old saves are sanitised | `story/speakers.gd`, `dialogue_runner.gd`, `dialogue_db.gd`, `story_state.gd`, `audio_director.gd` |
| No sound captions | — | `>` lines become a caption in capitals (script brackets stripped) | `dialogue_db.gd`, `dialogue_ui.gd` |
| The typewriter re-wrapped every character and typed under fades and documents | `.text` was rebuilt per character | The line is laid out once and revealed with `visible_characters` (after shaping). It holds while a document is open or the fade is above 0 | `dialogue_ui.gd`, `story_presenter.gd` |
| No backlog | `history` was never read | Dialogue history: pause menu, H, pad View. It pauses; closing restores the pause menu or play, the mouse (through `refresh_mouse`) and the reply focus | `ui/backlog_ui.gd`, `game_fp.gd`, `fp_ui.gd`, `input_setup.gd` |
| The radio command panel ran off screen at 1.5 (found in the s3a captures) | Fixed offsets, default grow direction | It grows to the left, and the legend and status wrap. New qa check | `fp_ui.gd`, `qa_sweep_test.gd` |
| Credits | The fonts were Apple system fonts | Credits list the OFL fonts | `data/credits.txt` |

- **Tests:**
  - regress R9 (42 checks);
  - qa_sweep at 0.8, 1.0 and 1.5, with identity lines and the command panel;
  - capture states `say_*`, `text15`, `doc_*`, `pause`, `backlog`.
- **Evidence:**
  - `renders/last_light/s3a_sheet_{1..4}.png` and `s3a_pair_*.png`;
  - the "before" shots came from a scratch worktree of `302f7ca`.
  - The 3D materials differ between the two builds, and the UI is the comparison. Verified cause: the 2k interior textures in `godot/assets/textures` are gitignored copies made by `sync_assets.py`, so the worktree had only 36 of the 72 files.
- **Master script:** `projects/games/last_light/STAGE3_NARRATIVE_MASTER.md` (draft, gate for 3B).
- **Daniel (2026-11-06): checkpoint 3A approved, committed locally.**
  - He is reading the master script and will reply. **No `.dlg` / `chapters.json` / `docs.json` rewrite until he approves.**
  - The script's four open questions: all recommendations accepted.
  - The command-panel and identity-row fixes are re-captured at the 3B checkpoint.

## Stage 2 log
- **Plan (2026-11-05), approved.** The full audit is at `~/.claude/plans/the-last-light-soft-hearth.md`.
  - **P0:**
    - a pad can't look (right stick unbound) or use device views, replies or the radio panel (all mouse- or keyboard-only);
    - the vessel buttons rebuild every 30 frames and can drop clicks (LIKELY).
  - **P1:**
    - dead `[Click] Study chart` prompt in the radio view;
    - Space or pad A re-sends the last radio order (focused button, LIKELY);
    - the door prompt never changes after ch4;
    - silent failures (START while running, charging with the generator off, info items);
    - pausing while holding START keeps cranking (LIKELY);
    - a one-state crosshair;
    - inconsistent prompt wording.
  - **P2:**
    - 60 Hz physics with no interpolation on a 120 Hz display (judder, LIKELY);
    - mouse sensitivity scales with window size (LIKELY);
    - Tab and wheel undiscoverable;
    - no head-bob option;
    - `hint_device` is a no-op.
  - **Not an issue:** the A/`boost` overlap (`boost` is v1-only), walk numbers, focus enter and exit, save/load reset, the Stage 0 fixes.
- **Daniel's decisions (2026-11-05):**
  - split files with iteration 5 (see the top note);
  - branding committed separately (`0f18df3`);
  - the 6 leftover `watch_room_T_LL_{Barometer,Calendar,Diagram}.png(.import)` files deleted;
  - **full playable gamepad**;
  - crosshair **quiet dot → ring**: dim dot; ring plus prompt when valid; dashed grey ring plus the reason when unavailable; no out-of-range cue; a ring cursor in device views;
  - **retire `hint_device`**;
  - feel: physics interpolation, `screen_relative` look and a head-bob option, with movement numbers unchanged until his playtest;
  - captures approved: 1 "before" run (worktree of `39fc0e7`) plus 1 per checkpoint plus 1 at the stage end, via `tools/godot_bg`. No benchmarks.
- **Iteration 2A (2026-11-05), interaction foundations. Approved by Daniel; committed `52bcb6f`.** His decisions: keep refusing START with a shut valve (rather than crank-and-fail); keep live gauge readings under the prompt.
  - **`station.gd` (interaction API only):**
    - wording pass (verb + object; "Switch the MAIN breaker off" replaces "Open MAIN breaker"; info items read "Check the battery" with the live reading as a sub-line);
    - `availability(id)` → {ok, reason};
    - `prompt_info(id, in_view)`;
    - `use()` refuses an unavailable press with its reason. START is refused when running, running down, too hot, the day-tank is empty or the valve is shut;
    - charging ON with the engine stopped adds a note.
  - **`player.gd`:**
    - `prompt_changed(info)` carries state (none / valid / unavailable), key, text, sub and help;
    - `_actionable()` mirrors `_press`, so a key is never shown for a press that does nothing;
    - direct view switching between neighbouring device views (radio ↔ chart; eyes ≤ 1.6 m apart);
    - `release_holds()`;
    - `virtual_cursor` / `cursor_pos()` for device-view picking without the OS pointer (captures now; the pad in 2C).
  - **`fp_ui.gd`:**
    - quiet dot → ring crosshair (warm ring when valid; dashed grey when unavailable; a bloom on each press);
    - in device views, a ring cursor with the prompt beside it, plus a bottom help line;
    - serif sub-line in dimmed parchment; 5 px soft outline on prompt text;
    - `show_notice_once` (no repeat within 3 s).
  - **`game_fp.gd`:**
    - refusal and note notices;
    - pause releases holds;
    - the door prompt follows the story (ch < 4 "Try the stair door"; ch ≥ 4 "bolted", no key; open "stands open");
    - unknown story events warn.
  - **`hint_device` retired:** removed from `chapters.json`. `StoryDirector.ACTIONS` / `PRESENTATION_EVENTS` are now the contract, and `story_test` checks all 131 beat actions against it.
  - **Capture tooling:**
    - `pp_<ia id>` player-pose views;
    - the `!valve_shut` state;
    - `focus_<view>~<ia>` hovers a control with the virtual cursor.
  - **Tests (headless, `taskpolicy -b`):**
    - regress 60/60 (new R5: 16 checks);
    - interaction 134/134 (6 known document-sound warnings);
    - qa_sweep 948/948;
    - story 0 failures;
    - sim_v2 no gate failures;
    - run_tests 95/95;
    - pytest 18/18.
  - **Evidence:**
    - `renders/last_light/s2a_before_*` (scratch worktree of `39fc0e7`) vs `s2a_*`;
    - sheets `s2a_vs_before_prompts.png` (centre crops) and `s2a_vs_before_views.png`;
    - typography fix verified in `s2a2_check_crops.png` (a second, 3-shot window).
  - **Known confound:** the after frames include the parallel iteration 5 desk props.
  - **Lesson:** a GDScript parse error makes a `-s` test script hang idle (it never reaches `quit()`). Run suites under `timeout`.
- **Iteration 2B (2026-11-05), radio panel and control discovery. Done; checkpoint presented, awaiting Daniel.**
  - **Confirmed first:** regress R6 failed 3/3 on the 2A code, so A3 (dropped vessel clicks) and B2 (Space re-sends the last order) are CONFIRMED, not just LIKELY.
  - **`fp_ui.gd`:**
    - `_refresh_vessels()` is a keyed update: one button per ship id, text updated in place, nodes added or removed only when the fleet changes;
    - radio-panel buttons use `FOCUS_NONE` (`_panel_button`). Stage 2C gives them focus only while a pad drives the panel;
    - an amber "Tab · next vessel" tip beside the Vessel header when two or more vessels are on the channel.
  - **Tips:**
    - `Settings.tip_wanted` / `tip_used`, kept in `settings.cfg` under `"tips"`; each retires after 2 uses (`TIP_RETIRE`);
    - `Settings.persist = false`, and capture or autotest runs never write the file;
    - knob prompts show "[Wheel] turn · [Right click] turn it back" until each control has been used (`player._turn`).
  - **Capture:** `!fleet2` adds a test vessel until two are on the channel (not restored; put it last).
  - **Tests:**
    - regress 66/66 (new R6: 6 checks);
    - interaction 134/134 (6 known warnings);
    - qa_sweep 948/948;
    - story 0 failures;
    - sim_v2 no gate failures;
    - run_tests 95/95;
    - pytest 18/18.
  - **Evidence:** `renders/last_light/s2b_*`; sheet `s2b_vs_s2a.png` (the 2A frames are the "before"; the bot's story timing drifted, so the objective text differs).
- **Iteration 2B approved by Daniel (2026-11-05); committed `1359e44`.** Tips stay per machine. He has no controller right now, so pad feel is NOT TESTED by a human.
- **Daniel (2026-11-05): Stage 2 approved.** Next: plan Stage 3 only (inspect and propose; no implementation).
- **Iteration 2D (2026-11-05), integration and QA. Done; part of the Stage 2 milestone commit.**
  - **Daniel's 2C decisions:** keep camera-only interpolation; hide the OS pointer while the pad drives a view.
  - **Pointer:** `player.capture_mouse()` uses `MOUSE_MODE_HIDDEN` when the pad is active, otherwise unchanged. `dialogue_ui` hides it for pad replies. A mouse movement brings it back (`game_fp._input` → `refresh_mouse`).
  - **R7 additions:** pad A hold-to-crank on START, pad A on the stair door, and the hidden pointer (windowed only).
  - **Tests:**
    - regress **87/87 windowed with no skips** (R1 real mouse capture after a reply, VISIBLE in device views, HIDDEN for the pad) and 84/84 headless;
    - interaction 134/134 (6 known warnings);
    - qa_sweep 948/948;
    - story 0 failures;
    - sim_v2 no gate failures;
    - run_tests 95/95;
    - pytest 18/18.
  - **Stage-end capture:** `s2f_*`, the same shot list as `s2a_before_*` (`39fc0e7`). Sheets: `s2f_vs_before_prompts.png` and `s2f_vs_before_views.png`. The room differs only by the iteration 5 desk props (`81d9818`).
  - **NOT TESTED (Daniel):** walking and look feel on the 120 Hz display; real-pad feel (no controller); the Options rows on screen; audio (still never listened to; Stage 5). No benchmark this stage.
- **Iteration 2C (2026-11-05), gamepad and feel. Approved by Daniel; committed `7a715c2`.**
  - **`input_setup.gd`:** bindings by context:
    - `PAD_FP`: A interact, B back, X transcript, Y logbook, LB/RB turn, L3 sprint, Start pause, left stick move, right stick look;
    - `PAD_V1`: boost moved from A to RT;
    - `PAD_SHARED`: d-pad handwheel;
    - `PAD_UI`: `ui_accept` A, `ui_cancel` B, d-pad (the engine defaults did not let A press a focused reply);
    - `stick()`: radial deadzone 0.15 with a quadratic curve;
    - `glyph()` / `key()` / `resolve()`: keyboard, Xbox or PlayStation names (auto-detected from the pad name);
    - `pad_active`, and `pad_forced` for captures.
  - **`player.gd`:**
    - the camera is top-level, drawn at the body position interpolated between physics ticks (`_pos_prev` / `_pos_cur`, `Engine.get_physics_interpolation_fraction`), with look applied immediately. Placements snap (`_snap_if_placed`);
    - **deviation from the plan:** no global `physics_interpolation`, which would have made every node animated in `_process` (gauges, ships, door, optic, capture cameras) step at 60 Hz;
    - mouse look uses `screen_relative` in points (`MOUSE_SENS` 0.0028 rad/pt, the old fullscreen feel on a 1512-pt display);
    - right-stick look at 2.6 rad/s × "Gamepad look sensitivity" (pitch 70 %);
    - the device-view pad cursor (`virtual_cursor`, 900 px/s) presses room controls by ray and on-screen buttons through `fp_ui.click_at`;
    - B steps back; LB/RB turn knobs, or change vessel in the radio view;
    - the "Head bob" option.
  - **`fp_ui.gd`:**
    - `cycle_vessel()`, `click_at()`;
    - the pad cursor shows a dot in device views;
    - the Tab tip and radio legend follow the device; pad B resumes from pause.
  - **Other UI and data:**
    - `dialogue_ui.gd`: the first reply takes focus on the pad;
    - `story_presenter.gd`: hints resolve `{interact}` / `{move}` / `{look}` / `{turn_back}` / `{wheel}` tokens; X toggles the transcription; B closes documents. The `chapters.json` hints are tokenised, and `story_test` checks they resolve for both devices;
    - `main_fp.gd` Options: "Gamepad look sensitivity", "Head bob while walking", and a three-column controls table (keyboard and mouse / gamepad).
  - **Tests:**
    - regress 82/82 (new R7: 15 checks, driving the real input path with `Input.parse_input_event` pad events);
    - interaction 134/134 (6 known warnings);
    - qa_sweep 948/948;
    - story 0 failures;
    - sim_v2 no gate failures;
    - run_tests 95/95;
    - pytest 18/18.
  - **Evidence:** `renders/last_light/s2c_pad_*` vs the 2A/2B keyboard frames; sheet `s2c_pad_vs_kbm.png`.
  - **Found by looking:**
    - the pad cursor was invisible when not over a control (now a dot);
    - the radio legend kept keyboard text (now follows the device);
    - captures need `pad_forced`, because Daniel's real mouse flipped `s2c_pad2` back to keyboard.
- **Iterations:**
  - **2A interaction foundations:** prompt state and availability, refusal reasons, wording, door, focus switching, pause releasing holds, `hint_device`;
  - **2B radio panel and discovery:** keyed vessel update, button focus, tips for Tab and the wheel;
  - **2C input and feel:** pad, interpolation, sensitivity, head bob;
  - **2D QA and stage report.**

## Stage 1: cabin (planned; starts after Stage 0 approval)
1. **1.0 Review:** infrastructure logic, story anchors and the tier table, written into `REFERENCE_SPEC.md`.
2. **1a Lighting and import correctness** (existing geometry):
   - cull masks to keep exterior lights out, plus a shadow-behaviour test;
   - window spill and lightning through the glass;
   - lamp fixes (light inside the glass, soft shadows, no glass shadows);
   - I-beam z-fight;
   - mipmaps and VRAM import;
   - a ReflectionProbe test matrix (power on and off, generator off, flash, dawn);
   - SSAO + SSIL per preset; wire up the unused `q_shadows()`.
3. **1b Material richness:**
   - palette in `spec.py`;
   - smooth shading and bevels;
   - metric UVs;
   - vertex wear mask;
   - `room_pbr.gdshader`;
   - 2k sets through `sync_assets.py` (reproducibility check before the gitignore);
   - rain-glass rewrite;
   - an optional VoxelGI spike, adopted only on evidence.
4. **2 Architecture:**
   - two-tone walls, dado and cornice;
   - splayed windows with dark-green frames;
   - oak wainscot;
   - ceiling and conduits following the power chain;
   - stair bulkhead with a heavy door;
   - well-glass lamps;
   - floor;
   - story anchors.
5. **3 Devices:**
   - P0 first, each passing the checklist: radio, generator set, power chain, console, door;
   - then the optic drive, desk and stair.
6. **4 Detail:** P2 story props (calendar, diagram, logbook shelf, oilskins, kettle, barometer), then P3 decals and repairs, then a performance pass.

## Later stages (scope only)
**Stage 2: interactions and gameplay**
- hover highlight and crosshair state;
- `hint_device` (currently a no-op);
- teach Tab and the scroll wheel;
- gamepad look (`interact` and `boost` share the A button);
- vessel buttons rebuilt every 30 frames lose hover and focus.

**Stage 3: dialogue, characters and story**
- Portraits: Blender CC0 busts (the approved method; see `docs/SESSION_HANDOFF.md`).
  - Write `blender/portraits.py`: six characters, three expressions each, Cycles at 512×640 with a 1970s grade.
  - Extend `.dlg` with `SPEAKER(expr):`.
  - Show portraits in `dialogue_ui.gd`.
- Bundled OFL fonts, which also fix italics.
- The clipped radio ID-card text.
- Text scaling that covers all of the text.
- A dialogue backlog.
- A document viewer that doesn't close on any click.
- Pacing: ch1 is front-loaded (15 beats); the ch6 jam has no beat explaining it.
- A per-ending card (`main_fp.gd:254` ignores the ending).
- Chapter fades.
- Optional content: more documents, optional radio talk.
- Decide whether there's a telephone.

**Stage 4: outside world and story events**
- Dock, the visitor's boat and its docking sound, the stairwell approach.
- Eased weather (`keeper_sim.gd:264` snaps); dusk hue; horizon skirt colour.
- Blender island, reefs, ship hulls and launch, prioritised by what the story shows.
- Wakes and spray.

**Stage 5: sound and cinematics**
- Daniel's listening session (the audio has never been heard).
- Reverb, outside muffling, radio band-pass.
- Player footsteps (`step_stone_*` unused).
- Music arc.
- Audio in the credits.
- The visitor's entrance.

**Stage 6: menus, effects and polish**
- Pause: Options, Load and Quit; confirm before leaving to the main menu.
- Slider hitch (`settings.gd:63-71`); the double highlight in the main menu.
- Spray, exhaust, sparks, ship fade-outs.
- Final optimisation: ocean LOD, radar at 30 Hz, menu cost.
- Re-export the `.app`.
- A timed full playthrough.

**Housekeeping (ask Daniel first)**
- Delete the v1 top-down code and its tests (`run_tests.gd`, `sim.gd`)? Note: those 95 tests are the only v1 coverage.
- Delete `tests/debug_station.gd`?
- Delete the redundant base-mesh zip?
- Git LFS for game PNGs.
- A CI job for the headless suites.
