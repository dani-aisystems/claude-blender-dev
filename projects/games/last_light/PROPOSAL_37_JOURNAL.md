# Proposal 37: journal system, discoveries and family history

**Status: AWAITING DANIEL'S APPROVAL. Not to be implemented until approved.** Sample entries are **DRAFTS** built only from facts in `STAGE3_NARRATIVE_MASTER.md` §4, §5 and §12.

## 1. What exists today (audit, confirmed)
- **Records that already exist:**
  - **L** opens the station **logbook** document in story mode (`g/scripts/fp/game_fp.gd:304-306`, `input_setup.gd:19`);
  - **H** opens the **transcript** of all dialogue (`backlog_ui.gd`);
  - the **objective** panel (item 9 adds steps);
  - **documents** read in the viewer (`docs.json`: log_1971, log_1953, letter_1957, note_046, inquiry_extract, clipping_1954, forecast, photo_keepers, coat_note, photo_1953, chart);
  - after-read thoughts (master §11.3);
  - clues in `StoryState.clues`.
- **No journal or diary exists anywhere.**
- **Father and son material is spread across** note_046, log_1953 (in Callum's hand, signed by Iain), photo_keepers, the letter, coat_note, and Callum's thoughts ("Father always said I wrote like a clerk").

## 2. Research: how comparable games use written records
These come from design knowledge and are to be checked:
- **Gone Home and What Remains of Edith Finch:** found documents in the world carry the backstory; no separate menu journal.
- **Firewatch:** a found-object inventory plus the radio; very light UI.
- **Return of the Obra Dinn:** the logbook is the game's UI and the deduction tool.
- **Disco Elysium and The Witcher:** an automatic quest journal summarising what you've learned.

**Pattern:** a journal earns its place when it does a job nothing else does:
- deduction, as in Obra Dinn;
- re-finding documents;
- or an inner voice the world can't show.

It hurts when it duplicates the quest log or the transcript.

## 3. Should a journal be added? Analysis
| Possible job | Already covered by | Gap? |
|---|---|---|
| Current objectives | Objective panel (9) | No |
| What was said | Transcript (H) | No |
| Re-reading found documents | Only by walking back to the object | **Yes**: the letter, clipping and inquiry are hard to re-find mid-chapter |
| Callum's inner reflections | Thought lines (`~`), once only, then gone except in the transcript | **Partial**: they're in the transcript but mixed with radio talk |
| Clue tracking ("what do I know about 1953?") | Nothing | **Yes**, for a mystery game, and it has to respect the player's choices |
| The father's and son's own journals | Nothing | Story risk: see §6 |

**Conclusion.** There is a real gap, but it is narrow:
- re-reading documents;
- a short record of what Callum has *learned*.

That doesn't justify a new J-key system with its own UI language. **It does fit inside the existing L logbook**, which is already on a key, already in the fiction (a keeper writes things down), and already a document. Callum is the keeper; the station log is his book.

## 4. Recommendation: extend the L logbook (no new J key)
- **L** opens the **station log** as now: the current page is tonight's log (`log_1971`).
- Turning pages (wheel, A/D, or the page-corner buttons) reaches **two new sections in the same book** (the back pages; a keeper's private notes on the end-papers is period-plausible):
  1. **"Kept papers"**: every document the player has read, re-openable in the existing viewer. No new art; it reuses the document PNGs.
  2. **"Notes"**: short automatic entries in Callum's voice, one per **major discovery** (a clue or document flag), never per action. Written as a keeper's terse notes, not feelings, consistent with the style guide ("Would never say: 'I feel…'").
- **Unlocks:** each note is tied to an existing `clue` or `read_*` flag. Entries reflect the player's choices: e.g. after `told_truth`, or not, the ch6 note differs.
- **No freeform writing**, and no new mechanics.
- **Why not J:** a second book duplicates L, and splitting the "logbook" from a "journal" confuses which one is the story record. If Daniel prefers J, it can open the same book at the Notes tab: a key alias, not a new system.

## 5. Presentation
- The **same document viewer** (`story_presenter`), zoom and pause behaviour.
- **Paper:** the existing log page style (`documents.py`), using the 3C OFL hands:
  - Callum's small square hand (Courier Prime or a clerkly hand);
  - Iain's annotations only where they already exist (note_046).
- **Page layout:** the date in the margin, terse lines, ruled ledger paper.
- **Navigation:** tabs on the page edge (Log / Kept papers / Notes); 1–4 can't be used, because they belong to replies, so the tabs are clicked or chosen with Q/E-free keys (A/D for pages).
- **Opening and closing:** L, or Esc / right click to close (existing).
- **First person:** the player is paused while the book is open, as documents are now. With the body (13): an optional hold-the-book pose (G3 polish, not required).

## 6. Father and son journals: evaluation
- **Iain's journal, not recommended.**
  - The story's weight rests on **one** document from Iain, the unsent letter (Christmas 1957), found in the drawer in ch5.
  - Any earlier Iain diary would either reveal the truth too early, or have to avoid it so carefully that it reads as filler.
  - It would also invent new history (his drinking, the wreck night) beyond the bible.
  - Iain is already present through the photo, the note, the bottle and the letter. That restraint is the point.
- **Callum's 1953 journal, not recommended.**
  - Callum's guilt is revealed through the *log in his hand* (ch2) and his choices.
  - A private 1953 diary would hand the player the confession the game is built to make them pursue.
- **A safe alternative, if Daniel wants more father-and-son texture:** **one** small existing-style document, a page of the 1952–53 station **stores and weather book**. Iain's entries and the boy's are on the same page, and the boy is learning to write the log ("C.M. under instruction"). It's pure texture with no new facts: the photo already dates them together in May 1952. It would be an optional document on the archive's second open, and **needs Daniel's approval as a new document**.

## 7. Sample "Notes" entries (DRAFT; each from an established fact and gated by an existing flag)
- *(after `read_log_1953`)* "14.11.53 page, Father's signature. My hand. I knew it would be."
- *(after `clue same_hand`, ch2)* "Two logs, eighteen years apart. One hand."
- *(after `clue notebook`, ch3)* "Morag. 01.52. 'No light.' Pencil, her own book. Kept eighteen years."
- *(after `clue grants`, ch4)* "The man at the door knows where the Grant's is. Top shelf, behind the Tables."
- *(after `read_letter`, ch5)* "Christmas '57. 'I made you write it.' He knew. He wrote it down for me and never sent it."
- *(ch6, `told_truth`)* "Correction to entry of 15.11.53 written. My hand."
- *(ch6, not `told_truth`)* "Light exhibited throughout."

Each line restates something the player has just seen. **None adds a fact.**

## 8. Technical dependencies
- The `story_presenter` document viewer.
- `docs.json` (the Notes as generated text pages), `documents.py` (page rendering) or runtime text on a page texture. **Runtime text is recommended**, so choices can vary the entries.
- `StoryState` flags and clues.
- 3C fonts.
- The save state (notes are derived from flags, so no new saved data).

## 9. Complexity
| Part | Estimate |
|---|---|
| Kept papers | S |
| Notes | M: about 20 entries, runtime page rendering |
| Optional stores-book page | XS (document only) |
| **Total** | **M** (about 1.5 days) |

## 10. Risks, alternatives and final recommendation
- **Risks:**
  - Notes that over-explain: mitigated by the restatement rule in §7.
  - UI clutter: avoided by staying inside the existing L book.
- **Alternatives:**
  - (a) Do nothing: documents are re-readable only in place, and the transcript covers dialogue.
  - (b) Kept papers only, no Notes (S).
  - (c) The full J journal: **not recommended**, as it duplicates.
- **Final recommendation:** **(b) Kept papers now, plus Notes if Daniel likes the sample voice in §7**, all inside the L logbook. No Iain or Callum diaries. The optional stores-book page is a separate approval.

## 11. Decisions for Daniel
- **A.** None / (b) Kept papers only / Kept papers + Notes.
- **B.** L only, or a J alias as well.
- **C.** The optional 1952–53 stores-book page.
