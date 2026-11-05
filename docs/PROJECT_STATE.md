# Project state: THE LAST LIGHT

Updated 2026-11-04, end of session 1. This repository is Daniel's Blender Dev workspace. Its active project is **THE LAST LIGHT** (`projects/games/last_light/`), a first-person, story-driven lighthouse-keeper game: Godot 4.7.2 for the game, Blender 5.2.3 for the assets.

Legend: ✅ done and verified · 🟡 done, only partly verified · ⬜ not started · ❌ known broken

## 1. Vision, in one paragraph
North Point Light, Outer Hebrides, the night of 14–15 November 1971. The player is principal keeper Callum Mackay, alone in a round watch room under the lantern. He runs real machinery (generator, batteries, breakers, the light console and handwheel, radio, radar) while a storm builds and ships need guiding in. On the radio a boat calls herself *Mary Ellen*, a trawler lost under this light in 1953. Later an unlit boat docks, footsteps climb the stair, and three knocks come at the door: her "dead" skipper, Alasdair Ross. The twist is that Callum wrote the false 1953 log entry himself, at his father's order. The climax: his daughter Elspeth's ship drifts onto the same reef, and the motor jams on the same bearing. It's grounded psychological mystery, with no supernatural elements.

## 2. Decisions (binding unless Daniel changes them)
| When | Decision |
|---|---|
| 2026-11-03 | Godot 4.7.2 installed with the macOS export template (DECISIONS Q9). Generated files in `godot/assets/` may be overwritten (Q10). Local milestone commits allowed, **no pushes**. |
| 2026-11-03 | Art direction: grounded, semi-photoreal North Atlantic (cold storm outside, warm tungsten inside). CC0 textures from Poly Haven only, licence logged. |
| 2026-11-03 | First-person keeper simulation in ONE room (the brief's "small environment, deep interaction"). |
| 2026-11-03 | Room rebuilt from Daniel's reference images R1–R3 (`projects/games/last_light/REFERENCE_SPEC.md`). R4, the lighthouse cutaway, was never received; the attachment duplicated R3. |
| 2026-11-04 | Story direction **A, "The Mary Ellen Inquiry"** (`projects/games/last_light/NARRATIVE.md`). |
| 2026-11-04 | **No AI-generated images or voices** (CLAUDE.md). Dialogue is text with synthesised radio sound; no voice acting. |
| 2026-11-04 | Portraits: **Blender 3D busts** from Blender Studio's CC0 Human Base Meshes, three expressions per character (approved; ⬜ not built yet). |
| 2026-11-04 | 8 more 2k CC0 interior texture sets approved and downloaded (⬜ not yet wired into materials). |
| 2026-11-04 (session 2) | **Staged polish programme.** Stages run 0 → 6, and each one needs Daniel's explicit approval. Cabin direction: maintained but aged 1971 NLB, cinematic but readable, period green and cream, full room remodel. Generator is an auxiliary standby set in the room. Optic drive is a motor plus clockwork standby. macOS only. All of it is recorded in `docs/ROADMAP.md`. |
| 2026-11-05 | **Stage 2 (interactions):** quiet dot → ring crosshair; refuse START with a shut valve (with the reason); live gauge readings under the prompt; `hint_device` retired; full playable gamepad; camera-only interpolation (no global physics interpolation); a head-bob option, with movement numbers unchanged until Daniel's playtest; tips remembered per machine; the OS pointer hides while the pad drives a view. Details: ROADMAP Stage 2 log. |

## 3. Implemented
### Game (Godot, `projects/games/last_light/godot/`)
| Area | Status | Where |
|---|---|---|
| First-person controller (walk, look, capsule collision, eased device views). Stage 2C: the camera is drawn at the body position interpolated between physics ticks (look applied at once), mouse look is independent of window size, and there is a Head bob option | ✅ (feel NOT TESTED by a human) | `scripts/fp/player.gd` |
| Interaction language (Stage 2A): quiet dot → warm ring (usable) / dashed grey ring (unavailable) with the reason; a ring cursor and prompt in device views; refusals shown once; no dead prompts; view switching radio ↔ chart; the door prompt follows the story | ✅ regress R5 | `station.gd::availability/prompt_info`, `player.gd::_actionable`, `fp_ui.gd` |
| Radio panel (Stage 2B): keyed vessel list (no rebuild), buttons don't keep focus after a click, one-time Tab and wheel tips (`Settings.tips`) | ✅ regress R6 | `scripts/fp/fp_ui.gd`, `settings.gd` |
| Gamepad (Stage 2C): look, a device-view cursor, A/B/X/Y/LB/RB/Start, d-pad replies, device-aware glyphs (keyboard / Xbox / PlayStation), context-grouped bindings | ✅ regress R7 (injected pad events) / ⬜ real-pad feel | `scripts/core/input_setup.gd`, `player.gd`, `fp_ui.gd`, `dialogue_ui.gd` |
| Data-driven interaction (`IA_*` volumes from the GLB, toggles, holds, cycles, documents, door) | ✅ | `scripts/fp/station.gd` (`DEVICES` table) |
| Crosshair picking: a specific control beats its cabinet's info/focus volume; furniture doesn't occlude controls mounted on it | ✅ Stage 0 fix (before it, START, the breakers and the console knobs couldn't be targeted). Covered by `tests/interaction_test.gd` | `scripts/fp/player.gd::pick()` |
| Mouse-capture policy: one place decides (free-walk only; not while paused, in device views, documents, logbook or open replies) | ✅ Stage 0 fix. Covered by `tests/regress_test.gd`, and windowed for the real mouse mode | `scripts/fp/game_fp.gd::mouse_should_capture()` |
| Station rules: power, generator (valve/crank/charge/temperature/fuel), breakers and overload, light modes (OFF/AUTO/MANUAL), handwheel, jams, radio orders, fleet, channel piloting | ✅ (headless tests) | `scripts/core/keeper_sim.gd`, `fleet_ship.gd`, `keeper_config.gd` |
| Radar PPI drawn in a SubViewport onto the desk CRT | ✅ (seen in captures) | `scripts/fp/radar.gd` |
| Exterior: Gerstner ocean with foam, storm sky, volumetric beam, rain, lightning, island, reefs, jetty, ships riding the waves | 🟡 (seen in captures; island, reefs and ships are procedural Godot stand-ins) | `scripts/fp/outside.gd`, `ship_view2.gd`, `ocean_waves.gd`, `shaders/*` |
| **Rain stays outside** (ring emitter plus heightfield collision, hide-on-contact) | 🟡 Fixed today; 3 storm frames checked, no drops inside | `outside.gd::_rain()` |
| Story system: `.dlg` parser, runner, `StoryState`, `StoryDirector` (beats from `chapters.json`) | ✅ (DFS and campaign tests) | `scripts/story/*` |
| All 6 chapters scripted: 46 conversations, 273 lines, 4 endings | ✅ logic / 🟡 presentation (only chapters 1–4 seen on screen) | `data/story/ch1..ch6.dlg`, `chapters.json` |
| Dialogue UI: radio panel with identity card, typewriter, choices gated to the radio; person/thought subtitles | 🟡 (radio panel seen in a capture) | `scripts/ui/dialogue_ui.gd` |
| Documents: 1971 log, 1953 log (same hand = clue), Iain's letter, 046 note, 1954 clipping, forecast, two photos (readable PNGs plus `T` transcription) | ✅ images / 🟡 viewer | `blender/documents.py` → `godot/assets/docs/`, `scripts/story/story_presenter.gd` |
| Visitor sequence: dark boat, docking, positional footsteps (jetty → base door → stair), three knocks, door choices, silhouette | 🟡 (logic tested; never seen or heard on screen) | `chapters.json` ch4, `audio_director.gd`, `visitor_figure.gd` |
| Main menu (Continue / New / Load / Options / Credits / Quit) over a live exterior shot; threaded loading screen; push-in transition | 🟡 (menu seen in a capture) | `scripts/main_fp.gd` |
| Options (graphics, audio, controls, accessibility), persisted to `user://settings.cfg` | 🟡 (code paths exist; not clicked through) | `scripts/settings.gd` (autoload `Settings`) |
| Save/load: autosave plus 3 slots, only between beats, corrupt-safe | ✅ (round trip, no duplicate events) / 🟡 (in-game UI) | `scripts/save_system.gd` (autoload `SaveSystem`), `game_fp.gd::save_dict/_apply_save` |
| Audio: 37 synthesised sounds (ambience, machinery, radio, thunder, footsteps, knocks, horns, music pads), buses, 3D positioning | 🟡 **generated but never listened to** | `audio/synth.py` → `godot/assets/audio/`, `scripts/audio_director.gd` |
| macOS desktop build (`The Last Light.app`, universal, ad-hoc signed) | ✅ exported; smoke test passed (60 s bot story run, exit 0) | `export_presets.cfg` → `../build/` (gitignored) |
| Legacy modes still in the tree: v1 top-down game, v2 "watch" night | ✅ tests pass (v2 is used for the menu background and the `--mode=watch` sims) | `scripts/core/sim_world.gd`, `game_world.gd`, `main.gd` (v1); `data/night.json` (v2) |

### Assets (Blender, `projects/games/last_light/blender/`)
| Asset | Status |
|---|---|
| `spec.py` (single source of truth); `layout.py` → `layout.json` (reefs, channels, routes, with clearance checks) | ✅ |
| `build.py` → `ASSET_watch_room` (round room from R1, all devices with `PT_`/`NDL_`/`LMP_`/`IA_`/`FOCUS_` hooks, colliders) and `ASSET_lighthouse` | ✅ v006 `.blend`; GLB v004 validated (0 FAIL) and reimport-checked |
| `textures.py` (gauge/label atlas, chart, compass rose, rug), `documents.py` (story documents) | ✅ |
| `pipeline.sh`: build → validate → export → reimport → sync → Godot import | ✅ |
| Island, reef rocks and ships as Blender models | ⬜ (procedural stand-ins in Godot) |
| Character portraits | ⬜ (base meshes downloaded; see the handoff for measurements) |

## 4. Test and verification status (last run 2026-11-05, Stage 2 end)
All suites below re-run at the end of Stage 2: pytest 18/18, regress 87/87 windowed (no skips) and 84/84 headless, interaction 134/134 (6 warnings: documents open with no sound), qa_sweep 948/948, run_tests 95/95, sim_v2 no gate failures, story_test 0 failures. The rows below give the commands. **Run every suite under `timeout`**: a GDScript parse error makes a `-s` test hang idle.
| Check | Command | Result |
|---|---|---|
| Workspace pytest (now includes GLB hooks, import hints, normals, budgets) | `tools/py -m pytest -q` | ✅ 18 pass |
| Regressions: Stage 0 R1–R4 (mouse after reply, reply/panel overlap, pause input, thought lines) plus Stage 2 R5 (interaction state), R6 (radio panel), R7 (gamepad and camera) | `… -s res://tests/regress_test.gd`. Run windowed through `tools/godot_bg` for the real mouse-mode checks | ✅ 87/87 windowed; 84/84 headless (mouse-mode checks skipped) |
| Interaction checklist (radio, generator, power, console, door, desk and documents: walkable approach from spawn, prompt, part, state, sound trigger, console-view clicks, document open and close, save/load) | `… -s res://tests/interaction_test.gd` | ✅ 134 checks, 0 failures, 6 warnings (documents open with no sound → Stage 5) |
| QA sweep: dialogue fit (546 lines, 142 replies, text size 1.0 and 1.5) and options apply live | `… -s res://tests/qa_sweep_test.gd -- --windowed` (headless skips the display checks) | ✅ 948/948 |
| Audio objective QA (peak, RMS, DC, clipping, loop seams) | `tools/py projects/games/last_light/audio/analyze.py` | ✅ 37 files: no clipping, seamless loops. 2 minor flags (`click_button` DC, `horn_fishing` mastered hot) |
| v1 unit tests | `tools/godot --headless --path projects/games/last_light/godot -s res://tests/run_tests.gd` | ✅ 95/95 |
| v1 sim gates | `… -s res://tests/sim.gd -- --seeds=1-5` | ✅ no gate failures |
| v2 sim gates | `… -s res://tests/sim_v2.gd -- --seeds=1-5` | ✅ no gate failures |
| Story QA: parse, DFS, 3 campaigns, save round-trip, corrupt saves | `… -s res://tests/story_test.gd` | ✅ 0 failures |
| Build smoke test | `"projects/games/last_light/build/The Last Light.app/Contents/MacOS/The Last Light" -- --autotest=60 --bot=expert --autotest-out=/tmp/at.json` | ✅ (earlier in this session; the app predates the rain fix) |

## 5. Known issues and limitations
1. **Performance: baseline measured (Stage 0), and the main cause found.** On the Retina display the 1920-wide capture window is **3840×2410 physical pixels**, so 3D renders at about 9.3 MP on High. Frame time tracks pixel count, so the game is fill-rate bound; it is not mainly macOS throttling, which was session 1's theory. Metal still reports 0 GPU time.

   Worst-case bench (storm 1.0, lightning every 3 s, generator running, one ship). These are indicative numbers from my runs; Daniel should confirm with the window frontmost:

   | Preset | 3D scale | Median (ms) | 95th percentile (ms) |
   |---|---|---|---|
   | Low | 0.75 | 25–26 | 27–30 |
   | Medium | 0.90 | 32–45 | 46–54 |
   | High | 1.0 | 44–51 | 47–69 |
   | **High** | **0.5** (about 1080p-equivalent pixels) | **18.1** | **18.7** |

   The budget is 16.7 ms. The JSON files are `renders/last_light/s0_q{0,1,2}_bench.json` and `s0_q2_s50_bench.json`.

   To re-measure: `tools/godot --path projects/games/last_light/godot -- --capture=NAME --bench --quality=2 --bot=expert`, optionally with `--scale3d=0.5`.

   **Iteration 0.2: Auto render resolution is now the default** (`Settings.render_scale()`, FSR 1.0). Bench files `s02_q{0,1,2}_bench.json`, median then 95th percentile in ms:

   | Preset | fp_desk | fp_window | fp_gen |
   |---|---|---|---|
   | High (scale 0.47) | 18.9 / 20.7 | 19.8 / 36.1 | 31.9 / 37.1 |
   | Medium (0.43) | 14.6 / 17.3 | 15.2 / 20.1 | 16.2 / 22.4 |
   | Low (0.36) | 25.0 / 29.2 | 12.0 / 16.6 | 11.0 / 14.7 |

   These numbers are **noisy**: the window was not focused for most shots, and frame times seem to snap to the 8.3 ms vsync steps of the 120 Hz display. Low's 25 ms on fp_desk is probably that artefact. High in the generator view is still over budget; shadow presets are Stage 1a work.

   **Stage 1 end (2026-11-05, `s1f_q{2,1}_bench.json`, window focused, Mac free: the first clean bench).** Median / 95th percentile in ms:

   | Preset | fp_desk | fp_window | fp_gen |
   |---|---|---|---|
   | High | 27.4 / 28.1 | 28.3 / 29.0 | 28.7 / 29.9 |
   | Medium | 24.8 / 26.3 | 25.6 / 26.8 | not measured |

   The Medium run stopped after 2 shots; Low was not measured. **Over budget; the cause is not yet isolated** (see ROADMAP, iteration 4).

   **Iteration 1p (2026-11-05):** shadow cache fixed. Medium is now the default 60 fps preset with FXAA; High is the quality preset with 2× MSAA and a 25 ms budget. Clean bench `s1p_q*` (median ms, desk / window / generator):
   - Medium: 17.4 / 18.0 / 16.6;
   - High: 26.0 / 27.0 / 28.4;
   - Low: 12.3 / 12.8 / 14.4.

   See the ROADMAP 1p entry.

   Visual comparison: `renders/last_light/s02_render_res_vs_s0.png`. The captures are downscaled to 1920 px, so they understate how much sharper Native looks on the Retina screen.
2. **Play length NOT verified.** Bots finish the campaign in about 1,000 sim-seconds. A human estimate is 45–70 minutes against a 2-hour target; nobody has played it start to finish.
3. **Audio never listened to.** Synthesised sounds may be harsh or badly balanced.
4. **Portraits not implemented.** The radio panel shows line-art identity cards. The Visitor and Ross have only the silhouette.
5. **Interior materials:** the new 2k textures are downloaded but `scripts/fp/materials.gd` still uses the original 6 graded sets (wood is a tinted painted-plank scan). There's no interior reflection probe, so metal reflects the outdoor sky.
6. **Visual leftovers:**
   - ceiling I-beams read as dark triangles;
   - the floor can look pale and wet;
   - the photograph documents are simple drawings;
   - island, reefs and ships are Godot stand-ins.
7. The `.app` in `projects/games/last_light/build/` was exported **before** the rain fix and the latest story changes. Re-export before shipping.
8. ~~Duplicate licence line~~: fixed in Stage 0.
9. Large files: `assets/textures` is 709 MB, `assets/models/human_base_meshes` 98 MB (zip plus extracted), `projects/games/last_light/build` 292 MB (gitignored). Free disk was 23 GB.
10. Session-1 work is committed locally as `51cc8b9` (not pushed). The textures and base meshes are still untracked by design. Stage 0 changes are uncommitted until Daniel approves the stage.
