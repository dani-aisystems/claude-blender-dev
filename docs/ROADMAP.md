# Roadmap: THE LAST LIGHT (living stage tracker)

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
| **Iteration** | 1b, material richness (started 2026-11-04). 1.0 and 1a are done and reviewed |
| **Next actionable task** | After Daniel's 1a feedback: iteration 1b, material richness (palette, bevels, smooth shading, metric UVs, wear mask, `room_pbr`, 2k sets, rain-glass rewrite) |

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
