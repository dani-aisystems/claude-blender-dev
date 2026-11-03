---
name: blender-film
description: Make a short 3D motion-graphics film from code following Daniel's playbook (Claude + Blender, Nate Herk/AIS) — production brief, one shared timeline file, headless Blender scene, stills/contact-sheet checks, chunked resumable Cycles/EEVEE renders, frame scan, ffmpeg encode. Use for animated films, turntables, product shots or title sequences.
---

# Film from code (playbook workflow, adapted to the Apple M3)

**Principle:** Claude writes a program that answers "what should the screen look like at frame N?" Every frame stands alone, so fixes are cheap.

## 1. Brief
Fill in `templates/film_brief.md`, which has the playbook's six blocks: BRAND, FORMAT, BEATS, CAMERA, LOOK, CHECKS. Grill Daniel on BRAND and BEATS if they're vague.

## 2. One timeline file
`projects/films/<name>/timeline.py` holds every event time, position, camera shot and sound hit. The scene, comp and sound scripts all import it, and nothing hard-codes a time anywhere else.

## 3. Build the scene headless
- `projects/films/<name>/scene.py` builds and keys everything, then saves `<name>_vNNN.blend` via `save_versioned`.
- Simple turntables: `scripts/render/turntable_scene.py`.

## 4. Stills before the full render (mandatory)
```bash
tools/bl <scene.blend> -P scripts/render/render.py -- --frames <18 spread frames> --out renders/<name>/stills_v00N --res-pct 50 --samples 40
tools/py scripts/render/contact_sheet.py renders/<name>/stills_v00N -o renders/<name>/stills_v00N_sheet.png --cols 6 --thumb 320
```
Look at the sheet (`blender-render-review`), fix with exact numbers, and repeat. The playbook needed 4 rounds.

## 5. Full render: chunked, resumable, re-render only what broke
```bash
tools/bl <scene.blend> -P scripts/render/gpu.py -P scripts/render/render.py -- --frames 1-360 --out renders/<name>/full
tools/py scripts/validation/scan_frames.py renders/<name>/full --frames 1-360    # prints "rerender": "105-110,..."
tools/bl <scene.blend> -P scripts/render/gpu.py -P scripts/render/render.py -- --frames <rerender> --out renders/<name>/full --force
```
- Pass `gpu.py` on **every** Cycles run, because GPU choice is a preference and isn't saved in the .blend.
- On this Mac the backend is METAL. A full 1080p Cycles film takes far longer than the playbook's RTX 5090 timing, so prefer EEVEE where the look allows.
- Check free disk space first (`df -h ~`). Frames are large, and `renders/` is gitignored.

## 6. Encode
```bash
tools/py scripts/film/encode.py renders/<name>/full -o exports/<name>/<name>_v00N.mp4 --fps 30 [--audio build/sound.wav]
```
This uses the playbook's command: libx264 high, CRF 17, yuv420p, vignette PI/6, AAC 320k, faststart. It refuses to overwrite.

## Deferred until a film needs them (Q1 decision)
The pieces below aren't installed yet. Ask before installing:
- **HTML UI / comp:** Node + Puppeteer (`npm i puppeteer`, in the film folder).
- **Sound:** synthesized with numpy/scipy/pedalboard; add them to `pyproject.toml`.
  - Check loudness every 0.5 s.
  - Set a −1 dB **true-peak** ceiling.
