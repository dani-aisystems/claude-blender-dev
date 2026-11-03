# Acceptance report

Run on 2026-11-03: macOS 27.0, Apple M3, Blender 5.2.3 LTS, Blender Lab MCP v1.0.3.

Demo asset: **hero lantern**, a hexagonal hand lantern in stylized realism.
- Meshes: `SM_Lantern_Frame` / `Glass` / `Candle` / `Flame`, one material each.
- 2,528 tris; 0.20 × 0.17 × 0.49 m.

Legend: **PASS** means executed and verified with the evidence shown. **PARTIAL** means it works with a limitation. **NOT TESTED** means it was not executed.

## Live connection (Workflow A)
These steps ran through the official MCP server over stdio, the same path Claude Code uses: `tools/mcp_acceptance.py` → `blender-mcp` → TCP → add-on in a running Blender GUI.

| # | Capability | Result | Evidence |
|---|---|---|---|
| 1 | Connect to Blender | **PASS** | `get_blendfile_summary_path_info` → `status: ok`. The bridge listens on `127.0.0.1:9876` only (`lsof`) |
| 2 | Read the active scene | **PASS** | `get_objects_summary` returned collections, objects, the active object and the camera |
| 3 | Create objects | **PASS** | `execute_blender_code` ran `build.py` live: `BUILD_RESULT` 4 objects, 2,528 tris |
| 4 | Assign materials | **PASS** | `get_object_detail_summary("SM_Lantern_Glass")` → `materials: ["M_Lantern_Glass"]` |
| 5 | Apply transforms | **PASS** | Validator rule `transforms_applied` PASS on all 4 meshes |
| 6 | Inspect object data | **PASS** | Live validation: `roblox` overall **PASS** (38 PASS / 0 WARN / 0 FAIL) |
| 7 | Save native .blend | **PASS** | `save_versioned` → `hero_lantern_live_v001.blend` |
| 8 | Export a game asset | **PASS** | Run headless; see Workflow B |
| 9a | Viewport screenshot | **PASS** | `get_screenshot_of_area_as_image(VIEW_3D)` → 3148×1882 PNG showing the lantern. Viewed and checked |
| 9b | Preview render via MCP | **PARTIAL** | `render_thumbnail_to_path` works, but by design it writes only to Blender's temp folder (returns the real path). It renders from the scene camera, which showed the default startup cube hiding the lantern. Use `preview.py` for asset reviews, and open the asset file (or an empty scene) when launching |
| 10 | Reopen the saved file | **PASS** | `execute_blender_code_for_cli` opened `hero_lantern_live_v001.blend` in background Blender and listed the 4 `SM_` meshes |
| — | MCP tool inventory | **PASS** | `list_tools` → 26 tools |
| — | Claude Code registration | **PASS** | `claude mcp get blender` → local scope, ✔ Connected. A new session is needed for `mcp__blender__*` to appear in Claude Code |

## Headless pipeline (Workflow B)
| Capability | Result | Evidence |
|---|---|---|
| Procedural build + versioned save | **PASS** | `build.py --new --save` → v001…v005 |
| Validation, 4 targets | **PASS** | roblox 38/0/0, gltf 34/0/0, unity 34/0/0, unreal 34/0/0 (PASS/WARN/FAIL) |
| Export, 4 targets | **PASS** | `exports/hero_lantern/{roblox,unity,unreal}/*.fbx`, `gltf/*.glb` (78–134 KB) |
| Reimport check, 4 targets | **PASS** | Mesh count, tris (2,528), materials and size all match. The Roblox FBX comes back at ×3.5714, the expected metres-to-studs factor |
| Negative test | **PASS** | An asset with unapplied scale and 2 materials **fails** Roblox validation, with a non-zero exit code |
| Never-overwrite guard | **PASS** | A repeat export writes `_v002`. A repeat MP4 encode is refused |
| Visual review loop | **PASS** | 5 preview sheets viewed. Flame colour distance went 145 → 122 → 109 → 128 → 76 over 4 measured rounds (the fixes are logged in `spec.py`). See `docs/images/` |
| Film path | **PASS** | 24-frame turntable: chunked render (12 + 12, of which 12 skipped on resume) → `scan_frames` 24/24 OK → H.264 MP4 (ffprobe: 960×540, 24 fps, 24 frames) |
| Cycles GPU (Metal) | **PASS** | `GPU_SETUP backend=METAL devices=['Apple M3 (GPU - 10 cores)']`. 1.61 s/frame warm at 960×540 with 32 samples; the first run takes ~75 s for kernel compilation |
| Test suite | **PASS** | `tools/py -m pytest`: 7 passed in 8.5 s |

## Not tested
| Item | Why |
|---|---|
| Import into Roblox Studio | Writing into the Roblox project needs Daniel's approval. The stud scale convention is still unconfirmed |
| Import into Unity / Unreal | Engines not installed (disk space); the presets are conventions |
| CC0 download (`fetch_cc0.py --confirm`) | Downloads need explicit approval; the dry-run path only |
| Puppeteer UI, synthesized sound | Deferred by decision Q1 |

## Known visual gaps on the demo asset (next iteration)
- There's no warm light pool on the ground around the lantern.
- The iron reads flat: it needs baked wear/edge textures.
- The preview backdrop shows a dark band at the top of the frame.
- The flame is still desaturated by AgX (#E4B58E vs a #FFB347 target).
