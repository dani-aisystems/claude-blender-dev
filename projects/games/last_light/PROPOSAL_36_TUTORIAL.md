# Proposal 36: opening tutorial and player onboarding

**Status: AWAITING DANIEL'S APPROVAL.** It builds on item 8, the dark-arrival opening, which is approved and planned for G2. Items 8, 9, 16, 20, 25 and 27 are implemented regardless of this proposal. This proposal decides only how the teaching is paced and worded around them.

## 1. Research: principles that fit THE LAST LIGHT
These come from design knowledge of first-person and narrative games, such as Firewatch, Half-Life 2, Outer Wilds, Papers, Please, Return of the Obra Dinn and Subnautica. They are to be checked against playtests, not treated as measured.

1. **Teach with a reason to act.** Each control is introduced at the moment the fiction needs it. Darkness teaches the torch; a dead battery teaches the generator.
2. **One new verb at a time**, practised once before the next arrives.
3. **Prompts follow intent.** A control hint appears only when the player looks at the relevant object, or hasn't used the verb after a grace period, and never again once used.
4. **The world explains itself.** Instructions are on plates, notices and notes where a keeper would find them, with the HUD as the fallback.
5. **There's no fail state while learning.** The tutorial can't softlock: see the power guard (32) and the step objectives that track real state (9).
6. **Short text.** Objective steps are at most about eight words, and hints are one sentence.

**What the current ch1 already does well (audit, confirmed).** ch1 is already a tutorial: console → generator → charge → radio → radar → orders. The existing `hint` timers fire once each. The problems are:
- the order (lights before power);
- the long objective sentences;
- no steps;
- the E-key and dialogue clashes (7);
- no feedback on inspection (16).

**So the recommendation is to restructure ch1, not to add a tutorial mode.**

## 2. Chronological flow (proposed ch1 opening, all within the existing chapter)
| Stage | Beat (new or existing) | Mechanics taught | Player actions | Information shown | Systems |
|---|---|---|---|---|---|
| 1 Entering | `arrive` (new beat 0) | Look, move | The door shuts behind; look around the dark room | `ch1_dusk` thoughts (reordered, kept) + a hint after 8 s of no input: "{look} to look · {move} to walk" | 8, 9, 26 |
| 2 The torch | `arrive`, step 1 | Interact (E), equip (F) | Find the torch on the top storage shelf. Prompt "[E] Take the torch", then hint "{torch} switches it on" | The step "Find the torch" ticks on pickup. Hint shown only if the torch is still off after 5 s | 8, 9, 14 |
| 3 Power | `arrive`, steps 2–4 | Toggle (valve), hold (START), read gauges (inspect) | Open FUEL VALVE, hold START, switch CHARGE on | Steps: "Open the fuel valve", "Hold START until she catches", "Switch on the charge". The inspect lines (16) explain each gauge. The existing **KEEPER'S ORDERS** notice above the shelf (rule 2, "Run the engine to charge…") is the in-world reference | 9, 16 |
| 4 Lights | `arrive`, step 5 (`live`) | Cause and effect | Lights come on as charge flows | Step "The lights come on" ticks only on `sim.lights_on()`. One thought line | 8, 9 |
| 5 The cabin | `light` (existing, reworded) plus free exploration | Look at documents, the console | MODE AUTO, LAMP NORMAL; optional reading: note_046, coat note, photo, chart legend (27) | Console plates already say MODE and LAMP. The after-read thoughts (master §11.3) exist | Existing |
| 6 Radio | `radio_check` / `kittiwake` / `vector` (existing) | Enter the radio view (E on the radio), replies (1–4), advance (Space), select a vessel (Tab), orders (1–6), radar | Answer Morag; confirm Kittiwake; turn her onto the line | The first reply shows a one-time hint "Press 1–4 to answer · Space to continue". Order buttons glossed (27). Checklist steps for Kittiwake: "Select Kittiwake (Tab)", "CONFIRM POSITION", "Turn her onto 000°", "MAINTAIN" | 23, 25, 27, 9 |

**Pacing:**
- Stages 1–4 target 3–5 minutes.
- Stage 5 has no objective timer, but the next beat's objective is always visible.
- ch1 gains one beat (`arrive`). The old `engine` and `charge` beats fold into its steps, so the beat count goes **down** from 11 to 10.

## 3. Environmental storytelling and readable logs (existing objects only)
| Topic | Existing object | Change |
|---|---|---|
| Generator operation | KEEPER'S ORDERS notice (`blender/textures.py notice()`) | Wording kept. Possibly add "5. FUEL VALVE OPEN BEFORE START" as one line, if Daniel agrees |
| Battery | The same notice (rule 2), plus the inspect lines (16) | None |
| Lighthouse controls | Console plates; `note_046` (the handwheel procedure for ch2 and ch6) | The note becomes legible on the console (11) |
| Radio procedure | The coastguard card on the radio (`sked` quad) | Could carry "Ch 16 calling and distress · 'Over' ends a turn". A text change on an existing quad |
| Navigation terms | The chart document | Terms legend (27) |
| History | log_1953, clipping, inquiry extract, photos, letter | Unchanged. Their unlock points are story-gated (master §12) |
| Father and son | note_046 (I.M. and C.M. lines), photo_keepers, log_1953 | Unchanged |

## 4. Presentation
- **Order of preference:** the object itself (plates, notices) → step objective → a one-time contextual hint → an internal thought line.
- Hints are tracked by the existing `used_<device>` and `moved` / `looked` flags (`game_fp.gd:524,604`). A hint never shows once its verb has been used. This is already how the `hint` timers work, extended per verb.
- **No modal pop-ups, no pausing tutorial cards,** and no control lists beyond the existing Options → Controls screen.

## 5. Dependencies
- 8: the opening.
- 9: steps.
- 16: inspect lines.
- 20: objective layout.
- 23: radio targeting.
- 25: number keys.
- 26: the arbiter, so hints don't collide with lines.
- 27: glosses and legend.
- 32: the power guard.
- 14: torch equip, with the hand animation if G3 is done.

**Order:** G1 → G2 (the tutorial wording lands with 8 and 9).

## 6. Frustrations and softlock risks, with mitigation
| Risk | Mitigation |
|---|---|
| Can't find the torch in the dark | The red stair lamp lights the shelf edge (the shelf is at 128°, next to the 170° door, about 1.5 m away); the torch's chrome bezel catches it. Hint after 20 s: "The torch is kept on the top storage shelf" |
| Fuel wasted, or the engine overheats in the tutorial | 32's top-up, plus an inspect line warning at 85 °C |
| The player turns the lights breaker off | The step is `live`, so it un-ticks; the inspect line on the panel says why |
| Ignores the radio | The existing hints at 45 s and 90 s; the radio scenes wait (32) |
| Locked out by an open document or the pause menu | Documents already pause the typing; the arbiter queues |

## 7. Acceptance criteria and testing
- A new player (Daniel) reaches lit lights in 5 minutes or less without reading anything outside the game.
- Every step ticks only on real state (story_test per-tick assertion).
- No hint repeats after its verb is used (story_test hint log).
- The bot completes ch1 with the new beats; all four endings pass.
- regress checks for 7, 23 and 25.
- Captures of the dark arrival, the torch beam, the lights on and the radio-view hint.
- **NOT TESTABLE by Claude:** whether it *feels* natural. That's Daniel's playtest.

## 8. Roadmap integration
- Stage 2 iteration 2E, with the G2 work.
- No new stage.

## 9. Decisions for Daniel
- **A.** Approve the restructure (§2).
- **B.** The optional line 5 on the KEEPER'S ORDERS notice, and the radio-procedure line on the coastguard card (§3).
- **C.** D8 from the findings log (flat battery, versus breaker off with MAIN tripped).
