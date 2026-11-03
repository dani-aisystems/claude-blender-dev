---
name: blender-live
description: Drive a running Blender GUI session through the official Blender Lab MCP (mcp__blender__* tools) — inspect the scene, run workspace bpy scripts live, take viewport screenshots, verify, save versioned. Use whenever the user wants Claude to work in their open Blender, look at the current scene, or iterate on a model interactively.
---

# Live Blender via the official MCP

Server: Blender Lab `blender_mcp` v1.0.3 (GPL-3.0), vendored at `~/blender_mcp`, registered at **local scope** as `blender`.
Bridge: Blender add-on "MCP" on `localhost:9876`, **auto-start off**.

## 0. Preflight
1. Run `tools/mcp_status.sh`.
2. If the port isn't listening, ask the user to run `tools/launch_blender.sh [file.blend]`. The script opens Blender with `--online-mode` and starts the bridge.
3. If `mcp__blender__*` tools are missing in this session, the user must restart Claude Code. The server loads only at session start.

## 1. The loop: inspect → act → look → judge → fix → save
| Step | Tool |
|---|---|
| Where am I? | `get_blendfile_summary_path_info`, `get_blendfile_summary_datablocks` |
| What's in the scene? | `get_objects_summary`, then `get_object_detail_summary(name=...)` |
| Unsure of an API? | `search_api_docs` / `get_python_api_docs` (offline, bundled with the server) **before** guessing |
| Act | `execute_blender_code`, preferably running a **workspace script** (below) rather than ad-hoc code |
| Look | `jump_to_view3d_object_by_name`, then `get_screenshot_of_area_as_image` (3D viewport) or `render_thumbnail_to_path` |
| Judge | Compare against the brief using `blender-render-review`. Never call it done without looking. |
| Save | `execute_blender_code` → `lib.scene_utils.save_versioned(dir, name)`, which never overwrites |

**Run a workspace script live** (keeps every result reproducible from source):
```python
import runpy, sys
WS = "/absolute/path/to/this/workspace"         # the real repo path (`pwd` in the repo)
sys.argv = ["blender", "--", "--save"]          # the script's args go after "--"
runpy.run_path(WS + "/projects/models/hero_lantern/build.py", run_name="__main__")
```
- Validate live with the same pattern on `scripts/validation/validate_asset.py`, with args `--collection ... --target roblox`.
- Exports use the same pattern on `scripts/exports/export_asset.py`. Prefer running exports headless (`blender-asset-pipeline`) so they're reproducible.

## 2. Code rules for `execute_blender_code` (the MCP has no real sandbox)
- **No** `os.remove`, `shutil.rmtree`, `subprocess`, `socket`, `urllib`/`requests`, `eval` of fetched text, or `bpy.ops.wm.read_factory_settings` in a live session.
- Write files only under the workspace, through `lib.safe_paths` / `save_versioned`. Never `save_mainfile()` over an existing file without the user's OK.
- Never delete objects you didn't create. Build scripts replace only their own `ASSET_*` / `DRESS_*` collections.
- Call `bpy.context.view_layer.update()` before maths that depends on parenting or world matrices.
- Keep each call small and print a short JSON result, so the output is inspectable.

## 3. Gotchas (verified 2026-11-03)
- `render_thumbnail_to_path` ignores your folder. It writes to Blender's temp dir (keeping only the file name) and returns the real path in `filepath`. Copy it into `renders/` if you need it.
- The thumbnail uses the **scene camera**. In the default startup scene, the 2 m default cube can hide a small asset at the origin. Prefer `get_screenshot_of_area_as_image` after `jump_to_view3d_object_by_name`.
- Ask Daniel to launch with the asset file (`tools/launch_blender.sh <file.blend>`).
- Repeatable end-to-end check: `~/blender_mcp/mcp/.venv/bin/python -I tools/mcp_acceptance.py`.

## 4. What the MCP cannot do
- **Headless work:** the `*_for_cli` tools open a .blend in background Blender for read-only summaries and code. Use `tools/bl` for real headless pipelines.
- **Camera-quality renders:** `render_viewport_to_path` uses current render settings and can be slow. For reviews use `scripts/render/preview.py` (EEVEE turntable) instead.
