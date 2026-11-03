"""Per-target export presets + validation budgets.

Provenance is recorded per preset so nobody mistakes a convention for an official rule.
Assets are always modelled in real-world metres (1 Blender unit = 1 m).
"""

ROBLOX_METERS_PER_STUD = 0.28  # create.roblox.com/docs/physics/units: "Length | 1 stud | 28 cm"

PRESETS = {
    "roblox": {
        "format": "fbx",
        "ext": ".fbx",
        "source": "create.roblox.com/docs/art/modeling/export-requirements + /art/blender (fetched 2026-11-03)",
        "fbx": dict(
            apply_scale_options="FBX_SCALE_UNITS",   # official: Apply Scalings = FBX Unit Scale
            global_scale=1.0 / ROBLOX_METERS_PER_STUD,  # CONVENTION: metres -> studs (verify on first Studio import)
            axis_forward="Z",                         # official: "Set Forward to Z Forward"
            axis_up="Y",                              # official: "Set Up to Y Up"
            path_mode="COPY",                         # official: Path Mode Copy
            embed_textures=True,                      # official: Embed Textures
            add_leaf_bones=False,                     # official: disable Add Leaf Bones
            bake_anim=False,                          # official: disable unless animated
            mesh_smooth_type="FACE",
            use_mesh_modifiers=True,
        ),
        "expected_scale": 1.0 / ROBLOX_METERS_PER_STUD,
        "budgets": dict(max_tris_per_mesh=20000, max_materials_per_mesh=1, max_uv_layers=1,
                        uv_in_unit_square=True, require_manifold=True, max_texture_px=4096,
                        warn_texture_px=1024),
        "notes": "Roblox Importer: leave Scale Unit = Studs (default). One material per MeshPart. "
                 "Use FBX, not GLB, for Roblox (GLB is metres; Studio would read them as studs).",
    },
    "gltf": {
        "format": "gltf",
        "ext": ".glb",
        "source": "glTF 2.0 spec (metres, +Y up); Blender glTF exporter defaults",
        "gltf": dict(export_format="GLB", export_apply=True, export_yup=True),
        "expected_scale": 1.0,
        "budgets": dict(max_tris_per_mesh=100000, max_materials_per_mesh=8, max_uv_layers=2,
                        uv_in_unit_square=False, require_manifold=False, max_texture_px=4096,
                        warn_texture_px=2048),
        "notes": "Web/three.js and general interchange.",
    },
    "unity": {
        "format": "fbx",
        "ext": ".fbx",
        "source": "CONVENTION. Unity 6 Manual states 1 unit = 1 m and says not to embed media; "
                  "it gives no Blender exporter settings (checked 2026-11-03).",
        "fbx": dict(
            apply_scale_options="FBX_SCALE_UNITS",
            axis_forward="-Z",
            axis_up="Y",
            bake_space_transform=True,   # 'Apply Transform' (experimental) -> no -90 X rotation on root
            path_mode="COPY",
            embed_textures=False,        # official Unity guidance: don't embed media
            add_leaf_bones=False,
            bake_anim=False,
            mesh_smooth_type="FACE",
            use_mesh_modifiers=True,
        ),
        "expected_scale": 1.0,
        "budgets": dict(max_tris_per_mesh=65000, max_materials_per_mesh=8, max_uv_layers=8,
                        uv_in_unit_square=False, require_manifold=False, max_texture_px=8192,
                        warn_texture_px=2048),
        "notes": "Not engine-tested. In Unity, enable Convert Units if size is off by 100x.",
    },
    "unreal": {
        "format": "fbx",
        "ext": ".fbx",
        "source": "CONVENTION. UE5 docs: FBX 2020.2 pipeline, units cm via 'Convert Scene Unit', "
                  "collision prefixes UBX_/UCP_/USP_/UCX_<RenderMesh>_##, pivot at origin; "
                  "no Blender exporter settings given (checked 2026-11-03).",
        "fbx": dict(
            apply_scale_options="FBX_SCALE_NONE",
            axis_forward="-Z",
            axis_up="Y",
            path_mode="COPY",
            embed_textures=False,
            add_leaf_bones=False,
            bake_anim=False,
            mesh_smooth_type="FACE",     # export smoothing groups
            use_tspace=False,
            use_mesh_modifiers=True,
        ),
        "expected_scale": 1.0,
        "budgets": dict(max_tris_per_mesh=500000, max_materials_per_mesh=8, max_uv_layers=8,
                        uv_in_unit_square=False, require_manifold=False, max_texture_px=8192,
                        warn_texture_px=4096),
        "notes": "Not engine-tested. Name collision meshes UCX_<RenderMesh>_01 and export them in the same FBX.",
    },
}
