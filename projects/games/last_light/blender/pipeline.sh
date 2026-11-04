#!/usr/bin/env bash
# THE LAST LIGHT asset pipeline: build -> validate (gltf) -> export -> reimport check -> sync into Godot.
#   projects/games/last_light/blender/pipeline.sh [collections...]   (default: watch_room lighthouse)
# Stops on any validation FAIL or failed reimport. Outputs: versioned .blend, exports/last_light/gltf/*.glb,
# renders/last_light/validation_*.json, godot/assets/models/*.glb (generated; DECISIONS Q10).
set -euo pipefail
WS="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$WS"
COLS=("${@:-watch_room lighthouse}")
[[ $# -eq 0 ]] && COLS=(watch_room lighthouse)
tools/py projects/games/last_light/blender/textures.py >/dev/null
# story documents + the in-world photo/logbook textures they feed (T_LL_Photo, T_LL_Logbook). The raw photo
# render (photo_render.py, Cycles, ~10 min) is NOT rerun here: it only changes when the photo scene changes.
tools/py projects/games/last_light/blender/documents.py >/dev/null
OUT=$(tools/bl -P projects/games/last_light/blender/build.py -- --new --save 2>&1 | grep BUILD_RESULT)
echo "$OUT" | cut -c1-220
BLEND=$(echo "$OUT" | sed -E 's/.*"saved": "([^"]+)".*/\1/')
V=$(basename "$BLEND" .blend | sed -E 's/.*_(v[0-9]+)/\1/')
for c in "${COLS[@]}"; do
  J="renders/last_light/validation_${c}_${V}.json"
  R=$(tools/bl "$BLEND" -P scripts/validation/validate_asset.py -- --collection "ASSET_$c" --target gltf --json "$J" 2>&1 | grep VALIDATION_RESULT)
  FAILS=$(echo "$R" | python3 -c "import sys,json; print(json.loads(sys.stdin.read().split(' ',1)[1])['counts']['FAIL'])")
  echo "validate $c: FAIL=$FAILS"
  [[ "$FAILS" == "0" ]] || { echo "validation failed for $c"; exit 1; }
  tools/bl "$BLEND" -P scripts/exports/export_asset.py -- --collection "ASSET_$c" --name "$c" --targets gltf --out exports/last_light >/dev/null 2>&1
  F=$(ls -t exports/last_light/gltf/${c}_v*.glb | head -1)
  OK=$(tools/bl -P scripts/validation/reimport_check.py -- --file "$F" --source-json "$J" --expected-scale 1 2>&1 | grep -oE '"ok": (true|false)')
  echo "reimport $c ($F): $OK"
  [[ "$OK" == '"ok": true' ]] || { echo "reimport failed for $c"; exit 1; }
done
tools/py projects/games/last_light/blender/sync_assets.py "${COLS[@]}" | head -"${#COLS[@]}"
tools/godot --headless --path projects/games/last_light/godot --import >/dev/null 2>&1 || true
echo "PIPELINE_OK $BLEND"
