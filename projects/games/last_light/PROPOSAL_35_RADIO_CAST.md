# Proposal 35: secondary characters and radio encounters

**Status: AWAITING DANIEL'S APPROVAL.** Nothing here is implemented or committed to the script. All dialogue is a **DRAFT**. Findings log entry: `FINDINGS_LOG.md` §35.

## 1. What already exists (audit, confirmed)
**Speaking cast** (`STAGE3_NARRATIVE_MASTER.md` §4, `g/scripts/story/speakers.gd`):

| Character | Vessel or station | Role |
|---|---|---|
| Callum | North Point (the keeper) | Player |
| Morag | Stornoway Coastguard | Main |
| Rory | *Kittiwake* SY 37 | Main |
| Hector | *Gannet* SY 112 | Ch2, plus the optional ch3 call |
| Elspeth | *Iona Star* | Main |
| The Mary Ellen caller / Ross | — | Main |
| *Corrie May* skipper | BRD 9 | Procedural voice, ch3 |
| *Lowestoft Star* skipper | LT 401 | Procedural voice, ch3 |

**Named but silent:** Kenny Bain (d. 1971), the *Catriona*, the relief boat (Thursday), the linesman.

**Mechanisms that already work:**
- `ship` spawns with radio orders and rescue outcomes (`chapters.json`);
- `optional_calls` shown as "Call a station" entries, with an open and close window (`story_director.request_call`);
- `talk` conversations in `.dlg` (`mode=radio`), with number-key replies once item 25 lands;
- relationships (`rel.*`), clues and flags;
- the Speakers resolver with hidden identities (`hidden_as` / `reveal`).

**Constraints:**
- The phone is dead all night (Daniel's decision). No calls.
- There is no supernatural content.
- The master §11 rule applies: optional content is never required, and each item pays off somewhere.
- Pacing: ch1 already has 11 beats and is front-loaded, and ch5 is the quiet truth chapter. Don't add load there.

## 2. Design position (challenge first)
- **The world already has eight voices**, and the cheapest way to make it feel populated is to use them better:
  - Hector's optional ch3 call exists;
  - the *Corrie May* and *Lowestoft Star* are one-scene voices.
- New characters must each add something those voices can't:
  - an outsider's view;
  - the modern world arriving;
  - a gameplay reason to use the radio and navigation outside the main story.
- **The brief's example premise needs adapting.** "I didn't know the lighthouse was operating again" contradicts the lore: North Point has been continuously manned and lit, and the whole story rests on the light's record. The same beat works if the caller is a stranger to these waters who expected no answer from a lonely station on a Sabbath night, or who has an out-of-date chart.
- **No new character may touch the ending (item 34),** the Ross reveal, or the ch4–5 confrontation. They live in the gaps: ch1's late watch, ch2 and ch3.

## 3. Candidates
Priority is one of **Recommended**, **Possible** or **Not recommended**. Category is one of **Essential** (needed for the story), **Optional** (gameplay or worldbuilding, skippable) or **Atmospheric** (texture only).

### 3.1 Captain Jan Visser, master of the Dutch coaster MV *Hendrika* (Groningen). Optional, with gameplay. **Recommended**
| Field | Detail |
|---|---|
| Identity | About 50. Master and part-owner of a 400-ton motor coaster, a common sight in the 1970s Minch |
| Why at sea | Timber for Stornoway, late after engine trouble at Kyle. The gale has caught him on the wrong side of Harris |
| Background and personality | Courteous, careful, dry humour in careful English. His wife sails as cook and keeps the chart table. He has never come this way at night |
| Link to the lighthouse | None. He knows North Point only as a light on the chart. **He knows nothing of 1953**, which is useful: the only person tonight who sees Callum simply as a good keeper |
| Reason for contact | Asks for a sheltered anchorage and a safe line in. He has an old chart edition and wants to check the West Gut leading line |
| Frequency | Once (ch3, before Elspeth), plus one optional thank-you call later in ch3 |
| Contribution | **Gameplay:** a third optional navigation job through the existing ship and orders system. Worldbuilding: the Minch as a working sea lane |
| Ongoing relationship | None. One night |
| Radio voice | Complete sentences, slightly too formal, "please" and "thank you" (which Elspeth would never say on the radio, a deliberate contrast). Says "North Point Light" in full |
| Look (dossier) | Stocky, clean-shaven, a reefer jacket over a roll-neck, a white-topped cap. *Hendrika*: a black hull, white wheelhouse aft |
| Known at first contact | Vessel name and call sign (he gives them; the profile shows *Hendrika* and the coaster card) |
| Known after | His name and his wife's, from conversation |
| Story connections | None to the mystery, on purpose. A clean contrast to Elspeth's ice |

**Draft encounter (`opt_ch3_hendrika`, `mode=radio`; window: ch3 after `both`, before `elspeth`):**
```
== opt_ch3_hendrika mode=radio
! static
VISSER: North Point Light, North Point Light, this is Hendrika, Hendrika, PEJX. Over.
* Hendrika, North Point. Go ahead. Over. -> go
* Hendrika, North Point. Say your position. Over. -> pos
= go
VISSER: Good evening, North Point. I did not expect a voice. On my chart you are a light and nothing more. Over.
-> ask
= pos
VISSER: Five miles west of you, North Point, and not liking it. Over.
-> ask
= ask
VISSER: I am timber for Stornoway, late, and my chart is the old edition. I would like the West Gut, if you will tell me it is still where my chart says. Over.
* She's where your chart says. Steer for the light, I'll put you on the line. Over. -> help
* Stay outside, Hendrika. Heave to till morning. Over. -> outside
= help
! set helped_hendrika
VISSER: Thank you, North Point. My wife says you have a kind voice for such a bad night. Over.
! ship {"name": "Hendrika", "kind": "steamer", "bearing": -38, "aim": "reef", "speed_mul": 0.7}
= outside
VISSER: Understood. We will heave to and drink coffee. Hendrika out.
```
**Payoff:**
- If helped and saved, a short thank-you from the West Gut lee, and a log line in Callum's own words in `log_1971` (optional; needs the document to be dynamic).
- If Daniel rejects the extra rescue, the call stands alone as atmosphere: only the `outside` branch, with no ship spawn.

**Gameplay cost:**
- Existing systems only (`ship`, optional call).
- Risk: ch3 already has two overlapping rescues (*Corrie May*, *Lowestoft Star*). **Recommend** the ship spawns only after both are resolved.

### 3.2 Mr Neil Gillies, master of the Northern Lighthouse Board tender *Sula* (fictional). Optional; supports the tutorial (36). **Possible**
| Field | Detail |
|---|---|
| Identity | About 55. The tender that brings relief keepers, stores and the promised linesman |
| Why at sea | Lying at Stornoway for the gale. He calls the stations on his round |
| Background and personality | The Board's man: brisk, paternal, fond of regulations. He knew Iain as "a good keeper, God rest him", and says nothing more |
| Link to the lighthouse | Professional. He carries the relief, so he's the outside world's promise to Callum ("Thursday, if the sea allows") |
| Knowledge of the history | Knows the official version only. **He must not add facts about 1953** |
| Reason for contact | Confirms the relief and stores for Thursday, and asks whether the 046 tooth has been looked at ("next refit", which echoes `note_046`) |
| Frequency | Once: the ch1 late watch, as an optional call between `kittiwake_home` and `late` |
| Contribution | Tutorial: the player's first chance to **start** a call from the "Call a station" panel, with no pressure. Worldbuilding: the Board as a distant institution. Theme: officialdom that never listens (Ross's letters were "thanked for his interest") |
| Ongoing relationship | None |
| Radio voice | Board formality: "Principal Keeper", "the Board will note it" |
| Look | Grey moustache, a peaked NLB cap with the badge, a duffel coat |
| Known at first contact | Fully identified: the Board tender is a known station, and the profile shows him immediately |

**Draft:**
```
== opt_ch1_sula mode=radio
CALLUM: Sula, Sula, North Point. Over.
! static
GILLIES: North Point, Sula. Good evening, Principal Keeper. Relief Thursday, weather allowing, with the linesman for your telephone. Over.
* Received. The 046 tooth is sticking again. Over. -> tooth
* Received, thank you. North Point out. -> end
= tooth
GILLIES: The Board will note it, Mr Mackay. It's down for the next refit. Sula out.
! clue board_noted
= end
GILLIES: Sula out.
```
- **Payoff:** Callum's ch2 thought about "twenty-two years of next refit" lands harder.
- **Concern:** ch1 pacing. Optional, and only after Kittiwake is home.

### 3.3 Dr Helen Marsh, survey party on the chartered seismic vessel *Western Venture* (fictional). Atmospheric. **Possible**
| Field | Detail |
|---|---|
| Identity | About 35. Geophysicist on a 1971 seismic survey west of the Hebrides (period-accurate: the North Sea and Atlantic oil exploration was starting) |
| Why at sea | Sheltering in the Minch, survey suspended for the gale |
| Personality | Bright and curious, an incomer, slightly too cheerful for the hour |
| Link to the lighthouse | None. She asks about the light as a curiosity: "Is it true they're going to make you automatic?" |
| Knowledge of the history | None |
| Reason for contact | Asks for a weather observation for their log (keepers did report weather). Small talk follows |
| Frequency | Once, ch2 optional (same window as `opt_ch2_rory`) |
| Contribution | **Theme:** "the last light". The era of keepers is ending, which gives the title a second meaning without touching the plot. No gameplay |
| Radio voice | English, a university voice, imperfect procedure |
| Look | Duffel coat, headscarf, horn-rimmed glasses |
| Risk | Breaks the mood if overwritten. One short exchange at most |

**Draft (excerpt):**
```
MARSH: North Point, Western Venture. Sorry, is it awfully rude to ask what it's like? Being the only one out there? Over.
* It's a job. Over. -> job
* Quiet. Mostly. Over. -> quiet
= quiet
MARSH: They say the Board will make you all automatic in ten years. A light that keeps itself. Over.
~ A light that keeps itself. Then nobody would have had to write anything down.
```

### 3.4 The Stornoway lifeboat coxswain. **Not recommended**
The lifeboat is implied in the aground endings. Giving it a voice would add a character inside the ending, which item 34 forbids. It would also take the rescue away from Callum and Elspeth.

### 3.5 Making more of the existing minor voices. **Recommended (cheapest)**
- **The *Lowestoft Star* skipper:** a ch3 optional "thank you" call after she's in. An English voice, frightened then relieved. A one-line payoff for the player's skill, with no new character.
- **The *Corrie May* skipper:** if lost, Morag reports it in ch3 (the existing `rescues` map). If saved, nothing extra.
- **Hector:** keep the existing optional ch3 call. No more.

## 4. Gameplay integration
| System | How candidates use it | New mechanics? |
|---|---|---|
| Radio | Optional calls via `optional_calls` windows; number-key replies (25) | No |
| Navigation | *Hendrika* only, through the existing `ship` and orders and the West Gut line | No |
| Illumination and power | Calls held while the radio has no power (the 32 rule); ships need the light (existing) | No |
| Weather | Visser's anchorage call scales with the storm text only | No |
| Objectives | Optional calls don't set objectives. *Hendrika*, if accepted, gets a short step objective (9) | No |
| Profiles (22) | Visser and Gillies are shown on first contact (they identify themselves); Marsh likewise. None needs a "?" stage, because none is a mystery | No |
| Transcript (4c) | All logged | No |
| Generator and battery | No dependency beyond the radio-power rule | No |

## 5. Recommended priority
1. **3.5**: more use of the existing voices (Lowestoft thanks, Corrie May outcome line). Lowest cost, no new characters.
2. **3.1 *Hendrika***: the one new character that adds a gameplay encounter, if Daniel wants ch3 longer.
3. **3.2 *Sula*** (tutorial support) or **3.3 *Western Venture*** (theme): pick at most one, to keep the cast tight.
4. **3.4**: not recommended.

## 6. Decisions for Daniel
- **A.** Approve none, some or all of 3.1, 3.2, 3.3 and 3.5.
- **B.** If 3.1: should *Hendrika* be a navigation job, or radio only?
- **C.** Portraits: new characters would need 3C portrait busts too (Blender, CC0 meshes), about half a day each.
