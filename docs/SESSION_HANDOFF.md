# Session handoff: 2026-11-04 (session 2, Stage 0)

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


Read this with `docs/ROADMAP.md`, which is now the **living stage tracker** (current stage and iteration, decisions, feedback log, next task), and with `docs/PROJECT_STATE.md`.

## Latest status (2026-11-05, Stage 1 iteration 5: cabin micro-detail)
- **Iteration 5 is approved by Daniel and committed locally.** It covers groups A–E: the desk, furniture, personal items and architectural fasteners.
- **Details:** the ROADMAP Stage 1 log, "Iteration 5". **Evidence:** `renders/last_light/s15f_vs_s15a_{a,b}.png` and `s15f_vs_s1_c.png`.
- **Build:** v026 `.blend`, GLB v024, 104k tris, 32 materials. All suites pass.
- **This session's files were** Blender/`tex`, `materials.gd`, the `station.gd` `_swap_materials` and PT_handset lines, the four desk views in `capture_fp.gd`, and its ROADMAP/REFERENCE_SPEC entries. Stage 2 (a parallel session) stages its own hunks only.
- **Bench done:** Medium +0–4 % median, inside budget rules; High desk +11 % median, at the threshold. See the ROADMAP for the suggested Stage 6 trim.

## Latest status (2026-11-05, Stage 2 approved by Daniel)
- **Next: plan Stage 3 only** (dialogue, characters and story pacing). Inspect, propose and agree with Daniel; **no implementation** before he approves.
- **Commits (local, never pushed):** branding `0f18df3`; 2A `52bcb6f`; 2B `1359e44`; 2C `7a715c2`; 2D plus docs in the Stage 2 milestone commit.
- **Plan:** `~/.claude/plans/the-last-light-soft-hearth.md`. Audit, decisions and per-iteration logs: ROADMAP "Stage 2 log".
- **Tests at the stage end:**
  - regress 87/87 windowed (no skips), 84/84 headless;
  - interaction 134/134;
  - qa_sweep 948/948;
  - story 0 failures;
  - sim_v2 no gate failures;
  - run_tests 95/95;
  - pytest 18/18.
- **NOT TESTED (needs Daniel):** walking and look feel on his 120 Hz display; pad feel (he has no controller right now); the Options screen rows on screen.
- **If Daniel asks for another iteration:** stay in Stage 2; the iteration-5 session's work is committed (`81d9818`), so the tree has only Stage 2 changes.
- **How Stage 2 commits were made:** shared files were staged by reverse-applying the other session's hunks onto a temp copy (`git diff -U1` → keep only their hunks → `patch -R` → `git hash-object -w` → `git update-index --cacheinfo`). **Not** `git apply --unidiff-zero`, which mis-placed hunks.
- **Gotchas:**
  - a parse error makes a headless `-s` test hang idle; always run the suites under `timeout`;
  - `-s` test scripts can't name autoloads at compile time; use `root.get_node("Settings")`.

## Earlier status (2026-11-05, Stage 2 started)
- The plan was approved, branding was committed, the 6 leftover textures were deleted, and the "before" capture was taken from a worktree of `39fc0e7` (`renders/last_light/s2a_before_*`).

## Latest status (2026-11-05, later)
- **Stage 1 approved** and committed locally. Next: plan Stage 2 with Daniel (no implementation before he agrees the plan).
- New working rules:
  - windowed runs go through `tools/godot_bg` (no focus stealing, silent);
  - Medium is the default 60 fps preset;
  - the last few ms of frame time are tracked for Stage 6.

## Status (2026-11-05, earlier)
- **Stage 1** iterations 3b and 4 are done (uncommitted). The stage-end report has been presented, awaiting Daniel's verdict.
  - Matched sheets: `renders/last_light/s1f_vs_s0_{a,b,c}.png`.
  - Bench: High 27–29 ms median, **over the 16.7 ms budget**.
  - Open items: the blank radio card for narration lines; the oilskins not yet seen in Godot; 3 stale textures awaiting the OK to delete. Details are in the ROADMAP Stage 1 log.

## Status (2026-11-04, evening)
- **Stage 1:** iterations 1b and 2 approved and committed (`2559508`, `5f22e63`). **Next is iteration 3** (devices); see ROADMAP.

## Earlier status (2026-11-04, afternoon)
- **Done and reviewed:** Stage 0 (approved, commit `a7ffc25`), Stage 1 steps 1.0 and 1a (Daniel continued to 1b, commit `4aff7b0`).
- **Stage 1b:** the code is done but not committed. The **visual check is on hold until Daniel says the Mac is free.** Next step and the queued capture command are in ROADMAP.md, Stage 1 log.
- **Machine-load policy (Daniel):**
  - logic tests run headless at background priority (`taskpolicy -b … --headless`); all pass for 1b;
  - **ask before opening any Godot window**;
  - batch captures per checkpoint, at Auto resolution;
  - no benchmarks unless the Mac is free.
- **A parallel geometry session owns `build.py`** (see the ownership section above). Its Iteration A is uncommitted in the working tree, awaiting Daniel.

## Update: iteration 0.2 (same day)
Daniel asked for another iteration and selected every area: UI nits, the Retina fix, a play-issue sweep (controls, dialogue, visual and performance, menus, saves and audio), and more coverage. He gave no specific bug, so this was done as a self-run QA sweep. The full list is in ROADMAP.md, under "Iteration 0.2".

**Code changes:**
- `settings.gd`: `render_res` setting, `render_scale()`, `apply_render_scale()`.
- `main_fp.gd`: Render resolution option.
- `dialogue_ui.gd`: grow upwards, `_layout_choices()`, wrapped replies, italic scaling.
- `game_fp.gd`: `_on_settings_changed`.
- `story_presenter.gd`: chapter card moved up.
- `style.gd`: button padding.
- New `tests/qa_sweep_test.gd` and `audio/analyze.py`. `interaction_test.gd` now has the walkability flood-fill and the desk and document checks.

**Results:**

| Suite | Result |
|---|---|
| interaction | 134 checks, 0 failures, 6 warnings (no document sound) |
| qa_sweep (windowed) | 948/948 |
| regress | 40/40 windowed |
| story / sim_v2 / run_tests / pytest | all pass |

**Before/after of the reply layout:** `renders/last_light/s0_reply_before_after.png`, captured from a scratch worktree of `51cc8b9` (worktree removed afterwards).

**Still awaiting Daniel's Stage 0 approval.**

## Where we are
- Daniel started a **staged polish programme**. Each stage goes inspect → propose → agree → implement → validate, then needs **explicit approval** from him.
- He reviewed plan revision 1 and asked for changes. Revision 2 was approved and is saved at `~/.claude/plans/pasted-content-id-5a42-the-staged-crown.md`. The binding parts are copied into ROADMAP.md.
- **Stage 0 is implemented and waiting for Daniel's approval.** Do not start Stage 1 until he approves Stage 0.
- Stage 0's changes are **uncommitted**. Commit them as a local milestone only after approval, and never push.

## Stage 0: what changed
| Area | Change |
|---|---|
| Commit | `51cc8b9`: a local checkpoint of all session-1 work. The textures and base-mesh bundle stay untracked by design. |
| `scripts/ui/dialogue_ui.gd` | Replies moved lower-left above the speech panel. `mouse_restore_fn` and `_restore_mouse()` run before `choice_made`. `has_open_choices()`. Input, typewriter and `_pick` are ignored while paused. `_clear_choices` detaches immediately. |
| `scripts/fp/game_fp.gd` | `mouse_should_capture()` and `refresh_mouse()` are the single place that decides mouse capture. Pause, document close and focus changes all route through them. `ui.number_keys_taken_fn` is wired up. |
| `scripts/fp/fp_ui.gd` | No radio orders while paused. Number keys yield to open replies (`number_keys_taken_fn`). |
| `scripts/fp/player.gd` | New `pick()` and `_occluded()`, with the rules below. |
| `scripts/capture_fp.gd` | New views, forced-state suffixes `!dark`, `!flash`, `!gen_off` and `!dawn`, and flags `--quality=N`, `--nohud` and `--bench`. The plan view clips at the ceiling. The cutaway no longer hides the battery rack or the room's optic gears. |
| `blender/review_views.py` | Mirrors the new views, with `lens_for_vfov()`. |
| Tests | New `tests/test_last_light_hooks.py` with fixture `tests/fixtures/last_light_hooks_v006.json` (80 frozen hooks, 49 colliders). New `godot/tests/regress_test.gd` and `godot/tests/interaction_test.gd`. |
| Docs | ROADMAP rewritten as the stage tracker. PROJECT_STATE updated: decisions, tests, the performance finding. |

The new rules in `player.pick()`:
- a specific control beats its cabinet's info or focus volume;
- the focused device's own volume is ignored;
- only walls, floor, ceiling and stair occlude.

Before this, **START, all three breakers and the console mode/intensity knobs couldn't be targeted by the crosshair**.

## Evidence
| Item | Where |
|---|---|
| Baseline captures | `renders/last_light/s0_*` (19 shots), with sheets `s0_sheet_a.png` (room views) and `s0_sheet_b.png` (close-ups, plan, iso, focus views) |
| Reply layout | `renders/last_light/s0_regress_reply_layout.png` |
| Blender versions of the new views | `renders/last_light/blender_s0views_sheet.png` (rendered before `cu_door` was moved back to 1.75 m from the door) |
| Bench | `renders/last_light/s0_q{0,1,2}_bench.json` and `s0_q2_s50_bench.json`. Summary in PROJECT_STATE §5.1 |

**Tests: all green.** Commands are in PROJECT_STATE §4.

| Suite | Result |
|---|---|
| pytest | 18 pass |
| regress | 40/40 windowed, 38/38 headless |
| interaction | 93/93 |
| story_test | 0 failures |
| sim_v2 | no gate failures |
| run_tests | 95/95 |

## Key findings to carry into Stage 1
1. **Performance is fill-rate bound on Retina.** The window is 3840×2410 physical pixels.

   | Preset | 3D scale | Median frame time |
   |---|---|---|
   | High | 1.0 | 44–51 ms |
   | High | 0.5 (about 1080p-equivalent) | 18.1 ms |

   The default render resolution on HiDPI displays is a decision for Daniel.
2. **Lantern light leaks through the roof** (`fp_desk!dark`). With the room lights off, the walls and floor stay lit.
3. **Lightning lights the room uniformly through the roof**, not through the windows (`!flash`).
4. **Spoke shadows from the wall lamps** (`cu_lamp`). Green machinery reads as dark striped wood (`cu_console`, `cu_power`). The optic column shows white discs (`cu_optic`).
5. **Small UI issues for later stages:**
   - the chapter card overlaps the "Step back" prompt in the first seconds;
   - reply buttons have almost no left padding;
   - the radio ID card text was clipped in older captures (Stage 3).

## Next steps
1. Present the Stage 0 checkpoint and get Daniel's approval. (This handoff was written while waiting for it.)
2. After approval:
   - make the local commit: "THE LAST LIGHT Stage 0: gameplay blockers, interaction picking, QA tooling, baselines";
   - start **Stage 1, step 1.0**: the period-accuracy and story-readiness review, written into REFERENCE_SPEC.md;
   - then **iteration 1a** (lighting and import correctness), measured against the s0 captures and bench.

## Gotchas learned this session
- **Mouse mode in headless Godot:** the headless display server ignores mouse modes. Run `regress_test.gd` **windowed** for the real `Input.mouse_mode` checks; headless skips them and says so.
- **Vessel refresh:** `fp_ui._refresh_vessels()` runs every 30 frames and resets `selected_ship` to −1 when there are no ships. In tests, set the selection just before injecting a key.
- **Loads re-enter the beat:** loading re-enters the saved beat and re-runs its `do` actions (ch1 beat 0 sets mode and intensity to 0). This is by design. Test save/load from a beat that doesn't touch the station.
- **The door swings at 1.2 rad/s**, about 0.02 rad per frame. "Settled" checks need a tighter threshold than "moved" checks.
- **Units:** `sim.bearing` is in **radians**.
- **`COL_` colliders** are named `COL_x-convcolonly` in the GLB on purpose. The hook test requires the hint on `COL_` nodes and forbids hints everywhere else.
- **Metal GPU time:** `viewport_get_measured_render_time_gpu` returns 0 on Metal, so use frame time.
- **Corrupt-save errors:** `story_test.gd` prints two "Parse JSON failed" errors. They're expected, because it tests corrupt saves on purpose.

## Workspace cleanup candidates (NOT deleted; ask Daniel)
These are unchanged from session 1:
- `tests/debug_station.gd`;
- the v1 top-down code;
- the base-mesh zip;
- the stale `.app`;
- the scratchpad Godot export-template download.
