# Playbook compliance matrix

Playbook: *Claude + Blender: Make 3D Motion Graphics From Code* by Nate Herk (AI Automation Society). The PDF is kept locally and is not redistributed.

| Playbook requirement | Interpretation | Implementation | Status |
|---|---|---|---|
| Blender 5, run headless with `blender -b` | Scripts are the source of truth; the GUI is optional | Blender 5.2.3; `tools/bl`; MCP `*_for_cli` tools | Complete |
| One `timeline.py` that every piece reads | Single source of truth per project | `spec.py` per asset; `timeline.py` per film (`blender-film` skill) | Complete (assets); template for films |
| Cycles GPU; pass `gpu.py` on every run | GPU choice is a preference, not saved in the .blend | `scripts/render/gpu.py`. **Metal** on this Mac (the playbook assumes NVIDIA) | Complete. Verified: `backend=METAL devices=['Apple M3 (GPU - 10 cores)']` |
| Render the interface + comp contact sheet, then 18 half-size stills, then the film | Visual gate before expensive work | `preview.py`, `render.py --res-pct 50 --samples 40`, `contact_sheet.py`; Claude views the sheets | Complete |
| Specific fixes with exact numbers; polish comes from rounds | Iteration discipline | `blender-render-review` skill; round history kept in `spec.py` comments | Complete. 4 rounds on the demo asset |
| Chunked, resumable render; re-render only what broke | Every frame stands alone | `render.py --frames 1-12,20-24` skips frames that exist; `--force` re-renders | Complete. Verified: 12 rendered, 12 skipped |
| Scan every frame for blank or broken images | Automated QA | `scan_frames.py` (missing, empty, corrupt, black, white, flat) prints a range to re-render | Complete. Tested with injected bad frames |
| AgX lightens colours; check pixels against the hex | Measure, don't eyeball | `pixel_check.py` | Complete. Used in all 4 review rounds |
| Hide lights from glossy rays | Avoid white blocks in reflections | `hide_from_glossy()`; rim/glow lights `visible_glossy=False` | Complete |
| `view_layer.update()` before parenting | Avoid objects snapping to the parent origin | Used in `turntable_scene.py`; rule in the `blender-live` skill | Complete |
| ffmpeg full build, vignette, H.264 high CRF 17, AAC 320k, faststart | Finish step | `scripts/film/encode.py` | Complete. Verified with ffprobe |
| Node + Puppeteer UI; numpy/scipy/pedalboard sound; true-peak −1 dB | Pieces specific to that film | Documented in the `blender-film` skill; to be installed when a film needs them (decision Q1) | Deferred |
| NVIDIA GPU, ~3.3 s/frame | Hardware assumption | **Conflict:** this is an Apple M3. Cycles Metal measured at 1.61 s/frame at 960×540 with 32 samples (warm; first run ~75 s for kernel compile). EEVEE: 1.3 s/frame at 960×540 | Adapted |
| "Make it yours": change only the BRAND block | Reusable brief | `templates/film_brief.md` (six blocks) | Complete |
