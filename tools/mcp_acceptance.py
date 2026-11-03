"""Live MCP acceptance test: drives the official Blender MCP server over stdio, exactly like Claude Code does.

Prereq: tools/launch_blender.sh is running (bridge on localhost:9876).
Run with the MCP server's own venv (it has the `mcp` client package):
  ~/blender_mcp/mcp/.venv/bin/python -I tools/mcp_acceptance.py
Writes renders/hero_lantern/live/{acceptance_log.json, *.png}. Builds the lantern in the open scene
(replacing only its own collections) and saves projects/models/hero_lantern/live/hero_lantern_live_vNNN.blend.
"""
import asyncio, base64, json, os, sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
WS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = WS + "/renders/hero_lantern/live"
os.makedirs(OUT, exist_ok=True)
P = StdioServerParameters(command="uv", args=["--directory", os.path.expanduser("~/blender_mcp/mcp"), "run", "blender-mcp"],
                          env={**os.environ, "BLENDER_PATH": "/Applications/Blender.app/Contents/MacOS/Blender"})
log = {}
async def call(s, step, tool, **args):
    r = await s.call_tool(tool, args)
    texts, imgs = [], 0
    for c in r.content:
        if c.type == "text":
            texts.append(c.text)
        elif c.type == "image":
            imgs += 1
            p = f"{OUT}/{step}_{tool}.png"
            open(p, "wb").write(base64.b64decode(c.data)); texts.append(f"[image saved {p.split('Blender Dev/')[1]}]")
    txt = "\n".join(texts)
    log[step] = {"tool": tool, "error": r.isError, "out": txt[:1500]}
    print(f"== {step} {tool} error={r.isError}\n{txt[:900]}\n")
RUN = lambda path, argv: (f"import runpy, sys\nsys.argv = ['blender', '--'] + {argv!r}\n"
                          f"runpy.run_path({(WS + '/' + path)!r}, run_name='__main__')")
async def main():
    async with stdio_client(P) as (r, w):
        async with ClientSession(r, w) as s:
            await s.initialize()
            await call(s, "01_connect", "get_blendfile_summary_path_info")
            await call(s, "02_read_scene", "get_objects_summary")
            await call(s, "03_create", "execute_blender_code", code=RUN("projects/models/hero_lantern/build.py", []))
            await call(s, "04_material", "get_object_detail_summary", name="SM_Lantern_Glass")
            await call(s, "05_06_validate", "execute_blender_code",
                       code=RUN("scripts/validation/validate_asset.py", ["--collection", "ASSET_hero_lantern", "--target", "roblox"]))
            await call(s, "07_save", "execute_blender_code", code=(
                f"import sys; sys.path.insert(0, {WS + '/scripts'!r})\n"
                "from lib.scene_utils import save_versioned\n"
                f"print('SAVED', save_versioned({WS + '/projects/models/hero_lantern/live'!r}, 'hero_lantern_live'))"))
            await call(s, "09a_focus", "jump_to_view3d_object_by_name", name="SM_Lantern_Frame")
            await call(s, "09b_viewport", "get_screenshot_of_area_as_image", area_ui_type="VIEW_3D")
            await call(s, "09c_thumb", "render_thumbnail_to_path", output_path=OUT + "/09c_thumbnail.png")
            import glob; blend = sorted(glob.glob(WS + "/projects/models/hero_lantern/live/hero_lantern_live_v*.blend"))[-1]
            await call(s, "10_cli_reopen", "execute_blender_code_for_cli", blend_file=blend,
                       code="import bpy\nresult = {'objects': sorted(o.name for o in bpy.data.objects), 'file': bpy.data.filepath.split('/')[-1]}")
    json.dump(log, open(OUT + "/acceptance_log.json", "w"), indent=2)
asyncio.run(main())
