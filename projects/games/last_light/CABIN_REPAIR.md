# Cabin repair: screenshot brief, defect report and iterations

Daniel's brief (2026-11-04, session 2b) names nine photographs (IMG_3116–3124). The images themselves were **not supplied**, so each defect was checked against direct Godot captures at matching views: `renders/last_light/iA_before_*` (baseline) and `iA_final_*` (after Iteration A).

All captures use the High preset (`--quality=2 --nohud`) and the views `cu_gauges`, `cu_selectors`, `cu_battery`, `cu_photo`, `cu_logbook`, `cu_radio`, `cu_shelf`, `cu_gen` and `doc_*`, which were added to `capture_fp.gd` for this brief.

## Defect report
| Ref | Subject | Finding | Class | Root cause | Status |
|---|---|---|---|---|---|
| 3117 | Console gauges | Upper half of the dials missing | Confirmed geometry defect | Dial plate tilted 15°, but the hood box had a vertical front, so the top of each dial sat inside the hood | Fixed (A): hood rebuilt with its front in the instrument plane |
| 3117 | Console gauges | Bearing dial face invisible | Confirmed geometry defect | A solid 0.215 m brass "flange" disc sat 7 mm in front of the dial | Fixed (A): flange is a ring behind the bezel |
| 3117, 3121, radio | All dials (8) | Jagged brass shapes through the faces | Confirmed rendering defect (z-fight) | `gauge()` bezel was a solid cylinder with its top cap exactly at the dial plane (+3 mm). Shared by all 8 dials | Fixed (A): layered gauge (case −4 mm, dial +3, needle +7..15, glass +18.5..21.5, bezel ring −6..+24) |
| 3117 | Needles | Thin bar; black needle invisible on the navy bearing dial | Material defect | `needle_fn` was a flat box; one material for all | Fixed (A): tapered pointer, counterweight tail, hub; ivory needle on the bearing dial |
| 3117 | OFF/AUTO/MANUAL, LOW/NORMAL/HIGH | Active position hard to read; label said "MAN" | Interaction readability | Round knob with a 2 mm slot | Fixed (A): bar selector with a white index inlay that rotates with the part; plate says MANUAL |
| 3121 | Battery and charge gauges | Needles follow `sim.battery` and `charge_amps()` | Verified OK | — | No change needed (station.gd `_set_gauge`) |
| 3122 | Framed photograph | Blank | Confirmed missing content | `SM_RoomPhoto` was an untextured `M_LL_Paper` box | Fixed (A): Cycles photograph from CC0 base meshes (see below), toned as a silver print, in a mitred frame with glass |
| 3122 | Photograph inspection | Opened a pictogram drawing | Missing content | `documents.py photo("keepers")` drew stick figures | Fixed (A): the same photograph is used for the inspection view |
| 3119 | Station logbook | Blank pages | Confirmed missing content | Two `M_LL_Paper` boxes | Fixed (A): ledger with curved page blocks, boards, spine, ribbon, and the 13/14 Nov entries (`T_LL_Logbook`) |
| 3119 | Logbook | Book turned 90° (spine across the reader) | Geometry defect | `basis_z(u, ~r)` set the page axis to −o | Fixed (A) |
| 3119 | Logbook | Pages blown out under the desk lamp | Material / lighting | Albedo about 0.9 under a strong spot | Improved (A): ledger albedo ×0.78. Lamp energy is in the lighting pass (the other session) |
| (period) | Wall clock | Face read "TRINITY HOUSE", the English authority | Content error | textures.py | Fixed (A): NORTHERN LIGHTHOUSE BOARD |
| 3124 | Optic drive | Glass column with white stacked lens discs; reads as a light sculpture | Geometry / design | `build_optic_drive` (brass drum + `M_LL_Lens` discs) | Open → Iteration B |
| 3124 | Radial "fan" on the wall | Wall-lamp light 0.1 m outside its cage; the six bars threw 1.2 m radial shadows | Confirmed rendering defect | `LIGHT_wall_*` position | Fixed by the parallel session (light moved inside the glass). Check that it holds in Iteration B |
| 3123 | Generator cage | Dense 6 mm wire grid hides the engine; engine is boxes | Geometry | `build_generator` | Open → Iteration B |
| 3123 | Stair door | Flat slab, no hardware | Geometry | `build_stair` door() | Open → Iteration B (keep `PT_stair_door` pivot and "bolted for the night") |
| 3116 | Storage shelf | Placeholder boxes and a torus | Geometry / content | `build_storage` | Open → Iteration B |
| 3118 | Radio | Mic is a rod on a disc; low-detail casing | Geometry | `build_desk` mic() | Open → Iteration C |
| 3120 | Windows | Heavy box frames; rust-brown steel instead of dark green | Geometry / material | `build_shell` window bays | Open → Iteration B/D |
| — | Green machinery | Reads as dark striped wood | Material | `M_LL_SteelPaint` grade in materials.gd (contrast 1.35) | Open → Iteration D (the other session may be on it) |
| — | Photography artefacts (moiré, glare) | Not assessable | — | Photos not supplied | n/a |

## Iteration A: what changed
| Area | Change |
|---|---|
| `blender/build.py` | `lathe()`, `prism()`, `tag()`. Multi-material `part(extra_mats=…)`. New `gauge()`, `needle_fn()`, `selector_fn()`. Console hood rebuilt with a sloped front; ring flange. `logbook()`, `photo_frame()`. Clock minute hand +4 mm. `TEXTURED` += `M_LL_Photo`, `M_LL_Logbook` |
| `blender/photo_render.py` (new) | Cycles render of Iain (48) and Callum (22) at the tower door, May 1952. CC0 Human Base Meshes in procedural NLB uniform, ASSET_lighthouse behind. About 10 min. **Not in the pipeline**: rerun only when the photo scene changes |
| `blender/documents.py` | `silver_print()` grade; `photo_keepers` from the render; writes `tex/T_LL_Photo.png` and `tex/T_LL_Logbook.png`. 13 Nov entries are routine only: weather, lamp, engine run, battery, radio check, all in Callum's hand |
| `blender/textures.py` | Clock maker plate; MANUAL label; selector index ticks |
| `blender/pipeline.sh` | Runs documents.py |
| `godot/scripts/fp/station.gd` | Photo and Logbook textures: mipmapped, anisotropic, roughness 0.5 / 0.88 |
| `godot/scripts/capture_fp.gd` | 8 close-up views plus `doc_<id>` inspection shots |

Hooks are unchanged (`NDL_*`, `PT_mode`, `PT_intensity`, `IA_photo`, `IA_logbook`, …): `test_last_light_hooks.py` passes.

The room grew **+6,250 render triangles** (45,660 → 51,910) and **+5 meshes**.

## Known limits after Iteration A
- The keepers' photograph is grey-toned 3D, not photographic. The figures stand in a stiff A-pose and the tower has no texture. It is readable and story-correct, and a better scene can replace it at any time by rerunning `photo_render.py`.
- In-room, the photo and the charger cabinet are dim since the parallel lighting changes. Readability there depends on the lighting pass.
- The ledger handwriting is too small to read from the chair. That's intended: the inspection view (E) shows the full page.
