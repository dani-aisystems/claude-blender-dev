# THE LAST LIGHT: narrative audit and story directions

## Audit (2026-11-04)
| Area | State | Verdict |
|---|---|---|
| First-person movement and collision | Works (WASD, mouse, capsule, wall/furniture colliders) | Keep |
| Watch room geometry | Rebuilt from R1–R3. Circular, 6.5 m across | Keep. Add a dock, an exterior path and a working stair door for the visitor |
| Generator and battery | Full sim: valve, start, charge, temperature, fuel, overload | Keep; story-script its faults |
| Radio | Orders to ships through a panel; subtitles only | Rebuild as the dialogue system's radio mode |
| Ship navigation | Radar, vectoring, channel capture, bots prove it solvable | Keep for set-piece rescues |
| Menus | Title screen over a live exterior shot; no options or saves | Rebuild |
| Dialogue infrastructure | None | New: data-driven, branching, typewriter |
| Save/load | None | New |
| Cinematic transitions | Fade-in only | New |
| Environmental audio | **None yet** | New (synthesised; no downloads) |
| Lighting and weather | Storm sky, Gerstner ocean, rain glass, beam, lightning | Keep and tune |
| Performance | 60 fps when the window was frontmost; about 22 fps when the window may not have been in front, which even half-res and every heavy effect off didn't change (macOS throttling suspected) | **Not verified.** Daniel needs to run `tools/godot --path projects/games/last_light/godot -- --windowed --capture=perf --shots=40@fp_desk` at the desk |

**Constraints:**
- No AI-generation APIs (CLAUDE.md). Portraits and voices must be made in the workspace.
- Two hours of play can't be verified by me: the bots test logic, not feel.

## Three directions

### A. "The Mary Ellen Inquiry" (recommended)
| | |
|---|---|
| **Setting** | North Point Light, Outer Hebrides, the night of 14–15 November 1971 |
| **Central mystery** | In 1953 the light failed for eleven minutes during a gale, and the trawler *Mary Ellen* went down on the East Gut rocks with eight men. The inquiry blamed her skipper, Alasdair Ross, whose body was never found. Tonight a boat on Channel 16 calls herself *Mary Ellen* |
| **Protagonist** | Callum Mackay, 41, principal keeper. In 1953 he was the 23-year-old assistant keeper under his father, Iain |
| **Supporting cast** | Morag Fraser (Stornoway Coastguard radio officer, his oldest friend); Ruaridh "Rory" Bain (young skipper of the fishing boat *Kittiwake*); Elspeth Ross (Alasdair's daughter, now a ferry mate); the Visitor |
| **Conflict** | What really happened in the lamp room that night, and who wrote the logbook |
| **Theme** | Guilt, loyalty to the dead, the cost of a protective lie |
| **Hook** | A routine watch, then a call on 16 using a call sign retired eighteen years ago |
| **Twist** | The logbook entry that blamed Ross is in Callum's own handwriting. Iain was drunk; young Callum restarted the light and wrote the lie his father dictated. The Visitor is Alasdair Ross: alive, washed up on Pabbay, living eighteen years under another name |
| **Suspense set piece** | The unlit boat docks below. Iron steps on the gallery, the stair door, three knocks, and a calm voice that knows the lamp room better than a stranger should |
| **Climax** | Elspeth's ferry loses steering in the same gale and drifts onto the same reef. The lamp's motor fails on the same bearing as in 1953. Callum and Ross keep the light together, by hand, while Callum talks the ferry through the East Gut |
| **Ending** | Callum chooses what to send on the radio: the truth, or the lie kept alive. The final log entry is written in his hand |
| **Gameplay fit** | Excellent: every system (light, power, radio, ships, logbook, door) carries the story |
| **Complexity** | Medium. One room, radio voices, one in-person character mostly heard through the door, a dock and exterior path |

### B. "Relief"
| | |
|---|---|
| **Setting** | 1961. The protagonist is a relief keeper sent to replace a keeper who vanished a week earlier |
| **Mystery** | Where did Thomas Gray go? |
| **Twist** | The protagonist is not who the Board thinks: he is Gray's brother, here to find him |
| **Strengths** | Strong isolation horror |
| **Weaknesses** | Leans on a famous real-world lighthouse mystery, so it risks feeling derivative; less use of the ship and radio systems |
| **Complexity** | Medium-high (needs more explorable space) |

### C. "Hesperus"
| | |
|---|---|
| **Setting** | 1962, the Cuban crisis week. A Royal Navy minesweeper the Admiralty says doesn't exist calls for help. The captain at the door is a defector, and the lighthouse is a relay station |
| **Strengths** | Tense thriller |
| **Weaknesses** | Spy exposition, needs more characters and world beyond the room; the emotional core is weaker |
| **Complexity** | High |

**Why A:**
- It is the most original of the three and fully grounded: no supernatural device.
- The twist is foreshadowed by objects already in the room (the logbook, the clock, the chart's East Gut, the motor that jams).
- The visitor scene grows out of character, not shock.
- It fits the single-room scope and turns every existing mechanic into story.

---

# Selected: A, "The Mary Ellen Inquiry" (Daniel, 2026-11-04). Voices: text plus synthesised radio sound

## What really happened (the truth the player uncovers)
| Time | 14–15 November 1953, south-westerly gale |
|---|---|
| 23:30 | Principal keeper **Iain Mackay** (49) takes the middle watch. He has been drinking since his wife's funeral in October. Assistant keeper **Callum Mackay** (23), his son, is asleep below. |
| ~01:40 | The rotation clockwork stalls at **046°** on a worn tooth in the gear race; the same fault is still there in 1971. The lamp keeps burning but stops turning, aimed at nothing, and the vapour lamp starves and gutters out minutes later. Iain is asleep in the chair. |
| 01:52 | Stornoway Coastguard (radio officer **Morag Fraser**, 26, on her first winter) logs a Mayday from the trawler *Mary Ellen*, SY 214, skipper **Alasdair Ross**: *"…no light at North Point, repeat no light…"* |
| 01:58 | *Mary Ellen* strikes the East Gut rocks. Seven of eight crew lost. |
| 02:01 | Callum, woken by the silence of the clockwork, relights the lamp and frees the gear by hand. |
| 03:00 | Iain dictates the log entry and makes Callum write it in his own neat hand: *"02:10. Light extinguished approx. 2 min (mantle). Relit 02:12. Trawler observed standing in too close at 01:30, no response to light."* The failure is moved to after the wreck, and the blame falls on Ross. |
| 1954 | The Inquiry relies on the light's log. Ross is "presumed lost" and blamed: *"…the master failed to keep a proper lookout and stood into danger despite the light being exhibited."* His wife and daughter are shamed out of Leverburgh. |
| The truth | Ross survived: he clung to the wheelhouse roof and washed up on Pabbay with a broken pelvis. Ashamed and believing he must have missed the light, he let the world think him dead. He became "Sandy Morrison", boatbuilder, in Govan. In 1969 he read the Inquiry report in a library and saw that the times were wrong. He wrote to the Northern Lighthouse Board and got no answer. He is now dying (lungs), and his daughter Elspeth is mate on the *Iona Star*, which crosses the Minch tonight, the anniversary. |
| 1958 | Iain dies, leaving an unsent letter to Callum in the desk drawer. |

## Characters
Each entry covers name, age, role, personality, motivation, fear, hidden information, voice, arc, key scenes, look, and connection to the mystery.

### 1. Callum Mackay, 41, principal keeper of North Point Light (protagonist)
- **Background:** he has kept lights for 21 years. North Point is his home light; he asked for it.
- **Personality:** meticulous, dry humour, guarded, kind to young skippers.
- **Motivation:** keep the light, keep the peace.
- **Fear:** becoming his father, and being found out.
- **Hidden:** he wrote the 1953 log entry.
- **Voice:** few words; correct radio procedure; quiet Hebridean idiom ("aye", "right enough"). Player choices give him options between protective and honest.
- **Arc:** silence → truth (or the protective lie kept, if the player chooses).
- **Key scenes:** the first Mary Ellen call, the door, the drawer letter, the climax, the final log entry.

### 2. Morag Fraser, 44, radio officer at Stornoway Coastguard (MRSC)
- **Relationship:** Callum's oldest friend from school in Tarbert; widowed (her man was lost on a drifter in '62).
- **Personality:** crisp on air, warm off-procedure after midnight, stubborn.
- **Motivation:** a quiet watch; and the 1953 Mayday she has never been able to put down.
- **Fear:** that she was wrong about the time, or right.
- **Hidden:** she kept her own pencilled notes of that night: Mayday 01:52, "no light".
- **Voice:** "North Point, Stornoway, over"; first names slip out when she's worried.
- **Arc:** comfort → confrontation → ally.
- **Key scenes:** the radio check (ch 1), tracing the call (ch 2), confronting Callum over the times (ch 3), coordinating the rescue (ch 6).

### 3. Ruaridh "Rory" Bain, 22, skipper of the fishing boat *Kittiwake* (inherited from his father)
- **Personality:** brave, chatty, superstitious, talks over himself.
- **Motivation:** get the catch home and impress the old men.
- **Fear:** being the boy who lost his father's boat.
- **Hidden:** his grandfather crewed on *Mary Ellen*; he knows the island legend that her skipper is out there.
- **Voice:** fast, half-finished sentences, "och", "eh, sorry, over".
- **Arc:** the tutorial ship; later he spots the unlit boat in the lee of Pabbay and stands by during the climax.

### 4. Elspeth Ross, 29, first mate of the coaster MV *Iona Star* (Glasgow–Stornoway)
- **Background:** Alasdair Ross's daughter. She grew up as "the drowned drunk's girl" and went to sea to prove a Ross could be trusted on a bridge.
- **Personality:** exact, cool, very competent.
- **Motivation:** her ship, her crew, her name.
- **Fear:** the East Gut.
- **Hidden:** a month ago she received an unsigned letter: *"The light was out. Your father was not to blame."*
- **Voice:** clipped, formal, flawless procedure; ice when she hears "North Point".
- **Arc:** distance → trust (the climax depends on her following Callum's courses).

### 5. The Visitor, revealed as Alasdair Ross, 64, former skipper of *Mary Ellen*, living as "Sandy Morrison"
- **Personality:** calm, unhurried, old-fashioned courtesy, steel underneath.
- **Motivation:** to have the truth written in the light's own book before he dies, and to see his daughter's ship safely past the rock that took his crew.
- **Fear:** that he did miss the light after all.
- **Hidden:** he is dying; he sent Elspeth the letter.
- **Voice:** slow, precise seamanship; calls Callum "keeper", then "the boy", then "Callum".
- **Arc:** accuser → witness → partner on the handwheel.
- **Look:** oilskin, sou'wester, white stubble, a face mostly in shadow at the stair door.

### 6. Iain Mackay (1904–1958), former principal keeper; present through objects
- His 1953 logbook, a photograph on the wall, and the unsent letter in the desk drawer.

## Chapters
Target total about 2 hours; times are estimates until playtested.

| Ch | Title | Clock | Target | Immediate objective | Gameplay | Narrative development | Memorable moment | Ends with |
|---|---|---|---|---|---|---|---|---|
| 1 | The Watch | 21:40–23:58 | 15–20 min | Set the light, charge the batteries, answer the radio check, bring *Kittiwake* in | Tutorial: walk/look/use, console (AUTO, NORMAL), battery gauge → generator → charge, radio, radar, CONFIRM, two turns, channel | Morag's routine; Rory's chatter mentions "Ross's ghost boat"; the 1953 photo on the wall; today's date in the log: 14 November | Rory's boat appearing out of the rain under the beam | 23:58, weakly on 16: *"North Point… Mary Ellen… we cannot see your light."* The light is lit. |
| 2 | Strange Signals | 00:00–00:55 | 15–20 min | Find out who called | Bring *Gannet* in; RADAR shows a stationary echo at 046 that fades; read the 1953 log in the archive cabinet; motor jam | Morag: no *Mary Ellen* registered since '53; the caller asked for "Iain Mackay"; the 1953 entry is in *Callum's* handwriting (player sees the matching hand in tonight's log) | The archive scene: two logbooks side by side, the same hand | The motor jams at exactly 046°, the East Gut bearing; the maintenance note says that tooth has been worn since before the war |
| 3 | The Storm | 01:00–02:20 | 20 min | Keep the light through the gale | Overlapping rescues (*Corrie May*, *Lowestoft Star*), overheat and breaker trip, Elspeth's routine call | Elspeth learns the station name: *"My father's boat was lost under your light."* Morag off-procedure: *"I took that Mayday, Callum. Ten to two. He said no light."* A choice: lie, deflect or admit "I was there" | A power failure while Morag reads her 1953 notes; silence in the dark | An unlit boat on radar heading straight for the landing |
| 4 | The Visitor | 02:20–03:00 | 20–25 min | See who comes ashore | Track the boat; MANUAL beam reveals the bow numbers SY 214; she docks; engine and lights off; radio dead. Footsteps on the jetty, the base door, the stair, then silence; three knocks. Door choices: talk, ask for identification, call Morag, check the 1953 log, open | The voice knows the gear race, the half bottle of Grant's behind the Admiralty Tables, and Iain's name | The knock, and the line: *"Evening, keeper. I could not see your light."* | Door open (he steps into the stair light) or kept shut (he slides a photograph under the door). Both lead to ch 5 |
| 5 | The Truth | 03:00–04:10 | 20–25 min | Hear him out; find what Iain left | Search the desk (Iain's letter), the photograph, Morag on the radio; a conversation with branches that remember earlier choices | Ross's story; Callum's admission (or not); Elspeth's ship loses steering in the gale, drifting for the East Gut | Reading Iain's letter while Ross waits in silence | Generator overheat **and** MAIN trip as the *Iona Star* Mayday comes in |
| 6 | The Last Light | 04:10–06:30 | 15–20 min | Bring the *Iona Star* through the East Gut | The motor jams at 046 again. MANUAL handwheel on the ship while vectoring Elspeth by radio; Ross can take the wheel if you ask, freeing you for power | Ross and Elspeth hear each other on 16 for the first time in eighteen years (if Callum lets him speak) | The beam held steady on a ship in the rain, two men at one wheel | Dawn. The final radio call to Morag: the truth, or nothing. The last log entry, in Callum's hand |

## Endings
Four outcomes, each with its own epilogue lines.

| | Truth told | Lie kept |
|---|---|---|
| **Iona Star saved** | Ross hears his name cleared on 16; Elspeth answers. Final log entry: *"Correction to entry of 15.11.53…"* | Ross leaves at dawn. Elspeth never knows. The log is clean and wrong. |
| **Iona Star aground** (crew taken off by the lifeboat) | Truth told in grief; Morag: *"Then we'll say it together."* | Silence, and a second inquiry |

## Story state (`StoryState`)
`chapter`, `beat`, `flags` (dictionary), `clues` (set), `choices` (dictionary), `rel` (morag, elspeth, ross: -3..3), `rescues` (name → saved/lost), `convs_done`, `log_lines` (dialogue history), `objective`.

## Set pieces (escalation)
1. The *Mary Ellen* call at 23:58 (ch 1).
2. The two logbooks in the same hand (ch 2).
3. Darkness during Morag's notes (ch 3).
4. The unlit boat, the footsteps, the three knocks (ch 4).
5. Iain's letter (ch 5).
6. Two men at one handwheel, the beam on the *Iona Star* (ch 6).

## Presentation rules
- **Radio mode:** a compact panel by the radio. Call sign and identity card (for ships: a vessel registry card; for Morag: the MRSC station card). Typewriter reveal with static, a signal meter and squelch tails.
- **In-person mode** (the Visitor): low subtitles only, no portrait. At the door he is a voice; once inside, a silhouette in the stair light.
- **Documents:** readable full-screen inspection with real, correctly written text.
