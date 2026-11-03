# THE LAST LIGHT: game design document

The player is a lighthouse keeper. One night of storm, one lamp, ships sailing blind toward a reef. The player turns the beam to give each captain their bearings before they strike.

## 1. Player experience
- **Sees:** an elevated three-quarter view of a small rocky island and its lighthouse. A warm amber beam sweeps through fog and rain. Ships' lamps appear out of the dark, and lightning briefly reveals the reef ring.
- **Hears:** wind, rain, the sea, the hum of the lamp's machinery, distant thunder, ship horns, a warning bell, and a soft chime for every ship guided home.
- **Controls:** one beam (turn it, boost it).
- **Goal:** keep the light until dawn without losing five ships.
- **Emotional arc:**

| When | Feeling | What happens |
|---|---|---|
| 0:00–0:45 | Curiosity | One slow fishing boat, gentle prompts |
| 0:45–1:45 | Understanding | Pairs of ships; the boost is introduced |
| 1:45–3:00 | Rising tension | The storm builds; ships arrive from opposite sides |
| 3:00–4:30 | A difficult stretch | Steamers, squalls, thick fog, three ships at once |
| 4:30–5:00 | Climax | A convoy of six in quick succession, heavy lightning |
| End | Release | Dawn breaks, or the night is lost |

## 2. Core loop
1. A ship appears on the storm horizon (170 m out), sailing a blind course toward a specific reef.
2. The player turns the beam onto it.
3. While lit, the ship slows to 70% speed and steers for the nearest safe channel, and its **bearings ring** fills.
4. When the ring is full, the ship has found its bearings: its lamp turns green and its horn sounds. It sails through the channel and out of the lagoon, and is **guaranteed safe**.
5. An unlit ship's ring drains, at 12% per second, and the ship drifts back onto its blind course.
6. If a ship strikes rock before its ring is full, it is lost.
7. Several ships overlap, so the player must choose who to save first.

The rule players learn: **fill the ring before impact and the ship is saved.** It's deterministic, readable and skill-based.

## 3. Controls
| Input | Action |
|---|---|
| A / D, ← / → (gamepad left stick or d-pad) | Turn the beam. Eased acceleration, 70°/s top speed |
| Space (gamepad A), hold | Boost: ring fills twice as fast, cone widens from 6° to 10°, range grows from 185 to 215 m. Burns oil at 22/s |
| Esc / P (gamepad Start) | Pause |
| F11 | Fullscreen |
| Mouse | Menus |

## 4. Systems and numbers (`godot/scripts/core/game_config.gd`)
- **Oil (energy):**
  - 100 maximum;
  - regenerates at 7/s, starting 0.6 s after the boost is released;
  - empty means a lockout until oil is back at 30;
  - below 25, a low-oil warning plays.
- **Ships:**

  | Type | Speed | Turn rate | Light needed | Value | Hull radius |
  |---|---|---|---|---|---|
  | Fishing | 7.0 m/s | 28°/s | 2.0 s | 100 | 2.5 m |
  | Schooner | 5.5 m/s | 18°/s | 3.0 s | 150 | 3.5 m |
  | Steamer | 4.0 m/s | 11°/s | 4.5 s | 250 | 5.0 m |

- **Danger:**
  - a red lamp, a "!" marker and the warning bell trigger when impact is under 6 s away;
  - storm speed rises up to ×1.12;
  - squalls (telegraphed 2.5 s ahead) push ships that haven't found their bearings sideways at up to 2 m/s.
- **Score:**
  - each ship's value × a streak bonus (+10% per consecutive rescue, capped at +50%);
  - +50 for a close call (bearings found with impact under 3 s away);
  - the personal best is kept for the current session.
- **Win and loss:**
  - five ships lost means defeat;
  - surviving the 330 s night (shown as 22:00 → 05:00) with every ship resolved means victory;
  - victory earns a 1–3 star rating: ★★★ for at least 95% rescued, ★★ for at least 80%, ★ otherwise.
- **Restart** builds a fresh `SimWorld`; nothing carries over except the session best.

## 5. World (`blender/spec.py` → `layout.json`)
- **Island:** radius 21 m at the origin, with a 15 m tower.
- **Reef ring:**
  - radius 62 m, spanning bearings −78° to +78°;
  - three 19 m channels, at −46°, 0° and +46°;
  - a back row of rocks and four isolated outer reefs.
- **Safe routes:** channel approach → channel → lagoon → side exit, east or west. They are checked by `layout.py`: no route comes within ship radius plus 1 m of rock.
- **Camera:** elevated three-quarter view from the south (about 44° down, 44° FOV), with gentle sway and a ±2° lean toward the beam.

## 6. Replayability
Each night is seeded with jitter (±2.5 s timing, ±7° bearing, ±6% speed) and a randomly chosen blind-course reef per ship. Scores and streaks reward clean play, and the session best gives a reason to try again. There are no accounts and no unlocks.

## 7. Fairness gates (`godot/tests/sim.gd`, seeds 1–10)
| Bot | Gate |
|---|---|
| Idle | Loses every seed |
| Expert | Wins every seed. Proves every spawn is saveable |
| Average (0.6 s reaction, 3° aim noise, naive priorities) | Wins at least half the seeds, losing 1–4 ships |

Additionally, no ship ever wrecks after finding its bearings.
