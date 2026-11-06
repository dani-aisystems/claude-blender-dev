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

## Latest status (2026-11-06, Daniel's 38-point brief: Phase A docs done)
- **Daniel sent a large brief.** It has 34 improvements, proposals 35–37, roadmap and log instructions, and a findings-log brief that arrived **truncated at its §4**. The plan was approved: `~/.claude/plans/the-last-light-cosmic-waffle.md`.
- **Daniel's decisions:**
  - documentation first, then work groups G1–G6, each checkpointed;
  - item 32: reuse the chapter-start fuel top-up once when the day tank runs dry, plus radio scenes that wait for power and power-aware hints;
  - item 12: the floor rose stays, and the chart compass is the pickup;
  - audio: SFX synthesised, music from a CC0 shortlist (no download before his pick).
- **Phase A written (docs only, no game changes):**
  - `projects/games/last_light/FINDINGS_LOG.md` (items 1–37);
  - `PROPOSAL_35_RADIO_CAST.md`, `PROPOSAL_36_TUTORIAL.md`, `PROPOSAL_37_JOURNAL.md` (all awaiting approval);
  - the ROADMAP section "Daniel's brief of 2026-11-06" plus the stage table;
  - PROJECT_STATE §5 item 13.
- **G1 implemented** (items 32, 7, 25, 23, 26, 21, 28, 3, 5). All suites green: story 0 failures, regress 188, interaction 159, qa 1,921, sim_v2, run_tests 95, pytest 18. Record: FINDINGS_LOG "G1 implementation record". Build v038 / GLB v036.
- **Uncommitted. Waiting on Daniel for:**
  - the G1 capture run (needs a Godot window);
  - whether to restore the churned doc and atlas PNGs (`pipeline.sh` regenerated `godot/assets/docs/*.png`, `T_LL_Photo`, `T_LL_Props` with new paper grain; the restore was blocked as an overwrite);
  - the commit.
- **Daniel added `projects/games/last_light/character-refs/`:** dossier images for Callum, Morag, Rory, Elspeth, Ross and Iain (Hector's folder is empty). These are the 3C / item 22 references; unread so far.
- **Open decisions:**
  - D8: the dark opening against the "41 %" lines in `ch1_lit` and `log_1971`;
  - the item 1 links;
  - the character profiles (22 and 3C still paused);
  - proposals 35–37;
  - item 31.

## Latest status (2026-11-06, Stage 3C started: portrait feasibility probe, paused for Daniel's reference profiles)
- **Character reference consolidation is in progress** (plan `~/.claude/plans/pasted-content-id-3fd1-the-temporal-seahorse.md`). Everything is in `projects/games/last_light/character-refs/`: start with its `README.md` (precedence, tags), then `CANON_INDEX.md`, `REVIEW_FLAGS.md`, `<id>/PROFILE.md` and `sources/batch-NN.md`, which holds Daniel's text verbatim.
  - Daniel sends material in batches. Final consolidation waits for **"ALL CHARACTER INFORMATION PROVIDED"**.
  - Batch 01 (Callum complete, Morag cut at §10 ch4) is drafted.
  - **Later the same day, at Daniel's instruction**, every conflict was resolved and profiles for all six principals plus Hector were written, using the dossiers as reference. The dossiers decide looks, voice and backstory; shipped game text decides plot facts. The REVIEW_FLAGS §D follow-ups D1–D11 (portraits.py, visitor_figure.gd, note_046, ch6:116, document renders, master and NARRATIVE fixes) are **not applied**.
  - **No game text is edited** and nothing is committed. Don't generate images: CLAUDE.md forbids it, even though the paste asked for it.
  - The visual flags F06, F09, F11, F12 and F13 need Daniel's rulings before 3C resumes. The brief's rule is applied: Ross is shown in silhouette only, never as a full portrait.
- **3C is paused.** Daniel will send reference profiles for the characters. Wait for them before shaping any face, and don't commit any 3C work yet.
- **Files so far (uncommitted, new):**
  - `projects/games/last_light/blender/portraits.py`: headless Blender. It loads the CC0 realistic body, cuts it to a bust, applies per-character face fields and expressions, adds hair, brows, beard, clothing, hats and glasses, and renders in a studio rig. Raw output goes to `blender/tex/src/portraits_raw/<id>_<expr>.png`.
  - `projects/games/last_light/blender/portraits_grade.py`: host-side 1971 print grade into `godot/assets/portraits/`. Not run yet.
  - Run with: `tools/bl -P projects/games/last_light/blender/portraits.py -- --only callum,morag --expr neutral --samples 48 [--debug]`.
- **Fixes already made in the probe:**
  - load the body in body-local coordinates;
  - place the eyes with `matrix_parent_inverse @ matrix_basis`, because appended objects have no evaluated `matrix_world`;
  - use the Khronos PBR Neutral view transform (AgX washed out the colours);
  - fit collars to the measured neck cross-section;
  - brass buttons on the tunic and jackets.
- **Probe state** (Callum and Morag only, scratchpad `probe4.png`):
  - eyes, brows, lip tint, collars and buttons all work;
  - still mannequin-like;
  - hair is a lumpy cap (Morag's reads as a cap);
  - the cloth neckline edge is jagged;
  - the skin is plasticky.
- **3C scope still to do** (stage plan r2, §4 3C):
  - 6 characters × 3 expressions;
  - a print card in the radio panel, 170×190 with a portrait of about 152×190;
  - `expr` carried through `dialogue_ui._resolved`, with the portrait key taken from the resolved speaker id only (Ross after `knows_name`);
  - the documents re-rendered with Courier Prime and Cedarville Cursive;
  - captures, including the 3B leftovers: the Calls box and the caption.

## Earlier status (2026-11-06, Stage 3B approved by Daniel and committed locally)
- **3A** (`dc87818`) and **3B** are approved and committed locally. Never push.
  - The untracked textures, base meshes, `cabin-photos/` and `.blend` v028–v030 and v032–v034 stay as they are.
  - v036 and v037 are this session's new versions (v036 is an intermediate build; v037 matches the GLB in Godot).
- **Master script approved by Daniel 2026-11-06** with fixes F1–F7.
  - `STAGE3_NARRATIVE_MASTER.md` §21 holds the fixes, and §21.1 the implementation notes, including the ch6 *Iona Star* hold-then-release change.
  - Playtime target: about 90 min.
- **What changed, the test results and the evidence:** ROADMAP Stage 3 log, "Iteration 3B". Sheets: `renders/last_light/s3b_pair_sheet_{1..3}.png` and `s3b_new_sheet_{1..3}.png`.
- **Tests (final code, headless):**

  | Suite | Result |
  |---|---|
  | story | 0 failures (all 4 endings plus variants; 13 autosave reloads) |
  | regress | 172/172 |
  | interaction | 159 checks, 0 failures, 12 sound warnings |
  | qa_sweep | 1,918/1,918 |
  | run_tests | 95/95 |
  | sim_v2 | no gate failures |
  | pytest | 18/18 |
- **Gotchas learned:**
  - The shell is zsh: `$G` holding a command is NOT word-split. Run the suites with a bash script (this session used a scratch `run_suites.sh`).
  - `pipeline.sh` reruns `documents.py`/`textures.py`. Their paper grain is unseeded, so every unchanged PNG churns. Restore the unchanged ones from HEAD, or run the build steps without them.
  - Vertex-based free-space probes miss big flat boxes (the radar cabinet has corner vertices only). Check placements with a top-down render.
  - A capture run can lose its game to a real key reaching the menu's focused button. `capture_fp` now swallows real input.
  - `jam_cleared` is cumulative; story beats use `jam_cleared_ch<N>`.
- **Daniel's 3B decisions:**
  - approved;
  - keep the ch6 rescue as built;
  - recapture the Calls box and the caption at 3C;
  - v037 is committed and v036 stays untracked.
- **Next:** plan 3C (portraits: `blender/portraits.py` from the CC0 base meshes, 6 characters × 3 expressions, a print card beside radio lines, Ross only after `knows_name`) and get Daniel's approval before building.

## Earlier status (2026-11-05, Stage 3 started: iteration 3A plus the master script)
- **Plan:** revision 2, approved by Daniel: `~/.claude/plans/the-last-light-stage3-plan-r2.md`. His decisions:
  - "targeted fill" lore scope;
  - the script written alongside 3A and reviewed at the 3A checkpoint;
  - about 90 min, measured later in Stage 6;
  - portraits on the radio, plus Ross in person after the reveal.
- **Master script (DRAFT, awaiting Daniel):** `projects/games/last_light/STAGE3_NARRATIVE_MASTER.md`. **Gate:** no `.dlg`, `chapters.json` or `docs.json` story rewrites until he approves. The only data edit so far is the ch1 objective, now using tokens.
- **3A code done:**
  - **Fonts.** The bundled OFL fonts are in `godot/assets/fonts/*`, pinned to google/fonts `fbe8181`, with each `OFL.txt` alongside and entries in `assets/ASSET_LICENSES.md`.
  - **Style.** `UIStyle` uses FontVariation plus a global text scale (group `ui_text`, driven from `Settings.apply`).
  - **Speakers.** `scripts/story/speakers.gd` is the identity resolver and line-look rules. It works with `DialogueRunner.present()`, and history entries are stored as shown.
  - **Parser.** `dialogue_db` accepts `>` sound captions, `SPEAKER@room|@radio:` and `SPEAKER(expr):`.
  - **Dialogue UI.** `dialogue_ui`:
    - lays the text out once and reveals it with `visible_characters`;
    - moves the identity line onto the name row;
    - holds the typewriter while a document or fade is up.
  - **Presenter.** The objective and hint share one VBox, and objectives resolve tokens.
  - **Backlog.** `scripts/ui/backlog_ui.gd` opens from the pause menu, H or pad View. It pauses the game, and `game_fp.open_backlog` / `close_backlog` keep `refresh_mouse` as the only mouse writer.
  - **Tests.** regress **R9** and qa_sweep at 0.8, 1.0 and 1.5.
- **New `class_name` gotcha:** after adding a `class_name` script, run `tools/godot --headless --path projects/games/last_light/godot --import` once. Otherwise every `-s` test hangs on "Identifier not declared".

## Earlier status (2026-11-05, cabin pass: Daniel's 8-photo brief, run before Stage 3)
- **Where it stands:** checkpoints 1–3 approved and committed (`91faeb1`, `9e0eeef`, `11b92d2`); **checkpoint 4 (final QA) approved by Daniel and committed.** Full log, the per-photo table (issue → root cause → fix → files) and a 7-step manual playtest: ROADMAP "Cabin pass".
- **Build:** v035 `.blend`, GLB v033, about 114k tris, 0 validation FAIL.
- **Tests (v035, headless):** regress 101/101, interaction 134/134 (7 warnings: documents have no sound), qa_sweep 948/948, story 0, sim_v2 no gate failures, run_tests 95/95, pytest 18/18.
- **Windowed regress 105/105** (no skips, twice). R6/R7 had failed windowed because the test waited a fixed 40 frames after a device-view enter or leave; at 120 Hz that can end inside the 0.45 s camera ease. `_settle_focus()` now waits for the ease itself. **When adding focus steps to tests, call it rather than a frame count.**
- **The mouse has one owner:** only `game_fp.refresh_mouse()` → `player.capture_mouse()` may change `Input.mouse_mode`. regress R8 checks this statically. Don't add a second writer in UI code.
- **Untracked on purpose:** `projects/games/last_light/cabin-photos/` (Daniel's photos) and `.blend` v028–v030, v032–v034 (Daniel: keep, don't delete).
- **Capture tool:** `cu_*` views now mute the player so the HUD prompt can't describe a different view. Torch and `fleet2` states aren't restored: put those shots last.
- **Stage 3** is still on hold: plan approved in principle, but Daniel has additions, so don't start 3A until he says go.

## Latest status (2026-11-05, Stage 1 iteration 5: cabin micro-detail)
- **Iteration 5 is approved by Daniel and committed locally.** It covers groups A–E: the desk, furniture, personal items and architectural fasteners.
- **Details:** the ROADMAP Stage 1 log, "Iteration 5". **Evidence:** `renders/last_light/s15f_vs_s15a_{a,b}.png` and `s15f_vs_s1_c.png`.
- **Build:** v026 `.blend`, GLB v024, 104k tris, 32 materials. All suites pass.
- **This session's files were** Blender/`tex`, `materials.gd`, the `station.gd` `_swap_materials` and PT_handset lines, the four desk views in `capture_fp.gd`, and its ROADMAP/REFERENCE_SPEC entries. Stage 2 (a parallel session) stages its own hunks only.
- **Bench done:** Medium +0–4 % median, inside budget rules; High desk +11 % median, at the threshold. See the ROADMAP for the suggested Stage 6 trim.

## Latest status (2026-11-05, Stage 2 approved by Daniel)
- **Stage 3 plan approved in principle (2026-11-05), but Daniel said "don't begin": he has additions.** The plan and all his decisions are in `~/.claude/plans/the-last-light-stage3-draft.md`: fonts, OFL exception, portraits, phone, optional content, script review, ch1, ending card, file ownership. **Do not start 3A** until his additions are folded in and he says go.
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
