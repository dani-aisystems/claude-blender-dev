# Confirmed decisions

These came from the requirements grilling on 2026-11-03. They are binding until Daniel changes them.

| # | Decision |
|---|---|
| Q1 | Serve both game assets and films. **Game-asset pipeline first.** Include the playbook's film workflow, but defer Puppeteer and synthesized sound until a film needs them. |
| Q2 | Targets: **Roblox (FBX)**, **Web (GLB)**, **Unity/Unreal (FBX presets only, no engine installs)**. |
| Q3 | Claude builds freely and saves versioned files. It **asks first** before overwrites, deletes, writes outside the workspace, downloads, or installs. |
| Q4 | The workspace stays standalone. Exports go to the Roblox project only with approval. A decision draft for that project is kept privately. |
| Q5 | Run on the host, hardened (localhost bind, local-scope MCP, manual start, rules, versioned saves). No VM for now. |
| Q6 | **CC0 assets only** (Poly Haven, ambientCG), fetched after an explicit OK, with the licence logged. No paid or AI-generation APIs. |
| Q7 | Default style: **stylized realism**. |
| Q8 | **EEVEE** for iteration previews. **Cycles (Metal)** for hero stills and finals, rendered in chunks. |
