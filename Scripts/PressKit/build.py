"""Assemble the prelaunch press kit from retained, reviewed Trinket media."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import zipfile
from datetime import date
from html import escape
from pathlib import Path

US_RELEASE = date(2026, 12, 21)

PITCH = ("Pair a hero with a companion and build the hand they take into battle "
         "in this solo-developed fantasy card RPG for iPhone and iPad.")
DESCRIPTION = [
    "A Wizard and a Frost Whelp head into Sanguine Court. The Wizard brings Ray of Frost. "
    "The Blood Countess brings a song of her own. In Trinket!, the cards you take into a turn-based "
    "fight come from the hero and companion you pair up and the abilities you choose for them.",
    "Recruit a Bear and its Sunder can cut an enemy’s Block in half before it hits. Between fights, "
    "tend the Herb Garden, compare the rewards on the Contracts board, or send a party on a Desert Voyage. "
    "The same roster can tackle the Campaign, climb boss Spires and explore the Labyrinth.",
]
FACTS = [
    ("Developer", "Ryan McIntire, solo indie developer"),
    ("Release", f"{US_RELEASE:%B} {US_RELEASE.day}, {US_RELEASE.year} · United States"),
    ("Platform", "iPhone and iPad · iOS / iPadOS 18 or later"),
    ("Genre", "Single-player fantasy RPG with turn-based card combat"),
    ("Price", "First three Campaign chapters free. One permanent Full Game purchase, US$4.99."),
    ("Free play", "Also includes unlimited Contracts, three Labyrinth floors, ten floors of every Spire "
                  "and Voyages in the Forest, Dungeon and Desert."),
    ("Offline", "Play offline without an account. Optional iCloud save sync."),
]
STILLS = {
    "146": ("knight-bear", "Knight and Bear face the Mud Elemental"),
    "08": ("ranger", "The Ranger hero"),
    "105": ("fox", "Inspecting the Fox companion"),
    "88": ("explore", "Illustrated destinations on the Explore screen"),
    "139": ("blackfletch", "Blackfletch unique equipment"),
}
ART = [
    ("trinket-key-art.png", "Landscape key art", "1920 × 1080 PNG", ""),
    ("trinket-icon.jpg", "Ranger and Wolf icon artwork", "2048 × 2048 JPG", ""),
    ("trinket-wordmark-light.png", "Light wordmark for dark backgrounds", "Transparent PNG", ""),
    ("trinket-wordmark-dark.png", "Dark wordmark for light backgrounds", "Transparent PNG", "light"),
]


def frame(movie, at, target, filters):
    seek = ["-ss", str(at)] if at else []
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", *seek, "-i", movie,
                    "-frames:v", "1", "-vf", filters, target], check=True)
    if not target.is_file() or target.stat().st_size == 0:
        raise ValueError(f"No frame at {at}s in {movie}")


def artwork(kit, browser):
    art = kit / "art"
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "art.html"
        def render(markup, name, w, h):
            page.write_text('<meta charset="utf-8"><style>*{box-sizing:border-box}body{margin:0}'
                            'b{font-family:Baskerville,Georgia,serif;font-weight:400}</style>' + markup)
            subprocess.run([browser, "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                            "--allow-file-access-from-files", "--run-all-compositor-stages-before-draw",
                            "--default-background-color=00000000", "--user-data-dir="+tmp+"/profile",
                            f"--window-size={w},{h}", "--screenshot="+str(art/name), page.as_uri()],
                           check=True, capture_output=True)
        for style, color in (("light", "#fff2d6"), ("dark", "#242023")):
            render(f'<b style="display:grid;place-items:center;height:270px;font-size:260px;'
                   f'line-height:1;color:{color}">Trinket!</b>', f"trinket-wordmark-{style}.png", 950, 270)
        src = (art / "trinket-icon.jpg").as_uri()
        render('<style>body{background:radial-gradient(ellipse at 62% 44%,#534235,#272323 44%,#17181a 85%)}'
               'img{position:absolute;right:0;top:0;height:1080px;mask-image:linear-gradient(90deg,transparent,black 30%)}'
               'b{position:absolute;left:95px;top:380px;font-size:255px;color:#fff2d6}</style>'
               f'<img src="{src}"><b>Trinket!</b>', "trinket-key-art.png", 1920, 1080)


def zip_files(target, base, files):
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_STORED) as archive:
        for path in sorted(files):
            archive.write(path, path.relative_to(base))


def build(evidence, output, browser):
    channel = evidence / "channel-edits"
    master = channel / f"countess-press-{US_RELEASE.isoformat()}"
    kit = output / "Trinket-Press-Kit"
    kit.mkdir(parents=True, exist_ok=False)
    for folder in ("video", "screenshots", "art", "previews"):
        (kit / folder).mkdir()
    shutil.copyfile(master / "Trinket-Blood-Countess-Feature-Reel.mp4", kit / "video/Trinket-feature-reel.mp4")
    shutil.copyfile(channel / "Trinket-Blight-Treant-Creator-Footage.mp4", kit / "video/Trinket-creator-footage.mp4")
    srt = (master / "Trinket-Feature-Reel.en.srt").read_text()
    (kit / "video/Trinket-feature-reel.en.srt").write_text(srt)
    (kit / "video/Trinket-feature-reel.en.vtt").write_text("WEBVTT\n\n"+re.sub(r"(\d\d:\d\d:\d\d),(\d{3})", r"\1.\2", srt))
    frame(kit / "video/Trinket-feature-reel.mp4", 74, kit / "previews/trailer.jpg", "scale=450:800")
    shutil.copyfile(evidence / "press-kit/trinket-app-icon.jpg", kit / "art/trinket-icon.jpg")
    artwork(kit, browser)

    shots = []
    manifest = json.loads((evidence / "asset-provenance.json").read_text())["screenshots"]
    with zipfile.ZipFile(evidence / "press-kit-stills.zip") as originals:
        for item in manifest:
            name, caption = STILLS[item["id"]]
            data = originals.read(item["file"])
            if hashlib.sha256(data).hexdigest() != item["sha256"]:
                raise ValueError("Screenshot differs from reviewed original: "+name)
            target = kit / "screenshots" / (name+Path(item["file"]).suffix)
            target.write_bytes(data)
            shots.append((target, caption))
    for name, caption, take, t in [
        ("blood-countess", "Wizard and Frost Whelp battle the singing Blood Countess", "countess-ending/long-take", 82),
        ("herb-garden", "The Herb Garden at the Homestead", "countess-feature-reel/take-02", 24),
    ]:
        target = kit / "screenshots" / (name+".png")
        frame(channel / take / "continuous.mp4", t, target, "crop=1180:2376:0:150")
        shots.append((target, caption))
    order = ["blood-countess", "knight-bear", "herb-garden", "explore", "ranger", "fox", "blackfletch"]
    shots.sort(key=lambda s: order.index(s[0].stem))
    figures = []
    for path, caption in shots:
        thumb = kit / "previews" / (path.stem+".jpg")
        frame(path, 0, thumb, "scale=-2:560")
        figures.append(f'<figure><a href="screenshots/{path.name}"><img src="previews/{thumb.name}" '
                       f'alt="{escape(caption)}" loading="lazy"></a><figcaption>{escape(caption)}</figcaption></figure>')
    def art_link(asset):
        name, title, kind, style = asset
        return (f'<figure><a href="art/{name}" download><img class="{style}" src="art/{name}" alt="{title}">'
                f'{title}</a><figcaption>{kind}</figcaption></figure>')
    markup = (Path(__file__).with_name("index.html")).read_text()
    parts = {"pitch": PITCH, "facts": "".join(f"<div><dt>{k}</dt><dd>{v}</dd></div>" for k, v in FACTS),
             "description": "".join(f"<p>{escape(p)}</p>" for p in DESCRIPTION),
             "screenshots": "\n".join(figures), "art": "\n".join(map(art_link, ART))}
    for key, value in parts.items():
        markup = markup.replace("{{"+key+"}}", value)
    (kit / "index.html").write_text(markup.replace("{{bundle_link}}", ""))
    # The distributable ZIP opens offline. Its companion landing page also links to the whole ZIP.
    landing = re.sub(r'(href|src|poster)="(?!#|https:|mailto:)', r'\1="Trinket-Press-Kit/', markup)
    download = '<a href="Trinket-Press-Kit.zip" download>Download press kit (.zip)</a>'
    (output / "index.html").write_text(landing.replace("{{bundle_link}}", download))
    (kit / "Trinket-fact-sheet.txt").write_text("\n\n".join([
        "Trinket! | Press fact sheet", PITCH, *DESCRIPTION,
        "\n".join(f"{key}: {value}" for key, value in FACTS), "Press & review access: Ryan McIntire · rymcintire@gmail.com",
        "Support: https://talyen.github.io/Trinket/", "Suggested asset credit: Trinket! / Ryan McIntire"
    ])+"\n")
    (kit / "screenshots/Captions.txt").write_text("\n".join(f"{p.name} — {c}" for p,c in shots)+"\n")
    zip_files(kit / "Trinket-images.zip", kit, [p for sub in ("screenshots","art") for p in (kit/sub).iterdir()])
    zip_files(output / "Trinket-Press-Kit.zip", output, (p for p in kit.rglob("*") if p.is_file()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path, help="Retained LaunchMarketing-Nov17 folder")
    parser.add_argument("output", type=Path, help="Directory for a fresh kit and ZIP")
    parser.add_argument("--browser", required=True, type=Path, help="Chromium executable for rendering wordmarks and key art")
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        parser.error("Choose a fresh output directory to preserve previous kits.")
    with tempfile.TemporaryDirectory(dir=output.parent) as temporary:
        staged = Path(temporary) / output.name
        build(args.evidence.resolve(), staged, args.browser.resolve())
        staged.rename(output)
