# THE LAST LIGHT: findings log (Daniel's brief of 2026-11-06, items 1–37)

The master reference for the brief. Every request has one entry and keeps its original ID. Sub-tasks carry the parent ID (4a, 4b and so on).

**Evidence labels:** **C** = CONFIRMED (seen in code or data, with file:line); **H** = HYPOTHESIS (inferred, to be checked during implementation).

**Status values:** `Not Started` · `Research Needed` · `Planned` · `In Progress` · `Implemented` · `Verified` · `Blocked`. Only `Implemented` and `Verified` need evidence, and none of the entries is at either yet.

**Groups:** each group ends with a checkpoint in the ROADMAP's four-part format and needs Daniel's approval.

| Group | Contents |
|---|---|
| G1 | Progression, input and correctness bugs |
| G2 | Opening, missions, feedback and saves |
| G3 | Body and equipment |
| G4 | Cabin assets |
| G5 | Weather and audio |
| G6 | Menu, profiles and ending |
| P | Proposal only (35–37, plus 31) |

**Plan:** `~/.claude/plans/the-last-light-cosmic-waffle.md` (approved 2026-11-06).

**Daniel's decisions (2026-11-06):**
- Documentation first, then G1 to G6, each checkpointed.
- Item 32 fuel: reuse the existing chapter-start top-up rule once when the day tank runs dry.
- Item 12: the floor compass rose stays, and the chart compass becomes the pickup.
- Audio: SFX stay synthesised; music comes from a CC0 shortlist Daniel picks from.

**Note:** the findings-log brief arrived truncated at its §4 ("…Before placing the wo"). Anything after that point isn't covered here.

Paths are relative to `projects/games/last_light/`. `g/` means `godot/`.

## Summary table
| ID | Title | Type | Pri | Cx | Stage / group | Status |
|---|---|---|---|---|---|---|
| 1 | Main menu redesign + links | UI/UX | P2 | M | 6 / G6 | Research Needed |
| 2 | Plugins and add-ons research | Research | P3 | S | 6 / docs | Implemented (recommendation below) |
| 3 | Beam circular end cap | Bug (visual) | P1 | S | 4 / G1 | Verified (captures g1_sheet_beam2: soft fade, no end disc; tuned once) |
| 4 | Pause menu, autosave only, transcript | UI/UX + gameplay | P1 | M | 6 / G2 | Planned |
| 5 | Door / floor white pixels | Bug (visual) | P1 | S | Cabin pass 2 / G1 | Verified (g1_sheet_door: base speckles gone, lit and dark) |
| 6 | Coat stand, jackets, pocket note | Visual | P2 | M | Cabin pass 2 / G4 | Planned |
| 7 | E key skips dialogue | Bug (input) | P0 | S | 2E / G1 | Verified (regress R11) |
| 8 | Opening: enter, dark, torch, generator | Gameplay | P0 | M | 2E / G2 | Planned (decision D8) |
| 9 | Missions with sub-objectives | Gameplay + UI | P0 | M | 2E / G2 | Planned |
| 10 | Shelf items, per object | Visual | P2 | M | Cabin pass 2 / G4 | Planned |
| 11 | Console note texture and writing | Visual | P2 | S | Cabin pass 2 / G4 | Planned |
| 12 | Compass as equipment | Gameplay | P2 | M | 2E / G3 | Planned |
| 13 | Visible player body | Visual + gameplay | P2 | L | 2E / G3 | Planned |
| 14 | Hand animations for equipment | Visual | P2 | L | 2E / G3 | Planned |
| 15 | Photograph realism | Visual | P3 | S | Cabin pass 2 / G4 | Planned |
| 16 | Generator / battery feedback | Bug (UX) | P0 | S | 2E / G2 | Planned |
| 17 | Cabin prop realism audit | Visual | P2 | M | Cabin pass 2 / G4 | Planned |
| 18 | Binoculars as equipment | Gameplay | P2 | M | 2E / G3 | Planned |
| 19 | Pipe smoking + exhaled smoke | Gameplay + VFX | P3 | M | 2E / G3 | Planned |
| 20 | Mission UI top-right | UI/UX | P1 | S | 2E / G2 | Planned |
| 21 | Time card before the fade | Bug (presentation) | P1 | S | 3D / G1 | Verified (regress R11 + g1_sheet_door: clock readable on black) |
| 22 | Radio character profiles | UI + art | P1 | L | 3C / G6 | Blocked (Daniel's profiles) |
| 23 | Radio interaction restrictions | Bug (interaction) | P0 | S | 2E / G1 | Verified (regress R8, R11) |
| 24 | Radio: sit or stand | Design decision | P2 | S | 2E / G2 + G3 | Planned (decision: seated) |
| 25 | Number-key reply selection | UX | P0 | S | 2E / G1 | Verified (regress R8, R11) |
| 26 | Dialogue overlap | Bug (system) | P0 | M | 2E / G1 | Implemented (regress R11; full-run frame audit still to add) |
| 27 | Maritime terminology | UX | P1 | S | 3D / G2 | Planned |
| 28 | Window rain moves upward | Bug (visual) | P1 | XS | 4 / G1 | PARTIAL (shader maths verified; on-glass motion too faint to judge from stills: check in play) |
| 29 | Distant lightning bolts | Visual | P2 | S | 4 / G5 | Planned |
| 30 | Storm and cabin SFX | Audio | P2 | M | 5 / G5 | Planned |
| 31 | Power-failure design brainstorm | Research | — | — | P | Recommendation only (not approved) |
| 32 | Kittiwake progression softlock | Bug (progression) | P0 | S | 2E / G1 | Verified (story_test power-out scenario) |
| 33 | Menu and loading music | Audio | P2 | S | 5 / G5 | Research Needed (CC0 shortlist) |
| 34 | Cinematic ending panels + rolling credits | Presentation | P1 | L | 5 / G6 | Planned |
| 35 | Secondary characters and radio encounters | Proposal | — | — | 3D / P | Awaiting approval: `PROPOSAL_35_RADIO_CAST.md` |
| 36 | Opening tutorial and onboarding | Proposal | — | — | 2E / P | Awaiting approval: `PROPOSAL_36_TUTORIAL.md` |
| 37 | Journal and historical records | Proposal | — | — | 3D / P | Awaiting approval: `PROPOSAL_37_JOURNAL.md` |

**Priority:** P0 is a blocker or progression issue, P3 is cosmetic. **Complexity:** XS < 1 h, S ≈ ½ day, M ≈ 1–2 days, L ≈ 3+ days.

## G1 implementation record (2026-11-06; awaiting Daniel's checkpoint)
| ID | What changed | Files |
|---|---|---|
| 32 | Radio conversations wait for `radio_on()` (never play on a dead set). Beats marked `needs_power` show a "No power…" hint naming the cause (MAIN, flat battery) after 8 s, then every 45 s. The chapter-start day-tank rule runs once per chapter when the tank is dry and the engine has stopped (flag `daytank_ch<N>`; line `sys_daytank`). No calls offered on a dead set. `radio_tx_draw` 0.10 → 0.06, so a call at LAMP HIGH no longer trips MAIN (0.84 + 0.06 < 0.92) | `story_director.gd`, `keeper_config.gd`, `chapters.json`, `data/story/system.dlg` |
| 7, 25 | Dialogue never reads `interact`. New action `dialogue_next`: Space, pad RT. It finishes the line, then advances after a 0.5 s dwell. Replies: physical 1–4, a click in device views, and the pad d-pad + A (focus only for the pad). No wheel, E, arrows or `ui_accept`. 0.4 s guard on new replies. Radio orders use physical keys too | `dialogue_ui.gd`, `input_setup.gd`, `fp_ui.gd` |
| 23 | Replies and answering only in the radio view (`_at_radio` = focused on the radio). The radar is its own `info` target ("Watch the radar", with a live state line), ignored inside the radio view (`part_of`) | `game_fp.gd`, `station.gd`, `player.gd` |
| 26 | Sim radio chatter goes through `game_fp._comms_radio`: silent on a dead set, logged to the transcript, queued while a story line is up, 1.6 s apart. Story lines fade the sim subtitles. `story_voice` suppresses the duplicate Kittiwake "channel lights". The ch1 `wait 4` → wait for Kittiwake's position reply. Notices and hints hold ≥ 2.5 s and queue | `game_fp.gd`, `fp_ui.gd`, `story_presenter.gd`, `story_director.gd`, `chapters.json` |
| 21 | The card draws above the fade. Time skip: fade to black → clock on black ≥ 1.8 s → scene back. Chapter: card on black → scene fades in → release → card out | `story_presenter.gd` |
| 3 | Beam fade bright at the lantern, exponential decay, zero by 92 % of its length; `fog_disabled` | `shaders/beam.gdshader` |
| 28 | `uv.y = +w_pos.y`: drops run down, trails above | `shaders/rain_glass.gdshader` |
| 5 | Shaft-wall tops 5 mm under the floor; stringers 2.5 cm lower; the stair lamp casts shadows on Low too. Build v038, GLB `watch_room_v036` (0 validation FAIL, reimport OK) | `blender/build.py`, `settings.gd` |

**Tests (headless, final G1 code):**

| Suite | Result |
|---|---|
| story | 0 failures (all 4 endings; Kittiwake power-out: no dead-set call, hint shown, day tank once, ch1 completes; HIGH call no trip) |
| regress | 188/188 (new R11) |
| interaction | 159/0 failed, 12 sound warnings (unchanged) |
| qa_sweep | 1,921/1,921 |
| sim_v2 | no gate failures |
| run_tests | 95/95 |
| pytest | 18/18 |

**Test changes:**
- regress R8 now expects number-key replies and radio-view-only gating.
- story_test's idle-keeper scenarios (E2, E4) keep the generator running, because a dead set now holds the radio calls.
- **Visual (captures, HEAD worktree before, after, Medium):** `renders/last_light/g1_sheet_beam.png`, `g1_sheet_beam2.png`, `g1_sheet_door.png`, `g1_sheet_rain.png`, `g1_rain_crop.png`.
  - **Beam:** first pass too bright (a hard wedge). Tuned to 0.5×, `exp(-3.2d)`, edge pow 2.4. Now a soft shaft that dissolves with no end disc.
  - **Door:** white speckles at the base gone.
  - **Clock card:** readable on black.
  - **Rain:** PARTIAL (see table).

## Dependency map
**Ordering constraints:**
- 7 and 25 → 26: the input split comes before the arbiter.
- 26 → 16 and 8: the feedback lines go through the arbiter.
- 9 → 8, 20, 36: the step objectives carry the opening.
- 13 → 14, 18, 12, 19, 24: the body comes before the equipment poses and the seated pose.
- 32 is independent of 8, but 8 changes ch1's power budget, so test them together.
- 22 needs Daniel's profiles, then `blender/portraits.py` (3C).
- 34 → 33: credits music.

**Shared files:**
- `g/scripts/ui/dialogue_ui.gd`: 7, 25, 26, 22.
- `g/scripts/story/story_presenter.gd`: 9, 20, 21, 34.
- `g/scripts/story/story_director.gd`: 26, 32, 8.
- `g/data/story/chapters.json`: 8, 9, 26, 27, 32, 12, 18.
- `g/scripts/fp/station.gd`: 16, 23, 12, 18, 19.
- `blender/build.py`: 5, 6, 10, 11, 12, 15, 17, 18, 19.

---

## 1. Main menu: UI/UX redesign and external links
- **Type:** UI/UX improvement plus research. **Intended result:** keep the live background; place the lighthouse in the right third and the menu on the left; better hierarchy and typography; a bottom-right link strip (Instagram, links, contact) that feels part of the design.
- **Current (C):**
  - The background is a live attract-mode game (`g/scripts/main_fp.gd:69-121`). The cine camera orbits about 158 m out at a bearing of about 017°, looking at (0, 17, 0) (`g/scripts/fp/game_fp.gd:668-675`), so the tower is centred and fills about 17 % of the frame height.
  - Left `VBoxContainer` at `PRESET_CENTER_LEFT` with offset 130/−300. It holds the logo (760×219), an amber subtitle (24 pt) and six equal 360×52 text buttons: Continue, New Game, Load Game, Options, Credits, Quit.
  - A 0.78 alpha gradient covers up to 60 % of the width.
  - There are no links. The ROADMAP Stage 6 already lists "the double highlight in the main menu".
- **Analysis:**
  - Every button has the same weight, so there is no primary action.
  - The tower is centred, so it competes with the menu column.
  - The camera path is procedural, which makes reframing a matter of camera maths, not new art.
  - Links need `OS.shell_open` and a single data file. No network code.
- **Research (G6, before the build).** Reference set: menus that sit over a live or painted scene, such as Firewatch, DREDGE, Disco Elysium, SIGNALIS, Return of the Obra Dinn and Kentucky Route Zero. Principles to check against screenshots:
  1. one strong focal subject offset to a third, with negative space under the menu;
  2. one primary action (Continue or New Game) visually heavier, secondary items smaller and quieter;
  3. left-aligned text with no button boxes, and a hover state shown by a small marker or colour, not a box;
  4. a 2–3 level type scale from the existing `UIStyle` fonts;
  5. utility links tucked into a corner at low contrast, rising on hover.

  *The principles come from design knowledge. The reference screenshots are still to be checked.*
- **Solution:**
  - Offset the `look_at` target and yaw the orbit so the lantern sits at about 68 % of the frame width. Keep the orbit motion.
  - Rebuild the column: logo, subtitle, a primary group (Continue/New Game in a larger size) and a secondary group (Load/Options/Credits/Quit in a smaller size) on a spacing scale.
  - Bottom-right strip: three small own-drawn SVG icons with labels, at about 45 % alpha rising to 100 % on hover, read from `g/data/links.json`.
  - Fix the double highlight.
- **Acceptance:**
  - The tower sits in the right third in captures at 16:9 and 16:10.
  - No overlap with the links at 0.8–1.5 text scale.
  - Mouse, keyboard and pad navigation all reach every item, with one highlight at a time.
  - Links open the system browser or mail client.
  - The `qa_sweep` menu checks pass.
- **Files:** `g/scripts/main_fp.gd`, `g/scripts/fp/game_fp.gd` (cine camera), `g/scripts/ui/style.gd`, `g/data/links.json` (new), and new icon SVGs in `g/assets/ui/`.
- **Depends:** 33 (menu music). **Blocker:** Daniel's Instagram handle, links and contact target; placeholders until then.
- **Verify:** `menu` capture viewed with Read; `qa_sweep`.

## 2. Plugins and add-ons: research
- **Type:** research.
- **Current (C):** no `g/addons/`, no `[editor_plugins]`, nothing vendored. Blender has only the official Blender Lab MCP add-on. Policy:
  - CLAUDE.md "Never: unvetted add-ons";
  - DECISIONS Q3: ask before installs;
  - CC0 or OFL for assets.
- **Evaluation:**

  | Candidate | For | Verdict |
  |---|---|---|
  | Rigify (ships with Blender) | 13, 14: rigging the player body and hands | **Use.** Bundled with Blender, so no install; stable and maintained |
  | Blender cloth simulation (built in) | 6: hanging oilskin folds, baked and applied | **Use.** Built in |
  | Godot `AnimationTree` + `Skeleton3D` modifiers (built in) | 13, 14: walk blending, look-at and hand placement | **Use.** Built in. Check the 4.7.2 IK modifier set (TwoBoneIK3D and the rest) at G3 before relying on it; otherwise use authored poses |
  | Godot `GPUParticles3D` (built in) | 19 smoke, 29 if needed | **Use.** Built in |
  | Dialogue Manager (community add-on) | 26 | **Reject.** The existing `dialogue_db`, `dialogue_runner` and `speakers` already do what's needed, and migrating would rewrite six `.dlg` files and every test |
  | Phantom Camera | 1, 24 | **Reject.** The cine camera and focus views are around 40 lines and work |
  | GUT / gdUnit4 | testing | **Reject for now.** The custom suites (story, regress, interaction, qa_sweep) cover the project. A switch is churn with no benefit |
  | Terrain3D, Sky3D, volumetric-cloud add-ons | 29 | **Reject.** The custom sky and ocean shaders give the look, and an add-on would replace art direction |
  | Jolt physics (built into Godot 4.4+) | — | **Not needed.** Physics is a capsule plus static colliders |
- **Recommendation:** install nothing. Every request can be met with built-in Blender and Godot features. Re-check only if the IK modifiers are missing in 4.7.2 at G3.
- **Status:** Implemented as documentation. No action needed from Daniel.

## 3. Lighthouse beam: circular end cap
- **Type:** bug (visual). **Intended result:** the beam fades into the dark with no visible disc.
- **Current (C):** three parts:
  - a `SpotLight3D` (7°, volumetric-fog energy 5);
  - an open `CylinderMesh` cone 190 m long, radius 0.6 → 18.3 m (`g/scripts/fp/outside.gd:356-393`);
  - volumetric fog of length 180 m (`outside.gd:107-118`).
- **Root cause (C, by the maths):** in `g/shaders/beam.gdshader`, `along` is 1 at the lantern and 0 at the far end, so `fade = (1-along)*smoothstep(0,0.03,along)` makes the beam brightest at its widest point. It then cuts to zero over the last 5.7 m, which reads as an 18 m ring. `cull_disabled` with `blend_add` doubles the rim.
- **H (secondary causes):** no `fog_disabled`, so depth fog outlines the cone; the fog volume (180 m) ends before the cone (190 m).
- **Solution:**
  - Invert the fade, using exponential falloff with distance from the lantern: `exp(-k·d)` times a soft start.
  - Add a radial edge softening with `edge`.
  - Add `fog_disabled`.
  - Make the cone length ≤ the fog length, and taper the end alpha to 0 well before the geometry ends.
  - Keep `spot_range` behaviour.
- **Acceptance:**
  - No visible end disc or ring from the menu camera, from the gallery, or from inside through the windows, on Low, Medium and High.
  - Brightness near the lantern is unchanged by eye.
- **Files:** `g/shaders/beam.gdshader`, `g/scripts/fp/outside.gd`. **Verify:** `menu` plus an exterior-beam capture before and after.

## 4. Pause menu, saving and transcript
- **Type:** UI/UX plus gameplay change. **Intended result:** automatic saves only; a reorganised pause menu; history in a transcript.
- **Current (C):**
  - **Story pause** (`g/scripts/fp/fp_ui.gd:513-525`): Resume, "Dialogue history · H", Save to slot 1/2/3, Main menu. No Options and no confirm.
  - **Main menu:** Continue, Load Game (auto plus 1–3, with delete).
  - **Autosaves:** every chapter switch, `autosave` beat actions (ch1 charge, kittiwake_home; ch2 gannet_in, 046; ch3 ×3; ch4 door; ch5 power), and quit to menu (`main_fp.gd:244`). **None at new game.**
  - **Saved state:** story state, sim, player and station (`game_fp.gd:327-333`).
  - **Not saved:** pending order replies and `tx_t`.
  - The backlog (`g/scripts/ui/backlog_ui.gd`) already exists: H, pad View, or the pause menu.
- **Sub-tasks:**
  - **4a autosave:** remove manual saving from pause and from Load. Old slot files stay on disk and aren't deleted. Autosave at new game, at every beat entry that isn't inside a conversation or an `until`, and on quit. Keep one autosave plus one rotating backup, so a bad state is never the only save (H: the current single file).
  - **4b layout:** Resume / Transcript (H) / Options (reuse the main-menu Options screen) / Main menu (with confirm). Same type scale as item 1. These match the Stage 6 bullets already in the roadmap.
  - **4c transcript:** the existing backlog stays the transcript. Add sim chatter to it (see 26), so every communication is reviewable.
- **Acceptance:**
  - No manual-save control exists anywhere.
  - Kill the game at any beat, then Continue: you resume at that beat or the previous one, with the same flags.
  - The pause menu works with mouse, keys and pad.
  - Options changes apply in game.
  - `story_test` autosave reloads pass.
- **Files:** `g/scripts/fp/fp_ui.gd`, `game_fp.gd`, `main_fp.gd`, `save_system.gd`, `story_director.gd`, `backlog_ui.gd`.
- **Regression risk:** loads re-run the beat's `do` actions (a known design). Autosave only at beat entry, before the `do` actions run.

## 5. Door: white pixels at the floor
- **Type:** bug (visual). **Intended result:** a clean door and floor junction from normal viewpoints.
- **Root cause (C, geometry):** the three `M_LL_Concrete` shaft-wall boxes in `blender/build.py:1613-1615` have `bevel=0`, and their tops lie exactly at floor level `F`. The front wall runs 0.83 m past the right side plate into the room, and a 4 cm strip shows outside the left plate. Cream concrete z-fights the dark floor, which shows as light speckles.
- **H (contributing causes):**
  - On Low the stair omni light has no shadows (`g/scripts/settings.gd:171`), so it lights the floor in front of the door through the housing.
  - Through the 20 mm door gap, the hatch hole's stepped edge (world-aligned floor cells against the 170° door) shows a bright, shimmering slot at 2× MSAA.
  - The stringers poke 2 cm above the floor.
- **Solution:**
  - Drop the shaft-wall tops 5 mm below `F` and trim them to the side plates.
  - Align the hatch cut to the door axis.
  - Lower the stringers.
  - Either enable stair-lamp shadows on Low, or cut its range so it can't reach the room.
- **Acceptance:**
  - The `cu_door` capture on Low, Medium and High, at the door and from about 3 m, shows no speckles and no light leak.
  - `test_last_light_hooks.py` and `interaction_test` pass.
- **Files:** `blender/build.py` (`build_stair`), `g/scripts/settings.gd`; then `pipeline.sh`.

## 6. Coat stand, jackets and pocket note
- **Type:** visual. **Intended result:** a believable hanging oilskin with thickness and folds, and a note held by the pocket.
- **Current (C):**
  - `build_coat_rack`, with `drape()` lofting rings (`build.py:2155-2265`). Sine folds, tapered-cylinder sleeves, a lathe sou'wester. No cloth simulation.
  - The note is a 0.07 × 0.003 × 0.055 box placed with an analytic `surf()` that ignores the hem and fold terms.
  - The printed quad sits about 0.3 mm behind the analytic surface.
- **Root cause (C/H):** the analytic surface differs from the faceted mesh by several millimetres, so parts of the note sit inside the coat (H: z-fighting and clipping visible).
- **Solution:**
  - Rebuild the coat as a cloth-simulated drape over a hanger proxy on its hook (Blender's built-in cloth, baked and applied), with solidify thickness (oilskin about 2 mm) and seams.
  - Model a real patch pocket with an opening, and seat the note inside it by raycasting against the final mesh, tilted by the pocket's lip.
  - Keep the sou'wester and the interaction volume.
- **Acceptance:**
  - In the `cu_coat` capture (new view) the note shows no clipping or floating from 0.4–2 m.
  - The coat silhouette reads as hanging from the hook.
  - `IA_coat_note` still opens `coat_note`.
  - Triangles within the P2 guardrails.
- **Files:** `blender/build.py`, `pipeline.sh`; `capture_fp.gd` gets the new view.

## 7. E key and dialogue skipping
- **Type:** bug (input). **Intended result:** E only interacts. Dialogue advances only with a separate key, and essential lines can't be skipped by accident.
- **Root cause (C):** `g/scripts/ui/dialogue_ui.gd:410-426` advances on E, Space or left click and calls `set_input_as_handled()`. The presenter receives `_unhandled_input` before the player, so E never reaches `player._press` while a line is showing. There is no concept of an essential line.
- **Solution:**
  - Remove E (and the pad A in free walk) from line advance.
  - **Space** (pad A only in device views) finishes the typewriter on the first press. A second press advances, accepted only after the line has been fully shown for ≥ 0.5 s, which stops double-tap skipping.
  - Left click is kept for the mouse in device views only.
  - The "essential" guarantee comes from the dwell plus the transcript (4c) plus objectives (9), not per-line flags. Lines never auto-advance today (`story_director:448`), so nothing is lost by waiting.
- **Acceptance (regress):**
  - E while a line shows works the targeted device, and the line stays.
  - Space double-tapped within 0.5 s of the reveal doesn't advance.
  - Space works again after the dwell.
  - The ending card's Space skip still works.
- **Files:** `dialogue_ui.gd`, `game_fp.gd` (input wiring), `input_setup.gd` (a `dialogue_next` action on Space so it's rebindable).

## 8. Game opening: entering in the dark
- **Type:** gameplay change. **Intended result:**
  1. start just inside the stair door;
  2. lights off;
  3. find the torch;
  4. use it to move around;
  5. first mission: start the generator and restore the lights.
- **Current (C):**
  - ch1 starts at 16:20 with battery 41 %, so the room lights are on (`lights_on = main_breaker and battery>0 and brk_lights`, `keeper_sim.gd:134`). The generator is off, the valve shut, and charging off.
  - The torch is on the top storage shelf, and can only be taken when the lights are off (`station.gd:516-518`). F toggles it.
  - The spawn is 1.1 m in front of the stair door, facing into the room.
  - Beat order: dusk → light (console) → engine → charge → …
- **Bug (C):** the door hinge is within the 1.8 m `at_door` radius of the spawn, so `at_door_once` latches on the first tick (`game_fp.gd:542-544`). The ch4 `door` beat (`when has_flag("at_door")`) could therefore fire immediately (H for ch4 consequences).
- **Solution:**
  - New beat 0 `arrive`: door-close sound, the player placed just inside facing the room, the room in darkness (the red emergency stair lamp already exists).
  - Then a step objective (item 9) "Restore the lights": find the torch ✓ → open the fuel valve ✓ → hold START ✓ → switch CHARGE on ✓ → lights on ✓.
  - Then the existing console beat (`light`), then on.
  - Ch1 `ch1_dusk` and `ch1_lit` are reordered to match.
  - Fix the latch by requiring the player to *approach* the door after spawn (distance must first exceed 2.2 m).
- **Decision D8 (for Daniel at the G2 checkpoint).** How to make the lights off coherent with the established text, which says "Forty-one percent at noon" (`ch1_lit`) and the log's "16.40 Engine started. Batteries on charge, 41%".
  - **D8-a (recommended):** a flat battery (the "tired cells" line already in `ch1_lit`). Change the 41 % lines to the new value (two-word edits).
  - **D8-b:** keep 41 % but start with the lights breaker off and MAIN tripped. This teaches the power panel, but the generator isn't strictly needed for the lights, which weakens the mission.
- **Acceptance:**
  - New game: dark room, torch obtainable, every step ticks only from real sim state, lights restored, then the console beat.
  - The ch4 door beat doesn't fire before ch4's `door` setup.
  - `story_test` bot path still completes all four endings.
- **Files:** `chapters.json`, `ch1.dlg`, `g/assets/docs/docs.json` (if D8-a), `story_director.gd`, `game_fp.gd`, `station.gd`.

## 9. Mission system: clear objectives and checklists
- **Type:** gameplay plus UI. **Intended result:** a main mission title, clear sub-steps that tick automatically from real actions, and no false ticks.
- **Current (C):** one plain objective string per beat, with tokens (`story_presenter.gd:63-75,180`). No steps.
- **Solution:**
  - Extend the beat `objective` to accept `{"title": "...", "steps": [{"text": "...", "done": "<StoryState expr>"}]}`, keeping string objectives for compatibility.
  - Steps are evaluated with `StoryState.eval` on the director tick.
  - A step **latches** once true, unless its entry sets `"live": true`. That's for states that can be undone, e.g. "the lights are on".
  - The beat still advances on its own `when`, never on the steps, so a checklist can't move the story forward or skip it.
  - Steps are saved with the story state.
  - Rewrite the ch1–ch6 objectives as concise titles plus steps where a task has more than one action (the opening, Kittiwake, the jam, the ch6 manual hold).
- **Acceptance:**
  - `story_test` asserts for every beat that no step ticks before its expression is true (watch the bot and assert per tick).
  - Save and reload keep the ticks.
  - Plain-string objectives still render.
- **Files:** `story_director.gd`, `story_state.gd`, `story_presenter.gd`, `chapters.json`, `story_test.gd`.

## 10. Shelf beside the coat stand: per-object pass
- **Type:** visual. The shelf is `build_storage`, bearing 128° (`build.py:1631-1690`), next to the coat stand at 149°.
- **Inventory and confirmed defects:**

  | Shelf | Object | Finding |
  |---|---|---|
  | Bottom (0.0925) | Wooden crate 0.5×0.42×0.36 + 3 slats | H: flat colour, no plank seams |
  | Bottom | Rope coil (sweep, 3 layers × 4 turns) | H: turns too regular |
  | 2nd (0.6125) | Red toolbox + lid seam, latches, handle | OK proportions. H: no paint wear |
  | 2nd | 2 spares boxes + stencil plates | H: plain stencils |
  | 2nd | Vapour-burner kit | **C: the cylinder (r 0.06 at 0.55) cuts about 1 cm into the red box (ends 0.5). The tube ends on the box top** |
  | 3rd (1.1125) | Storm lantern | H: check the glass and fount |
  | 3rd | Log box + 6 ledgers + labels | OK |
  | 3rd | Tide Tables ×3 + Grant's half-bottle | H: the label is a flat quad |
  | 3rd | Bulb box 0.16×0.14×0.11 | **C: passes about 1.5 cm through the log-box wall** |
  | Top (1.4925) | Rubber torch (pickup) | Becomes equipment in G3 (needs a held version) |
  | Wall above | Notice quad | Not on the shelf: no change |
- **Solution:**
  - Fix both intersections by repositioning, not shrinking.
  - Per object: contact with the board (sit on the top within ±1 mm), bevels, wear masks, label and stencil detail through the existing props atlas, rope turn jitter, crate plank seams.
  - No new objects.
- **Acceptance:** a new `cu_shelf` view shows no intersections at 0.5–2 m, and every object rests on its board. Hooks and interaction tests pass.
- **Files:** `blender/build.py`, `textures.py`, `capture_fp.gd`.

## 11. Console note: a real written document
- **Type:** visual. **Current (C):** `box(M_LL_Paper)` 0.16×0.11×0.002, 3 mm off the hood (`build.py:1744-1745`). A flat colour; floats. `documents.py note_046()` makes a 900×640 image for the viewer only.
- **Solution:**
  - Give the mesh UVs and its own texture `T_LL_Note046.png`. Render it from the existing `note_046` text (§12.2 of the master) in the established hands, adding paper fibre, a crease, a pin hole and a tea ring that is subtle.
  - Seat it flush on the hood with a slight curl.
  - The interaction and the document are unchanged.
- **Acceptance:** the `cu_console` capture shows the handwriting legible at 0.6 m, the paper sitting on the plate, and the viewer text unchanged.
- **Files:** `blender/build.py`, `documents.py`, `godot/scripts/fp/materials.gd` / `station.gd` `_swap_materials`.

## 12. Compass: interactive equipment
- **Type:** gameplay. **Decision (Daniel):**
  - the floor compass rose stays (it's architecture);
  - the **brass desk compass on the chart** (`build.py:891-893`) becomes the pickup.
- **Current (C):** merged into the props mesh, and covered only by `IA_chart`.
- **Solution:**
  - Split it out as `PROP_compass` with `IA_compass`.
  - It's collected in ch1 as a step of the Kittiwake navigation beat ("Take the hand compass from the chart").
  - Equip and holster with **G**. The left hand holds it at chest height, the needle follows world north (a needle shader or node driven by the player's yaw), and the bearing ring is readable.
  - It shares the equipment system with the torch and binoculars (14).
- **Acceptance:**
  - It can't be equipped before pickup.
  - The needle points to world north within 1° at every yaw.
  - G never conflicts with E, 1–4 or Space.
  - The pickup and equipped state are saved.
- **Files:** `build.py`, `station.gd`, `player.gd`, a new `g/scripts/fp/equipment.gd`, `chapters.json`, `input_setup.gd`.

## 13. Visible player body
- **Type:** visual plus gameplay. **Current (C):** no mesh. Capsule r 0.28, h 1.75; eye 1.65; the torch is a camera SpotLight (`player.gd:465-488`).
- **Solution:**
  - Blender: from the CC0 realistic male base mesh (`assets/models/human_base_meshes`), build a headless body (neck down) in Callum's clothes. The master §4.1 look: a grey wool jersey (the NLB tunic is for portraits; the chair already carries a gansey), dark trousers and boots.
  - Rig it with Rigify (bundled with Blender).
  - Actions: idle, walk, sit, turn-in-place, plus arm layers for each item.
  - Export a GLB with its skeleton. In Godot, an `AnimationTree` blends walk by speed. The body follows the capsule yaw; the camera is parented at the neck.
  - Cast shadows (layer 2). The head is excluded from the camera; the near plane is checked against the jersey collar.
- **Acceptance:**
  - Looking down shows legs and boots in contact with the floor (no sliding over 3 cm per step).
  - Arms visible when items are held.
  - No clipping into walls at the collider radius.
  - Frame time within the ROADMAP budget rule (+10 % median investigated).
- **Risk:** the largest single item. The "first-person body awareness" camera can clip at pitch extremes. Clamp pitch or blend the spine to follow pitch.
- **Files:** a new `blender/player_body.py`, `pipeline.sh`, `player.gd`, a new `g/scripts/fp/player_body.gd`.

## 14. Hand animations and equipment
- **Type:** visual. **Equipment:** torch (F, existing), compass (G), binoculars (B). A free-key check (C) shows Q, R, G, Z, X, C, V, B, N, M and others are unused. 1–4 belong to replies, 1–6 to radio orders in the radio view, E to interact and Space to dialogue.
- **Solution:**
  - A small `equipment.gd` with one active item and two-hand rules: the torch in the right hand; the compass in the left (the torch can stay on); binoculars take both hands, so the torch holsters while they're up.
  - Authored grip poses plus raise and lower clips, walk sway from the body animation, and item meshes attached to hand bones.
  - E-interaction still works with one hand free. With binoculars up, E lowers them first.
- **Acceptance:** every combination is tested in regress for state and key separation. Captures of each pose show no hand or item clipping. A walk capture.
- **Files:** `equipment.gd` (new), `player.gd`, `input_setup.gd`, `blender/player_body.py`.

## 15. Photograph: realism
- **Type:** visual. **Current (C):**
  - `photo_frame` at bearing −105°, z 1.85 (`build.py:1895-1920`). A mitred frame, print quad, and glass box (alpha 0.12).
  - Texture `T_LL_Photo.png` 1180×960, about 3,600 px/m, from `photo_render.py` plus `documents.py silver_print()`. The print has roughness 0.5.
- **H:** the glass has no reflection response (no SSR, probe-only), the print reads as flat, and the frame contact is unchecked.
- **Solution:**
  - Re-render at 2× resolution.
  - A paper roughness of about 0.7 with a mild sheen, and slight cockling via a normal map.
  - The glass gets a faint reflection from the ReflectionProbe plus a dust/smudge roughness mask.
  - Check that the frame sits on the wall, with the shadow gap.
  - Same image content and caption.
- **Acceptance:** `cu_photo` at 0.5 m and 2 m reads as a print behind glass; the content is unchanged.

## 16. Generator and battery: interaction feedback
- **Type:** bug (UX). **Root cause (C):**
  - `gen_panel`, `battery` and `power_panel` are kind `info`. E emits `{"type":"inspect"}`, which `game_fp._ui_events` doesn't handle, so the player gets only a click sound (`station.gd:478-595`).
  - `gen_start` and `gen_crank_stop` produce no notice.
  - The [E] key cap promises an action that does nothing.
- **Solution:**
  - Handle `inspect` with a short, state-aware Callum thought line through the dialogue arbiter (26). Examples: "Stopped. Forty-six litres in the day-tank. Valve's shut."; "Forty-one percent and falling. She wants charging."
  - Wording comes from the sim state with no new mechanics; each state's line plays once per state change.
  - Add `gen_start` ("She's caught") and crank-released-early ("Not yet: hold it till she catches") feedback.
- **Acceptance:** every generator, battery and power device gives visible feedback on E in every sim state (an `interaction_test` table), and nothing plays during a story line.
- **Files:** `game_fp.gd`, `station.gd`, a new `data/story/devices.dlg` (thought lines), `audio_director.gd` (drop the misleading click).

## 17. Full cabin prop realism audit
- **Type:** visual. **Scope:** existing props only.
- **Desk (`build_desk_detail`, `build.py:1065-1320`):** chart, parallel rule, dividers, pencil, logbook with pen and glasses, desk mug, pencil pot, mic and handset, radio, radar, lamp and cables, books, forecast, stores note, pipe and ashtray, Skerry Flake tin, phone, the 1953 photo.
- **Elsewhere:** the kettle on its ring, the sill mug, the shortbread tin, the chair with its gansey, the rug.
- **Confirmed simplifications (C):**
  - the sill mug is a primitive cylinder and torus, older than the desk mug;
  - the binocular eyepieces have no glass;
  - papers are single quads (the stores note is 0.5 mm above the desk; the forecast is 0.6 mm);
  - the extinguisher label is a 70° band.
- **Solution:**
  - Per prop: real-world dimensions checked (a mug about 80×95 mm, binoculars 7×50 about 180 mm, a pipe about 140 mm), contact within ±1 mm, bevels, a wear and roughness variation pass, and the stated simplifications fixed.
  - The props merged into `SM_Room_Props` that become interactive (binoculars 18, pipe 19, compass 12) are split out.
- **Acceptance:** before and after `cu_desk_l`, `cu_desk_r`, `cu_chart` and `cu_chair` sheets with no floating or clipping; hooks and the triangle guardrails pass.

## 18. Binoculars: usable equipment
- **Type:** gameplay. **Current (C):** desk mesh only, no hook (`build.py:1265-1279`).
- **Solution:**
  - Split `PROP_binoculars` and `IA_binoculars`.
  - Available after pickup. The unlock point is ch1's Kittiwake beat ("Watch Kittiwake into the Sound" is the first time looking out matters), with an optional step "Take the binoculars".
  - B raises and lowers them. FOV 72°→10° (7×) eased over 0.35 s, look sensitivity scaled by the FOV ratio, a two-circle eyepiece mask with slight vignette and edge blur, and a slow focus breathing effect.
  - Walking is slowed while they're raised.
- **Acceptance:**
  - Can't be used before pickup.
  - Ships and the beam are visibly magnified through the windows.
  - Their state is restored after focus views, pause and load.
  - No conflict with the torch or compass (14).

## 19. Pipe: smoking interaction
- **Type:** gameplay plus VFX. **Current (C):** pipe and ashtray are merged into the props mesh with no hook (`build.py:1298-1315`). The only particle systems are rain and the ship view.
- **Solution:**
  - Split `PROP_pipe` and `IA_pipe` (prompt "Smoke the pipe").
  - E plays: raise to mouth (body animation), a draw (the bowl glows faintly), lower, then exhale. A `GPUParticles3D` puff from the camera's mouth point: soft billboards rising about 0.3 m/s, spreading and fading over about 4 s, lit by the room. Then the pipe goes back to the ashtray.
  - Cooldown about 20 s. No story effect.
  - Not available during a story line or with binoculars raised.
- **Acceptance:** the smoke is visible in a capture sequence and draws no particles when off-screen; E is blocked during dialogue (26).

## 20. Mission UI (top-right)
- **Type:** UI/UX. **Current (C):** the objective is top-**left** with a "▸" prefix, and the hint shares the column (`story_presenter.gd:63-75`).
- **Solution:**
  - Move it to top-right with right-side margins from `UIStyle`.
  - Title in the small-caps style; steps below with an empty box or a ticked box (drawn, not a font glyph); a completed step dims and strikes out, then collapses after about 3 s once the whole objective is done.
  - The hint goes under the steps in italics.
  - Maximum width about 28 % of the screen.
  - Everything follows the global text scale.
- **Acceptance:** `qa_sweep` at 0.8, 1.0 and 1.5 shows no overlap with the radio panel, subtitles or prompt. A capture at each.

## 21. Time display and fade timing
- **Type:** bug (presentation). **Root cause (C):** in `story_presenter.gd`, `fade` is added after `card` (`:86` against `:161`), so the black covers the clock card. On a chapter change the card fades in only while the black lifts (`:197-205`). On a time skip the card and the black fade in together, and at full black the text is hidden (`:234-244`). At new game, `fp_ui.fade` (layer 20) also hides the ch1 card.
- **Solution:**
  - Draw the card above the fade.
  - Sequence: scene → fade to black (0.6–1.0 s) → time card in on black (≥ 1.6 s readable) → card out → scene in.
  - Chapter cards follow the same order.
  - Remove the double fade at new game.
- **Acceptance:** regress asserts the card's z-order is above the fade and that the card alpha is 1 for ≥ 1.6 s while the fade alpha is 1. Capture frames of a time skip.

## 22. Radio character profiles
- **Type:** UI plus art. **Current (C):**
  - `Speakers.resolve` hides Ross as "The man at the door" until `knows_name` (`speakers.gd:29-37`).
  - The radio card is a 170×190 parchment with a line drawing; `dialogue_ui._resolved` drops `expr`.
  - `blender/portraits.py` is a paused probe. `g/assets/portraits/` doesn't exist.
- **Spoiler (C):** MARY ELLEN's card shows "Registry: LOST 15.11.1953" from her first line.
- **Solution (3C):**
  - Portraits from `portraits.py` once Daniel's reference profiles arrive, framed head to mid-chest ("face and body"), 3 expressions each.
  - Unknown identity shows a "?" card with only what the player has heard: the Mary Ellen caller, an unidentified station, the Visitor until `knows_name`.
  - Known identity shows the portrait plus name, vessel and role.
  - The card state is driven by the resolver plus flags, never by the script's speaker id.
  - Fix the Mary Ellen registry line to show only after the player has heard it from Morag.
- **Blocked:** Daniel's character profiles (the ChatGPT prompts were given 2026-11-06).
- **Acceptance:** for every line in all six `.dlg` files, the card shown is consistent with the flags (a story_test sweep), and Ross's portrait never appears before `knows_name`.

## 23. Radio: interaction restrictions
- **Type:** bug (interaction). **Root cause (C):**
  - Replies unlock within 1.7 m of `FOCUS_radio_at` (`game_fp._at_radio`, `:150-156`).
  - The radar's DEVICES entry is `{"kind":"focus","focus_id":"radio"}` (`station.gd:71`), so looking at the radar opens the radio.
  - Nothing answers on proximity alone, but the replies appear on proximity.
- **Solution:**
  - `_at_radio` = the radio focus view is active.
  - The radio view is entered only by picking the radio volume (`IA_radio`) with the crosshair and pressing E.
  - The radar becomes its own `info` target ("Watch the radar") with a state-aware line (via 16's mechanism) and no radio focus.
  - Its large volume must not shadow the radio: check the `player.pick` priority.
- **Acceptance (`interaction_test`):**
  - Standing at the desk not looking at the radio: no replies.
  - Looking at the radar: radar prompt, no radio view.
  - Looking at the radio + E: radio view and replies.

## 24. Radio: sit or stand (decision)
- **Decision: seated.**
- **Why:**
  - (a) The existing radio focus view already eases to a seated eye height of 1.32 m over the chair (`build.py:917`, `player.enter_focus`), so this matches what's already on screen.
  - (b) With the body (13), a seated pose makes the desk set reachable and keeps the legs under the desk instead of clipping it.
  - (c) Standing would need a new eye point and camera rig for the same desk, adding complexity for no gain.
  - (d) Realism: a 1971 keeper sat at the set for a long watch.
- **Implementation:**
  - On entering the radio view: the body plays `sit` and moves to the chair's seat point (the chair mesh doesn't move).
  - On leaving: stand. Both blends happen during the existing 0.45 s camera ease.
- **Acceptance:** a capture in the radio view and on leaving it shows no clipping.

## 25. Dialogue selection: number keys
- **Type:** UX. **Current (C):** replies take 1–4 plus wheel, E, click, arrows (`ui_up`/`ui_down`, which also walk) and Space (`ui_accept`) (`dialogue_ui.gd:399-414`).
- **Solution:**
  - Replies are chosen only by 1–4 (from `physical_keycode`, layout-independent; each reply shows its number), or by mouse click in device views. Pad: d-pad plus A, kept for controller play.
  - Remove wheel, E, arrow and `ui_accept` selection, and stop the reply buttons taking keyboard focus so arrows can't move the highlight.
  - Choices ignore input for 0.4 s after appearing.
  - In the radio view, 1–6 orders stay suppressed while replies are open (the existing `number_keys_taken_fn`).
- **Acceptance (regress):** 1–4 pick the right reply; arrows and W/S only walk; Space doesn't pick; no pick within 0.4 s.

## 26. Dialogue systems: prevent overlap
- **Type:** bug (system). **Sources (C):**
  - story conversations (radio, person, thought, sound);
  - asides;
  - optional calls;
  - **sim radio chatter** (`fp_ui.add_subtitle`: ack, position, lost_light, has_light, mayday, piloting, saved, lost, call, recall, and the keeper's tx lines);
  - hints, notices, captions and documents.

  Story conversations are already serialised (`story_director:204,510,571`), but **there is no arbiter between sim chatter and story lines**. The sim subtitles draw on layer 20 over the story panel on layer 15.
- **Concrete collisions (C):**
  - ch1: the `wait 4` before `ch1_bearings` against Kittiwake's position reply at about 4.3 s;
  - the sim's "We have the channel lights" plus `ch1_rory_in` "I've got the green" (said twice);
  - hints and notices overwrite each other.
- **Solution:**
  - A small `CommsArbiter` in the presenter layer: one channel for spoken or radio lines with priority (story > optional call > sim chatter > device thoughts), and a queue for lower priority while higher is active.
  - Sim chatter is deferred, not dropped, and logged to the transcript.
  - Notices and hints get a minimum hold of 2.5 s and queue.
  - ch1 `wait 4` → `until` the Kittiwake position event; suppress the sim's duplicate "channel lights" when a story beat covers it (a per-ship `story_voice` flag).
- **Acceptance:**
  - A story_test bot run logs zero frames with two spoken lines visible at once.
  - Every sim radio line appears in the transcript.
  - All four endings still complete.

## 27. Maritime terminology
- **Type:** UX. **Where the terms occur (C):**
  - "leading line": `chapters.json:23`, chart text at `story_presenter.gd:47`;
  - North Sound: `ch1.dlg:76,136`, `ch4.dlg:5`, `log_1971`;
  - port/starboard: order buttons `fp_ui.gd:13`, `keeper_sim:794,797,827`, `ch1.dlg:82`, hint `chapters.json:24`;
  - bearing and heading: several `.dlg` files plus the position reply;
  - Gut and lee: objectives and dialogue.
- **Solution (keeps the nautical voice in the dialogue):**
  - Objectives and order buttons carry plain glosses: "Turn port 30° (to her left)"; "Bring Kittiwake onto the North Sound leading line: steer her until she points straight up the channel (000°)".
  - A **terms legend added to the existing chart document**: port, starboard, bearing, heading, leading line, Gut, lee, abeam, over. No new object.
  - A first-use hint per term (once).
  - Dialogue lines are not changed, so the characters' voices stay as written.
- **Acceptance:** each instruction-carrying objective is understandable without the legend (Daniel reads them at the checkpoint); the meaning of each instruction is unchanged (diff review).

## 28. Window rain: direction bug
- **Type:** bug (visual). **Root cause (C):** `g/shaders/rain_glass.gdshader:69` `uv = vec2(dot(w_pos,tang), -w_pos.y)`. Since `y = fract(uv.y*0.35 + t*speed)`, the drop heads climb in world space, with the trail below them.
- **Solution:** `uv.y = +w_pos.y`, so the drops fall with the trail above them. Check the trail orientation.
- **Acceptance:** a capture sequence (3 frames 0.2 s apart) shows the heads moving down.

## 29. Distant lightning bolts
- **Type:** visual. **Current (C):** flash only (`outside.gd:446-491`; sky shader `flash_dir`); no bolt geometry.
- **Solution:**
  - On each strike event, a procedural branching polyline built as camera-facing quad strips (unshaded, additive, `fog_disabled`). Spawned 400–900 m away along `_flash_dir`, from the cloud base to the horizon, visible for about 0.15–0.35 s with 1–2 restrikes synced to the existing flicker.
  - Respect the reduce-flashing setting (no bolt or a dimmed one).
  - Only some strikes show a bolt (others stay in-cloud), so it isn't excessive.
- **Acceptance:** visible through the windows and from the gallery with no clipping into the near ocean; the frequency equals the existing strike rate; frame cost negligible.

## 30. Storm and cabin SFX
- **Type:** audio. **Current (C):**
  - Everything comes from `audio/synth.py` (seed 1953).
  - Loops: rain 14.5 s, wind 22.5 s, sea 28.5 s, gen_idle 7.5 s, hum 5.5 s, static 5.7 s, motor_grind 2.8 s.
  - Thunder: 3 variants, unseeded pick; the delay is a random 0.5–2.5 s, not tied to distance (`keeper_sim.gd:583`).
  - No bus effects.
  - Defects: `set_menu` ignores its argument; `_dev()` ignores its name and returns the fallback position; `carrier_click` was never synthesised.
- **Solution (synthesised, per Daniel):**
  - Thunder delay = bolt distance / 343 m/s (from 29). Low-pass and rumble length rise with distance.
  - 6 seeded thunder variants.
  - Rain loop ≥ 45 s, plus a desynced glass-patter layer on the window side.
  - Wind gust envelopes tied to the storm value.
  - Longer hum and static loops (≥ 20 s), or two desynced layers.
  - Interior muffling of exterior sounds (low-pass on the Ambient bus when indoors).
  - Fix the three code defects and synthesise `carrier_click`.
  - `analyze.py` gates: peak, DC offset, loop seams.
- **Acceptance:** `analyze.py` passes; no loop shorter than 20 s on a constant layer. **Whether it sounds right is Daniel's call**, at a listening session.

## 31. Generator and battery failure: brainstorm (RECOMMENDATION ONLY, NOT APPROVED, NOT TO BE IMPLEMENTED)
**Facts (C):**
- Power = MAIN and battery > 0. The lamp, rotation motor, radio, radar and room lights all need it.
- The generator cranks without the battery. A flat battery recovers by charging.
- Fuel is 46–48 L per chapter and is topped up only at chapter start ("from the main tank" downstairs).
- An empty day tank mid-chapter is a dead end today (32's interim fix covers it).
- Protected story ships heave to rather than sink.
- Assets that already exist: the paraffin storm lantern, the old vapour-burner kit, the console handwheel (manual rotation), the red emergency stair lamp. The main engine room is downstairs and out of action (an approved decision).

**Questions and analysis:**
1. **Leave the lighthouse to fetch fuel?** Not recommended.
   - The stair door is the ch4 set piece (the knock, the bolt). Sending the player through it earlier spends that tension and breaks the single-room scope.
   - Going outside needs exterior traversal that Stage 4 hasn't built.
2. **An in-room alternative (recommended if a mechanic is wanted):** a **semi-rotary hand pump on the day tank in the generator cage**, fed from the main tank below.
   - That's period-correct for small standby sets.
   - Hold E to pump, at about 0.5 L/s, with a sound and a gauge.
   - Limit it to a per-chapter reserve, so fuel management still matters.
   - It replaces 32's invisible top-up with a visible action, adds no new space, and teaches the fuel gauge.
3. **Other consequences of power loss, using only what exists:**
   - the room goes dark (the emergency lamp only);
   - the radio and radar die (story radio scenes wait, from 32);
   - the light goes out, so non-story ships lose the light and existing `lost_light` events and rescue failures can happen;
   - story ships heave to.

   These already create tension without new systems.
4. **When both sources are empty:** the player can pump fuel (option 2), crank (no battery needed), charge, and use the torch. The lamp can't be lit without power. The handwheel turns the optic only when the lamp burns. No second backup light is recommended: it would overlap the 1953 vapour-lamp story beat.
5. **A limited torch battery?** **Not recommended.**
   - The torch is needed most in the dark opening (8) and in blackouts.
   - A dying torch during the dark moments adds frustration with no story return.
   - If wanted later: a very generous battery with a spare cell on the shelf, never able to softlock.
6. **Effect on progression:** add a power guard to every beat whose exit needs power (the 32 pattern). The hints say what to fix. Story time never pauses on its own.

**Recommendation:** option 2 (hand pump with a per-chapter reserve) plus the power-aware guards and hints from 32, no torch battery, and no leaving the lighthouse.
- **Advantages:** no softlock, no new space, period-correct, teaches the systems.
- **Drawbacks:** one new interaction and asset in the cage, plus a re-balance of the chapter fuel numbers.
- **Technical:** a `pump` device in `station.gd`, a `KeeperSim.main_reserve` value, a cage mesh, a sound, and story_test power-out scenarios per chapter.
- **Status: awaiting Daniel's approval. Nothing is to be implemented.**

## 32. Kittiwake: progression softlock
- **Type:** bug (progression). **Reported:** Kittiwake signalled, then the campaign stopped, with the generator and battery both depleted.
- **Root cause (C):**
  1. Story radio conversations ignore power. `ch1_rory_call` plays on a dead set; `start_conversation` and `_do("talk")` have no `radio_on` check.
  2. Every exit from the beat needs power:
     - `until flag("tx_confirm")` needs a `tx` event, which `KeeperSim.command` refuses with `radio_dead` (`keeper_sim:250`);
     - `piloting("Kittiwake")` needs `_try_capture` → `sees_light` → `lamp_on` → `powered` (`:696-716`);
     - Kittiwake spawns with `hold:true, protected:true`, so she never moves or sinks without orders.
  3. Fuel is only topped up at chapter start (`story_director.gd:168-169`). There's no refuel in-chapter, and the hints never mention power, so fuel = 0 is permanent.
  4. Manual saves are blocked during the `until`, so the only fallback is the charge-beat autosave.
- **Secondary (C):** at LAMP HIGH, transmitting draws 0.94 against the 0.92 limit, and `tx_time` 2.5 s exceeds the 2.0 s trip delay, so every transmission trips MAIN.
- **Contributing (C/H):**
  - the sim drains during conversations;
  - charging overheats the engine after about 4 minutes;
  - an idling engine burns fuel for nothing.
- **Solution (Daniel's decision):**
  - A story-mode **day-tank top-up from the main tank, once**, when the tank runs dry and the engine stops. It reuses the existing chapter-start rule and comes with one Callum thought line. Not a new event: the same rule, applied when it's needed.
  - Story radio conversations (`mode=radio`) **wait for `radio_on()`**, showing the power hint, and resume when power is back. The line is held, never skipped.
  - Hints for kittiwake and vector become power-aware, e.g. "No light: check MAIN, the battery and the generator".
  - The transmit draw is fixed so a call alone can't trip MAIN: `tx_draw` is scaled so the HIGH total stays under the limit. This doesn't change the overload mechanic for real overloads.
  - Item 31 may later replace the top-up with the hand pump.
- **Acceptance (story_test, new):**
  - At the `kittiwake` beat, drain the battery to 0 and the fuel to 0, then run the bot's recovery (crank, charge, lamp).
  - Assert that the beat completes, no conversation started while the radio was dead, and the top-up ran only once.
  - The HIGH-transmit case doesn't trip.
  - All four endings still pass.
- **Files:** `story_director.gd`, `keeper_sim.gd`, `keeper_config.gd`, `chapters.json`, `story_test.gd`, `ch1.dlg` (the thought line).

## 33. Main menu and loading music
- **Type:** audio. **Current (C):** `music_menu` is a 44 s synthesised D-modal pad (the menu); `music_tension` is 36 s (ch4 on). The credits are silent. `set_menu` ignores its argument.
- **Decision (Daniel):** a **researched CC0 shortlist** with licences. Nothing is downloaded before Daniel picks; once picked, it's fetched with `tools/fetch_cc0.py --confirm` and logged in `assets/ASSET_LICENSES.md`.
- **Criteria:**
  - sparse, slow (≤ 70 bpm or unmetred);
  - solo piano, cello, low strings, harmonium or drone;
  - minor or modal;
  - at least 2 minutes, or loopable;
  - no vocals and no percussion;
  - sits under the wind and rain without masking them.
- **Then:** loop points, −18 to −14 LUFS under the ambience, crossfades from the menu to loading to the game (fading out under the first chapter card), and credits music for 34.
- **Acceptance:** the licence is logged, the loops are seamless (`analyze.py`), and the mix is checked by Daniel.

## 34. Campaign ending: cinematic panels and rolling credits
- **Type:** presentation. **Current (C):**
  - `story_director._ending_card` works out 1 of 4 endings, from `told_truth` × `saved("Iona Star")`, and collects the epilogue lines (`ch6.dlg:134-150`).
  - `story_presenter.show_ending` fades the lines in over warm black.
  - `game_fp:313` deletes the autosave → `main_fp._on_campaign_over` → a static `credits.txt` panel (27 lines). It doesn't scroll and has no audio, and it still says Apple fonts "until Stage 3C".
- **Scene count (smallest that tells it):** **4 panels per playthrough**:
  1. "Two men to one wheel" (ch6 hold);
  2. the *Iona Star* outcome (through the Gut, or upright on the sand ledge: variant by `saved`);
  3. the log page in Callum's hand (correction, or "Light exhibited throughout": variant by `told_truth`);
  4. one ending-specific panel taken from the existing epilogue lines: the inquiry with Morag's notebook (Correction), Ross in a chair with Elspeth's hand (Heard Together), the black boat leaving on the morning tide or the Stornoway pier (Nothing to Report), or the second inquiry (Light Exhibited).
- **Visuals:** Blender renders of the existing scene, ships and CC0 base-mesh figures, graded to a consistent illustrated-print style (ink and halftone grade, the period palette). **No AI-generated images.** The text is the existing epilogue lines, unchanged.
- **Flow:**
  - after the existing final beat: panel 1 fades in;
  - its lines reveal beside it; Space advances only after the dwell;
  - crossfade between panels;
  - after panel 4: the closing lines, then **rolling credits** (scrolling `credits.txt`, corrected to fact with no invented contributors) over the credits music (33);
  - then the existing main menu.
  - Gameplay input, sim chatter and the arbiter are suspended for the whole sequence.
- **Acceptance (story_test):**
  - all four endings play every panel and line, reach the credits, then the menu;
  - the sequence can't start before `end_campaign`;
  - E, 1–4 and equipment keys do nothing during it;
  - Space respects the dwell.
  - Visual: captures of each panel are reviewed.
- **Files:** `story_presenter.gd`, `story_director.gd`, `main_fp.gd`, a new `blender/ending_panels.py`, `g/assets/ending/`, `g/data/credits.txt`.

## 35. Secondary characters and radio encounters (PROPOSAL)
See `PROPOSAL_35_RADIO_CAST.md`. **Status: awaiting approval; nothing implemented.**

## 36. Opening tutorial and onboarding (PROPOSAL)
See `PROPOSAL_36_TUTORIAL.md`. **Status: awaiting approval.** It builds on item 8, and items 8, 9 and 16 are implemented regardless of it.

## 37. Journal and historical records (PROPOSAL)
See `PROPOSAL_37_JOURNAL.md`. **Status: awaiting approval.**
