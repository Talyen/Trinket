"""Render approved Ambush end cards and off-store films from reviewed iPhone masters."""
import argparse
from datetime import date
import json
from pathlib import Path
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont

US_RELEASE = date(2026, 12, 21)
REPO = Path(__file__).resolve().parents[2]
MASTER = REPO / "AssetSources/2d Assets/Game Sources/Branding/Trinket-Ambush.png"
LOGO = REPO / "Trinket/LaunchArtwork/ambush-logo.png"
REEL = "Trinket-Blood-Countess-Feature-Reel.mp4"
FONTS = Path("/System/Library/Fonts/Supplemental")
INK = "#1c191c"


def centered_art(canvas, path, width, center_y):
    with Image.open(path) as original:
        art = original.convert("RGBA")
        art = art.resize((width, round(width * art.height / art.width)), Image.Resampling.LANCZOS)
    canvas.paste(art, ((canvas.width - width) // 2, round(center_y - art.height / 2)), art)


def end_card(path, badge, release=None):
    card = Image.new("RGB", (1080, 1920), INK)
    centered_art(card, LOGO, 1032, 700)
    draw = ImageDraw.Draw(card)

    def line(words, y, font, size, color):
        draw.text((540, y), words, font=ImageFont.truetype(str(FONTS / font), size),
                  fill=color, anchor="mm")

    if release:
        line("Coming to iOS", 1160, "Arial.ttf", 52, "#dac7ad")
        line(release, 1260, "Georgia.ttf", 82, "#f1c876")
    line("Start playing for free.", 1420 if release else 1220, "Arial Bold.ttf", 65, "#fff1d8")
    line("Unlock the full game with one purchase.", 1514 if release else 1315,
         "Arial.ttf", 45, "#e0d5c8")
    if not release:
        centered_art(card, badge, 385, 1490)
    card.save(path)


def ffmpeg(inputs, graph, maps, output, extra=()):
    subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-n",
                    "-filter_complex_threads", "2", *inputs, "-filter_complex", graph, *maps,
                    "-c:v", "h264_videotoolbox", "-profile:v", "high", "-b:v", "12M",
                    *extra, "-movflags", "+faststart", output], check=True)


def feature(channel, original, card, dest):
    source = channel / original
    edit = json.loads((source / "edit.json").read_text())
    boss, ending = edit["sections"][-2:]
    if boss["id"] != "boss" or ending["id"] != "card" or not boss["raw"]:
        raise ValueError("Expected the reviewed Countess take and final dissolve")
    rate = edit["fps"]
    start = ending["timeline"]
    overlap = ending["dissolve_frames"]
    boss_frame = boss["first"] + start - boss["timeline"]
    # The approved master already has the old dissolve baked in. Take precisely
    # those overlapping fight frames from the phone original, before blending.
    inputs = ["-i", source / REEL, "-ss", str(boss_frame / rate), "-i", channel / boss["file"],
              "-loop", "1", "-framerate", str(rate), "-i", card]
    graph = (
        f"[0:v]fps={rate},trim=end_frame={start},setpts=N/({rate}*TB),setsar=1,format=yuv444p[head];"
        f"[1:v]fps={rate},trim=end_frame={overlap},setpts=N/({rate}*TB),crop=1180:2376:0:150,"
        "scale=-2:1920,pad=1080:1920:(1080-iw)/2:0:color=0x141216,setsar=1,format=yuv444p[fight];"
        f"[2:v]trim=end_frame={ending['count']},setpts=N/({rate}*TB),setsar=1,format=yuv444p[card];"
        f"[fight][card]xfade=transition=fade:duration={overlap/rate}:offset=0[tail];"
        "[head][tail]concat=n=2:v=1:a=0,format=yuv420p[picture]"
    )
    ffmpeg(inputs, graph, ["-map", "[picture]", "-map", "0:a:0", "-map", "0:s?"],
           dest, ["-c:a", "copy", "-c:s", "copy"])


def social(source, card, dest):
    length = json.loads(source.with_suffix(".cues.json").read_text())["duration"]
    graph = ("[0:v]scale=-2:1920,pad=1080:1920:(1080-iw)/2:0:color=0x141216,"
             "setsar=1,fps=60,format=yuv420p[play];"
             "[1:v]trim=end_frame=108,setsar=1,format=yuv420p[card];"
             "[play][card]concat=n=2:v=1:a=0[picture];"
             f"[0:a]atrim=duration={length},apad=pad_dur=1.8[audio]")
    ffmpeg(["-i", source, "-loop", "1", "-framerate", "60", "-i", card], graph,
           ["-map", "[picture]", "-map", "[audio]"], dest, ["-c:a", "aac", "-b:a", "256k"])


def render_trailers(evidence, output):
    channel = evidence / "channel-edits"
    badge = channel / "apple-download-badge-3x.png"
    for label, original, date_copy in (
        ("Press", f"countess-press-{US_RELEASE.isoformat()}", f"{US_RELEASE:%B} {US_RELEASE.day}, {US_RELEASE.year}"),
        ("Launch", "countess-launch-card", None),
    ):
        card = output / f"Trinket-{label}-End-Card.png"
        end_card(card, badge, date_copy)
        feature(channel, original, card, output / f"Trinket-{label}-Feature-Reel.mp4")
    for cue in sorted((evidence / "boss-lyric-trailers").glob("*.cues.json")):
        source = cue.with_suffix("").with_suffix(".mp4")
        social(source, output / "Trinket-Launch-End-Card.png", output / f"{source.stem}-Social.mp4")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("output", type=Path, help="New directory for branded trailers")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error("Choose a fresh output directory.")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as work:
        staged = Path(work) / "Trailers"
        staged.mkdir()
        render_trailers(args.evidence.resolve(), staged)
        staged.rename(output)
