"""Assemble the public press downloads and offline kit in a Pages staging directory."""
from pathlib import Path
import shutil
import sys
import zipfile


def zip_files(target, base, files):
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_STORED) as archive:
        for path in sorted(files):
            archive.write(path, path.relative_to(base))


def package(press, master, preview):
    shutil.copyfile(master, press / "art/trinket-logo.png")
    shutil.copyfile(preview, press / "previews/trinket-logo.png")
    images = [p for folder in ("art", "screenshots") for p in (press / folder).iterdir() if p.is_file()]
    zip_files(press / "Trinket-images.zip", press, images)
    full = press / "Trinket-Press-Kit.zip"
    page = press / "index.html"
    marker = "<!-- full kit download -->"
    html = page.read_text()
    if marker not in html:
        raise ValueError("Prepare downloads in a fresh copy of Website/press")
    files = [p for p in press.rglob("*") if p.is_file() and p != full]
    zip_files(full, press, files)
    page.write_text(html.replace(marker, '<a href="Trinket-Press-Kit.zip" download>Download press kit (.zip)</a>'))


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    package(Path(sys.argv[1]), root / "AssetSources/2d Assets/Game Sources/Branding/Trinket-Ambush.png",
            root / "Trinket/LaunchArtwork/ambush-logo.png")
