# THE LAST LIGHT: game design (v2, first-person keeper)

v1 (a top-down beam-steering game) is preserved in git at `56e6231`. v2 keeps its world, its storm and its fairness tooling. The player now runs the station by hand, from inside it.

## Premise
It's 02:17. You are the sole keeper of North Point Light. Storm rising, batteries low, an old generator in the engine house below. Vessels are calling for help on the radio. Keep the light burning and bring them in through the reef until dawn (about 06:30 in game, about 11 minutes of play).

## The room (watch room, directly under the lantern)
- **Shape:** octagonal, 6.2 m across inside, 2.9 m ceiling.
- **Position:** about 20 m above the sea, on top of a 4.2 → 3.4 m radius tapered tower. The lantern room and optic sit above it.
- **Central column:** a brass drive column runs through the room's centre up to the optic.

| Wall (bearing) | What's there |
|---|---|
| N 0° (window) | **Light console:** mode switch (OFF / AUTO / MANUAL), manual handwheel, intensity selector (LOW / NORMAL / HIGH), motor-load ammeter, bearing repeater |
| NE 45°, E 90° (windows) | **Chart table:** coastal chart with reefs and the three channels, logbook |
| NW −45°, W −90° (windows) | **Radio desk:** VHF transceiver, handset, radar scope (PPI), desk lamp |
| SW −135° | **Generator remote panel:** fuel gauge, fuel valve, starter, temperature gauge, run lamp, CHARGE switch |
| SE 135° | **Power cabinet:** battery meter, charge ammeter, breakers (MAIN, ROOM LIGHTS, RADAR) |
| S 180° | Stair door, wall clock, photographs, safety notice |

## Controls
| Input | Action |
|---|---|
| WASD | Walk |
| Mouse | Look |
| E or left mouse button | Use the focused control |
| Shift | Walk faster (it's a small room, so modest) |
| Esc | Leave a device view, or pause |
| L | Logbook |

The radio desk and light console open a **device view**: the camera eases onto the device, the mouse cursor appears, and controls are clicked directly. Q/E or the arrow keys turn the handwheel. Esc or right-click exits.

## Systems (`godot/scripts/core/keeper_sim.gd`, node-free and tested)
### Power
- **Battery:** 0–100%. Loads drain it every second.

  | Load | Drain |
  |---|---|
  | Lamp, by intensity | LOW 0.20 / NORMAL 0.35 / HIGH 0.60 %/s |
  | Rotation motor (running) | 0.08 %/s |
  | Radio | 0.03 %/s, plus 0.10 %/s while transmitting |
  | Radar | 0.06 %/s |
  | Room lights | 0.05 %/s |

- **Generator:** in the engine house, started remotely.
  1. Open the fuel valve.
  2. Hold START for about 1.5 s; it cranks, then catches.
  3. Switch CHARGE on: +1.1 %/s.
  - Fuel burns while running, at 0.12 L/s from a 50 L tank.
  - Temperature rises while charging and falls when idle or stopped.
- **Battery at 0:** everything goes dark except the red emergency lamp. Restart the generator to recover.
### Malfunctions
Each has a cause, a warning, and a fix.

| Malfunction | Cause | Warning | Fix | If ignored |
|---|---|---|---|---|
| Overheat | Charging for a long stretch in the late storm | Temp needle in amber, warning lamp | Switch CHARGE off for a while | The generator shuts down at 100% and won't restart until it cools to 60% |
| Motor jam | Storm-driven (salt and ice in the gear race) | Grinding, ammeter in red, console lamp | Set mode to OFF, then back on | Main breaker trips after 8 s |
| Breaker trip | Overload from a jammed motor, or HIGH lamp + radar + transmitting with the generator off | Lights out, MAIN breaker handle down | Push MAIN back up at the power cabinet | — |
### The light
- **AUTO:** the optic turns at 12 rpm. Every ship within visual range has a reference.
- **MANUAL:** the handwheel slews the beam (max 40°/s) and holds it steady. A ship in the focused beam sees the light at 1.6× range and confirms visually.
- **Visual range:** LOW 90 m, NORMAL 140 m, HIGH 190 m, reduced by up to 45% as the storm thickens the fog.
### Ships and radio
- **Calling in:** ships call by name, for example "North Point Light, this is fishing vessel *Kittiwake*…". Transmissions are subtitled, with synthesized radio static and chirps.
- **Commands** (radio desk; each costs one transmission):

  | Command | Effect |
  |---|---|
  | Confirm Position | The ship reports bearing and range, and its radar blip is labelled |
  | Turn Port / Turn Starboard | Ordered heading −30° / +30° |
  | Reduce Speed | Toggles slow (55%) |
  | Hold Position | Heaves to and drifts |
  | Maintain Course | Resumes |

- **Ships that can't see the light** (out of visual range, or the lamp is dark) execute turns badly: ±25° error, and a 2 m/s storm set pushes them toward the reef.
- **Entering a channel:** a ship that can see the light, inside a channel's approach cone (within 28° of the channel axis, 60–140 m out), reports "We have the channel, proceeding in" and pilots itself to the harbour. That ship is saved.
- **Collision:** a ship that hits a reef is lost.
- **Radio static:** rises with the storm. Words in incoming text are masked, but Confirm Position always answers clearly.

## The night
| Stage | Time | What happens |
|---|---|---|
| 1 | 02:17 | Calm-ish, battery at 62%. *Kittiwake* (fishing) calls in; the logbook walks through Confirm Position and turns |
| 2 | ~2 min | A battery warning; the logbook explains the generator. *Gannet* (schooner) calls |
| 3 | ~4.5 min | Storm builds, fog closes in, first motor jam. *Corrie May* and *Lowestoft Star* overlap |
| 4 | ~8 min | *Meridian* (cargo steamer) drifting onto the eastern rocks, plus an overheat or breaker trip |
| 5 | ~10.5 min | The storm eases and dawn greys the windows. The coastguard radio calls the end of the shift; results show ships saved and lost, score and time |

- **Defeat:** three ships lost.
- **Score:** 1000 per ship saved, +250 when saved with the lamp never dark, minus 50 per 10 s of darkness.

## Migration plan
- **Reused:**
  - `layout.json` (reefs and channels), `Geo`, `LayoutData`;
  - the ship type data, storm curve and seeded jitter;
  - the bot simulation and capture harness;
  - the Blender pipeline;
  - the CC0 materials.
- **Rebuilt:**
  - the camera (first-person);
  - the direct beam control (now a physical console);
  - the ship rule (bearings meter → radio vectoring plus light visibility);
  - the HUD (now an in-world interface, prompts and subtitles only).
- **New:** watch-room GLB with named hooks; first-person controller; interaction framework; power, malfunction and radio systems; radar screen; rain-on-glass.

## Blender → Godot hooks (`watch_room.glb`)
| Name | Meaning |
|---|---|
| `IA_<id>` | Interaction volume (empty; its scale is the box size) |
| `PT_<id>` | Moving part. Pivot at origin; rotates about Blender local Z (= Godot local Y) |
| `NDL_<id>` | Gauge needle (same axis rule as `PT_`) |
| `LMP_<id>` | Indicator lamp |
| `SCR_radar` | Radar screen quad |
| `GLS_*` | Window glass |
| `*-convcolonly` | Collision proxy |
| `FOCUS_<id>` + `FOCUS_<id>_at` | Device-view camera eye and look-at point |
| `SPAWN_player` | Player start |
