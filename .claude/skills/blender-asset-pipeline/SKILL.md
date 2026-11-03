---
name: blender-asset-pipeline
description: Take a 3D game asset from brief to validated engine export (Roblox FBX, web GLB, Unity/Unreal FBX) in this workspace — spec.py source of truth, procedural build.py, naming, triangle/material budgets, UVs, validation, export presets, reimport check. Use for any prop, model, building or environment piece meant for a game or the web.
---

# Asset pipeline: Concept → Export → Validation

## Files per asset: `projects/<models|environments|games>/<name>/`
- `spec.py` is the **single source of truth**: dimensions, colours (hex), budgets, materials, preview settings. Log each review round as a comment on the value it changed (`# Round 2: 4 -> 2 because ...`).
- `build.py` builds procedurally from the spec. It must be context-free (bmesh), replace only `ASSET_<name>` / `DRESS_<name>`, and support `--new --save` headless.
- `<name>_vNNN.blend` files are versioned saves made by `lib.scene_utils.save_versioned`. They are never overwritten.
- Start from `templates/asset_spec_template.py` and copy `projects/models/hero_lantern/build.py` as the reference implementation.

## Conventions (the validator enforces them)
- **Units:** metres, Z up. 1 Blender unit = 1 m. Origin at the **base centre** (world origin). Transforms applied (scale 1, rotation 0).
- **Names:** meshes `SM_` (static) or `SK_` (skinned), materials `M_`, textures `T_<Asset>_<Map>`. Unreal collision is `UCX_<RenderMesh>_01`.
- **Materials:** Principled BSDF with plain values (or image textures) only. Procedural shader nodes don't export, so bake them first.
- **Roblox:**
  - one material per mesh, so split parts (e.g. Frame/Glass/Candle/Flame);
  - ≤ 20,000 tris per mesh;
  - a single UV set inside 0–1;
  - watertight, no zero-thickness geometry;
  - textures ≤ 1024² recommended (4096² max);
  - normal maps in OpenGL format.
- **Stylized realism** (default style): real silhouettes, chamfered or bevelled hard edges, PBR values. No noise-only detail that won't survive export.

## Commands (headless; the workspace path has `:` so use `tools/bl` and `tools/py`, never `uv run`)
```bash
tools/bl -P projects/models/<name>/build.py -- --new --save
tools/bl projects/models/<name>/<name>_v00N.blend -P scripts/validation/validate_asset.py -- \
    --collection ASSET_<name> --target roblox --json renders/<name>/validation_roblox_v00N.json --strict
tools/bl projects/models/<name>/<name>_v00N.blend -P scripts/exports/export_asset.py -- \
    --collection ASSET_<name> --name <name> --targets roblox,gltf,unity,unreal --out exports/<name> --version v00N
tools/bl -P scripts/validation/reimport_check.py -- --file exports/<name>/roblox/<name>_v00N.fbx \
    --source-json renders/<name>/validation_roblox_v00N.json --expected-scale 3.571428
```
`--expected-scale` takes the value from the export's `EXPORT_RESULT`: Roblox 3.571428, everything else 1.

## Target notes
- **roblox:** FBX settings from the official Roblox docs. ×3.5714 converts metres to studs (1 stud = 0.28 m), and the importer's Scale Unit stays at Studs.
  - The scale is a convention: confirm it on the first Studio import.
  - Use the FBX, **not** the GLB, for Roblox.
- **gltf:** GLB in metres, +Y up. Use it for the web/three.js and general interchange.
- **unity / unreal:** these are **conventions**. The official docs give no Blender exporter settings, and neither engine is installed here, so they aren't engine-tested.

## Done means
1. Validation is PASS with no FAILs for every requested target, and any WARNs are explained.
2. Exports were reimported and their checks passed.
3. Preview renders were **looked at** and critiqued (`blender-render-review`).
4. The versioned `.blend` is saved.
5. Engine hand-off (e.g. copying into Roblox Builder) happens **only with Daniel's approval**.
