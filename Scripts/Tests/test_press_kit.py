from html.parser import HTMLParser
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

from script_test_support import ROOT

sys.path.insert(0, str(ROOT / "Scripts/PressKit"))
from package_site import package


class PressLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.files = set()

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ("href", "src", "poster") and not value.startswith(("#", "https:", "mailto:")):
                self.files.add(value.partition("#")[0])


class PublicPressKitTests(unittest.TestCase):
    def test_offline_and_hosted_downloads_resolve(self):
        source = ROOT / "Website/press"
        with tempfile.TemporaryDirectory() as temp:
            press = Path(temp)
            for path in source.rglob("*"):
                relative = path.relative_to(source)
                if path.is_dir():
                    (press / relative).mkdir(exist_ok=True)
                elif path.name == "index.html":
                    (press / relative).write_bytes(path.read_bytes())
                else:
                    (press / relative).touch()
            logo = press.parent / (press.name + ".png")
            self.addCleanup(logo.unlink, missing_ok=True)
            logo.write_bytes(b"test logo")
            package(press, logo, logo)
            links = PressLinks()
            links.feed((press / "index.html").read_text())
            self.assertIn("Trinket-Press-Kit.zip", links.files)
            self.assertTrue(all((press / name).is_file() for name in links.files))
            with zipfile.ZipFile(press / "Trinket-Press-Kit.zip") as kit:
                offline = PressLinks()
                offline.feed(kit.read("index.html").decode())
                self.assertTrue(offline.files <= set(kit.namelist()))
                self.assertIn("Trinket-images.zip", links.files)
                self.assertNotIn("Trinket-images.zip", kit.namelist())
                with zipfile.ZipFile(press / "Trinket-images.zip") as images:
                    self.assertIn("screenshots/Captions.txt", images.namelist())
                    self.assertTrue(set(images.namelist()) <= set(kit.namelist()))
                self.assertEqual(kit.read("art/trinket-logo.png"), b"test logo")
