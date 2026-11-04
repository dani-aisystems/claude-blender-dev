# Roadmap: THE LAST LIGHT (living stage tracker)

## ⚠ Parallel sessions and file ownership (Daniel, 2026-11-04)
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
| **Stage** | 1, cabin lighting, materials and architecture |
| **Iteration** | 3, devices (starting 2026-11-04). Iteration 2 is approved and committed (`5f22e63`) |
| **Next actionable task** | Iteration 3, devices in priority order:<br>• P0: stair door and housing (reads as a black slab), generator auxiliary set (day-tank, extractor, exhaust, AUX plate, capped MAIN ENGINES pipe), power chain, console, radio. Each must pass the 8-item checklist.<br>• P1: optic drive (motor, gearbox, standby clockwork, governor, revolution counter, the 046 worn tooth), desk, stair |

## Stages
| # | Stage | Status |
|---|---|---|
| 0 | Critical fixes and regression baseline | ✅ **approved by Daniel 2026-11-04** (iteration 0.2) |
| 1 | Cabin lighting, materials and architecture | 🟡 in progress (iterations 1.0, 1a, 1b, 2, 3, 4) |
| 2 | First-person interactions and gameplay | ⬜ |
| 3 | Dialogue, characters and story pacing | ⬜ |
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
