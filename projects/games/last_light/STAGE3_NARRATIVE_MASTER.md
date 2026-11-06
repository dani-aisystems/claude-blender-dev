# THE LAST LIGHT: Stage 3 master narrative script

**Status: APPROVED by Daniel 2026-11-06**, with fixes F1–F7 (§21). Written 2026-11-05 during iteration 3A.

This is being implemented in iteration 3B. Where this document and the `.dlg` / `chapters.json` / `docs.json` files disagree, this document wins until the 3B checkpoint.

**What this replaces.**
- `NARRATIVE.md` stays as the history of the 2026-11-04 direction choice.
- This document is the canonical story bible and script from now on.

**Scope (Daniel, 2026-11-05): "Targeted fill".**
- It fixes the verified continuity errors (C1–C13).
- It fills the plot holes (N1–N9) only from lore the game already implies.
- It adds no new characters and no new plot threads.

**How to read the script sections.**
- Each conversation is marked **KEPT**, **EDITED**, **NEW** or **RETIRED**.
- EDITED and NEW conversations are printed in full, in `.dlg` syntax, ready to transcribe.
- KEPT conversations are only referenced by id. Their text is in `godot/data/story/chN.dlg`.

**Syntax this script adds.** The 3A engine work implements all of it.

| Syntax | Meaning |
|---|---|
| `> [text]` | A **sound caption**: small caps, not italic. Captions describe sounds the player would otherwise only hear (there's no voice acting) |
| `SPEAKER@room:` | The speaker is **physically in the watch room** (or behind its door) even though the conversation is `mode=radio`. It renders as a person subtitle, not on the radio panel |
| `ROSS` / `VISITOR` | Resolved by the identity resolver. Both show **"The man at the door"** until `knows_name` is set. `MARY ELLEN` always shows as "Mary Ellen" |

---

## Contents
1. Story premise
2. Central mystery
3. Themes
4. Character bible, with a voice guide for each character
5. Complete timeline: the story bible
6. Six-chapter structure and pacing map
7. Scene-by-scene breakdown (every beat, with the 15 fields)
8. Dialogue scripts (every conversation, with its status)
9. Player choices
10. Conditional dialogue
11. Optional encounters
12. Environmental clues and document texts
13. Suspense sequences
14. Climactic moments
15. Four ending paths
16. Narrative-state dependencies: the flag map and the ending map
17. Expected playtime (design estimate)
18. Implementation requirements
19. Change log (C1–C13, N1–N9)
20. Open questions for Daniel

---

## 1. Story premise
**Setting.** North Point Light, Outer Hebrides, from Sunday 14 to Monday 15 November 1971: a south-westerly gale rising to storm 10.

**The keeper.** Callum Mackay, 41, principal keeper, is alone in the watch room under the lantern. He keeps the light and power running and talks ships in by radio and radar.

**The call.** Just before midnight a boat calls him on Channel 16. She names herself *Mary Ellen*, the trawler that went down on the East Gut rocks under this light eighteen years ago tonight.

**The visitor.** Later an unlit boat ties up at the landing. Footsteps climb the stair, and three slow knocks come at the door.

**The truth.** The man on the stair is the *Mary Ellen*'s skipper, Alasdair Ross, who is supposed to be dead. He has come for the truth about that night, and Callum is the one man who knows it.

**The climax.** Ross's daughter's ship loses her steering and drifts for the same rocks. The light jams on the same worn tooth. Callum has to keep it lit, talk her in, and decide what the station log will say at dawn.

## 2. Central mystery
**The surface question (chapters 1–4):** who is calling as the *Mary Ellen*, and what do they want with North Point?

**The real question (chapters 2–6):** what happened in this room on 15 November 1953, and why does the station log blame a drowned man?

**How the answer is controlled.** The player meets it in order:

1. **Ch1, Callum knows something.** He sat looking at the date this morning. Morag says, "It's the fourteenth." Rory's grandfather had his own ghost story.
2. **Ch2, Callum wrote the 1953 entry.** The player opens the 1953 log and sees tonight's hand. Callum's thoughts are evasive, not ignorant. **The player learns it before Callum says it.**
3. **Ch3, the entry is false.** Morag's notebook has the Mayday at 01:52 with "no light". The log has the light failing at 02:10.
4. **Ch4, the caller is someone who was there.** He knows the gear race, the bottle and the song. His boat is a Mary Ellen look-alike.
5. **Ch5, Ross explains the calls; the letter explains why.** Iain was asleep with the bottle, and he made the boy write it.
6. **Ch6, what Callum does about it.** It is the player's decision.

**Nothing in the mystery is supernatural.** Every eerie event has a grounded cause, and Ross admits to each one in ch5:

| Event | Cause |
|---|---|
| The carrier at dusk | Ross testing his set |
| The calls | Ross, on a low-power set in the lee of Pabbay |
| The echo at 046 | Ross's boat lying in the Gut |
| The dead Channel 16 | Ross's handset lashed keyed when he tied up |
| The jam | A worn tooth, reported in 1949, 1953 and 1961 |

## 3. Themes
- **The protective lie and its cost.** One lie told to shield a father becomes the only "truth" a town has about another man.
- **Loyalty to the dead and to the living.** Callum's loyalty to Iain stands against what he owes Ross, Elspeth and Morag.
- **Light as testimony.** "People always believe the light." The log is the light's voice, and it lied.
- **Handwriting as identity.** A clerk's hand convicts the one who wrote it. The same hand can correct it.
- **Isolation.** The radio is the only link, and even that can be silenced. The phone has been dead since September.

---

## 4. Character bible

### 4.1 Callum Mackay, 41, principal keeper, North Point Light (the player)
| Field | Detail |
|---|---|
| Narrative function | Protagonist and guilty party. The player decides how honest he becomes |
| Background | Born 1930 in Tarbert, Harris. Assistant keeper under his father at North Point from 1950 to 1955. Then postings at Rubha Rèidh and the Flannans *(postings: bible only)*. He asked to come back to North Point as principal keeper in 1962. 21 winters on the lights |
| Personality | Meticulous, dry, guarded. Kind to young skippers. Correct procedure as armour |
| Motivation | Keep the light. Keep the peace. Keep his father's name |
| Internal conflict | He loved his father, and he knows his father made him lie. Every honest act betrays one of them |
| External conflict | Morag's notebook, Ross's knock, Elspeth's ship |
| Conceals | He wrote the 1953 entry. In December 1953 he quietly re-reported the 046 tooth: a half-confession nobody read |
| Doesn't know | Iain's letter is in the bottom drawer, under the old tide tables nobody uses. Ross is alive |
| Relationships | Morag: oldest friend. Rory: a lad he looks out for. Hector: knew his father. Elspeth: the daughter he helped to shame. Ross: his father's friend, whom he helped to bury alive |
| Arc | Silence → evasion → (the player's choice) truth, or the lie kept on purpose |
| Key scenes | Ch1 the call. Ch2 the archive. Ch3 Morag's notes. Ch4 the door. Ch5 the letter. Ch6 the dawn report |
| Look (for 3C) | Lean, weathered. Dark hair greying at the temples, clean-shaven. NLB navy keeper's tunic with brass buttons over a grey wool jersey. Watchful, tired eyes |

### 4.2 Morag Fraser, 44, radio officer, HM Coastguard Stornoway
| Field | Detail |
|---|---|
| Narrative function | Conscience, investigator, and finally ally. The voice of the outside world |
| Background | Tarbert school with Callum (she was three years ahead). Joined the Coastguard radio room in 1953. In her first winter she took the *Mary Ellen* Mayday at 01:52 and pencilled "no light" in her own notebook. Her senior logged the call. The court called the message "confused and unreliable", and **she was never called to give evidence. She didn't push.** Her husband Donald was lost on a drifter in 1962 |
| Personality | Crisp and correct on air. Warm, teasing and stubborn off procedure after midnight |
| Motivation | A quiet watch. And the one Mayday she has never been able to put down |
| Internal conflict | Her guilt at staying silent in 1954. Her fear that she was wrong about the time, or that she was right |
| Conceals | The pencil notebook, kept in her handbag for eighteen years |
| Arc | Comfort (ch1) → probing (ch2) → confrontation (ch3) → fear for him (ch4–5) → partner in the truth (ch6) |
| Look | Auburn hair going grey, set in waves. Reading glasses on a chain. Coastguard navy cardigan over a white blouse. A Stornoway pin |

### 4.3 Ruaridh "Rory" Bain, 22, skipper of the fishing boat *Kittiwake* (SY 37)
| Field | Detail |
|---|---|
| Narrative function | Tutorial ship, warmth and humour. Carrier of the island legend. **Grandson of the sole survivor** |
| Background | Inherited *Kittiwake* from his father. His grandfather **Kenneth "Kenny" Bain** was the *Mary Ellen*'s engine-man, below decks when she struck, and the only one of the crew who came home. Kenny died at Easter 1971 |
| Personality | Brave and chatty. Superstitious. Talks over himself. Wants the old men's respect |
| Motivation | Get the catch home. Not be "the boy who lost his father's boat" |
| Conceals | Nothing. He doesn't know that his grandfather met Ross in secret in March 1970 |
| Arc | Rescued (ch1) → witness to the legend (ch1–2) → spots the dark boat (ch3) → stands by with his deck lights on (ch6) |
| Look | Unruly red-brown hair under a cloth bunnet. Navy gansey. Wind-reddened cheeks, a gap-toothed grin |

### 4.4 Hector Macleod, about 68, master of the schooner *Gannet* (SY 112)
| Field | Detail |
|---|---|
| Narrative function | An old-generation witness. The one who innocently says "Sandy Ross" |
| Background | Has run passengers and cargo round the Harris coast for forty years. Knew Iain well, and knew the summers when Ross ran the Board's stores and sat up with Iain |
| Personality | Courteous, unhurried, old-fashioned. Forgets the dead are dead |
| Arc | A cameo in ch2, and optionally ch3 |
| Look | Full white beard, a reefer jacket, a peaked cap, a pipe |

### 4.5 Elspeth Ross, 29, chief officer (mate) of the coaster MV *Iona Star* (Glasgow–Stornoway)
| Field | Detail |
|---|---|
| Narrative function | The stake of the climax. Living proof of what the lie cost |
| Background | Alasdair's daughter. She was eleven in 1953 and grew up as "the drowned drunk's girl". Her mother moved them to Glasgow in 1955. She went to sea at seventeen to prove a Ross could be trusted on a bridge. **A month ago she received an unsigned letter: "The light was out. Your father was not to blame."** |
| Personality | Exact, cool, very competent. Ice when she hears "North Point" |
| Motivation | Her ship, her crew, her name |
| Fear | The East Gut, and that the letter is someone's cruelty |
| Arc | Distance (ch3) → reliance (ch6) → (if reunited) "Dad?" |
| Look | Dark hair pinned back. Merchant Navy officer's jacket with a mate's braid. Grey eyes: her father's |

### 4.6 Alasdair "Sandy" Ross, 64, former master of the *Mary Ellen* (SY 214), living as "Sandy Morrison"
| Field | Detail |
|---|---|
| Narrative function | Accuser → witness → partner on the handwheel |
| Background | Born 1907, Leverburgh. A fine seaman with a name for a dram ashore, never at sea. **Iain Mackay's friend.** In the summers of 1951–53 his boat ran the Board's stores out to North Point, and he and Iain sat up in the watch room with the Grant's while the boy sang to the clockwork |
| The night | Racing his crew home before the Sabbath in a rising gale, he pushed her. He saw no light, sent the Mayday, and struck the Gut at 01:58. He washed up on Pabbay with a broken hip, lived nine days on shellfish and rainwater, and gave a crofter the only name that came easily: Sandy |
| 1953–1971 | Believing he had missed the light, he let Alasdair Ross stay dead and became Sandy Morrison, boatbuilder, of Govan. In 1969 he read the Inquiry report in the Mitchell Library: the Mayday at 01:52, and a photostat of the log page **in the hand that wrote the stores lists**. He wrote to the Board twice and they "thanked him for his interest". In 1969 he bought the *Mary Ellen*'s sister, the *Catriona*, for scrap. In March 1970 he visited Kenny Bain in secret. In 1971: lung disease from the yards. In October he sent Elspeth the unsigned letter |
| Tonight | He lies in the lee of Pabbay. At dusk he tests his set (two clicks), at 23:58 he calls as the *Mary Ellen*, and he lies in the Gut at 046 (the echo). At 00:45 he calls "tell Iain", knowing Iain is dead. About 02:15 he comes in unlit. At the landing he lashes his handset keyed, blocking Channel 16 so he has an hour alone with Callum. Then the stair and the knocks |
| Personality | Calm, courteous, unhurried. Steel underneath. Capable of deliberate cruelty, and ashamed of it |
| Motivation | The truth written in the light's own book, in the hand that wrote the lie, before he dies. And to see his girl's ship past the Gut |
| Fear | That he did miss the light. That Elspeth won't want him |
| Arc | "Keeper" → "the boy" → "Callum" |
| Look | Tall and stooped. Hollow-cheeked with illness. White stubble. Old black oilskin and sou'wester. Deep-set grey eyes |

### 4.7 Iain Mackay (1904–1958), principal keeper 1946–1958. Present only through objects
- **What he did:** in 1953 he drank after his wife's death in the October. He fell asleep on watch and dictated the lie.
- **The letter:** he wrote it at Christmas 1957 and left it in the desk drawer.
- **The Harris Hotel:** that Christmas he said to Kenny Bain, drunk, "I've written it down for the boy."
- **His death:** March 1958.
- **Present through:** the 1952 photograph, the 046 note, the Grant's half-bottle and the letter.

### 4.8 Minor voices
- **The *Corrie May* skipper** (BRD 9, Skye) and **the *Lowestoft Star* skipper** (LT 401, an English boat): purely procedural. Short, frightened, correct.

### 4.9 Dialogue style guide

| | Callum | Morag | Rory | Hector | Elspeth | Ross |
|---|---|---|---|---|---|---|
| **Sentence length** | Short. Often fragments | Medium on air, longer off it | Run-on, self-interrupting | Long, rolling | Short, complete | Medium, deliberate. Pauses as full stops |
| **Formality** | Correct procedure on air. Plain in his head | Full procedure on air. First names slip out under stress | Procedure half-remembered ("eh, sorry, over") | Old courtesy ("I'd take a bearing kindly") | Flawless procedure. "Mr Mackay", "Miss Ross" | Old-fashioned courtesy ("keeper", "lass") |
| **Vocabulary** | Keeper's terms: exhibited, relit, bearing, the cage | Stornoway radio-room terms: roger, wait one, received and logged | "Och", "eh", "here", "God rest him", "daft" | "Grand job", "och", sailing-ship terms | Bridge terms: souls aboard, abeam, setting us | Seaman's, precise: "stood into danger", "the Gut", "the lee" |
| **Emotion shown** | Through what he doesn't say, and through the machinery | Through teasing, and then through first names | Openly, immediately | Warmly, then embarrassed | Through cutting a sentence short | Through slowing down. A cough instead of a sob |
| **Patterns** | Repeats a fact to steady himself ("The light is burning") | "Aye." "Right." Long pauses (`...`) | Says a thing twice ("Holding. Holding.") | Apologises for the dead | Repeats the other person's words back, coldly ("Your word. Right.") | Quotes the record back at you ("Under the word 'blame'") |
| **Under pressure** | Goes quieter and more procedural | Drops procedure: "Callum! Answer me!" | Gets faster, loses "over" | Prays, a little | Becomes even more exact | Becomes very gentle, which is worse |
| **Would never say** | "I feel…", anything about forgiveness, a speech | Anything unkind about the dead | Anything formal or bitter | Anything cruel | "Please" on the radio; her own feelings before ch6 | Raised-voice threats, "ghost", modern idiom |

**Shared rules:**
- 1971 Hebridean English, with a light touch of Scots: aye, wee, och, skelp, kirk, lass.
- No modern slang.
- No character explains what the listener already knows unless it's procedure (repeating a forecast back is correct radio practice).
- Cryptic lines are allowed only from the *Mary Ellen* caller in ch1–2, and Ross explains them in ch5.

---

## 5. Complete timeline: the story bible
Items marked *(bible)* support consistency but aren't stated in the game.

### 5.1 Before the wreck
| When | Event |
|---|---|
| 1904 | Iain Mackay born |
| 1907 | Alasdair Ross born, Leverburgh |
| 1930 | Callum born, Tarbert |
| 1946 | Iain becomes principal keeper, North Point |
| 1949 | Iain reports the worn tooth at 046 (note: "4.3.49 I.M.") |
| 1950 | Callum joins as assistant keeper under his father |
| 1951–53 | Summers: Ross runs the Board's stores when the boatman's laid up. He drinks with Iain in the watch room, and the half-bottle of Grant's lives behind the Admiralty Tide Tables. Callum writes the stores lists |
| May 1952 | Photograph: "Iain & Callum Mackay, North Point" |
| July 1953 | Photograph: the *Mary Ellen* crew at Leverburgh pier ("A. Ross, master"; "Kenny B. on the hatch") |
| Oct 1953 | Iain's wife dies. He begins drinking on watch |

### 5.2 The night of Saturday 14 to Sunday 15 November 1953 (south-westerly gale)
| Time | Event |
|---|---|
| Evening | *Mary Ellen*, eight aboard, is racing home from west of the Flannans to Leverburgh before the Sabbath |
| 23:30 | Iain takes the middle watch with the bottle. Callum is asleep below |
| **01:40** | The clockwork stalls at **046°** on the worn tooth. The lamp burns but stops turning, aimed down the East Gut at nothing |
| **≈01:50** | The untended vapour burner starves and gutters out. **The light is dark** |
| **01:52** | Stornoway takes the Mayday: *"…no light at North Point, repeat, no light…"* Morag answers "Roger, *Mary Ellen*", then nothing more comes |
| **01:58** | *Mary Ellen* strikes the East Gut. Ross is at the wheel; Kenny Bain is below |
| **02:01** | Callum wakes to the silence of the clockwork, frees the gear by hand and relights the lamp. **Dark for 11 minutes** (01:50–02:01). Not turning for 21 minutes (01:40–02:01) |
| 02:30 | Stornoway W/T reports wreckage in the East Gut |
| ≈03:00 | Iain dictates the false entry ("02.10 extinguished approx. 2 min, mantle failure… 01.30 trawler standing in too close, no response to light") and makes Callum write it. It is signed "I. Mackay, P.K." |

### 5.3 1953–1971
| When | Event |
|---|---|
| Nov 1953 | Ross on Pabbay: nine days, then a crofter finds him. He becomes "Sandy" |
| **9 Dec 1953** | Callum adds "Reported again 9.12.53. C.M." to the 046 note and files a defect report. His half-confession |
| 18 Mar 1954 | The Inquiry: master to blame; the wireless message "confused and unreliable". Kenny Bain, below at the time, could say nothing of the light |
| 1955 | Mrs Ross and Elspeth move to Glasgow. Ross is in Govan as Sandy Morrison, a mile away, and never goes to them |
| 1955–62 | Callum's other postings. The drawer under the old tide tables goes untouched |
| Christmas 1957 | Iain writes the letter and leaves it unsealed in the bottom drawer. In the Harris Hotel he tells Kenny Bain, "I've written it down for the boy. It's in the desk." |
| Mar 1958 | Iain dies |
| 1959 | Elspeth goes to sea |
| 1961 | Callum reports the tooth again ("next refit") |
| 1962 | Morag's Donald is lost on a drifter. Callum returns to North Point as principal keeper |
| 1969 | Ross reads the Inquiry report in the Mitchell Library and recognises the hand. He writes to the Board twice. He buys the *Catriona* (the *Mary Ellen*'s sister, built at the same Fraserburgh yard) for scrap and spends two years making her the *Mary Ellen* again, SY 214 on the bow |
| Mar 1970 | Ross knocks on Kenny Bain's door in Scalpay. Kenny knows him at once and tells him about the drawer. Afterwards Kenny tells Rory: "There's a boat out in the East Gut on nights like this. She's not finished." |
| Easter 1971 | Kenny Bain dies |
| Summer 1971 | Ross's lungs are diagnosed (*bible*: the yards) |
| Oct 1971 | Ross sends Elspeth the unsigned letter |
| Sep 1971 | A gale takes the North Point telephone cable on the shore and cracks the second west pane. The relief boat is due "Thurs. if the sea allows" |

### 5.4 Tonight: Sunday 14 to Monday 15 November 1971
| Clock | Event | Chapter |
|---|---|---|
| 16:20 | Lighting-up. The date. The dead phone | 1 |
| ≈16:45 | A carrier on 16: two clicks, no voice (Ross) | 1 |
| 18:30 | Radio check with Morag. The gale warning | 1 |
| 18:50 | *Kittiwake* brought in | 1 |
| 23:25 | Morag off the log | 1 |
| 23:58 | "*Mary Ellen*… we cannot see your light" | 1 |
| 00:02–00:55 | Morag traces the call. The 046 echo. *Gannet*. "Tell Iain". The archive. The jam | 2 |
| 01:05–02:20 | Storm 10. *Corrie May* and *Lowestoft Star*. Elspeth's passage report. Morag's notebook. Blackout. The dark boat | 3 |
| 02:21–03:00 | The unlit boat, SY 214. Docking. 16 blocked. Footsteps, a cough, the knocks | 4 |
| 03:04–04:10 | Ross's story. The letter. Morag. The *Iona Star* Mayday. Engine and MAIN lost | 5 |
| 04:12–06:30 | *Iona Star*. The jam at 046. Freed by hand. The rescue. Dawn. The report. The log | 6 |

### 5.5 Who knows what, chapter by chapter
| | Ch1 | Ch2 | Ch3 | Ch4 | Ch5 | Ch6 |
|---|---|---|---|---|---|---|
| **Player** | Callum is uneasy about the date. A ghost-boat story | Callum wrote the 1953 entry. The jam is at 046 | The log contradicts the Mayday by 18 minutes | The visitor knows the room. SY 214 | Everything except what Callum will do | The choice |
| **Callum** | Everything about 1953 except the letter, and that Ross is alive | Suspects someone who knows | Knows Morag knows the time | Fears it is Ross | Has the letter | — |
| **Morag** | The anniversary | The caller knew the words. *(Optional)* the sister boat went to a "Mr Morrison, Govan" | The time gap. What Callum admits (if he does) | A man at the door (if called) | It's Ross | What Callum reports |
| **Rory** | The legend | — | Saw the dark boat | — | — | Standing by |
| **Elspeth** | — | — | The letter, Callum's name | — | — | Possibly her father |
| **Ross** | Everything except the letter's text | Hears 16 all night, including Morag | — | — | The letter's text (if handed it) | — |

---

## 6. Six-chapter structure and pacing map

**Codes:**

| Code | Kind | Code | Kind |
|---|---|---|---|
| Q | Quiet or exploration | S | Suspense |
| E | Equipment | C | Climax |
| D | Dialogue | R | Resolution |
| I | Investigation | o | Optional |

| Ch | Title / clock | Opening → hook | Sequence | Chapter climax | Transition |
|---|---|---|---|---|---|
| 1 | The Watch · Sun 14 Nov · 16:20–23:58 | The date, the dead phone (0–1 min). The voiceless carrier (≈5 min) | Q·E·E·E/S·D·D/E·E·Q·D·I·S | 23:58: the *Mary Ellen* call | "Did you hear that?" → fade |
| 2 | Strange Signals · Mon 15 Nov · 00:02 | Morag's trace | D·S·D/E·E·S·I·E·E (+o D, o D) | The same hand. The jam at 046 | "It always sticks at forty-six." → fade |
| 3 | The Storm · 01:05 | Storm 10 | D·E·E (+o D)·D·D·S·E·D·S | Morag's notebook, the blackout, the confrontation | The dark boat heading for the landing |
| 4 | The Visitor · 02:21 | The unlit echo | S·E/S·S·S (+o actions)·C/D | Three knocks. The door | Open or shut → fade |
| 5 | The Truth · 03:04 | Ross's first words | D·I·D·S·E | The Mayday. Black | Darkness → card |
| 6 | The Last Light · 04:12 | *Iona Star* | D·S/E·E·D·C·R·R | The beam on her; the handset | Dawn report → log → ending card |

**Pacing rules applied:**
- No two equipment-failure beats in a row without a story beat between them.
- Every chapter turns a relationship: Morag (1, 3, 6), Rory (1, 3, 6), Elspeth (3, 6), Ross (4–6).
- Quiet beats are deliberate:
  - the ch1 log;
  - the ch2 archive;
  - the ch5 letter, read in silence while Ross waits.

---

## 7. Scene-by-scene breakdown
Every scene lists:
- where and who;
- starting conditions;
- narrative and gameplay objectives;
- dialogue;
- interactions;
- choices;
- trigger;
- state changes;
- end condition;
- duration;
- transition.

The chapter is in the id. "Watch room" means the round watch room under the lantern; radio voices are elsewhere.

### Chapter 1: The Watch
Start state: clock 980 (16:20), clock rate 0, storm 0.12, battery 41, fuel 46, MODE OFF, LAMP OFF.

#### 1.1 `dusk`: Lighting-up time (EDITED beat; merges old `dusk` and `look`)
| Field | Detail |
|---|---|
| Where / who | Watch room · Callum |
| Starts | Chapter start |
| Narrative objective | Establish the date, the isolation and Callum's unease within the first minute |
| Gameplay objective | None. The player can walk and look while the thought plays |
| Dialogue | `ch1_dusk` (EDITED) |
| Interactions | All room objects. *(Optional)* the phone and the tide tables (§11) |
| Choices / trigger | None / chapter start |
| State | Sky dusk, mode 0, intensity 0 |
| Ends | Immediately (no condition) |
| Duration · next | ≈1 min · 1.2 |

#### 1.2 `light`: Light the lamp (EDITED; merges `look`, `light_on` and `lamp_normal`)
| Field | Detail |
|---|---|
| Where / who | Watch room, east console · Callum |
| Starts | After 1.2 begins (no wait) |
| Narrative objective | Ritual and competence. The clockwork is a living thing |
| Gameplay objective | `Lighting-up time: MODE to AUTO and LAMP to NORMAL at the light console under the east window. ({move} to walk, {look} to look.)` |
| Hints | 25 s: "Move with {move}. Look around with {look}."; 50 s: "The light console stands under the east window. Look at the MODE knob and press {interact}." |
| Dialogue | `ch1_lit` (EDITED; absorbs `ch1_normal` and `ch1_battery`) |
| Interactions / choices | Console / none |
| Trigger | `sim.mode == 1 and sim.intensity >= 1` |
| State | — |
| Ends | The condition is met |
| Duration · next | 2–3 min · 1.3 |

#### 1.3 `engine`: Start the generator (EDITED; merges `battery` and `gen`)
| Field | Detail |
|---|---|
| Where / who | Generator cage, south-west · Callum |
| Narrative objective | Physical labour, plus Father's engine |
| Gameplay objective | `The batteries are tired. Start the generator in the cage (south-west): open the FUEL VALVE, then hold START.` |
| Hint | 60 s, as the current `gen` hint |
| Dialogue | `ch1_gen` (KEPT) |
| Trigger | `sim.gen == 2` |
| Duration · next | 2–3 min · 1.4 |

#### 1.4 `charge`: Charge, and the carrier (EDITED; gains the hook)
| Field | Detail |
|---|---|
| Where / who | Charger, west wall · Callum (and, unseen, Ross) |
| Narrative objective | **First mystery signal:** a voiceless carrier on 16 |
| Gameplay objective | `Switch CHARGE on at the charger (west wall).` (hint as now) |
| Dialogue | `ch1_charging` (KEPT), then `ch1_carrier` (NEW) |
| Trigger | `sim.charge_flow > 0.0` |
| Actions after the trigger | `talk ch1_charging` → `wait 3` → `sfx carrier_click` → `talk ch1_carrier` → `autosave` |
| State | — |
| Duration · next | 1–2 min · 1.5 |

#### 1.5 `radio_check`: Evening radio check (KEPT beat; EDITED conversation)
| Field | Detail |
|---|---|
| Where / who | The radio · Callum, Morag |
| Narrative objective | Morag's warmth. "It's the fourteenth." |
| Gameplay objective | Choose replies |
| Dialogue | `ch1_radio_check` (EDITED: "Sunday") |
| Choices | proper / early; knows / deflect / flat (`rel.morag`) |
| Trigger | `timeskip 1110 "18:30"` (the deterministic fade, §18.1), then talk |
| Duration · next | 2 min · 1.6 |

#### 1.6 `kittiwake`: Rory calls; confirm his position (EDITED; merges `kittiwake_call` and `confirm`)
| Field | Detail |
|---|---|
| Where / who | Radio and radar · Callum, Rory |
| Narrative objective | Warmth and comedy. The Sabbath |
| Gameplay objective | `Use the radio (desk): select Kittiwake and ask her to CONFIRM POSITION.` (hint as now) |
| Dialogue | `ch1_rory_call` (EDITED), then `ch1_bearings` (KEPT) on confirm |
| Actions | `wait 4` → ship *Kittiwake* → talk; when `flag("tx_confirm") >= 1` → `wait 4` → `talk ch1_bearings` |
| Duration · next | 2–3 min · 1.7 |

#### 1.7 `vector`: Bring her onto the line (KEPT)
| Field | Detail |
|---|---|
| Gameplay objective | As now (000° North Sound) |
| Dialogue | `ch1_rory_in` (EDITED: the Bain line, C5) |
| Choices | joke / which (`clue rory_grandfather`) |
| Trigger | `piloting("Kittiwake")` |
| Duration · next | 3–4 min · 1.8 |

#### 1.8 `kittiwake_home` (KEPT)
| Field | Detail |
|---|---|
| Gameplay objective | `Watch Kittiwake into the Sound.` |
| Trigger | `saved("Kittiwake")` |
| State | `autosave` |
| Duration · next | ≈1 min · 1.9 |

#### 1.9 `late`: Morag off the log (KEPT)
| Field | Detail |
|---|---|
| Trigger | `timeskip 1405 "23:25"`, storm 0.25 |
| Dialogue | `ch1_morag_late` (KEPT) |
| Choices | mind / rules; true / warm / quiet; never / once (`admitted_once`) |
| Duration · next | 3 min · 1.10 |

#### 1.10 `log`: Write up the evening (KEPT beat)
| Field | Detail |
|---|---|
| Gameplay objective | `Write up the evening in the station log (desk).` |
| Dialogue | Document `log_1971` (EDITED, C10), then `ch1_log_after` (EDITED) |
| Trigger | `has_flag("read_log_1971")` |
| Duration · next | 1–2 min · 1.11 |

#### 1.11 `mary_ellen`: The call (KEPT)
| Field | Detail |
|---|---|
| Trigger | Clock 1437 (23:58), `wait 4`, `sfx static_burst` |
| Dialogue | `ch1_mary_ellen` (KEPT), then `ch1_morag_heard` (KEPT) |
| Choices | again / burning (`answered_me`) / silent (`ignored_me`); heard / lie (`lied_heard`) |
| Ends | The conversation ends |
| Duration · next | 2 min · **chapter transition** |

### Chapter 2: Strange Signals
Start: clock 1442 (00:02), rate 0.12, storm 0.3, fuel 44. Subtitle **"Monday 15 November · 00:02"**.

| # | Beat | Who | Narrative / gameplay objective | Dialogue | Trigger → state → end | Duration |
|---|---|---|---|---|---|---|
| 2.1 | `trace` (KEPT) | Morag | Morag knows the caller knew the 1953 words. The first "you were there" | `ch2_trace` (EDITED, C8) | `wait 2` → talk. Choices set `admitted_there` / `said_asleep` / `rel.morag` | 2–3 min |
| 2.2 | `radar` (KEPT) | Callum | The echo at 046 / watch the radar | `ch2_phantom` (KEPT) | `phantom_echo 46 95 40` → `wait 18` → talk | 1 min |
| 2.3 | `gannet` (KEPT) | Hector | A friend of Iain's / respond | `ch2_gannet` (KEPT) | `wait 4` → ship → talk | 1 min |
| 2.4 | `gannet_in` (KEPT) | Hector | "Tell your father…" / West Gut 314° | `ch2_gannet_after` (EDITED, C3) | saved or lost → talk → autosave. **Opens optional calls `opt_ch2_rory` and `opt_ch2_morag`** | 4–5 min |
| 2.5 | `second_call` (KEPT) | *Mary Ellen* | "Tell Iain" | `ch2_mary_ellen` (KEPT) | `wait 8` (deferred while an optional call is running, §18.1) → talk. Choices set `told_dead` / `ignored_me` | 1–2 min |
| 2.6 | `archive` (KEPT) | Callum | **Callum's own hand** / find the 1953 log | `log_1953` → `clipping_1954` → `ch2_same_hand` (EDITED, N2) | `has_flag("read_log_1953")` → `clue same_hand` | 2–3 min |
| 2.7 | `jam` (EDITED) | Callum | The machine remembers / react | `ch2_jam` (EDITED) | `wait 6` → `fault jam` (story jam: no MAIN trip, §18.2) → talk | <1 min |
| 2.8 | `clear` (EDITED) | Callum | 046: the note's dates / **teaches the ch6 procedure** | `ch2_046` (EDITED) | Objective `Free the gear by hand: MODE to OFF, turn the handwheel back past 046°, then MODE to AUTO.` Hint 30 s: "MODE knob on the console: {turn_back} turns it back. With the motor off, {wheel} on the handwheel turns the optic by hand." Trigger `flag("jam_cleared") >= 1 and sim.mode == 1` → talk → autosave → transition | 2 min |

**Shared fields for ch2:** location watch room; start condition is the previous beat; no new interactions except the optional calls; transition is the chapter fade after 2.8.

### Chapter 3: The Storm
Start: clock 1505 (01:05), rate 0.1, storm 0.55, fuel 46.

| # | Beat | Who | Narrative / gameplay objective | Dialogue | Trigger → state → end | Duration |
|---|---|---|---|---|---|---|
| 3.1 | `forecast` (KEPT) | Morag (broadcast) | Storm 10 | `ch3_forecast` (KEPT) | `wait 2` → talk → storm 0.7 | <1 min |
| 3.2 | `two_ships` (KEPT) | Corrie, Lowestoft | Overlapping pressure | `ch3_corrie`, `ch3_lowestoft` (KEPT) | As now | 1 min |
| 3.3 | `both` (KEPT) | — | Bring both in. Mind the battery | `ch3_after_two` (EDITED) | Both resolved → talk → autosave. **Opens the optional call `opt_ch3_hector`** | 6–8 min |
| 3.4 | `elspeth` (KEPT) | Elspeth | The daughter. **The letter** | `ch3_elspeth` (EDITED, N4) | `wait 6` (deferred while an optional call is running) → talk. Choices: `rel.elspeth`, `told_elspeth_there`, `elspeth_letter_told` | 2 min |
| 3.5 | `notes` (KEPT) | Morag | The notebook, then darkness | `ch3_notes_a`, `ch3_dark` (KEPT) | `wait 8` → talk → `fault trip` → `set blackout=1` → talk | 1 min |
| 3.6 | `restore` (KEPT) | Callum | Reset MAIN in the dark | — | `sim.main_breaker` → `unset blackout` → `wait 2` → `talk ch3_notes_b` (EDITED, callbacks) | 2–3 min |
| 3.7 | `dark_boat` (KEPT) | Rory | "No lights. Not a single light." | `ch3_rory_dark` (KEPT) | `wait 6` → talk → autosave → transition | 1 min |

### Chapter 4: The Visitor
Start: clock 1581 (02:21), rate 0.08, storm 0.75, fuel 44.

| # | Beat | Who | Narrative / gameplay objective | Dialogue | Trigger → state → end | Duration |
|---|---|---|---|---|---|---|
| 4.1 | `approach` (EDITED) | Callum | The unlit echo | `ch4_watch` (KEPT) | Ship *Visitor* (as now), music tension. **Talk starts only after the chapter card has finished** (§18.1) | 1 min |
| 4.2 | `identify` (KEPT) | Callum | SY 214 / MANUAL plus handwheel | `ch4_bow` (KEPT) | `lit_by_hand("Visitor") or has_flag("docked_Visitor")` → `clue sy214` | 3–4 min |
| 4.3 | `hail` (KEPT) | Callum | The silence on 16 | `ch4_docked` (EDITED, N9) | `has_flag("docked_Visitor")` → talk. **Opens the ch4 optional actions:** bolt, phone, the MF call (§11) | 1 min |
| 4.4 | `steps` (EDITED) | Ross, unseen | Footsteps, a cough, the knocks. **The player keeps control** | `ch4_stairs` (NEW) plus captions | Caption and footstep schedule (below). Optional actions are live throughout | ≈1 min (the player may use it) |
| 4.5 | `door` (KEPT beat) | Ross (VISITOR) | The door conversation / go to the door | `ch4_door` (EDITED) | `has_flag("at_door")` → talk → autosave. **Ends when the door is opened or kept shut** → transition | 5–7 min |

**4.4 `steps` schedule (EDITED actions):**
```
wait 4  → footsteps jetty   → caption "[Footsteps on the jetty, slow]"
wait 7  → talk ch4_stairs
wait 2  → footsteps base_door → caption "[The base door, far below]"
wait 4  → caption "[A cough, deep in the chest. It goes on a long time.]"
wait 3  → footsteps stair   → caption "[Footsteps on the stair. One step at a time.]"
wait 12 → sfx silence       → caption "[Silence]"
wait 4  → knock             → caption "[Three slow knocks]"
wait 2
```
`caption` is a new non-blocking beat action (§18.1). Footstep positions are unchanged (spatial audio is already wired; it is verified by events, never played).

### Chapter 5: The Truth
Start: clock 1624 (03:04), rate 0.08, storm 0.8, fuel 46.

| # | Beat | Who | Narrative / gameplay objective | Dialogue | Trigger → state → end | Duration |
|---|---|---|---|---|---|---|
| 5.1 | `story` (EDITED) | Ross | Who he is, what happened, **who made the calls**, the friendship, Kenny Bain | `ch5_ross` (EDITED, major) | After the card → talk. Sets `knows_name` (if unset), `blamed_father` / `confessed_to_ross`, `rel.ross` | 6–8 min |
| 5.2 | `drawer` (KEPT) | Callum, Ross | The letter / search the desk drawers | `letter_1957` (EDITED, C11) → `ch5_letter` (EDITED) | `has_flag("read_letter")` → talk → `clue letter`. Choice: `gave_letter` / `kept_letter` | 3–4 min |
| 5.3 | `morag` (KEPT) | Morag, Ross@room | Morag hears the name | `ch5_morag` (EDITED) | `wait 4` → talk | 2 min |
| 5.4 | `mayday` (KEPT) | Elspeth, Morag, Ross@room | "That's my girl." | `ch5_mayday` (EDITED, C6, N6) → `ch5_dark` (KEPT) | `wait 6` → static → talk → `fault overheat` → `fault trip` → talk | 1 min |
| 5.5 | `power` (KEPT) | Callum | Reset MAIN; keep the generator alive | — | `sim.main_breaker and sim.gen == 2` → autosave → transition | 2–4 min |

### Chapter 6: The Last Light
Start: clock 1692 (04:12), rate 0.06, storm 1.0, fuel 48.

| # | Beat | Who | Narrative / gameplay objective | Dialogue | Trigger → state → end | Duration |
|---|---|---|---|---|---|---|
| 6.1 | `iona` (EDITED) | Elspeth | "Put me through the East Gut." | `ch6_iona` (EDITED) | After the card → ship *Iona Star* → talk | 1–2 min |
| 6.2 | `jam` (EDITED) | Ross | The tooth binds in **any** mode | `ch6_jam` (EDITED) | `wait 4` → `fault jam` (story jam, mode-independent, no MAIN trip) → talk. Choice: `ross_wheel` / door opened | 1 min |
| 6.3 | `free` (NEW) | Callum (+ Ross) | **Free it by hand** | `ch6_freed` (NEW) | Objective `Free the gear by hand: MODE to OFF, back the handwheel past 046°, then MODE to MANUAL.` Hint 25 s (as 2.8). Trigger `flag("jam_cleared") >= 1 and sim.mode == 2` → talk | 1–2 min |
| 6.4 | `standby` (NEW) | Rory | Rory stands by (N5) | `ch6_rory` (NEW) | `wait 6` → talk (radio, short) | <1 min |
| 6.5 | `rescue` (KEPT) | Elspeth | Hold the light on her and talk her through the East Gut (046°) | `ch6_outcome` (EDITED) | saved or lost → `wait 3` → talk. Choice: `reunion` | 6–9 min |
| 6.6 | `dawn` (EDITED) | Morag (+ Ross@room) | The report | `ch6_morag_dawn` (EDITED) → `ch6_final_log` (EDITED) | `timeskip 1830 "06:30"`, storm 0.25, sky dawn → talks. Choice: `told_truth` / `kept_lie` | 3 min |
| 6.7 | `ending` (NEW) | — | The ending card | `ch6_epilogue` (EDITED), shown on the card | `ending_card` → `end_campaign` | 1 min |

**The Ross assist (6.5):** if `ross_wheel == 1`, then in MANUAL the beam tracks *Iona Star* automatically. Ross holds the wheel, so `lit_by_hand("Iona Star")` stays true and the player only vectors. Alone, the player must work the handwheel and the radio themselves (§18.2).

---

## 8. Dialogue scripts
Line ids are conversation ids. Text in `godot/data/story/chN.dlg` is the "old" text.

### 8.1 Chapter 1

#### `ch1_dusk` (EDITED)
```
== ch1_dusk mode=thought
~ Sixteen-twenty. The sun's gone behind Pabbay and taken the colour with it.
~ Sunday the fourteenth of November. I wrote the date at the top of the page this morning and sat looking at it.
~ Twenty-one winters on the lights, and the wind still sounds like someone trying the door.
~ The phone's been dead since the September gale. The radio's all the company there is till Thursday.
~ Lighting-up time. Then the batteries. Then the long quiet.
```

#### `ch1_lit` (EDITED: absorbs `ch1_normal` and `ch1_battery`, which are RETIRED)
```
== ch1_lit mode=thought
~ The clockwork takes up the weight overhead. Twelve turns a minute, same as the day it was built.
~ Normal power. Forty miles on a clear night. Tonight won't be clear.
~ Batteries next. Forty-one percent at noon, and the engineer's been saying since Easter these cells are tired.
~ The engine, then, before the weather turns. The cage, south-west corner.
```

#### `ch1_gen`, `ch1_charging` (KEPT)

#### `ch1_carrier` (NEW)
```
== ch1_carrier mode=thought
> [A carrier on Channel 16. Two clicks. No voice.]
~ Somebody keyed a set on sixteen. Twice. Nobody spoke.
~ Some boy with his father's handset. On the Sabbath. His mother'll skelp him.
```

#### `ch1_radio_check` (EDITED: one choice)
- Old: `* It's a Saturday. That's all it is. -> flat`
- New: `* It's a Sunday. That's all it is. -> flat`
- Everything else is KEPT.

#### `ch1_rory_call` (EDITED: one line added after line 62)
```
RORY: Callum, is that you? Thank God. Sorry, eh, North Point. I'm coming in from the Flannans, and the rain's that thick I can't see my own bow. I was meant to pick up the Sound an hour ago. Over.
RORY: And, eh. Don't be telling my mother I was out on the Sabbath. Over.        <- NEW
RORY: I've stopped her. I'm just sitting here like a gull on a fence post. Can you put me in? Over.
```
The rest is KEPT, including the closing thought ("First I need to know where he is…").

#### `ch1_bearings` (KEPT)

#### `ch1_rory_in` (EDITED: the `which` branch, C5)
```
= which
RORY: The Mary Ellen. Ross's boat. My grandfather was on her the night she went down. Below, in the engine. Only one of them that came home.
RORY: He always said Ross was a better seaman sober than most men are... eh. Sorry. You'd know all that. He died at Easter, God rest him. Over.
! clue rory_grandfather
```
Old: "My grandfather was on her the season before she went down. He always said Ross was a better seaman sober than most men are... eh. Sorry. You'd know all that. Over."

#### `ch1_morag_late` (KEPT)

#### `ch1_log_after` (EDITED: first line, C10)
```
== ch1_log_after mode=thought
~ Eighteen-thirty, radio check, gale warning. Ten to seven, Kittiwake in by the North Sound. Twenty-three-twenty-five, Stornoway on sixteen. All well.
~ The same small square letters I learned at the school in Tarbert. Father always said I wrote like a clerk.
```

#### `ch1_mary_ellen`, `ch1_morag_heard` (KEPT)

### 8.2 Chapter 2

#### `ch2_trace` (EDITED: lines 8 and 12, C8)
```
== ch2_trace mode=radio
! static
MORAG: North Point, Stornoway. Over.
CALLUM: Go ahead, Morag.
MORAG: I've rung round. Nobody's reporting a Mary Ellen. The register's had nothing by that name since nineteen fifty-three. Over.
MORAG: Lost with seven of the eight aboard, the skipper among them. Presumed. You know all this.
* I know it. -> know
* Then it's a prank. Some boy with a set and a bottle. -> prank
= prank
MORAG: That's what I told myself. Except he said it near enough the way it was said that night. "Cannot see your light."
MORAG: Those words were never in any paper, Callum. The court called them confused and unreliable and left them out.
-> next
= know
! add rel.morag 1
MORAG: Aye. You would.
= next
MORAG: Callum. You were on the light that night. With your father.
* I was there. I was twenty-three. -> there
* I was asleep. It was his watch. -> asleep
* Let's not, Morag. Not tonight. -> notnow
= there
! set admitted_there=1
MORAG: I know. I took the call. I was twenty-six and it was my first winter on the set.
-> end
= asleep
! set said_asleep=1
MORAG: Asleep. Right.
MORAG: I took that call, Callum. My first winter on the set. I've never forgotten a word of it.
-> end
= notnow
! add rel.morag -1
MORAG: Not tonight. It's always "not tonight" with the Mackays.
= end
MORAG: Watch your radar. If somebody's out there playing silly beggars, they're close. That signal was strong. Stornoway out.
```

#### `ch2_phantom`, `ch2_gannet` (KEPT)

#### `ch2_gannet_after` (EDITED: one word, C3)
- Old: "…Fifteen years and I still forget. Gannet out."
- New: "…Thirteen years and I still forget. Gannet out."

#### `ch2_mary_ellen` (KEPT)

#### `ch2_same_hand` (EDITED: evasive, not ignorant, N2)
```
== ch2_same_hand mode=thought
~ I know what it says. I don't need to open it.
~ I open it.
~ Fifteenth November, nineteen fifty-three. Oh-two-ten. "Light extinguished approx. two minutes, mantle failure. Relit oh-two-twelve."
~ "Trawler observed standing in too close at oh-one-thirty. No response to light." Signed, I. Mackay, P.K.
~ Small square letters. A clerk's hand. Tonight's page is lying open on the desk.
~ Eighteen years, and my hand hasn't changed at all.
```

#### `ch2_jam` (EDITED)
```
== ch2_jam mode=thought
> [A grinding shudder overhead. The clockwork stops.]
~ The motor's labouring. Amber lamp on the console. The beam's stuck.
~ Motor off before she takes the main with her. Then free it by hand, the way the note says.
```

#### `ch2_046` (EDITED)
```
== ch2_046 mode=thought
> [A clunk you feel in your teeth]
~ Free again.
~ The bearing repeater says oh-four-six. The East Gut.
~ Father's note on the console, and my lines under his. "Free by hand." Forty-nine. December fifty-three. Sixty-one.
~ December fifty-three. Three weeks after. As if writing it down would count for something.
~ It always sticks at forty-six.
```

### 8.3 Chapter 3

#### `ch3_forecast`, `ch3_corrie`, `ch3_lowestoft` (KEPT)

#### `ch3_after_two` (EDITED: the last line)
- Old: `~ Two o'clock coming. The worst of it still to come.`
- New: `~ Coming up on two o'clock. I know what this hour sounds like in this room.`

#### `ch3_elspeth` (EDITED: the `name` branch, N4)
```
= name
ELSPETH: Mackay.
! wait 1.2
ELSPETH: My father's boat was lost under your light, Mr Mackay. Eighteen years ago tonight.
ELSPETH: This is Elspeth Ross. First mate. I wanted you to know who was out here.
ELSPETH: Someone sent me a letter last month. No name on it. "The light was out. Your father was not to blame."
! set elspeth_letter_told=1
! wait 1.0
ELSPETH: I'd like to know who writes a letter like that and doesn't sign it. Over.
* I'm sorry, Miss Ross. I was there that night. -> sorry_there
* I know who your father was. -> know
* (Say nothing.) -> silence
```
The labels `sorry_there`, `know`, `silence` and `curt` are KEPT.

#### `ch3_notes_a`, `ch3_dark` (KEPT)

#### `ch3_notes_b` (EDITED: callbacks before the choice, and "six widows")
```
== ch3_notes_b mode=radio
! static
MORAG: ...North Point! Callum! Answer me!
CALLUM: Lost the main breaker. I'm back. Light's back. Over.
MORAG: Thank God. Callum, did you hear what I said? Oh-one-fifty-two. No light. Your father's log says the light failed at oh-two-ten. After she struck.
MORAG: Eighteen minutes, Callum. They hanged Alasdair Ross's name on eighteen minutes.
[if has_flag("admitted_once")] MORAG: And you told me tonight you'd missed lighting-up once. I've been sitting here working out which night.
[if has_flag("admitted_there")] MORAG: You told me you were there. So tell me.
[if has_flag("said_asleep")] MORAG: Asleep, you said. Then you'll not know what time it went out. Or will you.
* The log says oh-two-ten. The log is right. -> lie
* Morag, it was eighteen years ago. What does it matter now? -> deflect
* I was there. The light was out before she struck. -> admit
= lie
! set lied_to_morag=1
! add rel.morag -2
MORAG: ...Right.
MORAG: Right. I'll write that in my log, then. "North Point confirms the log." Stornoway out.
-> END
= deflect
! set deflected_morag=1
! add rel.morag -1
MORAG: It matters to six widows in Leverburgh, and to his. It matters to his girl. It matters to me, Callum. Stornoway out.
-> END
= admit
! set admitted_to_morag=1
! add rel.morag 2
MORAG: ...Oh, Callum.
MORAG: Not on the air. Not now. When this blows through, you and I are going to sit at my kitchen table. Stornoway listening.
```

#### `ch3_rory_dark` (KEPT)

### 8.4 Chapter 4

#### `ch4_watch`, `ch4_bow` (KEPT)

#### `ch4_docked` (EDITED, N9)
```
== ch4_docked mode=thought
~ She's alongside the landing below the light. The engine note drops, coughs, stops.
~ Then she's dark. Not a lantern. Not a cigarette.
! static fade
> [A dead carrier on Channel 16]
~ The speaker's gone quiet. Not static. A carrier, flat and steady, with nobody on it.
~ Somebody's sitting on sixteen.
```

#### `ch4_stairs` (NEW: plays between the jetty and the base door)
```
== ch4_stairs mode=thought
~ Nobody comes up those stairs but the relief keeper and the engineer. Neither of them at half past two in the morning.
~ A hundred and nine steps. I've counted them every day for nine years.
```

#### `ch4_mf_morag` (NEW: an optional radio action during 4.3–4.4, "Call Stornoway on the MF set")
```
== ch4_mf_morag mode=radio
! set called_morag=1
~ Sixteen's blocked solid. The old MF set, then. Two-one-eight-two.
CALLUM: Stornoway, Stornoway, North Point on two-one-eight-two. There's a boat tied up at my landing. No lights, and somebody's sitting on sixteen. Over.
! static
MORAG: ...North Point, Stornoway. I hear you, Callum. Faint. The lifeboat's out on a shout at the Shiants. Two hours at least. Over.
MORAG: Whoever it is, you do not open that door. Do you hear me? Over.
CALLUM: I hear you.
MORAG: I'm staying on the set. Both sets. Stornoway listening.
```

#### `ch4_door` (EDITED: full text. Changes: "top shelf"; `found_grants` and `sister_boat` reads; a cough; the MF radio branch; the bolt conditional; C4)
```
== ch4_door mode=person
! knock
~ Three knocks. Slow. Evenly spaced, like a man who has all night.
VISITOR: Evening, keeper.
VISITOR: I could not see your light.
* Who's there? -> who
* [if clue("sy214")] You came in on SY 214. That boat's at the bottom of the East Gut. -> sy
* The landing's private. State your business or get back in your boat. -> hard
= who
VISITOR: A man who's come a long way in poor weather. That's enough to be going on with.
-> probe
= sy
! add rel.ross 1
VISITOR: She is. That's her sister. Same yard, same lines. I bought her for scrap and spent two years making her look like the one I lost.
[if clue("sister_boat")] VISITOR: The Catriona. I heard your friend at Stornoway read out the register on sixteen. She does her homework.
VISITOR: You've good eyes, Callum.
-> probe
= hard
! add rel.ross -1
VISITOR: Private, is it. The Board's landing, the Board's light, the Board's book. Aye. I know whose everything is.
= probe
* How do you know my name? -> name
* What do you want? -> want
* [if not has_flag("called_morag")] (Go to the radio and call Morag.) -> radio
* [if clue("same_hand")] Tell me what happened on the fifteenth of November, 1953. -> fifteenth
= name
VISITOR: Your father's boy. You were thin as a boathook, and you used to sing to the clockwork when you wound it. Fear a' bhàta. Your father hated that song.
VISITOR: He kept a half-bottle of Grant's behind the Admiralty Tables. Top shelf. Is it still there?
! clue grants
[if has_flag("found_grants")] ~ It is. I had my hand on it this afternoon.
-> probe2
= want
VISITOR: To come in out of the rain, first. Then to see a page in your book.
-> probe2
= radio
! set called_morag=1
~ I back away from the door to the desk without taking my eyes off it. Sixteen's still dead. The MF set, then.
CALLUM: Stornoway, North Point on two-one-eight-two. There's a man at my door. Came off that dark boat. Over.
MORAG: ...North Point, Stornoway. Callum, the lifeboat's out on a shout at the Shiants. Two hours at least. Do not open that door. Do you hear me? Over.
CALLUM: I hear you.
MORAG: I'm staying on the set. Leave your handset keyed if you have to. Stornoway listening.
~ Back to the door. The knocking hasn't come again. He's waiting.
-> probe2
= fifteenth
! add rel.ross 1
VISITOR: You were twenty-three. I was the man on the wheel.
VISITOR: At ten to two the light at North Point was dark. I said so on the radio. A girl in Stornoway wrote it down.
-> probe2
= probe2
VISITOR: The clockwork stuck tonight, didn't it. At forty-six degrees. It always did.
> [He coughs. It goes on a long time.]
VISITOR: Open the door, Callum. I'm sixty-four, I'm soaked to the bone, and I've no wish to harm you. I want to talk to you before I die. I'll not be long about either.
* (Draw the bolt and open the door.) -> open
* Say who you are first. Your name. -> name_ask
* (Keep the door shut.) -> shut
= name_ask
VISITOR: You know my name. Your father wrote it in his book, under the word "blame."
! wait 1.5
VISITOR: Alasdair Ross. Master of the Mary Ellen.
! set knows_name=1
* (Draw the bolt and open the door.) -> open
* (Keep the door shut.) -> shut
= open
! set door_open=1
! door_open
[if has_flag("bolted")] ~ The bolt is stiff with salt. The door comes in with the storm behind it.
[if not has_flag("bolted")] ~ It was never even bolted. The door comes in with the storm behind it.
~ An old man in an oilskin, one hand on the rail, rain running off the brim of his sou'wester. He doesn't step in until I stand aside.
! visitor_enter
ROSS: Thank you.
-> END
= shut
! set door_shut=1
VISITOR: ...Aye. I'd have done the same, at your age, with a ghost at the door.
! sfx paper_slide
> [Something slides under the door]
~ A photograph, cracked and soft as cloth.
~ Eight men on a deck at Leverburgh pier. The one at the wheel is laughing. On the back, in pencil: "Mary Ellen, July 1953. A. Ross, master."
! clue photo_1953
VISITOR: I'll talk through the door, then. I've talked to worse.
```
"ROSS: Thank you." resolves to "The man at the door" unless `knows_name` is set.

### 8.5 Chapter 5

#### `ch5_ross` (EDITED: full text, N1, N3, C5, C12, C13, callbacks)
```
== ch5_ross mode=person
[if has_flag("door_open")] ~ He stands just inside the door and lets the water run off him onto Father's floor. He won't take the chair.
[if has_flag("door_shut")] ~ I sit with my back against the door. I can hear him breathing on the other side of two inches of oak.
[if not has_flag("knows_name")] ROSS: You'll be wanting a name. Alasdair Ross. Master of the Mary Ellen, SY two-one-four. Presumed drowned.
[if not has_flag("knows_name")] ! set knows_name=1
ROSS: We struck at two minutes to two. I know because I was looking at the clock in the wheelhouse when the light didn't come round.
ROSS: Eight of us. The sea took the wheelhouse roof off with me holding it. I woke on the shingle on Pabbay with my hip broken and a seal looking at me.
* How did you live? -> how
* Why didn't you come back? -> why
= how
ROSS: Shellfish and rainwater, nine days. A crofter found me. I told him my name was Sandy. It's what your father always called me, so it came easy.
[if clue("sandy")] ~ Sandy. Hector said it tonight, and I let it go past me.
-> why
= why
ROSS: Because I thought I'd killed them.
ROSS: I had them racing for home. A good trip in the hold and the Sabbath coming, and the men wanting their own beds. I pushed her. That much is mine, whatever else isn't.
ROSS: Then your father told the Inquiry the light was burning. The Board's own keeper. Who'd believe a drowned man with a name for a dram over that? I didn't believe me.
* So you stayed dead. -> stayed
* (Let him talk.) -> stayed
= stayed
ROSS: So I let Alasdair Ross stay dead. My wife was told I'd put seven good men on the rocks with drink in me. My girl grew up hearing it in the schoolyard.
> [He coughs. It goes on too long.]
ROSS: Two years ago I'm in the Mitchell Library in Glasgow with the Inquiry report, the way some men read their Bible. And I see it. Mayday logged at Stornoway at oh-one-fifty-two. "No light."
ROSS: And at the back, a photostat of your station log. Light failed at oh-two-ten.
ROSS: I knew that hand. You wrote out the stores for the relief boat, the summers I ran them out for the Board. Small square letters. A clerk's hand.
ROSS: I wrote to the Board. Twice. They wrote back to thank me for my interest.
* My father wrote that entry. -> blame_father
* [if clue("same_hand")] I wrote that entry. -> confess
* What do you want from me? -> want
= blame_father
! set blamed_father=1
ROSS: Did he.
ROSS: Then he wrote it with your hand, Callum. I'd know it anywhere.
-> calls
= confess
! set confessed_to_ross=1
! add rel.ross 2
ROSS: ...
ROSS: Aye. I know. I've known for two years.
ROSS: You were twenty-three. You did what your father told you. God help me, so did I at that age.
-> calls
= want
ROSS: The truth in the light's own book. In your hand, since it was your hand. And I want to see my girl's ship past the Gut tonight. She's on the Stornoway run. She'll be abeam of your light by five.
-> calls
= calls
* And the calls on sixteen. That was you. -> calls_ask
* (Say nothing.) -> calls_quiet
= calls_ask
ROSS: It was. I keyed my set at dusk to see if North Point was listening. Then I gave you the Mary Ellen, near enough the words I gave Stornoway that night.
-> calls_rest
= calls_quiet
ROSS: You'll be wondering about the wireless. That was me. Dusk, and midnight, and after. Near enough the words I gave Stornoway that night.
= calls_rest
[if has_flag("answered_me")] ROSS: You answered me. Proper procedure, the way your father taught you. I nearly turned for home.
[if has_flag("ignored_me") and not has_flag("answered_me")] ROSS: You didn't answer me. That told me more than an answer would have.
ROSS: I lay in the Gut where she struck, twenty minutes. You'll have had me on your radar. Then back into the lee.
[if has_flag("told_dead")] ROSS: You told me Iain died in fifty-eight. I knew. I read it in the Gazette.
ROSS: I asked for him knowing he was in Tarbert kirkyard. That was cruel. I've had eighteen years to learn cruel.
ROSS: And when I tied up I lashed my handset down. A carrier on sixteen, and nobody gets a word through. I wanted the hour with you. The battery'll be flat by now.
-> drawer
= drawer
ROSS: Your father and I sat in this room more summer nights than I could count. I brought the stores; he brought the Grant's. You'd be up the ladder winding the clockwork and singing.
ROSS: He was my friend, Callum. That's the part I've never managed.
ROSS: A year past March I knocked on Kenny Bain's door in Scalpay. The only one of my crew still breathing. He knew me before I opened my mouth.
* [if clue("rory_grandfather")] His grandson brought a boat in tonight. Rory. -> rory
* (Let him go on.) -> kenny
= rory
ROSS: Kenny's boy's boy. Kenny said he'd the gift of the gab and none of the caution.
ROSS: He'll have told you about the boat in the Gut, then. That was Kenny's story. Kenny knew fine whose boat it was.
= kenny
ROSS: Kenny told me your father drank in the Harris Hotel the Christmas before he died. And one night he said, "I've written it down for the boy. It's in the desk. He'll find it when I'm gone."
ROSS: Kenny thought it was the drink talking. Kenny died at Easter.
ROSS: Iain was a tidy man. Look in the bottom drawer of that desk.
```

#### `ch5_letter` (EDITED: quotes the canonical letter, C11)
```
== ch5_letter mode=thought
~ Under the old tide tables, an envelope. My name on the front, in Father's careful copperplate. Never sealed.
~ "Callum. I made you write it. I made a boy of twenty-three put his hand to my lie, because I was asleep in this chair with the bottle, and the light was out, and I could not face it."
~ "Ross was a better man than me, and he was my friend. If you ever have the courage I did not, put it right."
~ Christmas, nineteen fifty-seven. He died in the March.
* (Hand the letter to Ross.) -> hand
* (Fold it into your pocket.) -> keep
= hand
! set gave_letter=1
! add rel.ross 1
[if has_flag("door_shut")] ~ I slide it under the door. On the other side, a long time, nothing.
ROSS: ...
ROSS: He used to sing that song as well, you know. When he thought nobody could hear. Badly.
-> END
= keep
! set kept_letter=1
[if has_flag("door_open")] ~ Ross watches me fold it away. He doesn't ask.
[if has_flag("door_shut")] ~ I fold it away. Through the door he can't know what I've done, and he doesn't ask.
```

#### `ch5_morag` (EDITED)
```
== ch5_morag mode=radio
! static
MORAG: North Point, Stornoway. Sixteen's been blocked solid for half an hour. Callum, talk to me. Are you safe? Over.
* [if has_flag("door_open")] He's inside. He's an old man and he's wet through. I'm safe. -> safe
* [if has_flag("door_shut")] He's still at the door. I'm safe. -> safe
* Morag. It's Alasdair Ross. -> ross
= safe
MORAG: Who is he, Callum?
= ross
MORAG: ...
MORAG: That's not possible.
[if has_flag("door_open")] ROSS@room: It's possible, lass. You wrote me down at eight minutes to two. I heard you say "Roger, Mary Ellen" and then nothing. Yours was the last voice I heard before the sea.
[if has_flag("door_shut")] CALLUM: He says you wrote him down at eight minutes to two. He says yours was the last voice he heard before the sea.
MORAG: ...I'm going to need to sit down.
```
The old `safe_door` label is merged into `safe`, since the line was identical.

#### `ch5_mayday` (EDITED: C6, N6, in-room tags)
```
== ch5_mayday mode=radio
! static heavy
ELSPETH: Mayday, Mayday, Mayday. This is Iona Star, Iona Star, Iona Star.
ELSPETH: Master's injured. This is the mate. Steering gear failed. We've rigged hand steering aft, slow to answer.
ELSPETH: The flood tide's setting us down onto North Point faster than we can steer. Twelve souls aboard. Position one point two miles north-east of North Point Light. Over.
MORAG: Iona Star, Stornoway. Mayday received. Lifeboat is engaged at the Shiants, two hours. North Point Light is your nearest station. Over.
[if has_flag("door_open")] ~ Ross has his hand on the back of the chair. All the colour has gone out of his face.
[if has_flag("door_shut")] ~ Behind the door, something heavy slides down to the floor.
ROSS@room: That's Elspeth. That's my girl.
```

#### `ch5_dark` (KEPT)

### 8.6 Chapter 6

#### `ch6_iona` (EDITED)
```
== ch6_iona mode=radio
! static
ELSPETH: North Point, Iona Star. I see your light. I see it. Callum Mackay, I need you to put me through the East Gut. I can't make the open sea against this. Over.
[if has_flag("told_elspeth_there")] ELSPETH: You said you were there, that night. Then you know this water better than anyone alive. Over.
[if not has_flag("elspeth_letter_told")] ELSPETH: And Mr Mackay. A month ago someone wrote to tell me your light was out the night my father drowned. No name on it.
[if not has_flag("elspeth_letter_told")] ! set elspeth_letter_told=1
[if has_flag("elspeth_letter_told") and not has_flag("told_elspeth_there")] ELSPETH: If it goes out tonight, I'll know they were right. Over.
* I'll put you through, Elspeth. Confirm your position when I call. Over. -> yes
* [if relation("elspeth") > 0] You'll come through, Miss Ross. You've my word. Over. -> word
= word
! add rel.elspeth 1
ELSPETH: Your word. Right. Over.
= yes
ELSPETH: Hand steering's slow. Give me your corrections early. Iona Star listening.
```

#### `ch6_jam` (EDITED: mode-independent, freeing by hand, how Ross addresses Callum)
```
== ch6_jam mode=thought
> [A grinding shudder overhead. The clockwork stops.]
~ The amber lamp. The bearing repeater stops at oh-four-six. The handwheel's gone rigid as a post.
~ Of course it does. Of course it does tonight.
[if has_flag("door_open") and relation("ross") >= 2] ROSS@room: Callum. It's the tooth. Motor off, and we'll back her off it by hand. Then give me the wheel and talk my girl in.
[if has_flag("door_open") and relation("ross") < 2] ROSS@room: Keeper. It's the tooth. Motor off, and back her off it by hand. Then give me the wheel and talk my girl in.
[if has_flag("door_shut")] ROSS@room: Callum! It's the tooth, I can hear it from here. Motor off and back her off by hand. Then open this door. You can't hold the light and talk her in both.
* [if has_flag("door_shut")] (Open the door.) -> open_now
* [if has_flag("door_shut")] Stay where you are. I'll do it myself. -> alone
* [if has_flag("door_open")] Take the wheel, Mr Ross. -> together
* [if has_flag("door_open")] I'll do it myself. -> alone
= open_now
! set door_open=1
! unset door_shut
! door_open
! visitor_enter
ROSS: There's the boy.
= together
! set ross_wheel=1
! add rel.ross 1
ROSS@room: Two men to one wheel, then. Same as it should have been.
-> END
= alone
! set ross_wheel=0
~ Motor off. Back the wheel off the tooth. Then MANUAL, and find her in the rain.
```
If the player chose `open_now`, the conversation falls through to `together`: opening the door means accepting his help, as now.

#### `ch6_freed` (NEW)
```
== ch6_freed mode=thought
> [A clunk you feel in your teeth. The wheel turns free.]
[if has_flag("ross_wheel")] ~ Ross takes the spokes from me without a word. His hands know this wheel. They've been on it before.
[if has_flag("ross_wheel")] ROSS@room: I have her. Go to your radio.
[if not has_flag("ross_wheel")] ~ Free. Hand on the spokes, eye on the radar, the handset on its long cord. Find her in the rain and hold her there.
```

#### `ch6_rory` (NEW)
```
== ch6_rory mode=radio
! static
RORY: North Point, Kittiwake. I heard the Mayday. I'm at the mouth of the Sound with every light I own switched on. If she wants a mark on the far side of the Gut, she's got one. Over.
* Good lad. Stay there. Over. -> ok
* [if clue("rory_grandfather") and has_flag("knows_name")] Rory. Your grandfather was right about the boat in the Gut. -> right
= right
RORY: ...Eh?
RORY: Tell me after, Callum. Tell me after. Kittiwake standing by.
-> END
= ok
RORY: Standing by. Kittiwake.
```

#### `ch6_outcome` (EDITED: the letter payoff, in-room tags)
```
== ch6_outcome mode=radio
[if saved("Iona Star")] ELSPETH: North Point, Iona Star. We're through. We're through the Gut, we've the island's lee. Nobody hurt. Over.
[if saved("Iona Star")] -> saved
[if lost("Iona Star")] ~ She takes the ground on the outer edge of the Gut with a sound I can feel through the floor. The beam is on her the whole time.
[if lost("Iona Star")] ELSPETH: ...Iona Star aground, North Point. We're holed forward. She's sitting upright. All twelve on the bridge. We'll hold till the lifeboat. Over.
[if lost("Iona Star")] -> lost
= saved
* [if has_flag("ross_wheel") or has_flag("door_open")] (Hand Ross the handset.) -> father
* Well steered, Iona Star. North Point. Out. -> plain
= father
! set reunion=1
ROSS@room: Elspeth.
! wait 2.0
ELSPETH: ...Who is this.
ROSS@room: I've your mother's eyes on a photograph in my coat. I named my boat for her before I named it for anything else. Eighteen years, lass. I'm sorry.
! wait 2.5
ELSPETH: ...Dad?
[if has_flag("elspeth_letter_told")] ! wait 1.5
[if has_flag("elspeth_letter_told")] ELSPETH: You sent the letter.
[if has_flag("elspeth_letter_told")] ROSS@room: I did. I'd not the courage to sign it.
-> END
= plain
ELSPETH: Thank you, North Point. Thank you. Iona Star out.
-> END
= lost
ROSS@room: She's upright. She's upright, Callum. That's the Gut's sand ledge. They'll walk off her at low water.
```

#### `ch6_morag_dawn` (EDITED: C2, C7, callbacks, "together")
```
== ch6_morag_dawn mode=radio
! static
MORAG: North Point, Stornoway. Lifeboat reports on scene. Wind veering westerly. It's over, Callum. Over.
MORAG: I've a log to close for tonight. And an old one I never closed. Is there anything North Point wishes to report? Over.
* Stornoway, North Point. Amend my station log, entry of fifteenth November 1953. Over. -> truth
* Nothing to report, Stornoway. North Point out. -> silence
= truth
! set told_truth=1
CALLUM: The light at North Point stopped turning at approximately oh-one-forty, and was extinguished from approximately oh-one-fifty until oh-two-oh-one.
CALLUM: The log entry for oh-two-ten was false. It was written by me, on the principal keeper's instruction.
[if has_flag("kept_letter")] CALLUM: I hold a letter from the principal keeper, Iain Mackay, admitting it.
[if has_flag("gave_letter")] CALLUM: Mr Alasdair Ross holds a letter from the principal keeper, Iain Mackay, admitting it.
CALLUM: The master of the Mary Ellen kept a proper lookout. There was no light for him to see. Over.
! wait 2.0
MORAG: ...North Point, Stornoway. Received and logged. Every word.
[if has_flag("lied_to_morag")] MORAG: You told me at half past one that the log was right. I'll not say anything about that on the air.
[if has_flag("deflected_morag")] MORAG: You asked me what it mattered, after eighteen years. Well. Now you know.
[if has_flag("admitted_to_morag")] MORAG: You told me first. In the dark, with the set half dead. I'll remember that.
[if has_flag("lied_heard")] MORAG: And at midnight, when you said you'd heard nothing. Let that be the last one.
[if lost("Iona Star")] MORAG: Then we'll say it together. My notebook and your book, in the same room.
[if relation("morag") >= 2] MORAG: Kitchen table, Callum. I'll put the kettle on. Stornoway out.
[if relation("morag") < 2] MORAG: Stornoway out.
-> END
= silence
! set kept_lie=1
[if has_flag("admitted_to_morag")] MORAG: ...Three hours ago you told me the light was out before she struck.
[if has_flag("admitted_to_morag")] MORAG: I'll not put that in my log, Callum. You'll have to.
MORAG: ...Roger, North Point. Nothing to report.
MORAG: Stornoway out.
[if has_flag("door_open")] ~ Behind me Ross sets down the cup I gave him, very carefully, as if it might break.
[if has_flag("door_open")] ROSS@room: Aye. Well.
[if has_flag("door_shut")] > [Footsteps going down the stair, one at a time]
```

#### `ch6_final_log` (EDITED: wording reflects `confessed_to_ross`, `blamed_father` and `gave_letter`)
```
== ch6_final_log mode=thought
~ Oh-six-thirty. The rain's thinning to a mist, and the sea's going from black to the colour of slate.
[if has_flag("told_truth")] ~ I open the station log and write it the way it happened. Small square letters. A clerk's hand.
[if has_flag("told_truth") and has_flag("confessed_to_ross")] ~ "15.11.71. 06.30. Correction to entry of 15.11.53. Light extinguished 01.50 to 02.01. The entry at 02.10 is false, and in my hand. The master of the Mary Ellen is not to blame. C. Mackay, P.K."
[if has_flag("told_truth") and not has_flag("confessed_to_ross")] ~ "15.11.71. 06.30. Correction to entry of 15.11.53. Light extinguished 01.50 to 02.01. The entry at 02.10 is false, written on the instruction of the principal keeper. The master of the Mary Ellen is not to blame. C. Mackay, P.K."
[if has_flag("told_truth") and has_flag("blamed_father")] ~ On the instruction of the principal keeper. True. And still a way of standing behind him.
[if has_flag("kept_lie")] ~ I open the station log and write: "15.11.71. 06.30. Storm abating. Light exhibited throughout. Nothing to report."
[if has_flag("kept_lie")] ~ It's the second lie I've written in this book. It comes no easier than the first.
[if has_flag("kept_lie") and has_flag("gave_letter")] ~ Ross has Father's letter. He can do what he likes with it. I'll not stop him.
```

#### `ch6_epilogue` (EDITED: shown on the ending card, §15; C9; Leverburgh)
```
== ch6_epilogue mode=thought
[if has_flag("told_truth") and saved("Iona Star")] ~ The Board opened a new inquiry in the spring. It took eleven minutes to read Morag's notebook into the record.
[if has_flag("told_truth") and saved("Iona Star") and has_flag("gave_letter")] ~ Father's letter was read after it. Nobody in the room looked at me while it was read, which was a kindness.
[if has_flag("told_truth") and saved("Iona Star") and has_flag("kept_letter")] ~ I read Father's letter into the record myself. My voice held until the last line.
[if has_flag("told_truth") and saved("Iona Star")] ~ Alasdair Ross lived until August. Elspeth took him home to Leverburgh, and he was buried there under his own name.
[if has_flag("told_truth") and lost("Iona Star")] ~ The Iona Star was refloated on the March springs. Nobody was lost.
[if has_flag("told_truth") and lost("Iona Star")] ~ The two inquiries were heard together, the old one and the new. Morag read her notebook. I read my book.
[if has_flag("told_truth") and lost("Iona Star")] ~ Ross gave his evidence from a chair. Elspeth sat beside him and held his hand the whole day. He lived to hear it.
[if has_flag("kept_lie") and saved("Iona Star") and not has_flag("reunion")] ~ Ross left with the morning tide in the black boat. Elspeth brought the Iona Star into Stornoway at noon and never knew who had held the light on her.
[if has_flag("kept_lie") and saved("Iona Star") and has_flag("reunion")] ~ Ross left with the morning tide. Elspeth met him on the pier at Stornoway that night. I heard it from Morag, not from either of them.
[if has_flag("kept_lie") and saved("Iona Star") and has_flag("reunion")] ~ The Inquiry's finding stands. She knows it isn't true. She can't prove it. I could have.
[if has_flag("kept_lie") and has_flag("gave_letter")] ~ He never used Father's letter. I think it was a kindness. I think it was the cruellest thing he ever did.
[if has_flag("kept_lie") and saved("Iona Star")] ~ Some nights on sixteen I hear a carrier with no voice on it, and I don't answer it.
[if has_flag("kept_lie") and lost("Iona Star")] ~ There was a second inquiry, for the Iona Star. They read my log into the record. Light exhibited throughout.
[if has_flag("kept_lie") and lost("Iona Star")] ~ They believed it. People always believe the light.
~ North Point Light. Fifteenth of November, nineteen seventy-one.
~ The light was kept.
```

### 8.7 Conversation status summary
| Status | Conversations |
|---|---|
| **KEPT (28)** | `ch1_gen`, `ch1_charging`, `ch1_bearings`, `ch1_morag_late`, `ch1_mary_ellen`, `ch1_morag_heard`; `ch2_phantom`, `ch2_gannet`, `ch2_mary_ellen`; `ch3_forecast`, `ch3_corrie`, `ch3_lowestoft`, `ch3_notes_a`, `ch3_dark`, `ch3_rory_dark`; `ch4_watch`, `ch4_bow`; `ch5_dark`; and the rest unchanged |
| **EDITED (26)** | `ch1_dusk`, `ch1_lit`, `ch1_radio_check`, `ch1_rory_call`, `ch1_rory_in`, `ch1_log_after`; `ch2_trace`, `ch2_gannet_after`, `ch2_same_hand`, `ch2_jam`, `ch2_046`; `ch3_after_two`, `ch3_elspeth`, `ch3_notes_b`; `ch4_docked`, `ch4_door`; `ch5_ross`, `ch5_letter`, `ch5_morag`, `ch5_mayday`; `ch6_iona`, `ch6_jam`, `ch6_outcome`, `ch6_morag_dawn`, `ch6_final_log`, `ch6_epilogue` |
| **NEW (9 + room lines)** | `ch1_carrier`; `ch4_stairs`, `ch4_mf_morag`; `ch6_freed`, `ch6_rory`; `opt_ch2_rory`, `opt_ch2_morag`, `opt_ch3_hector` (§11); the `look_*` room lines (§11.3) |
| **RETIRED (2)** | `ch1_normal`, `ch1_battery`: their lines are merged into `ch1_lit`. Old saves can't reference them, because saves are taken between beats; the ch1 beat ids are remapped (§18.1) |

---

## 9. Player choices
| Where | Choice | Sets | Read by (consequence) |
|---|---|---|---|
| `ch1_radio_check` | proper / early | `rel.morag` +1 (early) | Dawn: the kitchen-table line |
| `ch1_radio_check` | knows / deflect / flat | `rel.morag` ±1 | Dawn |
| `ch1_rory_call` | calm ×2 | — | Flavour only: both are honest procedure (an acknowledged flavour choice) |
| `ch1_rory_in` | joke / which | `clue rory_grandfather` | `ch5_ross` (Rory branch), `ch6_rory` (right) |
| `ch1_morag_late` | mind / rules; true / warm / quiet | `rel.morag` | Dawn |
| `ch1_morag_late` | never / once | `admitted_once` | `ch3_notes_b` |
| `ch1_mary_ellen` | again / burning / silent | `answered_me` / `ignored_me` | `ch5_ross` |
| `ch1_morag_heard` | heard / lie | `lied_heard`, `rel.morag` −1 | Dawn (truth branch) |
| `ch2_trace` | know / prank | `rel.morag` | Dawn |
| `ch2_trace` | there / asleep / notnow | `admitted_there` / `said_asleep` / `rel.morag` | `ch3_notes_b` |
| `ch2_gannet` | help ×2 | — | Flavour (procedure) |
| `ch2_mary_ellen` | who / dead / off | `told_dead` / `ignored_me` | `ch5_ross` |
| `ch3_elspeth` | name / curt | `rel.elspeth` −1 (curt); `elspeth_letter_told` (name) | `ch6_iona`, `ch6_outcome` |
| `ch3_elspeth` | sorry_there / know / silence | `told_elspeth_there`, `rel.elspeth` | `ch6_iona` |
| `ch3_notes_b` | lie / deflect / admit | `lied_to_morag` / `deflected_morag` / `admitted_to_morag`, `rel.morag` | Dawn (both branches) |
| `ch4_door` | who / sy / hard | `rel.ross` | `ch6_jam` (how Ross addresses him) |
| `ch4_door` | name / want / radio / fifteenth | `clue grants`, `called_morag`, `rel.ross` | grants: the tide-tables room line; `called_morag` hides repeats |
| `ch4_door` | open / name_ask / shut | `door_open` / `door_shut`, `knows_name`, `clue photo_1953` | All of ch5–6 |
| `ch5_ross` | how / why | — | Order and content (`how` adds the "Sandy" line) |
| `ch5_ross` | stayed ×2 | — | Pacing beat (acknowledged flavour) |
| `ch5_ross` | blame_father / confess / want | `blamed_father` / `confessed_to_ross` (+`rel.ross` 2) | `ch6_final_log` wording; `ch6_jam` |
| `ch5_ross` | calls_ask / calls_quiet | — | Same information, delivered differently (flavour) |
| `ch5_ross` | rory / kenny | — | Extra Rory lines |
| `ch5_letter` | hand / keep | `gave_letter` / `kept_letter` | Dawn, final log, epilogue |
| `ch5_morag` | safe / ross | — | Flavour |
| `ch6_iona` | yes / word | `rel.elspeth` | Flavour plus relation |
| `ch6_jam` | together / alone / open_now | `ross_wheel`, `door_open` | **Sim assist**; reunion availability |
| `ch6_rory` | ok / right | — | Flavour |
| `ch6_outcome` | father / plain | `reunion` | Epilogue (C9) |
| `ch6_morag_dawn` | truth / silence | `told_truth` / `kept_lie` | **Ending** |
| Gameplay | Rescue each ship | `saved` / `lost` | Dialogue variants; *Iona Star* decides the ending |

## 10. Conditional dialogue (index)
- **Callbacks to earlier choices:**
  - `ch3_notes_b` ← `admitted_once`, `admitted_there`, `said_asleep`;
  - `ch5_ross` ← `answered_me`, `ignored_me`, `told_dead`, `clue sandy`, `clue rory_grandfather`, `knows_name`;
  - `ch6_iona` ← `told_elspeth_there`, `elspeth_letter_told`;
  - `ch6_jam` ← `relation("ross")`, `door_*`;
  - `ch6_outcome` ← `elspeth_letter_told`;
  - `ch6_morag_dawn` ← `lied_to_morag`, `deflected_morag`, `admitted_to_morag`, `lied_heard`, `kept_letter`, `gave_letter`, `lost`, `relation("morag")`;
  - `ch6_final_log` ← `confessed_to_ross`, `blamed_father`, `gave_letter`;
  - `ch6_epilogue` ← `told_truth`, `kept_lie`, `saved`/`lost`, `reunion`, `gave_letter`, `kept_letter`.
- **Optional finds:**
  - `ch4_door` ← `found_grants`, `clue sister_boat`, `bolted`.
- **Outcomes:**
  - kept as now: `ch2_gannet_after`, `ch3_after_two`, `ch4_bow`.

## 11. Optional encounters
**Rules:**
- Optional content is never needed to understand the story.
- Each item pays off somewhere: a dialogue variant, a later line, or player knowledge that a later scene confirms.

### 11.1 Optional radio calls
They are offered through the radio panel as a **"Call" entry** on a station that has a pending call. They are available only while no story conversation is running. The director defers queued `talk` actions until an optional call ends (§18.1).

**`opt_ch2_rory`** (NEW; window: from 2.4 `gannet_in` until 2.6 `archive` resolves; station: *Kittiwake*)
```
== opt_ch2_rory mode=radio
CALLUM: Kittiwake, North Point. You're tied up snug? Over.
! static
RORY: Eh, North Point! Snug as anything. I'm sat here watching your light go round. Over.
RORY: Here, Callum. That call on sixteen. The Mary Ellen. Half the Sound heard it. Over.
RORY: My grandfather'd have had his coat on and been out the door. He'd never go past the Gut after dark, not once in eighteen years. Said he'd no wish to meet her. Over.
* Get some sleep, Rory. -> sleep
* Did he say why? -> why
= why
RORY: He said she wasn't finished. That's all. "She's not finished, Ruaridh."
RORY: ...Eh. That's the wind talking. Sorry. Over.
= sleep
RORY: Aye. Aye, right. Kittiwake out.
```
Payoff: Ross in ch5 ("Kenny knew fine whose boat it was").

**`opt_ch2_morag`** (NEW; window: same; station: Stornoway)
```
== opt_ch2_morag mode=radio
CALLUM: Stornoway, North Point. Over.
! static
MORAG: North Point, Stornoway. Go ahead, Callum.
CALLUM: That register. Anything else under her name? Sisters. Rebuilds. Over.
MORAG: You're thinking what I'm thinking. Wait one.
! wait 2.5
MORAG: Mary Ellen had a sister off the same yard in Fraserburgh. The Catriona. Sold for breaking in nineteen sixty-nine, to a Mr Morrison. Govan.
MORAG: Govan's a long road from razor blades to the Minch. Stornoway out.
! clue sister_boat
```
Payoff: Ross in `ch4_door` (`sy` branch) heard this broadcast, which shows he has been listening all night.

**`opt_ch3_hector`** (NEW; window: from 3.3 `both` until 3.4 `elspeth`; station: *Gannet*)
```
== opt_ch3_hector mode=radio
CALLUM: Gannet, North Point. Are you snug, Hector? Over.
! static
HECTOR: Snug as a dog in a basket, North Point. Lying to two anchors in the West Gut lee, and the passengers asleep at last. Over.
HECTOR: I was thinking of your father. On a night like this he'd have had the kettle on and the tide tables open, and Sandy Ross up from the boat telling lies about herring.
* Sandy Ross? -> sandy
* He never spoke of it. -> never
= sandy
HECTOR: Alasdair. Nobody called him that but the minister. Sandy and Iain, thick as thieves, the summers Sandy ran the Board's stores.
HECTOR: Och. I'm sorry, Callum. I'm an old fool tonight. Gannet out.
! clue sandy
-> END
= never
HECTOR: No. He wouldn't, after. Nobody on Harris said the name for a long while. Gannet out.
! clue sandy
```
Payoff: the "Sandy" line in `ch5_ross`, plus the friendship (N3) for players who never pick `how`.

### 11.2 Optional objects and examinations (new interactions)
| Object | Where (existing geometry) | Available | Thought (conversation id) | Sets / pays off |
|---|---|---|---|---|
| GPO telephone | `ANCHOR_telephone`, desk | Always | `look_phone`: `~ The GPO line to Leverburgh exchange. Dead since the September gale took the cable on the shore.` / `~ Nothing in it but my own breathing. The relief boat's to bring a linesman. Thursday, if the sea allows.` In ch4 between 4.3 and 4.5: `~ Dead. I knew it was dead. I tried it anyway.` | Isolation. No calls, ever (Daniel's decision) |
| Admiralty Tide Tables + Grant's | `ANCHOR_tide_tables`, top storage shelf (the bottle already modelled behind them) | Always | Before `clue grants`: `look_grants_a`: `~ Admiralty Tide Tables, nineteen fifty-three. Nobody's opened them in eighteen years.` / `~ Behind them, Father's half-bottle of Grant's. Still half. I've never drunk it, and I've never poured it out.` After `clue grants` and not `found_grants`: `look_grants_b`: `~ Top shelf, behind the Tables. He was right. How would a stranger know that?` | `found_grants` → `ch4_door` |
| Vapour-burner kit | Storage shelf (modelled) | Always; the text changes after `clue same_hand` | Before: `look_vapour_a`: `~ The old vapour burner, from before they put the electric in. Paraffin under pressure, and a mantle like a lady's stocking.` After: `look_vapour_b`: `~ Leave the pump alone for half an hour and she starves, and gutters, and goes out. "Mantle failure," the book says. Two minutes.` | Investigation (C): how the light really went out |
| Photograph from 1953 | Floor anchor inside the stair door (REFERENCE_SPEC) | `clue photo_1953` (door shut); or from ch5 if `door_open` (Ross leaves it on the desk; see the `look_photo53` intro) | Opens document `photo_1953` (EDITED, §12) | The Kenny Bain link; the faces of the crew |
| Stair-door bolt | The stair door | Ch4 from 4.3 until the door scene | `look_bolt`: `> [The bolt goes home]` / `~ Two inches of oak and a bolt my father fitted. It'll have to do.` | `bolted` → `ch4_door` `open` |
| Old-log box (second open) | Existing `archive` | After 2.6 | Opens `inquiry_extract` (NEW, §12) | The "confused and unreliable" wording. The photostat Ross saw |
| MF radio call | Desk radio | Ch4, from 4.3 until the door scene, if `called_morag` is not set | `ch4_mf_morag` (NEW) | `called_morag` |

### 11.3 Chapter-dependent room lines (after-read thoughts on existing documents)
Each one plays once, after the document closes, the first time the player reads it in that chapter range.

| Object | Ch1–2 | Ch3–4 | Ch5–6 |
|---|---|---|---|
| Wall photo (`photo_keepers`) | `~ Father and me, May fifty-two. He'd his arm round me for the camera. He never did otherwise.` | `~ Eighteen months after that, he had me write it.` | `~ He'd his arm round me for the camera. I'd give a good deal to know what he was thinking.` |
| Console note (`note_046`) | `~ Father's note and mine under it. Twenty-two years of "next refit".` | — | `~ Free by hand. He wrote that in nineteen forty-nine. He knew.` |
| Coat note (`coat_note`) | `~ Paraffin, cells, tea. Glass for the west window. And a linesman for the phone, if they remember.` | — | `~ My stores list. The same hand Ross carried out here every summer.` (needs `knows_name`) |
| Forecast (`forecast`) | — | `~ Storm ten. They said imminent at four o'clock. They were right.` | — |

---

## 12. Environmental clues and document texts

### 12.1 Clue table
| Clue | Medium | First available | Points toward |
|---|---|---|---|
| The date line, "sat looking at it" | Ch1 thought | 0:10 | Callum knows something about tonight |
| A carrier with no voice | Ch1 sound | ≈5 min | Someone out there with a set (Ross) |
| Rory's grandfather (aboard, sole survivor) | Ch1 radio | Ch1 | A living link to the wreck |
| 046 note dated Dec 1953 | Console note | Always | Callum reported the fault right after the wreck |
| Vapour kit and mantle | Shelf | Always | How the light really went out |
| Grant's behind the Tide Tables | Shelf | Always | Iain drank on watch. Who else knew? |
| 1953 log in Callum's hand | Archive | Ch2 | Callum wrote it |
| Clipping: Kenneth Bain, sole survivor | Archive | Ch2 | Rory's grandfather |
| Inquiry extract ("confused and unreliable"; photostat) | Archive, second open | Ch2 | The court ignored the Mayday. Ross saw the page |
| Sister boat, *Catriona*, sold to a Mr Morrison, Govan | Optional radio | Ch2 | The look-alike boat. Ross's alias |
| "Sandy Ross" | Optional radio | Ch3 | Ross's alias, and the friendship |
| Morag's notebook, 01:52 | Ch3 radio | Ch3 | The log is false |
| SY 214 on the bow | Ch4 beam | Ch4 | Someone wants to be seen as the *Mary Ellen* |
| The song, the bottle, the tooth | Ch4 door | Ch4 | The visitor has been in this room |
| Photograph from 1953 | Under the door / desk | Ch4–5 | Ross and Kenny together |
| Iain's letter | Drawer | Ch5 | Why |

### 12.2 Canonical document texts (`docs.json`; rendered in 3C with the OFL fonts)

**`log_1971` (EDITED, C10).** Title "Station log, 14 November 1971":
```
14.11.71 Sun.  16.22  SW 6, overcast, rain. Light exhibited. Lamp normal.
16.40  Engine started. Batteries on charge, 41%.
18.30  Radio check Stornoway CG. Gale warning: SW 7 rising severe gale 9.
18.50  Kittiwake (SY 37) brought in by North Sound on radio bearings.
23.25  Stornoway CG on Ch. 16. All well.
(Hand: C. Mackay)
```

**`log_1953` (KEPT).** "Signed I. Mackay, P.K." The entries are in the same small square hand as tonight's log.

**`letter_1957` (EDITED, C11: the single canonical text; `ch5_letter` quotes it exactly):**
```
Christmas 1957

Callum,

I made you write it. I made a boy of twenty-three put his hand to my lie, because I was asleep in this chair with the bottle, and the clockwork stuck on the bad tooth, and the light was out, and I could not face it.

The girl at Stornoway had it right. Ten minutes to two. I heard the wireless in my sleep and thought I was dreaming.

Ross was a better man than me, and he was my friend. If you ever have the courage I did not, put it right.

Your father,
Iain Mackay
```

**`note_046` (EDITED: dated entries, and the procedure that teaches ch2 and ch6):**
```
GEAR RACE: worn tooth at 046°. Sticks in heavy weather.
FREE BY HAND: motor OFF, back the handwheel past the tooth, then re-engage.
Reported to Board 4.3.49. I.M.
Reported again 9.12.53. C.M.
Reported again 2.2.61. Engineer says "next refit". C.M.
```

**`clipping_1954` (KEPT).** It already names deckhand Kenneth Bain as the sole survivor, below at the time.

**`photo_1953` (EDITED):**
> Eight men on a deck at Leverburgh pier. The one at the wheel is laughing. On the back, in pencil: "Mary Ellen, July 1953. A. Ross, master." Beneath, in another hand: "Kenny B. on the hatch."

**`inquiry_extract` (NEW).** Title "Report of Formal Investigation: m.f.v. *Mary Ellen* (SY 214). Stornoway, March 1954. Extract and Appendix C":
```
22. The Court has considered a wireless message logged by Stornoway Coastguard at 01.52, which was said to report that no light was visible from North Point. The message was received in conditions of severe interference. The Court finds it confused and unreliable.

23. The Court prefers the evidence of the station log of North Point Light, kept by a principal keeper of long and unblemished service, which records that the light was exhibited throughout save for approximately two minutes at 02.10.

24. The Court finds that the master, Alasdair Ross, failed to keep a proper lookout and stood into danger despite the light being exhibited.

APPENDIX C. Photostat of the station log, North Point Light, 14-15 November 1953. (The page shown is in a small square hand.)
```

**`forecast`, `photo_keepers`, `coat_note` (KEPT).**

---

## 13. Suspense sequences
1. **The voiceless carrier (ch1, about 5 min).** Two clicks, no voice. Callum dismisses it as some boy, and the player remembers it.
2. **The *Mary Ellen* call (ch1 end).** Heavy static, fragments, the player's choice of reply. Then nothing, not even the carrier.
3. **The 046 echo (ch2).** It holds still against the sweep, then it's gone.
4. **"Tell Iain" (ch2).** The caller asks for a dead man by his first name.
5. **The archive (ch2).** A quiet dread: "I know what it says. I don't need to open it."
6. **The blackout (ch3).** Morag reading her notes, then bang, darkness, and only the red MAIN lamp.
7. **The dark boat and the stair (ch4). The centrepiece:**
   - the echo coming in on the radar;
   - the beam finds SY 214;
   - the engine stops and the carrier blocks 16;
   - **the player keeps control throughout.** Optional actions: bolt the door, take the torch, try the phone, call on the MF set;
   - jetty footsteps, the base door, a cough deep in the chest, a hundred and nine steps one at a time;
   - silence, then three slow knocks;
   - "Evening, keeper. … I could not see your light."
   - No forced camera. Captions carry the sound for accessibility.
8. **The Mayday (ch5).** Elspeth's voice, procedure-perfect, and Ross's "That's my girl." Then black.

## 14. Climactic moments
1. **The admission to Morag (ch3).** This is the player's first chance to say it.
2. **The door (ch4).** Open it or keep it shut. Both are valid and both carry through to the end.
3. **The letter (ch5).** It is read in silence while Ross waits. Hand it over or keep it.
4. **The jam at 046 (ch6).** The same tooth on the same bearing as in 1953. **The player frees it by hand**, as the note says. If Ross is in the room, two men work one wheel.
5. **The beam on the *Iona Star* (ch6).** Gameplay: hold the light, vector her through the Gut.
6. **The handset (ch6, saved).** "Elspeth." … "…Dad?" … "You sent the letter."
7. **The dawn report (ch6).** The truth on the air or "Nothing to report", then the log entry in the clerk's hand.

---

## 15. Four ending paths
**The ending is decided by:**
- the dawn report (`told_truth` / `kept_lie`), a choice the player plainly understands;
- whether the *Iona Star* is brought through (`saved` / `lost`).

Earlier choices colour every ending with their own lines (§16.2), but no earlier choice locks one out. The truth is always available, which is the theme: it's never too late, but it costs something.

| | **Truth told** | **Lie kept** |
|---|---|---|
| ***Iona Star* saved** | **"Correction"** | **"Nothing to Report"** |
| ***Iona Star* aground** | **"Heard Together"** | **"Light Exhibited Throughout"** |

### 15.1 "Correction": truth + saved
- **Conditions:** `told_truth` and `saved("Iona Star")`.
- **Emotional meaning:** the lie is ended by the hand that wrote it. A father gets his name back, and a daughter gets her father back.
- **Final scene:** the dawn report, then the log correction.
- **Final dialogue:** Morag: "Received and logged. Every word."
- **Card:**
  > **CORRECTION**
  > *The Board opened a new inquiry in the spring. It took eleven minutes to read Morag's notebook into the record.*
  > *(letter variant)*
  > *Alasdair Ross lived until August. Elspeth took him home to Leverburgh, and he was buried there under his own name.*
  > North Point Light · 15 November 1971
  > *The light was kept.*

### 15.2 "Heard Together": truth + aground
- **Conditions:** `told_truth` and `lost("Iona Star")`.
- **Meaning:** grief and truth in the same room. Nobody died, but nothing came easy.
- **Final dialogue:** Morag: "Then we'll say it together. My notebook and your book, in the same room."
- **Card:**
  > **HEARD TOGETHER**
  > *The Iona Star was refloated on the March springs. Nobody was lost.*
  > *The two inquiries were heard together, the old one and the new. Morag read her notebook. I read my book.*
  > *Ross gave his evidence from a chair. Elspeth sat beside him and held his hand the whole day. He lived to hear it.*
  > North Point Light · 15 November 1971
  > *The light was kept.*

### 15.3 "Nothing to Report": lie + saved
- **Conditions:** `kept_lie` and `saved("Iona Star")`.
- **Meaning:** the light did its duty and the keeper didn't.
- **Variants:**
  - **with `reunion`:** Elspeth knows her father lives but can't clear him (C9);
  - **with `gave_letter`:** Ross holds the proof and never uses it.
- **Final dialogue:** Morag: "…Roger, North Point. Nothing to report." Then Ross: "Aye. Well." (if inside), or footsteps going down (if the door stayed shut).
- **Card (no reunion):**
  > **NOTHING TO REPORT**
  > *Ross left with the morning tide in the black boat. Elspeth brought the Iona Star into Stornoway at noon and never knew who had held the light on her.*
  > *Some nights on sixteen I hear a carrier with no voice on it, and I don't answer it.*
  > North Point Light · 15 November 1971
  > *The light was kept.*
- **With a reunion**, the first line is replaced by: *"Ross left with the morning tide. Elspeth met him on the pier at Stornoway that night. I heard it from Morag, not from either of them. / The Inquiry's finding stands. She knows it isn't true. She can't prove it. I could have."*

### 15.4 "Light Exhibited Throughout": lie + aground
- **Conditions:** `kept_lie` and `lost("Iona Star")`.
- **Meaning:** the bleakest ending. The lie is told a second time and believed a second time.
- **Card:**
  > **LIGHT EXHIBITED THROUGHOUT**
  > *There was a second inquiry, for the Iona Star. They read my log into the record. Light exhibited throughout.*
  > *They believed it. People always believe the light.*
  > North Point Light · 15 November 1971
  > *The light was kept.*

### 15.5 Presentation (for 3B)
- **The card:**
  - a slow fade from the dawn view to warm black;
  - the title in Libre Baskerville small caps;
  - the epilogue lines typed in italic serif, one at a time, each waiting for input or 4 s;
  - the place and date line, then *"The light was kept."*;
  - then the credits.
- **No scores and no stats.** The card is the only place the ending's title appears.

---

## 16. Narrative-state dependencies

### 16.1 Flag and clue map
Every flag or clue that is set is listed here with what reads it. "Engine" means it's read by code, not by dialogue.

| Flag / clue | Set in | Read in |
|---|---|---|
| `rel.morag` | ch1 (×3), ch2, ch3 | `ch6_morag_dawn` (`relation >= 2`) |
| `rel.elspeth` | ch3, ch6 | `ch6_iona` (`relation > 0`) |
| `rel.ross` | ch4, ch5, ch6 | `ch6_jam` (`relation >= 2`: "Callum" vs "Keeper") |
| `admitted_once` | `ch1_morag_late` | `ch3_notes_b` |
| `answered_me` | `ch1_mary_ellen` | `ch5_ross` |
| `ignored_me` | `ch1_mary_ellen`, `ch2_mary_ellen` | `ch5_ross` |
| `lied_heard` | `ch1_morag_heard` | `ch6_morag_dawn` |
| `rory_grandfather` (clue) | `ch1_rory_in` | `ch5_ross`, `ch6_rory` |
| `admitted_there` | `ch2_trace` | `ch3_notes_b` |
| `said_asleep` | `ch2_trace` | `ch3_notes_b` |
| `told_dead` | `ch2_mary_ellen` | `ch5_ross` |
| `same_hand` (clue) | `archive` beat | `ch4_door`, `ch5_ross` |
| `sister_boat` (clue) | `opt_ch2_morag` | `ch4_door` |
| `sandy` (clue) | `opt_ch3_hector` | `ch5_ross` |
| `elspeth_letter_told` | `ch3_elspeth` or `ch6_iona` | `ch6_iona`, `ch6_outcome` |
| `told_elspeth_there` | `ch3_elspeth` | `ch6_iona` |
| `lied_to_morag` | `ch3_notes_b` | `ch6_morag_dawn` |
| `deflected_morag` | `ch3_notes_b` | `ch6_morag_dawn` |
| `admitted_to_morag` | `ch3_notes_b` | `ch6_morag_dawn` (both branches) |
| `blackout` | `notes` beat | Engine (lighting and HUD) |
| `sy214` (clue) | `identify` beat | `ch4_door` |
| `found_grants` | `look_grants_a` | `ch4_door` |
| `grants` (clue) | `ch4_door` | `look_grants_b` availability |
| `bolted` | `look_bolt` | `ch4_door` (`open`) |
| `called_morag` | `ch4_mf_morag`, `ch4_door` | `ch4_door` (hides the option); MF-call availability |
| `knows_name` | `ch4_door` `name_ask`, `ch5_ross` | **Engine** (identity resolver, portraits); `ch5_ross`; `ch6_rory`; `coat_note` room line |
| `door_open` / `door_shut` | `ch4_door`, `ch6_jam` | ch5, ch6 throughout |
| `photo_1953` (clue) | `ch4_door` `shut` | Engine (photo availability) |
| `blamed_father` | `ch5_ross` | `ch6_final_log` |
| `confessed_to_ross` | `ch5_ross` | `ch6_final_log` |
| `letter` (clue) | `drawer` beat | Engine (`drawer` device text); **history only** otherwise: the dawn lines key on `gave_letter` / `kept_letter` |
| `gave_letter` / `kept_letter` | `ch5_letter` | `ch6_morag_dawn`, `ch6_final_log`, `ch6_epilogue` |
| `ross_wheel` | `ch6_jam` | **Engine** (sim assist); `ch6_freed`; `ch6_outcome` |
| `reunion` | `ch6_outcome` | `ch6_epilogue` |
| `told_truth` / `kept_lie` | `ch6_morag_dawn` | `ch6_final_log`, `ch6_epilogue`, the ending card |
| `read_log_1971`, `read_log_1953`, `read_letter`, `at_door`, `docked_*`, `tx_*`, `seen_*`, `last_choice_*`, `jam_cleared`, `moved`, `looked` | Engine | Engine (beat conditions). **History only:** `moved` and `looked` are no longer beat conditions after the ch1 merge; keep them for the tutorial-hint suppression |

**Test requirement (§18.4).** `story_test` asserts that every flag or clue set in a `.dlg` file is either read in a condition somewhere or is on the explicit "engine / history only" allow-list above.

### 16.2 Ending dependency map
```
                     ┌─ told_truth ─┬─ saved  → CORRECTION      [+gave/kept_letter line]
dawn report choice ──┤              └─ lost   → HEARD TOGETHER
                     └─ kept_lie  ──┬─ saved  → NOTHING TO REPORT [+reunion variant][+gave_letter line]
                                    └─ lost   → LIGHT EXHIBITED THROUGHOUT [+gave_letter line]

Colour, not gate:
  rel.morag≥2 ──────────── "Kitchen table" (truth branch)
  lied_to_morag / deflected / admitted / lied_heard ── Morag's dawn lines (both branches)
  confessed_to_ross vs blamed_father ── final log wording
  ross_wheel ──────────── the sim assist during the rescue (makes "saved" easier) + reunion availability
  door_open (ever) ─────── the reunion option, Ross's presence at dawn
  elspeth_letter_told ──── "You sent the letter."
```

**Reachability (to be proven in `story_test`):**

| Ending | Policy |
|---|---|
| E1 | Honest choices, *Iona Star* saved |
| E2 | Honest choices, *Iona Star* lost (the bot doesn't vector) |
| E3 | Lie at dawn, saved, with a reunion |
| E3′ | Lie at dawn, saved, without a reunion |
| E4 | Lie at dawn, lost |

Also: door kept shut for the whole game, combined with each ending.

---

## 17. Expected playtime (design estimate, NOT a measurement)
Human playtesting is needed. These figures assume a first-time player who reads every line at the default text speed.

| Ch | Main path | Optional | Notes |
|---|---|---|---|
| 1 | 14–17 min | +1–2 (phone, tide tables, photo) | 11 beats. The first mystery signal is at 0:10 (date) and about 5 min (carrier) |
| 2 | 14–17 min | +3–4 (two optional calls, vapour kit, extract) | The *Gannet* rescue is the main gameplay |
| 3 | 15–18 min | +2 (Hector) | Two rescues plus the blackout |
| 4 | 12–15 min | +1–2 (bolt, phone, MF call) | Tension, short |
| 5 | 12–15 min | +1 (the photo) | The longest conversation (`ch5_ross`, about 6–8 min) |
| 6 | 13–16 min | — | Rescue plus dawn plus the card |
| **Total** | **80–98 min** | **+8–11 min** | **About 85–105 min with optional content.** Two hours would need more gameplay set pieces; the Stage 6 timed playthrough decides (Daniel, 2026-11-05) |

---

## 18. Implementation requirements

### 18.1 Engine, director and presentation (3A/3B)
| # | Requirement | Where |
|---|---|---|
| E1 | `>` sound-caption line (look `sound`): rendered in capitals, upright and muted, and stored in history. **Built in 3A** | `dialogue_db.gd`, `dialogue_ui.gd`, `dialogue_runner.gd` |
| E2 | `SPEAKER@room:` / `@radio` tags. Also: ROSS and VISITOR are always "in the room" and the remote stations are always "radio", so most lines need no tag. **Built in 3A** (`Speakers.look`) | `dialogue_db.gd`, `speakers.gd` |
| E3 | Identity resolver: VISITOR → "The man at the door"; ROSS → the same until `knows_name`, then "Alasdair Ross"; MARY ELLEN unchanged. History stores the label as shown. **Built in 3A** | `speakers.gd`, `dialogue_runner.gd`, `story_state.gd` |
| E4 | Beat action `caption "<text>"`: non-blocking, shown in the subtitle area for about 3 s | `story_director.gd`, `story_presenter.gd` |
| E5 | Deterministic transitions: chapter start and `timeskip` emit `transition_done`. The director holds the first `talk` and `wait` until then. Typing is paused while the fade is above 0 | `story_director.gd`, `story_presenter.gd` |
| E6 | Optional radio calls: a per-chapter `optional_calls` list in `chapters.json` (`{station, conv, open_after_beat, close_at_beat}`). A "Call" entry on that station in the radio panel. The director defers queued `talk` actions while an optional call runs | `chapters.json`, `fp_ui.gd`, `story_director.gd` |
| E7 | After-read thoughts: a doc → `{chapter range: conv}` map (§11.3), played once each | `chapters.json` or `docs.json`, `game_fp.gd` |
| E8 | Beat action `ending_card`: computes the ending id from the flags and `saved`/`lost`, shows the title, then `ch6_epilogue` in card style, then `end_campaign` → credits | `story_director.gd`, `story_presenter.gd`, `main_fp.gd` |
| E9 | `sfx carrier_click`: a new synthesised sound (two key clicks with a carrier hiss). **Generated, never played** | `audio/synth.py`, `audio_director.gd` |
| E10 | Remap ch1 beat ids on load: old `look`/`light_on`/`lamp_normal` → `light`; `battery`/`gen` → `engine`; `kittiwake_call`/`confirm` → `kittiwake` | `save_system.gd` or `game_fp._apply_save` |
| E11 | Chapter subtitles: ch1 "North Point Light · Sunday 14 November 1971 · 16:20"; ch2–6 "Monday 15 November · …" | `chapters.json` |

### 18.2 Simulation
| # | Requirement | Where |
|---|---|---|
| S1 | **Mode-independent story jam.** `fault jam` binds the gear race at 046 in any mode. In AUTO the motor labours and the amber lamp lights. In MANUAL the handwheel won't turn forward. In OFF the optic is free to be backed off | `keeper_sim.gd` |
| S2 | **Player clear only.** `jam_cleared` is emitted only when MODE is OFF and the handwheel has been turned back at least N° past 046 (N ≈ 6°, in `keeper_config.gd`). It is never emitted on power loss. This fixes the ch2 race | `keeper_sim.gd`, `keeper_config.gd` |
| S3 | **Story jams don't trip MAIN.** `fault jam` takes `{trip: false}` from story beats, so the existing 8 s trip stays only for unscripted jams, if any are kept | `keeper_sim.gd`, `story_director.gd` |
| S4 | In OFF, the handwheel turns the optic by hand. This is needed for the "free by hand" procedure | `keeper_sim.gd`, `station.gd` |
| S5 | **Ross assist.** With `ross_wheel == 1` in MANUAL, the beam slews toward the bearing of the selected or most endangered ship at the handwheel's rate, so `lit_by_hand` holds. It switches off if MODE leaves MANUAL | `keeper_sim.gd` (assist hook), `game_fp.gd` (flag → sim) |

### 18.3 Interactions and documents
| # | Requirement | Where |
|---|---|---|
| I1 | New examine devices: `phone` (`ANCHOR_telephone` → `IA_phone`), `tide_tables` (`ANCHOR_tide_tables` → `IA_tide_tables`), `vapour` (new IA on the kit), `photo_1953` (floor anchor or desk; availability by flag), `bolt` (an action on the stair door, ch4 only). **These are Blender hook changes, so run the hook and interaction tests after them** | `blender/build.py` (IA volumes), `station.gd` `DEVICES`, `game_fp.gd` |
| I2 | Archive second open → `inquiry_extract` | `game_fp._on_doc` |
| I3 | Docs: new `inquiry_extract`; edited `log_1971`, `letter_1957`, `note_046`, `photo_1953`. Rendered in 3C (`documents.py` with Courier Prime and Cedarville Cursive) | `docs.json`, `blender/documents.py` |
| I4 | The MF radio call in ch4 is a radio-panel "Call Stornoway (MF)" entry, using the E6 mechanism | `chapters.json` `optional_calls` |

### 18.4 Tests (3B)
- **`story_test`:**
  - parse all new syntax (`>`, `@room`);
  - DFS with the "kept_lie + lost" and "door shut throughout" fixtures;
  - **the flag-read audit** (§16.1);
  - **all 4 endings plus the E3 reunion variant reached by valid policies, with distinct `ending_card` ids**;
  - ch1 has exactly 11 beats;
  - remapped ch1 save ids load.
- **`regress`:**
  - the ch2 jam can't clear on a MAIN trip;
  - the ch6 jam binds in AUTO and in MANUAL and clears by OFF → back → MANUAL;
  - the Ross assist holds `lit_by_hand`;
  - no typing while the fade is above 0;
  - an optional call defers the next beat's talk;
  - the resolver never shows "Alasdair Ross" before `knows_name` (label, card, history, portrait key).
- **`interaction_test`:** the new devices (phone, tide tables, vapour, photo_1953, bolt): walkable approach, prompt, open/close, and the flag set.
- **`qa_sweep`:** all new lines fit at text sizes 0.8, 1.0 and 1.5.

---

## 19. Change log
| Id | Problem | Resolution in this script |
|---|---|---|
| C1 | "Saturday 14 Nov 1971", but it was a Sunday | Ch1 "Sunday", ch2–6 "Monday 15". "It's a Sunday." Sabbath texture: Rory, the carrier line, Ross racing home before the Sabbath in 1953 |
| C2 | 11 vs 21 minutes of darkness | 01:40 stalled, ≈01:50 dark, 02:01 relit. The confession and final log state both |
| C3 | Hector's "fifteen years" | "Thirteen years" |
| C4 | Boat "three years" vs truth learned "two years ago" | "Two years" |
| C5 | Rory's grandfather "the season before" vs Kenneth Bain the survivor | Kenny Bain was aboard, below, the only one who came home. Died at Easter 1971 |
| C6 | A SW wind can't set the ship west onto the light | "The flood tide's setting us down onto North Point faster than we can steer." (tide, not wind) |
| C7 | "Backing westerly" | "Veering westerly" |
| C8 | Morag's "old procedure" tell, contradicted by Rory | The caller used the 1953 words, which were never printed |
| C9 | Kept lie plus reunion → "never knew" | A separate epilogue line for the reunion |
| C10 | `log_1971` times out of order | Re-timed: 18.30 radio check, 18.50 *Kittiwake*, 23.25 Stornoway |
| C11 | Two versions of the letter | One canonical text. "Put his **hand** to my lie" (the entry was signed I. Mackay in Callum's hand) |
| C12 | Ross "watched you write it through the windows" | He knew the hand from the relief-boat stores lists (1951–53) and from the Inquiry photostat |
| C13 | "A man in Govan heard of an unposted letter" | Iain told Kenny Bain in the Harris Hotel. Ross visited Kenny in March 1970 |
| N1 | The mystery mechanics were never explained | Ross admits the carrier, the calls, the echo and the blocked 16 in `ch5_ross` |
| N2 | Callum faked surprise at his own hand | "I know what it says. I don't need to open it. I open it." |
| N3 | The Iain–Ross friendship was unused | `ch5_ross` "He was my friend"; Hector's "Sandy and Iain, thick as thieves"; the letter's "and he was my friend" |
| N4 | Elspeth's letter was unused | Told in `ch3_elspeth` (or `ch6_iona`); paid off as "You sent the letter." |
| N5 | Rory vanished; "say it together" was missing | `ch6_rory` stands by; Morag's dawn line in the aground branch |
| N6 | Why the mate sends the Mayday | "Master's injured. This is the mate." |
| N7 | Ross's illness not shown | A cough on the stair, at the door and mid-story |
| N8 | About 20 flags never read; endings only from the last choice | Every flag read or allow-listed (§16.1). Callbacks in ch3, ch5 and ch6. The Ross assist makes `ross_wheel` mechanical |
| N9 | Unexplained Channel 16 silence | A carrier lashed keyed when Ross tied up ("battery'll be flat by now"). The ch4 Morag call moves to the MF set (2182 kHz) |
| — | Ross named early | The resolver plus `knows_name` set at `name_ask` or at Ross's first line in ch5 |
| — | Lloyd's "seven of her eight crew" was ambiguous | "Lost with seven of the eight aboard, the skipper among them. Presumed." Morag's "six widows in Leverburgh, and to his" |
| — | Shamed out of Leverburgh vs buried there | Moved to Glasgow in 1955. Elspeth takes him *home* to Leverburgh in the "Correction" epilogue |

---

## 20. Open questions for Daniel
**Answered by Daniel (2026-11-06): all four recommendations accepted.** Mrs Ross stays unstated; the ch2 jam teaches the procedure; `ch6_rory` plays before the rescue; the Ross assist is full. The rest of the script is still awaiting his read.

1. **Mrs Ross.**
   - The script leaves Ross's wife off-screen: he says "My wife was told…", and the epilogue mentions only Elspeth.
   - The bible implies she is no longer alive in 1971, which is why he goes home to his daughter's.
   - Options: state this in one line ("She died in sixty-six, believing it."), or keep it unstated? **Recommendation: keep it unstated** (the lighter touch).
2. **The ch2 jam now teaches the ch6 procedure.** It becomes OFF → back the handwheel → AUTO, one step more than today. That way the "free by hand" climax isn't new under pressure. Is that acceptable? **Recommendation: yes.**
3. **Rory mid-rescue.** `ch6_rory` is a short radio exchange just before the rescue begins. Keep it there, or move it after the outcome as a quieter beat? **Recommendation: keep it before the rescue.** It is short and raises the stakes.
4. **The Ross assist strength.** With Ross on the wheel the beam tracks the ship fully, which makes "saved" easier and makes trusting him a real advantage. Should it instead be a partial assist (slower slew)? **Recommendation: a full assist.** The player still has to vector her through the Gut.

---

## 21. Approval fixes (Daniel, 2026-11-06)
Daniel approved the script together with these fixes. They came from checking the script against the code and the approved cabin decisions. The fixes take precedence over the text in §1–§20.

| # | Fix | Applies to |
|---|---|---|
| F1 | **Motor, not clockwork, in the AUTO lines.** The room's optic drive is an electric motor with the clockwork kept as standby (ROADMAP cabin decision). AUTO lines say "the motor" or "the optic". The clockwork belongs to the 1953 story | `ch1_lit` line 1: "The motor takes up the optic overhead. Twelve turns a minute, same as the day they fitted it." `ch2_jam` / `ch6_jam` captions: "[A grinding shudder overhead. The optic stops.]" |
| F2 | **Drawer.** The letter lies "under the old Notices to Mariners", so the shelf's 1953 Tide Tables (which hide the Grant's) are the only tide tables. One added line explains why Callum never found it | `ch5_letter` line 1: "Under the old Notices to Mariners, an envelope…". Line added after it: "~ Nine years at this desk and I never once emptied that drawer. I think I knew." Bible §4.1 "Doesn't know" and §5.3 Christmas 1957 updated to match |
| F3 | "Three years" → "two years" (C4) | `ch4_door` `sy` branch (already "two years" in §8.4; the change list now records it) |
| F4 | `VISITOR` hard-coded in ch6 → `ROSS@room` | `ch6_jam` (all Ross lines use `ROSS@room`, so the resolver decides the label) |
| F5 | Missing texts | `look_photo53` (below); §11.3 room-line ids `after_<doc>_<range>`; §8.7 KEPT count is 18 |
| F6 | Morag's "Leave your handset keyed if you have to" is cut | `ch4_door` `radio` branch |
| F7 | §5.3 order: the September 1971 gale before the October letter | §5.3 |

**`look_photo53`** (an after-read line, ch4–6, the first time the 1953 photograph is closed):
```
== look_photo53 mode=thought
[if has_flag("door_open")] ~ He left it on the desk, face up, and said nothing about it.
[if not has_flag("door_open")] ~ He slid it under the door and said nothing about it.
~ Eight men on a deck at Leverburgh. Four months later, Kenny Bain was the only one of them anyone saw again.
```
The photograph is on the floor inside the stair door if it was slid under (`door_shut`), or on the desk if Ross came in.

**Room-line ids (§11.3):** `after_photo_keepers_a` / `_b` / `_c` (ch1–2, ch3–4, ch5–6), `after_note_046_a` / `_c`, `after_coat_note_a` / `_c`, `after_forecast_b`.

**Playtime (Daniel, 2026-11-06):** the target stays **about 90 minutes**, measured in the Stage 6 timed playthrough.

### 21.1 Implementation notes (3B, for the checkpoint)
These are consistency fixes made while transcribing. None changes the story, and each is listed here so the script stays the single source of truth.

| Where | Change | Why |
|---|---|---|
| `ch1_mary_ellen` tail, `ch3_dark` | "the clockwork" → "the motor" | F1, applied to the two AUTO lines §21 didn't list |
| Pre-ch4 door hint (code) | "Bolted for the night, the way Father always kept it" → "The stair door, and the long stair down. Nobody on it till the relief comes on Thursday." | It contradicted the ch4 line "It was never even bolted" |
| Desk drawer hint before ch5 (code) | "Old Notices to Mariners and a tin of pencils. I never go through it." | F2 foreshadowing |
| `note_046` | Iain's 1949 line reads "FREE BY HAND: take the drive off, back her past the tooth, then put the drive in again." | The light had no motor in 1949, so §12.2's "motor OFF" was an anachronism. The game's objective still says MODE OFF |
| `inquiry_extract` | "Inverness, March 1954" | The Gazette clipping already places the Inquiry at Inverness |
| `log_1971` 18.30 | "Radio check Stornoway CG. Gale warning, severe gale 9." | It fits one line of the log page |
| `photo_1953` title | "Photograph: the Mary Ellen's crew, July 1953" | It is not always slid under the door |
| Ch6 gameplay | *Iona Star* spawns holding position (bearing 66°, heading 30° across the 046° line) and is **released** after Rory's call (new `release` action). Measured: with no orders she is aground about 85 s after release, **even with Ross holding the beam on her**; the expert bot saves her; a player who starts vectoring 60 s late still saves her | Before, her spawn heading self-captured the East Gut as soon as she saw the light, in AUTO too, so vectoring was never needed. That contradicted decision 4 (the player vectors) and made "aground" unreachable when Ross helped |
| Jam visibility | A jammed optic in AUTO is a fixed beam: ships see it only along its bearing | A jammed light no longer counts as "seen all round" |
| `ch1` `kittiwake` beat | Uses a new `until` action (wait for CONFIRM inside the beat) | The merge of `kittiwake_call` and `confirm` needed it |
