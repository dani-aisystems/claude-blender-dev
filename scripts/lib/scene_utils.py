"""bpy helpers shared by build, export, validation and render scripts. Import only inside Blender."""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

from .safe_paths import next_version_path


# ---------- colour ----------

def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(hex_str: str, alpha: float = 1.0):
    """'#C4703A' -> linear RGBA tuple for Blender colour sockets."""
    h = hex_str.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), alpha)


# ---------- scene ----------

def clear_scene():
    """Remove all objects and orphaned mesh/material/light/camera data (current file only)."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras, bpy.data.images):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)
    for c in list(bpy.data.collections):
        if c.users == 0 or not c.objects and not c.children:
            bpy.data.collections.remove(c)


def get_collection(name: str, parent=None):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
    parent = parent or bpy.context.scene.collection
    if coll.name not in parent.children:
        parent.children.link(coll)
    return coll


def set_metric_units(scene=None):
    scene = scene or bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.unit_settings.length_unit = "METERS"


def mesh_object_from_bmesh(name: str, bm: bmesh.types.BMesh, collection, material=None):
    """Create (or replace the data of) a mesh object from *bm*. Origin = world origin."""
    me = bpy.data.meshes.get(name)
    if me is None:
        me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    me.update()
    obj = bpy.data.objects.get(name)
    if obj is None:
        obj = bpy.data.objects.new(name, me)
    else:
        obj.data = me
    if obj.name not in collection.objects:
        collection.objects.link(obj)
    obj.matrix_world = Matrix.Identity(4)
    me.materials.clear()
    if material is not None:
        me.materials.append(material)
    return obj


def apply_transforms(obj):
    """Bake the object's transform into its mesh data (context-free equivalent of Ctrl+A > All)."""
    if obj.type == "MESH":
        obj.data.transform(obj.matrix_basis)
        obj.data.update()
    obj.matrix_basis = Matrix.Identity(4)


def box_project_uvs(bm: bmesh.types.BMesh, layer_name: str = "UVMap", margin: float = 0.0):
    """Context-free box projection, normalised so every UV lies in 0..1 (single UV set)."""
    uv = bm.loops.layers.uv.get(layer_name) or bm.loops.layers.uv.new(layer_name)
    raw = []
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        u_i, v_i = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            co = loop.vert.co
            raw.append((loop, co[u_i], co[v_i]))
    if not raw:
        return uv
    us = [r[1] for r in raw]
    vs = [r[2] for r in raw]
    umin, vmin = min(us), min(vs)
    span = max(max(us) - umin, max(vs) - vmin, 1e-9)
    scale = (1.0 - 2 * margin) / span
    for loop, u, v in raw:
        loop[uv].uv = ((u - umin) * scale + margin, (v - vmin) * scale + margin)
    return uv


def hide_from_glossy(obj):
    """Playbook fix: lights must not show up as white blocks in glossy reflections."""
    obj.visible_glossy = False


def save_versioned(directory, name: str) -> str:
    """Save the current file as ``directory/name_vNNN.blend``; never overwrites."""
    path = next_version_path(directory, name)
    bpy.ops.wm.save_as_mainfile(filepath=str(path), check_existing=True, compress=True)
    return str(path)


# ---------- materials ----------

def principled_material(name, base_hex, roughness=0.5, metallic=0.0, alpha=1.0,
                        emission_hex=None, emission_strength=0.0, transmission=0.0,
                        subsurface=0.0):
    """Create/replace a Principled BSDF material with plain values (engine-exportable)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (-300, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    inp = bsdf.inputs
    inp["Base Color"].default_value = hex_to_linear(base_hex)
    inp["Roughness"].default_value = roughness
    inp["Metallic"].default_value = metallic
    inp["Alpha"].default_value = alpha
    if "Transmission Weight" in inp:
        inp["Transmission Weight"].default_value = transmission
    if "Subsurface Weight" in inp:
        inp["Subsurface Weight"].default_value = subsurface
    if emission_hex:
        inp["Emission Color"].default_value = hex_to_linear(emission_hex)
        inp["Emission Strength"].default_value = emission_strength
    mat.diffuse_color = hex_to_linear(base_hex, alpha)  # viewport/solid colour + FBX fallback
    if alpha < 1.0:
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
        if hasattr(mat, "use_transparent_shadow"):
            mat.use_transparent_shadow = True  # EEVEE: let light through glass instead of trapping it
    return mat


# ---------- bounds / camera ----------

def world_bounds(objects):
    pts = [o.matrix_world @ Vector(c) for o in objects if o.type == "MESH" for c in o.bound_box]
    if not pts:
        return Vector((0, 0, 0)), Vector((0, 0, 0))
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def look_at(obj, target: Vector):
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def orbit_position(center: Vector, radius: float, azimuth_deg: float, elevation_deg: float) -> Vector:
    az, el = math.radians(azimuth_deg), math.radians(elevation_deg)
    return center + Vector((radius * math.cos(el) * math.sin(az),
                            -radius * math.cos(el) * math.cos(az),
                            radius * math.sin(el)))
