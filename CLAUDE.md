# Blender Dev: 3D, game-asset and film workspace

Daniel's workspace for creating 3D models, game assets, environments and short films with Blender, driven by Claude Code. Claude designs the work, builds it in Blender, **looks at the result**, improves it, and prepares it for its target (Roblox, web, Unity/Unreal, video).

## Precedence
1. Daniel's explicit instructions and confirmed decisions (`docs/architecture/DECISIONS.md`).
2. The playbook: `Claude + Blender_ Make 3D Motion Graphics From Code.pdf`. How it's interpreted: `docs/playbook/COMPLIANCE_MATRIX.md`.
3. Verified official docs (Blender API; Roblox, Unity and Unreal docs).
4. Maintained open-source tools.
5. Claude's own recommendations.

## Tools
- **Blender 5.2.3 LTS:** `/Applications/Blender.app` (Homebrew cask).
- **Headless:** `tools/bl [file.blend] -P script.py -- args`.
- **Live (MCP `blender`):** the official Blender Lab MCP v1.0.3 at `~/blender_mcp`, registered at local scope, on `localhost:9876`. Daniel starts the bridge with `tools/launch_blender.sh`; check it with `tools/mcp_status.sh`.
- **Host Python:** `tools/py` (`.venv` has numpy, Pillow, pytest). **Never `uv run`**: the workspace path contains `:`, which breaks it.
- **Other:** ffmpeg 9 (full build), git + LFS.

## Skill routing
| Task | Skill |
|---|---|
| Work in Daniel's open Blender, inspect or modify the live scene | `blender-live` |
| Prop, model, building, environment piece; export to an engine | `blender-asset-pipeline` (+ `blender-render-review`) |
| Any visual check, colour or lighting problem, "does it look right" | `blender-render-review` |
| Animated film, turntable, title sequence (playbook) | `blender-film` (+ `blender-render-review`) |
| Vague request, or a new project's requirements | `grilling` with AskUserQuestion, in small batches |
| Roblox hand-off | `blender-asset-pipeline`, then ask Daniel before writing into `../Roblox Builder` |

## Conventions
- **Layout:**
  - `projects/<models|environments|games|films>/<name>/` holds `spec.py` (single source of truth), `build.py`, and versioned `<name>_vNNN.blend`.
  - `assets/` holds reusable, licence-logged material.
  - Outputs go to `renders/` and `exports/`, both gitignored and reproducible.
- **Geometry and naming:** metres, Z up, origin at base centre, transforms applied. Names use `SM_`, `M_`, `T_`, and `UCX_` for collision.
- **Budgets:**
  - per-target budgets live in `scripts/exports/presets.py`;
  - Roblox: ≤ 20k tris per mesh, one material per mesh, one UV set in 0–1, watertight;
  - default style is stylized realism.
- **Scripts:** reuse `scripts/lib` (args, safe paths, versioned save, materials, bounds). Don't reinvent them.

## Safety (the MCP runs Python with Daniel's privileges and has no real sandbox)
- **Free to do without asking:**
  - create or modify scene objects;
  - run workspace scripts;
  - save **new** versions (`save_versioned`);
  - render into `renders/`, export into `exports/`.
- **Ask first:**
  - overwriting or deleting any file;
  - writing outside this workspace (including `../Roblox Builder`);
  - any download (`tools/fetch_cc0.py --confirm`; CC0 only, licence logged in `assets/ASSET_LICENSES.md`);
  - installing anything;
  - commits and pushes.
  
  The project `.claude/settings.json` has ask rules for these. They still prompt under `bypassPermissions`.
- **Forbidden in generated bpy code:** `os.remove`, `shutil.rmtree`, `subprocess`, sockets, `urllib`/`requests`, `read_factory_settings` in a live session.
- **Never:**
  - paid or AI-generation APIs;
  - credentials in files;
  - the community `mcp-for-blender` (it conflicts on port 9876 and has telemetry);
  - unvetted add-ons.

## Completion criteria
1. Validation is PASS for every requested target, with WARNs explained.
2. Exports were reimported and their checks passed.
3. Preview or stills were rendered, **viewed with Read**, critiqued, and fixed with exact numbers.
4. A versioned `.blend` is saved.
5. Results are reported as PASS / PARTIAL / FAIL / NOT TESTED with evidence. Never claim a visual or engine check that wasn't done.
- Run `tools/py -m pytest` after changing anything in `scripts/`.
