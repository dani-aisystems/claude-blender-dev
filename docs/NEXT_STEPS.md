# Next steps (ranked by practical value)

1. **Confirm the Roblox scale with one real import.** Import `exports/hero_lantern/roblox/*.fbx` into Studio next to a character and adjust `presets.py` if needed. With approval, use the existing `Roblox_Studio` MCP to automate the check.
2. **Texture baking.**
   - Add a `scripts/bake/` step: curvature/AO-driven edge wear, baked to `T_<Asset>_{Color,Normal,Roughness,Metalness}` at 512–1024 px.
   - This is what makes "stylized realism" survive export, because engines don't run Blender shader nodes.
3. **LOD + collision generation.** Decimate-based LOD1/LOD2 and `UCX_` convex hulls, with validator rules for them.
4. **Preview rig polish:** an infinite cyclorama backdrop (removes the horizon band), and an optional night/HDRI mode for warm-light assets.
5. **Free disk space**, then consider a VM or a separate macOS user for stronger MCP isolation (Blender Lab's recommendation).
6. **Editor autocomplete:** add `fake-bpy-module` as a dev dependency so VS Code stops flagging `bpy` imports.
7. **When the first film is scheduled:** add Node + Puppeteer for the UI and comp, and numpy/scipy/pedalboard for sound, inside the film's folder (playbook pieces deferred by Q1).
8. **CI:** a GitHub Action running `pytest -m "not blender"` on push. Blender-in-CI is possible later with the Linux tarball.
