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

## Stage 1 review (step 1.0, 2026-11-04): period accuracy and story readiness
This section **overrides** the material and finish columns above wherever they conflict (Daniel's Stage 1 decisions in `docs/ROADMAP.md`). The layout, bearings and every hook name stay as above.

### Finish and condition: "maintained but aged" (a 1971 Northern Lighthouse Board station)
- **Look:** a proud, clean station, not a derelict one.
  - Gloss **cream** walls (#D6C9A6) above a **dark-green dado** (#2E4537) to 1.05 m, with a half-round oak dado rail and dark skirting.
  - **Grey-green machinery** (#66796B), polished **brass** (#B58A3C), varnished **oak** (#7A4E2A / dark #4A2E1A), bakelite controls (#1A1412).
  - **Dark-green window frames.**
  - **Dark polished concrete** floor (#4A4743) with the brass compass rose and the rug.
- **Wear** shows 20+ years of careful use, not neglect:
  - paint chipped at hand height and on edges;
  - dull, worn traffic paths between spawn, desk, console, power wall and generator;
  - brass rubbed bright where it's handled;
  - touched-up paint in a slightly different cream;
  - riveted patch plates.

  No rust streaks, peeling paint or grime build-up indoors. Weathering belongs outside.
- **Superseded entries above:** "Weathered concrete (inner face)", "Dark aged oak" (now varnished oak), "rusted steel" beams (now grey-green riveted steel), and "Dark painted steel" frames (now dark green).

### Infrastructure logic: the room is one working system
Any reference-image detail that conflicts with this logic is **dropped**, not blended in.

| System | How it works in 1971 | What the player sees |
|---|---|---|
| Power chain | Auxiliary generator → charger → battery bank → distribution cabinet → lamp, room-lights and radar circuits | Visible surface conduits link the units in exactly that order, along the dado and ceiling. Each cabinet's cables enter where the previous one leaves |
| Generator | A small **auxiliary standby diesel set** in the watch room. The main engines are in the engine room below and **out of action tonight** | Fuel day-tank on a bracket with sight glass and valve (`PT_fuel_valve`); lagged exhaust through the wall at −150° (it meets the exterior stack); extractor fan grille; drip tray; an "AUX. SET" maker plate; a capped pipe run marked "MAIN ENGINES" going down through the floor |
| Optic rotation | An **electric rotation motor and reduction gearbox** drive the optic through a vertical shaft to the lantern. The original **weight-driven clockwork** is kept as standby on the same gear race | The glazed column at 45° shows the motor and gearbox, the clockwork train with its winding crank, the weight-tube entry through the floor, a **fly-ball governor** (new `PT_optic_governor`), a revolution counter, and the **gear race** (`PT_optic_drive`). No lens parts: the Fresnel optic is in the lantern |
| Manual fallback | The console handwheel (`PT_handwheel`) turns the optic by hand through the ceiling lineshaft when the motor jams | The lineshaft runs visibly from the console's position, across the ceiling to the column's hub, with bevel boxes at the turns |
| The lamp | Electric. It sits in the lantern above; the console's intensity switch sets it | Nothing lamp-like in the room. The storage shelf holds a spare bulb box and, as a story prop, the **old vapour-burner kit** from before electrification (1953's lamp was a vapour lamp) |

### Story anchors (place now; most interactions come in later stages)
Reserve these with non-interactive `ANCHOR_*` empties (Godot ignores them) and clear wall or shelf space:

| Anchor | Where | Story use | Stage | Exists? |
|---|---|---|---|---|
| Gear race worn tooth at **046°** | Optic column, visible through the glazing at eye height | The 1953 stall and the 1971 jam happen on the same tooth (ch2, ch6). It could become an examinable detail | 1 (geometry); 2/3 (examine) | ⬜ |
| Admiralty Tide Tables plus a **half bottle of Grant's behind them** | Desk or storage shelf | The Visitor knows it's there (ch4), proving he knew the room | 1 (prop); 3 (examine) | ⬜ |
| Door gap and **floor anchor for the slid photograph** | Inside the stair door at 180°; a visible 20 mm light gap under the door | ch4 "keep it shut" branch: a photograph slides under the door. `photo_1953.png` exists but nothing opens it yet | 1 (gap and anchor); 3/4 (interaction) | ⬜ |
| Door audio emitter | Stair-door centre, 1.6 m | Knocks, voice and footsteps (`audio_director` currently uses a fallback position) | 1 (anchor); 5 (audio) | partial |
| Heavy bulkhead door | 180° | It must *look* like it holds back the night: dogs, rattling bolt, door coaming | 1 (iteration 2) | basic |
| Wall calendar, November 1971 | Near the desk | Anchors the date. The 14th could be ringed | 1 (iteration 4) | ⬜ |
| Wiring and maintenance diagram | Power wall | Explains the power chain; could carry a hint later | 1 (iteration 4) | ⬜ |
| Logbook shelf | Desk or archive | The 1971 and 1953 logs belong to one series of station logs | 1 (iteration 4) | partial (archive) |
| Telephone | Reserved space by the desk only | **Candidate.** The story's only link is the radio, and a telephone would weaken the isolation. Decide in Stage 3 | 3 | ⬜ |
| Existing story props | Photo `IA_photo`, drawer letter `IA_drawer`, 046 note `IA_note`, clock, chart | Already wired. Keep positions and hooks | (kept) | ✅ |

### Asset priority tiers (detail follows what the player sees and uses)
| Tier | Assets | Treatment |
|---|---|---|
| **P0** | Radio, generator controls, power panel (charger, batteries, distribution), light console, stair door | Highest detail. Must pass the full 8-item interaction checklist (`godot/tests/interaction_test.gd`) |
| **P1** | Windows, desk and chart, optic drive (gear race), stair, wall lamps | High-quality geometry and materials |
| **P2** | Storage, conduits, chair and stool, archive, secondary instruments, story props | Reusable modular pieces |
| **P3** | Rivets, bolts, distant machinery, clutter | Cheap: decals and texture detail; shadows off |

**Rule for new objects:** each one gets a row in the props table, stating what it adds (gameplay, realism, story or composition). An object with no answer isn't built.

| Planned object | Tier | Adds | Iteration |
|---|---|---|---|
| Fuel day-tank, extractor grille, "AUX. SET" plate, "MAIN ENGINES" capped pipe | P0/P2 | Realism: explains why a generator is in the watch room | 3 |
| Power-chain conduits | P2 | Realism and gameplay: shows the power flow | 2 |
| Optic motor, gearbox, standby clockwork, governor, revolution counter, gear race with a worn tooth | P1 | Realism; story (046°); gameplay (the governor spins with the beam) | 3 |
| Vapour-burner kit and spare bulb box on the storage shelf | P2 | Story: 1953 versus 1971 | 4 |
| Tide Tables plus the half bottle of Grant's | P2 | Story (ch4) | 4 |
| Door gap plus floor anchor | P1 | Story (ch4 branch) | 2 |
| Calendar, wiring diagram, logbook shelf | P2 | Story and composition | 4 |
| Oilskins and sou'wester on a hook by the stair | P2 | Composition: a lived-in room that mirrors the Visitor's look | 4 |
| Kettle on an electric ring, mug rings | P3 | Composition: the keeper's night | 4 |
| Barometer | P2 | Realism: the storm builds | 4 |

## Comparison views kept for every iteration
| View | Matches |
|---|---|
| `plan` (top-down, ceiling hidden) | R1 |
| `iso` (cutaway from the south-west, ceiling hidden) | R2 |
| `fp_desk` (seated at the desk looking north-east) | R3 |
| `fp_power` | First person at the electrical panels |
| `fp_console` | First person at the light console |
| `ext` | Exterior inspection |
| `fp_ceiling`, `cu_lamp`, `cu_optic`, `cu_console`, `cu_power`, `cu_window`, `cu_door` | Stage 0 close-ups. Forced states: `!dark`, `!flash`, `!gen_off`, `!dawn` (see `godot/scripts/capture_fp.gd`) |

Blender renders and Godot captures use the same viewpoints, so geometry, scale, composition, lighting and materials are judged separately.
