# Film brief (six blocks, after the playbook)

Keep FORMAT, CAMERA, LOOK and CHECKS between films; change BRAND and BEATS.

## BRAND
- **HERO:** your mascot or product, as a simple toy shape. Brand colour: `#______`.
- **APP / WORLD:** what the hero interacts with. Name every panel and its state. No real logos.
- **RESULT:** what the hero builds. Every action must visibly change something.
- **SET:** where it all floats.

## FORMAT
- Blender, 1920×1080, 30 fps, __ s at __ BPM.
- Engine: EEVEE (default on this Mac), or Cycles (Metal) for finals.
- One shared `timeline.py`; every piece reads its times and positions from it.

## BEATS
| Seconds | What happens | What changes on screen |
|---|---|---|
| 0–2 | | |

## CAMERA
- Wide to start.
- Follow each action at the hero's height, with shallow focus.
- End on the result alone.

## LOOK
- Screens glow under black glossy glass.
- Lights are kept out of reflections (`visible_glossy = False`).
- Colour is measured against the brand hex (AgX shifts colours).

## CHECKS
1. Contact sheet of the comp or UI.
2. 18 half-size stills at 40 samples, viewed as one grid. Check:
   - text is readable at phone size;
   - elements are where they belong;
   - the hero matches the brand colour;
   - nothing blows out;
   - the last frame works as a poster.
3. Fix with exact numbers, and repeat.
4. Full render in chunks, then `scan_frames.py`, then re-render the bad ranges.
5. Encode. If there's audio, check loudness every 0.5 s and set a −1 dB true-peak ceiling.
