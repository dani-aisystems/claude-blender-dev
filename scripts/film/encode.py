"""Encode a PNG frame sequence (+ optional audio) to MP4 with the playbook's ffmpeg settings (Step 7).

  tools/py scripts/film/encode.py renders/x/full -o exports/x/film_v001.mp4 [--audio build/sound.wav] [--fps 30] [--no-vignette]
Refuses to overwrite the output. Prints ENCODE_RESULT with ffprobe stream info.
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.safe_paths import no_overwrite  # noqa: E402


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("frames_dir")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--audio", default="")
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--prefix", default="f_")
    ap.add_argument("--start", type=int, default=1, help="first frame number")
    ap.add_argument("--crf", type=int, default=17)
    ap.add_argument("--no-vignette", action="store_true")
    a = ap.parse_args(argv)
    if not shutil.which("ffmpeg"):
        raise SystemExit("ffmpeg not found (brew install ffmpeg)")
    out = no_overwrite(a.out)
    pattern = str(Path(a.frames_dir) / f"{a.prefix}%04d.png")
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-framerate", str(a.fps),
           "-start_number", str(a.start), "-i", pattern]
    if a.audio:
        cmd += ["-i", a.audio]
    if not a.no_vignette:
        cmd += ["-vf", "vignette=angle=PI/6"]
    cmd += ["-c:v", "libx264", "-profile:v", "high", "-crf", str(a.crf), "-pix_fmt", "yuv420p"]
    if a.audio:
        cmd += ["-c:a", "aac", "-b:a", "320k", "-shortest"]
    cmd += ["-movflags", "+faststart", str(out)]
    subprocess.run(cmd, check=True)
    probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
                            "stream=codec_type,codec_name,width,height,r_frame_rate,nb_frames:format=duration,size",
                            "-of", "json", str(out)], capture_output=True, text=True, check=True)
    print("ENCODE_RESULT " + json.dumps({"out": str(out), "ffprobe": json.loads(probe.stdout)}))


if __name__ == "__main__":
    sys.exit(main())
