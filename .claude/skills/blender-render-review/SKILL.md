---
name: blender-render-review
description: Visually verify Blender work — render EEVEE turntable previews or film stills, build a contact sheet, LOOK at it, measure colours against target hex values, and write exact-number fixes. Use after any modeling, material, lighting or camera change, and before claiming a 3D result is done.
---

# Render review: stills before anything expensive

A script that ran without errors proves nothing about how the result looks. Always look.

## 1. Render
```bash
# Asset turntable (EEVEE, ~2 s for 8 angles at 640 px on the M3)
tools/bl <file.blend> -P scripts/render/preview.py -- --collection ASSET_<name> \
    --out renders/<name>/preview_v00N --angles 8 --elevation 16 --res 640 --samples 48
tools/py scripts/render/contact_sheet.py renders/<name>/preview_v00N -o renders/<name>/preview_v00N_sheet.png --cols 4 --thumb 380
```
- **Live session:** use `get_screenshot_of_area_as_image` for the viewport. Use `preview.py` through runpy for the turntable.
- **Hero stills or finals:** add `--engine cycles` (Metal GPU). It's about 1.6 s per frame at 960×540 with 32 samples once warm, and the first run compiles kernels (around 75 s).

## 2. Look
Open the sheet with the Read tool and check:
- **Silhouette and proportions:** does it read at thumbnail size and match the brief and spec?
- **Materials:**
  - Is metal actually metal?
  - Is glass see-through, not milky?
  - Do emissive parts glow the right hue?
- **Colour:** measure it, don't eyeball it:
  `tools/py scripts/validation/pixel_check.py <png> --at X,Y --radius 3 --target "#HEX"`
  AgX washes bright or saturated colour toward white. Fix by lowering emission or exposure and darkening or saturating the base colour.
- **Lighting:**
  - Are there white blocks in reflections? Set `visible_glossy = False` on the light.
  - Is light trapped behind glass? Turn on transparent shadows.
  - Is a light flooding the surface it sits in? Use light linking to exclude that surface.
- **Artefacts:** faceting (add segments or smooth shading), pink SSS bands (subsurface radius), z-fighting, horizon lines, clipping.
- **Composition (films):** is the text readable at phone size, is the hero in frame, is the last frame strong enough for a poster?

## 3. Fix with exact numbers
- Write what you saw and the exact change, e.g. "flame #FEE5CF vs #FFB347 → emission 14 → 4", not "make it warmer".
- Change the value in `spec.py` with a `# Round N:` comment, rebuild to a new version, re-render, and re-measure.
- Compare crops side by side when a change is subtle.
- Stop when the brief is met, or report clearly what's still off. Never claim a visual check you didn't do.

## Worked example
`projects/models/hero_lantern/spec.py`: four rounds took the flame from #FEE5CF (distance 145) to #E4B58E (distance 76). The round history is in comments in that file.
