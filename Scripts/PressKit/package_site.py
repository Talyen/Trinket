"""Assemble the public press downloads and offline kit in a staging directory."""
from pathlib import Path
import shutil
import sys
import zipfile


def zip_files(target, base, files):
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_STORED) as archive:
        for path in sorted(files):
            archive.write(path, path.relative_to(base))


def package(press, master, preview, *, output=None):
    """Pages serves the archives together. The local builder keeps the full ZIP one level up."""
    page = press / "index.html"
    html = page.read_text()
    full_marker = "<!-- full kit download -->"
    image_marker = "<!-- image bundle link -->"
    if any(html.count(marker) != 1 for marker in (full_marker, image_marker)):
        raise ValueError("Prepare downloads in a fresh copy of Website/press")

    shutil.copyfile(master, press / "art/trinket-logo.png")
    shutil.copyfile(preview, press / "previews/trinket-logo.png")
    images = [p for folder in ("art", "screenshots") for p in (press / folder).iterdir() if p.is_file()]
    image_zip = press / "Trinket-images.zip"
    zip_files(image_zip, press, images)

    base = output or press
    full = base / "Trinket-Press-Kit.zip"
    full_url = "../" + full.name if output else full.name
    files = [p for p in press.rglob("*") if p.is_file() and p not in (full, image_zip, page)]
    with zipfile.ZipFile(full, "w", compression=zipfile.ZIP_STORED) as archive:
        for path in sorted(files):
            archive.write(path, path.relative_to(base))
        archive.writestr(str(page.relative_to(base)), html.replace(full_marker, "").replace(image_marker, ""))

    image_link = f'<a href="{image_zip.name}" download>Download all images (.zip, {image_zip.stat().st_size / 1e6:.0f} MB)</a>'
    full_link = f'<a href="{full_url}" download>Download press kit (.zip, {full.stat().st_size / 1e6:.0f} MB)</a>'
    page.write_text(html.replace(full_marker, full_link).replace(image_marker, image_link))


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    package(Path(sys.argv[1]), root / "AssetSources/2d Assets/Game Sources/Branding/Trinket-Ambush.png",
            root / "Trinket/LaunchArtwork/ambush-logo.png")
