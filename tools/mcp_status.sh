#!/usr/bin/env bash
# Report Blender MCP health: registration, bridge port, and who is listening on it.
PORT="${BLENDER_MCP_PORT:-9876}"
cd "$(dirname "$0")/.." || exit 1
echo "== claude mcp get blender"; claude mcp get blender 2>&1 | sed -n '1,4p'
echo "== bridge port $PORT"
if nc -z localhost "$PORT" 2>/dev/null; then
  echo "listening"; lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | tail -n +2
else
  echo "not listening (run tools/launch_blender.sh)"
fi
