# Architecture

## Two workflows, one set of scripts
```
Workflow A (live)      Claude Code ⇄ stdio ⇄ blender-mcp (~/blender_mcp, v1.0.3) ⇄ TCP localhost:9876 ⇄ Blender add-on "MCP"
Workflow B (headless)  Claude Code → tools/bl → Blender -b --factory-startup -P scripts/... -- args
Host tools             tools/py → .venv (numpy, Pillow, pytest): contact sheets, frame scan, pixel check, ffmpeg encode
```
- Both workflows run the same versioned scripts. In a live session they are executed with `runpy.run_path(..., run_name="__main__")`, so every asset can always be rebuilt from source.
- Each project's `spec.py` is the single source of truth (playbook principle).
- Path guard: writes are allowed only in the workspace or the system temp folder, and existing files are never overwritten (`scripts/lib/safe_paths.py`).

## Environment (audited 2026-11-03)
| Item | Found / installed |
|---|---|
| OS / HW | macOS 27.0, Apple M3 (10-core GPU, Metal 4), 16 GB RAM. No NVIDIA GPU. |
| Disk | ~16 GB free (92% used). Renders and exports are gitignored, and no game engines are installed. |
| Blender | **5.2.3 LTS**, installed via `brew install --cask blender` (it was not present before). |
| MCP | Official Blender Lab MCP **v1.0.3** (tag commit `2cea8d5`), local scope. Add-on auto-start is off; online access is enabled per session only. |
| Tooling | Homebrew 7, uv 0.12.5, Python 3.14 (system) / 3.12 (.venv), Node 26, ffmpeg 9.0.1 full build, git 2.54 + LFS 3.7.1, Claude Code 2.1.274. |
| Reused | Existing `grilling` skill + AskUserQuestion; Roblox Studio + `Roblox_Studio` MCP (other projects). |
| Path quirk | The workspace path contains `:`, which breaks `uv run`. Use `tools/py` instead. The MCP is vendored outside the workspace for the same reason. |

## Integration research (2026-11-03)
| Candidate | Evidence | Decision |
|---|---|---|
| **Blender Lab MCP**<br>projects.blender.org/lab/blender_mcp | GPL-3.0+, Blender ≥ 5.1. Releases v1.0.0 (2026-04-27) → v1.0.3 (2026-09-11). **26 tools**, including `execute_blender_code`, scene/object summaries, area/window screenshots, `render_thumbnail_to_path`, offline API + manual search, and `*_for_cli` background-Blender variants (via `BLENDER_PATH`). Binds `localhost:9876`. Its "weak sandbox" blocks only things like `sys.exit`. Its docs recommend a VM. | **Selected:** official, maintained, no telemetry, no third-party services, offers visual feedback. |
| **mcp-for-blender**<br>ahujasid, formerly blender-mcp | MIT, v2.2.6 (2026-10-28), ~33k★. Tools: `execute_blender_code`, `look`, `get_scene_info`, `generate_3d` (Rodin/Tripo/Hunyuan/Meshy), Poly Haven/Sketchfab/Poly Pizza. Anonymous telemetry by default (`DISABLE_TELEMETRY=true`). Same default port, 9876. A vendor blog reports a CVE, but none appears in GitHub advisories. | **Rejected:** duplicates the selected server, conflicts on the port, has telemetry, and adds paid/external services that are out of scope. |
| Third-party Blender skills (agent-almanac `script-blender-automation`, registry `blender-pipeline`, `creating-3d-assets-blender`) | Small, unvetted. | **Not installed.** Lean project skills were written instead. |

Engine facts used in the presets:
- **Roblox (official docs):**
  - FBX/glTF/OBJ formats;
  - ≤ 20,000 tris per mesh;
  - one material per mesh;
  - a single UV set in 0–1;
  - watertight geometry;
  - textures ≤ 4096² (1024² guidance);
  - PBR maps: Color, Normal (OpenGL), Roughness, Metalness, Emissive;
  - FBX settings: Apply Scalings = FBX Unit Scale, Path Mode Copy + Embed, no leaf bones, Forward Z / Up Y;
  - 1 stud = 28 cm.
- **Unity 6 Manual:** 1 unit = 1 m; don't embed media; no Blender exporter settings given.
- **Unreal Engine 5:**
  - FBX 2020.2 pipeline, units in cm;
  - collision prefixes `UBX_/UCP_/USP_/UCX_<Mesh>_##`;
  - pivot at origin;
  - no Blender exporter settings given.

Sources:
- blender.org/lab/mcp-server
- projects.blender.org/lab/blender_mcp (readme, readme_tools.rst, wiki Setup, releases API)
- github.com/ahujasid/mcp-for-blender
- pypi.org/project/mcp-for-blender
- create.roblox.com/docs/art/modeling/{specifications,export-requirements}, /studio/importer, /physics/units, /art/blender
- docs.unity.com (Unity 6.0 FBX importer and model preparation)
- dev.epicgames.com (FBX Static Mesh Pipeline, FBX Import Options)
- code.claude.com/docs (mcp, permissions, permission-modes, settings)

## Security model
- The bridge listens on localhost only and has no auth, so anything local that can reach port 9876 can run Python in Blender. It is therefore started manually (`tools/launch_blender.sh`) and stopped when not in use.
- The MCP is registered at local scope (this folder only).
- `CLAUDE.md` forbids file deletion, subprocess and network calls in generated bpy code.
- `.claude/settings.json` `ask` rules cover deletes, downloads, installs, MCP changes, commits/pushes, and writes to other projects or `~/.claude`. Ask rules still prompt under `bypassPermissions` (code.claude.com/docs/en/permission-modes).
- **Residual risk:** code runs with the user's privileges. For stronger isolation, use a separate macOS user or a VM (UTM) once disk space allows.
