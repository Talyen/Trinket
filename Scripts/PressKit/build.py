"""Assemble the prelaunch press kit from retained, reviewed Trinket media."""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from package_site import package
from brand import LOGO, MASTER, REPO, US_RELEASE, end_card, feature


def frame(movie, at, target, filters):
    seek = ["-ss", str(at)] if at else []
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", *seek, "-i", movie,
                    "-frames:v", "1", "-vf", filters, target], check=True)
    if not target.is_file() or target.stat().st_size == 0:
        raise ValueError(f"No frame at {at}s in {movie}")


def build(evidence, output, trailers=None):
    channel = evidence / "channel-edits"
    master = channel / f"countess-press-{US_RELEASE.isoformat()}"
    kit = output / "Trinket-Press-Kit"
    # Web and offline editors receive the same curated stills, artwork and copy.
    shutil.copytree(REPO / "Website/press", kit, ignore=shutil.ignore_patterns("video"))
    (kit / "video").mkdir()
    reel = kit / "video/Trinket-feature-reel.mp4"
    if trailers:
        shutil.copyfile(trailers / "Trinket-Press-Feature-Reel.mp4", reel)
    else:
        with tempfile.TemporaryDirectory() as work:
            card = Path(work) / "press.png"
            end_card(card, channel / "apple-download-badge-3x.png",
                     f"{US_RELEASE:%B} {US_RELEASE.day}, {US_RELEASE.year}")
            feature(channel, master.name, card, reel, phone_frame=True)
    shutil.copyfile(channel / "Trinket-Blight-Treant-Creator-Footage.mp4", kit / "video/Trinket-creator-footage.mp4")
    srt = (master / "Trinket-Feature-Reel.en.srt").read_text()
    (kit / "video/Trinket-feature-reel.en.srt").write_text(srt)
    (kit / "video/Trinket-feature-reel.en.vtt").write_text("WEBVTT\n\n"+re.sub(r"(\d\d:\d\d:\d\d),(\d{3})", r"\1.\2", srt))
    frame(kit / "video/Trinket-feature-reel.mp4", 74, kit / "previews/trailer.jpg", "scale=476:960")
    package(kit, MASTER, LOGO, output=output)
    html = (kit / "index.html").read_text()
    landing = re.sub(r'(href|src|poster)="(?!#|https:|mailto:|\.\./)', r'\1="Trinket-Press-Kit/', html)
    (output / "index.html").write_text(landing.replace('href="../Trinket-Press-Kit.zip"', 'href="Trinket-Press-Kit.zip"'))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path, help="Retained LaunchMarketing-Nov17 folder")
    parser.add_argument("output", type=Path, help="Directory for a fresh kit and ZIP")
    parser.add_argument("--branded-trailers", type=Path, help="Reuse the output of Scripts/PressKit/brand.py")
    parser.add_argument("--browser", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        parser.error("Choose a fresh output directory to preserve previous kits.")
    with tempfile.TemporaryDirectory(dir=output.parent) as temporary:
        staged = Path(temporary) / output.name
        build(args.evidence.resolve(), staged, args.branded_trailers)
        staged.rename(output)
