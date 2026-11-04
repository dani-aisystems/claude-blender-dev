# THE LAST LIGHT: reference-based reconstruction spec

- **References** (supplied in chat on 2026-11-03; not stored in the workspace):

  | Ref | Content |
  |---|---|
  | R1 | Top-down floor plan |
  | R2 | Isometric cutaway |
  | R3 | First-person interior |
  | R4 | Architectural cutaway. **Not received:** attachment #4 duplicated R3. Daniel approved proceeding without it; lantern, optic and lower levels follow real lighthouse practice |

- **Orientation:** bearing 0° = north = the top of R1 = the window arc facing the sea. Bearings run clockwise (east = 90°).
- **Units:** metres. The room floor is at z = 20.0 (Blender).

## Resolving conflicts between the references
| Conflict | Decision |
|---|---|
| R3 puts the electrical cabinet between the windows; R1 and R2 put it on the west wall | **Follow R1 (the layout reference).** R3 drives eye height, mood, density and materials only |
| R2 and R3 show a full Fresnel lens *inside* the control room, which is architecturally impossible: the optic must sit in the lantern above | Model it as the **optic drive housing**: a glazed brass clockwork column in the north-east corner, rising through the ceiling to the lantern. It shows rotating gears and a lens-like glazed drum, keeping the silhouette while staying plausible. The real Fresnel optic is in the lantern room |
| Floor: R1 polished concrete with a compass-rose inlay; R2 diamond plate; R3 boards and a rug | **Dark polished concrete** with a brass compass-rose inlay at the centre, and a Persian-style rug under the desk chair |
| My previous room (`48becde`) was octagonal with a central brass column | **Replaced:** circular, central floor kept clear as in R1 |

## Asset inventory
Columns: Asset · Ref · Geometry and dimensions · Material · Interactive · Complexity · Exists already?

### Essential architecture
| Asset | Ref | Geometry / dimensions | Material | Int. | Cx | Exists? |
|---|---|---|---|---|---|---|
| Room shell | R1, R2 | Ring wall: Ø6.5 m inside, 0.55 m thick, 3.1 m high, 96 segments | Weathered concrete (inner face), lower band dark | no | M | octagon → rebuild |
| Window bays | R1–R3 | 3 flat-glazed bays centred at −36°/0°/+36°, about 1.7 m chord each. Sill 0.95, head 2.55. Set in the wall depth | Steel frames (riveted), glass with a rain shader | no | M | rebuild |
| Window frames | R2, R3 | Heavy outer frame plus 2×2 panes per bay, rivets | Dark painted steel | no | M | rebuild |
| Wainscot | R3 | Curved wood panelling under the windows, 0.05–0.95 m | Dark aged oak | no | L | rebuild |
| Floor | R1 | Disc slab plus compass-rose inlay (Ø1.2 m) | Dark concrete; brass inlay | no | L | rebuild |
| Ceiling and beams | R2, R3 | Slab, 8 radial steel I-beams, ring beam | Concrete; rusted steel | no | M | rebuild |
| Conduits and pipes | R1–R3 | Two ring pipes at 2.75/2.9 m; vertical runs to each device | Galvanised/rusted steel | no | L | partial |
| Stair housing | R1, R2 | Riveted steel box, 1.3 × 1.3 × 2.3 m, at 180°. Open bulkhead door; spiral stair descends through the floor | Riveted steel; tread plate | no (door is static) | M | new |
| Bulkhead wall lamps | R1, R2 | Caged lamps at −48°, 62°, ±160° | Brass, glass, cage; warm light | no (fed by the ROOM LIGHTS breaker) | L | new |

### Primary interactive (every control drives real sim state)
| Asset | Ref | Placement / dimensions | Controls (hook names) |
|---|---|---|---|
| Navigation desk | R1–R3 | 0°: 2.2 × 0.85 × 0.78 m, two drawer pedestals, chair, rug | Hosts the radio, radar, chart (`IA_chart`) and logbook (`IA_logbook`) |
| Radio transceiver | R3 | On the desk, left of centre. 0.55 × 0.32 × 0.26 m. Amber dial window, microphone on a stand | `IA_radio` focus view; `NDL_signal`; `LMP_radio_rx`/`tx`; `PT_volume`/`channel` |
| Radar scope | R1 (grey box on the desk) | On the desk, right of centre. 0.42 m cube with a hooded CRT | `SCR_radar` (live render), `IA_radar` |
| Charger cabinet | R1, R2 | −55°: wall cabinet, 0.85 × 0.8 m | `NDL_battery`, `NDL_charge_amps`, `PT_charge`, `LMP_charge` |
| Distribution cabinet | R1, R2 | −80°: floor cabinet, 0.9 × 0.45 × 1.85 m | `PT_brk_main`/`lights`/`radar`, `LMP_main` |
| Battery bank | R1, R2 | −105°: 2-tier rack, 1.2 × 0.5 × 0.95 m, 12 cells with red terminals | Visual only, read through `NDL_battery` |
| Generator cage | R1, R2 | −140°: 1.6 × 1.5 m mesh cage; green diesel engine with flywheel and radiator; exhaust through the wall | Cage-front control box: `NDL_fuel`, `NDL_temp`, `PT_start`, `LMP_gen_run`/`hot`; `PT_fuel_valve` on the fuel line |
| Light console | R1–R3 | 78°: angled steel console, 1.6 × 0.85 × 1.05 m | `PT_wheel` (handwheel), `NDL_bearing` (large dial), `NDL_motor`, `PT_mode`, `PT_intensity`, `LMP_motor_fault`/`console_power` |
| Optic drive housing | R2, R3 | 45°: brass column, Ø0.7 m, floor to ceiling, glazed | `PT_optic_drive` turns with the real beam bearing |

### Secondary detail
- **Desk:** desk lamp (`LIGHT_desk`), open logbook, chart, compass, binoculars, book stack, anchor mug, pencil cup, microphone stand.
- **Storage (125–155°, R1, R2):** shelving with crates, a red toolbox, a rope coil, a storm lantern and tins.
- **Fire extinguisher:** on the wall at 118°.
- **Other:** wall clock (`NDL_clock_h`/`m`), the keeper's orders notice, and a stool by the console.

### Exterior
- **Tower:** weathered grey concrete (R2), tapering from 4.8 m to 3.8 m radius. Coping blocks on the watch-room rim (R1 and R2).
- **Gallery:** an external grated catwalk with railing (R2). The exhaust stack runs up the outside at −150° (R2).
- **Lantern room:** glazed, with the rotating Fresnel optic (`PT_optic`) and a copper dome. This follows real practice, since R4 is missing.
- **Already in the game:** ocean, rocks and ships from `layout.json`, plus storm, fog and rain (M3 work).

## Comparison views kept for every iteration
| View | Matches |
|---|---|
| `plan` (top-down, ceiling hidden) | R1 |
| `iso` (cutaway from the south-west, ceiling hidden) | R2 |
| `fp_desk` (seated at the desk looking north-east) | R3 |
| `fp_power` | First person at the electrical panels |
| `fp_console` | First person at the light console |
| `ext` | Exterior inspection |

Blender renders and Godot captures use the same viewpoints, so geometry, scale, composition, lighting and materials are judged separately.
