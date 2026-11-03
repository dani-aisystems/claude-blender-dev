# Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `error: path segment contains separator ':'` | `uv run` can't handle `:` in the folder path | Use `tools/py` (the venv's Python) instead of `uv run python` |
| `mcp__blender__*` tools missing | The MCP server loads only at session start | Run `claude mcp get blender`, then restart Claude Code |
| MCP tools error "connection refused" | The bridge isn't running (auto-start is off by design) | Run `tools/launch_blender.sh`, or in Blender: Preferences → Add-ons → MCP → Start |
| "Online access must be enabled" | The add-on requires Blender's online access setting | The launcher passes `--online-mode` for that session. Don't enable it permanently unless you want to |
| Launcher: "already listening on 9876" | Another Blender (or the community MCP) is using the port | Close the other Blender. Don't install `mcp-for-blender`, which uses the same port |
| Colour looks washed out or pink | AgX tone mapping, too much emission, a light inside the object, or a red-biased SSS radius | Measure with `pixel_check.py`. Lower emission, use a deeper hue, use light linking to exclude the object, set subsurface to 0 |
| White blocks in glossy reflections | Lights are visible to glossy rays | `obj.visible_glossy = False` (`hide_from_glossy`) |
| Light trapped behind glass (EEVEE) | Alpha-blended material casts opaque shadows | `material.use_transparent_shadow = True` (done automatically for alpha < 1) |
| Objects land in the wrong place after parenting | Stale world matrices | Call `bpy.context.view_layer.update()` before parenting maths |
| First Cycles render takes about 75 s | Metal kernels compile on the first run | Wait once. Later runs take about 1.6 s/frame at 960×540 with 32 samples |
| Blank or corrupt frames after a long render | Memory pressure or interruption | Run `scan_frames.py`, then re-render only the printed range with `--force` |
| Export refused / "Refusing to overwrite" | By design | Exports auto-version; for a named version, pick a new `--version` |
| Roblox import is the wrong size | The metres-to-studs convention is unconfirmed | Adjust `global_scale` in `scripts/exports/presets.py` (`roblox`) and re-export |
| ffmpeg "No such filter" | Minimal ffmpeg build | `brew install ffmpeg` (full build) |
| Import errors about `bpy` in VS Code | The editor can't see Blender's bundled Python | Harmless. Optionally add `fake-bpy-module` as a dev dependency for autocomplete |
