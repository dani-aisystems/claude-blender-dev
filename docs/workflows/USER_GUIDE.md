# User guide

## Starting a session
1. Open this folder in Claude Code (VS Code extension or `claude` in a terminal).
2. **Live Blender (optional):**
   - Run `tools/launch_blender.sh [file.blend]`.
   - Wait for "bridge is listening on localhost:9876".
   - If Claude Code was already open, restart it so the `blender` MCP tools load.
   - Check status with `tools/mcp_status.sh`.
3. Describe what you want, for example:
   - "Make a stylized wooden crate for Roblox, under 1,500 tris."
   - "Look at my open scene and tell me what's wrong with the lighting."
   - "Do a 4-second turntable of the lantern."

## What Claude does (and when it asks you)
- **Vague brief:** Claude grills you in small batches (`grilling` + AskUserQuestion).
- **Then it builds:**
  1. creates `projects/<type>/<name>/spec.py` and `build.py`;
  2. builds headless, or live if Blender is open;
  3. validates;
  4. renders a preview and **looks at it**;
  5. fixes with exact numbers;
  6. saves `<name>_vNNN.blend`;
  7. exports and reimports.
- **It asks before:**
  - overwriting or deleting;
  - writing outside this folder (for example into your Roblox project);
  - downloading CC0 assets;
  - installing anything;
  - committing or pushing.

## Everyday commands
| Goal | Command |
|---|---|
| Rebuild an asset | `tools/bl -P projects/models/<name>/build.py -- --new --save` |
| Validate | `tools/bl <blend> -P scripts/validation/validate_asset.py -- --collection ASSET_<name> --target roblox` |
| Export | `tools/bl <blend> -P scripts/exports/export_asset.py -- --collection ASSET_<name> --name <name> --targets roblox,gltf --out exports/<name>` |
| Preview + sheet | `tools/bl <blend> -P scripts/render/preview.py -- --collection ASSET_<name> --out renders/<name>/p1` then `tools/py scripts/render/contact_sheet.py renders/<name>/p1 -o renders/<name>/p1.png` |
| Measure a colour | `tools/py scripts/validation/pixel_check.py <png> --at X,Y --target "#HEX"` |
| Turntable film | `turntable_scene.py` → `render.py` → `scan_frames.py` → `encode.py` (see the `blender-film` skill) |
| CC0 asset (after OK) | `tools/py tools/fetch_cc0.py polyhaven hdri <id> --res 1k` (dry run), then add `--confirm` |
| Tests | `tools/py -m pytest` (or `-m "not blender"` for the fast tests only) |

## Bringing an asset into Roblox Studio
1. In Studio, go to **File → Import 3D** and choose `exports/<name>/roblox/<name>_vNNN.fbx`.
2. Leave **Scale Unit = Studs**. The export already converts metres to studs.
3. Each mesh imports as a MeshPart with one material. Set transparency on glass and an emissive look on lights in Studio, using SurfaceAppearance or Material.
4. On the first import, check the size against a default character (about 5 studs tall). If the size is off, tell Claude. The conversion factor lives in `scripts/exports/presets.py`.

## Disk hygiene
`renders/` and `exports/` are regenerable. Clear them when space is tight; Claude asks before deleting anything.
