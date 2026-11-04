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

## 3. Implemented
### Game (Godot, `projects/games/last_light/godot/`)
| Area | Status | Where |
|---|---|---|
| First-person controller (walk, look, capsule collision, eased device views) | ✅ | `scripts/fp/player.gd` |
| Data-driven interaction (`IA_*` volumes from the GLB, toggles, holds, cycles, documents, door) | ✅ | `scripts/fp/station.gd` (`DEVICES` table) |
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

## 4. Test and verification status (last run 2026-11-04)
| Check | Command | Result |
|---|---|---|
| Workspace pytest | `tools/py -m pytest -q` | ✅ pass |
| v1 unit tests | `tools/godot --headless --path projects/games/last_light/godot -s res://tests/run_tests.gd` | ✅ 95/95 |
| v1 sim gates | `… -s res://tests/sim.gd -- --seeds=1-5` | ✅ no gate failures |
| v2 sim gates | `… -s res://tests/sim_v2.gd -- --seeds=1-5` | ✅ no gate failures |
| Story QA: parse, DFS, 3 campaigns, save round-trip, corrupt saves | `… -s res://tests/story_test.gd` | ✅ 0 failures |
| Build smoke test | `"projects/games/last_light/build/The Last Light.app/Contents/MacOS/The Last Light" -- --autotest=60 --bot=expert --autotest-out=/tmp/at.json` | ✅ (earlier in this session; the app predates the rain fix) |

## 5. Known issues and limitations
1. **Performance NOT verified.** The first run gave 60 fps; later runs sat at about 22 fps even with every heavy effect off and at half resolution, with render CPU at about 1 ms. That suggests macOS throttling a background window. Metal reports no GPU time. Daniel must measure at the desk.
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
8. `assets/ASSET_LICENSES.md` has a **duplicate line** for `concrete_floor_worn_001`, from a download race.
9. Large files: `assets/textures` is 709 MB, `assets/models/human_base_meshes` 98 MB (zip plus extracted), `projects/games/last_light/build` 292 MB (gitignored). Free disk was 23 GB.
10. Uncommitted work: everything after commit `98c570e` (story system, audio, menus, saves, rain fix, documents, downloads). See SESSION_HANDOFF.md.
