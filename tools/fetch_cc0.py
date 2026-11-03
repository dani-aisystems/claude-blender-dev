"""Fetch a CC0 asset from Poly Haven or ambientCG into assets/ and log its licence.

POLICY (CLAUDE.md): Claude must get Daniel's OK before running this with --confirm.
Without --confirm it only queries the source's public API and prints what it WOULD download.

  tools/py tools/fetch_cc0.py polyhaven hdri  <asset_id> --res 1k [--confirm]
  tools/py tools/fetch_cc0.py polyhaven texture <asset_id> --res 1k [--confirm]
  tools/py tools/fetch_cc0.py ambientcg texture <AssetId> --res 1K-JPG [--confirm]
"""

import argparse
import datetime as dt
import io
import json
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

WS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WS / "scripts"))
from lib.safe_paths import ensure_allowed  # noqa: E402

UA = "BlenderDev-workspace/1.0 (personal, non-commercial asset fetch)"
LICENSES = WS / "assets" / "ASSET_LICENSES.md"
SAFE_ID = re.compile(r"^[A-Za-z0-9_\-]{2,80}$")


def get(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    return data if binary else json.loads(data)


def polyhaven_plan(kind, asset_id, res):
    files = get(f"https://api.polyhaven.com/files/{asset_id}")
    plan = []
    if kind == "hdri":
        entry = files["hdri"][res]
        fmt = "hdr" if "hdr" in entry else next(iter(entry))
        plan.append((entry[fmt]["url"], WS / "assets" / "hdri" / f"{asset_id}_{res}.{fmt}"))
    else:
        for map_name, by_res in files.items():
            if map_name in ("blend", "gltf", "mtlx") or res not in by_res:
                continue
            entry = by_res[res]
            fmt = "png" if "png" in entry else ("jpg" if "jpg" in entry else next(iter(entry)))
            if "url" not in entry[fmt]:
                continue
            plan.append((entry[fmt]["url"], WS / "assets" / "textures" / asset_id / f"{asset_id}_{map_name}_{res}.{fmt}"))
    return plan, f"https://polyhaven.com/a/{asset_id}"


def ambientcg_plan(asset_id, res):
    data = get(f"https://ambientcg.com/api/v2/full_json?id={asset_id}&include=downloadData")
    asset = data["foundAssets"][0]
    downloads = asset["downloadFolders"]["default"]["downloadFiletypeCategories"]["zip"]["downloads"]
    d = next(x for x in downloads if x["attribute"] == res)
    return [(d["downloadLink"], WS / "assets" / "textures" / asset_id / d["fileName"])], \
        f"https://ambientcg.com/view?id={asset_id}"


def safe_extract(zip_bytes, dest: Path):
    dest = ensure_allowed(dest)
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as z:
        for m in z.infolist():
            target = (dest / m.filename).resolve()
            if dest not in target.parents and target != dest:
                raise RuntimeError(f"zip-slip blocked: {m.filename}")
        z.extractall(dest)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("source", choices=["polyhaven", "ambientcg"])
    ap.add_argument("kind", choices=["hdri", "texture"])
    ap.add_argument("asset_id")
    ap.add_argument("--res", default="1k")
    ap.add_argument("--confirm", action="store_true", help="actually download (needs Daniel's OK)")
    a = ap.parse_args(argv)
    if not SAFE_ID.match(a.asset_id):
        raise SystemExit("invalid asset id")
    if a.source == "polyhaven":
        plan, page = polyhaven_plan(a.kind, a.asset_id, a.res)
    else:
        plan, page = ambientcg_plan(a.asset_id, a.res)
    for url, path in plan:
        print(f"{'DOWNLOAD' if a.confirm else 'WOULD DOWNLOAD'} {url} -> {path.relative_to(WS)}")
    if not a.confirm:
        print("Dry run only. Re-run with --confirm after approval.")
        return 0
    for url, path in plan:
        path = ensure_allowed(path)
        if path.exists():
            print(f"exists, skipping: {path.relative_to(WS)}")
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        data = get(url, binary=True)
        if path.suffix == ".zip":
            safe_extract(data, path.parent)
        else:
            path.write_bytes(data)
    LICENSES.parent.mkdir(parents=True, exist_ok=True)
    if not LICENSES.exists():
        LICENSES.write_text("# Asset licences\n\n| Date | Asset | Source | Licence | Local path |\n|---|---|---|---|---|\n")
    with LICENSES.open("a") as f:
        f.write(f"| {dt.date.today()} | {a.asset_id} ({a.kind}, {a.res}) | {page} | CC0 1.0 | "
                f"{plan[0][1].parent.relative_to(WS)} |\n")
    print("Logged licence in assets/ASSET_LICENSES.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
