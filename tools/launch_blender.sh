#!/usr/bin/env bash
# Launch the Blender GUI with the MCP bridge started deliberately (Workflow A).
#   tools/launch_blender.sh [file.blend]
# - Online access is enabled for THIS session only (--online-mode); the saved preference stays off.
# - The bridge listens on localhost:9876 (add-on preference). Auto-start is off by design.
# - Stop it any time: Edit > Preferences > Add-ons > MCP > Stop, or quit Blender.
set -euo pipefail
BLENDER_APP="${BLENDER_APP:-/Applications/Blender.app}"
PORT="${BLENDER_MCP_PORT:-9876}"

if nc -z localhost "$PORT" 2>/dev/null; then
  echo "Something is already listening on localhost:$PORT (a Blender MCP session is probably open)." >&2
  exit 1
fi

START_EXPR='import bpy
def _blmcp_start():
    try:
        r = bpy.ops.blmcp.server_start()
        print("BLMCP start:", r)
    except Exception as ex:
        print("BLMCP start failed:", ex)
    return None
bpy.app.timers.register(_blmcp_start, first_interval=2.0)'

ARGS=(--online-mode --python-expr "$START_EXPR")
if [[ $# -ge 1 ]]; then
  ARGS=("$(cd "$(dirname "$1")" && pwd)/$(basename "$1")" "${ARGS[@]}")
fi
open -n -a "$BLENDER_APP" --args "${ARGS[@]}"

for _ in $(seq 1 30); do
  if nc -z localhost "$PORT" 2>/dev/null; then
    echo "Blender MCP bridge is listening on localhost:$PORT"
    exit 0
  fi
  sleep 1
done
echo "Bridge not detected after 30 s. In Blender: Edit > Preferences > Add-ons > MCP > Start MCP Bridge Server." >&2
exit 2
