"""Exact-build symbol validation and durable release/profile artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

from internal.cli import write_json_atomic


def artifact_root() -> Path:
    return Path(os.environ.get("TRINKET_SYMBOL_BACKUP_ROOT",
                               Path.home() / "Library/Developer/Trinket/BuildArtifacts")).expanduser().resolve()


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        value = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def uuids(path: Path) -> set[tuple[str, str]]:
    output = subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(path)], text=True)
    values = {(uuid.upper(), arch) for uuid, arch in
              re.findall(r"UUID: ([0-9A-Fa-f-]{36}) \(([^)]+)\)", output)}
    if not values:
        raise ValueError(f"No Mach-O UUIDs: {path}")
    return values


def symbol_index(roots: list[Path]) -> dict[tuple[str, str], Path]:
    result = {}
    for root in dict.fromkeys(path.resolve() for path in roots if path.exists()):
        bundles = [root] if root.suffix == ".dSYM" else sorted(root.rglob("*.dSYM"))
        for bundle in bundles:
            for dwarf in sorted((bundle / "Contents/Resources/DWARF").glob("*")):
                if dwarf.is_file():
                    for identity in uuids(dwarf):
                        result.setdefault(identity, bundle)
    return result


def app_manifest(app: Path, symbols: Path) -> dict:
    index = symbol_index([symbols])
    bundles = [app, *sorted(path for path in app.rglob("*")
                           if path.suffix in (".framework", ".appex", ".app") and path.is_dir())]
    binaries = []
    for bundle in bundles:
        with (bundle / "Info.plist").open("rb") as stream:
            info = plistlib.load(stream)
        binary = bundle / info["CFBundleExecutable"]
        identities = uuids(binary)
        missing = identities - index.keys()
        if missing:
            raise ValueError(f"Missing matching dSYM for {binary}: {sorted(missing)}")
        binaries.append({"path": str(binary.relative_to(app)), "sha256": digest(binary),
                         "uuids": [list(value) for value in sorted(identities)]})
    with (app / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    return {"bundleIdentifier": info["CFBundleIdentifier"], "version": info["CFBundleShortVersionString"],
            "build": info["CFBundleVersion"], "sdk": info.get("DTSDKName"),
            "xcodeBuild": info.get("DTXcodeBuild"), "binaries": binaries}


def validate_ipa(ipa: Path, manifest: dict) -> None:
    with zipfile.ZipFile(ipa) as archive:
        apps = [name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info.plist", name)]
        if len(apps) != 1:
            raise ValueError("IPA must contain exactly one application")
        info = plistlib.loads(archive.read(apps[0]))
        for key, field in (("CFBundleIdentifier", "bundleIdentifier"), ("CFBundleVersion", "build"),
                           ("CFBundleShortVersionString", "version")):
            if str(info[key]) != str(manifest[field]):
                raise ValueError(f"IPA {key} differs from the retained archive")
        app = apps[0].removesuffix("Info.plist")
        for binary in manifest["binaries"]:
            with tempfile.TemporaryDirectory() as directory:
                target = Path(directory) / "binary"
                with archive.open(app + binary["path"]) as source, target.open("wb") as output:
                    shutil.copyfileobj(source, output)
                if uuids(target) != {tuple(value) for value in binary["uuids"]}:
                    raise ValueError("IPA executable UUIDs differ from the retained archive")
            for uuid, _ in binary["uuids"]:
                entry = f"Symbols/{uuid}.symbols"
                if entry not in archive.namelist() or archive.getinfo(entry).file_size == 0:
                    raise ValueError(f"IPA lacks Apple's symbol payload for {uuid}")
                # Reading to EOF verifies the payload's CRC, not just its filename.
                with archive.open(entry) as stream:
                    while stream.read(1024 * 1024):
                        pass


def tree_hashes(root: Path) -> dict[str, str]:
    return {str(path.relative_to(root)): ("symlink:" + os.readlink(path) if path.is_symlink() else digest(path))
            for path in sorted(root.rglob("*")) if path.is_symlink() or path.is_file()}


def backup_archive(archive: Path, ipa: Path | None, receipt: dict, root: Path | None = None, *, write_receipt: bool = True) -> dict:
    archive = archive.resolve(strict=True)
    apps = list((archive / "Products/Applications").glob("*.app"))
    if len(apps) != 1:
        raise ValueError("Archive must contain exactly one application")
    manifest = app_manifest(apps[0], archive / "dSYMs")
    for field, key in (("bundleIdentifier", "bundle_id"), ("version", "version"), ("build", "build")):
        if key in receipt and str(manifest[field]) != str(receipt[key]):
            raise ValueError(f"Archive {field} does not match deployment receipt")
    if ipa:
        validate_ipa(ipa, manifest)
    files = tree_hashes(archive)
    manifest.update({"schema": 1, "commit": receipt.get("commit"), "xcode": receipt.get("xcode"),
                     "archiveFiles": files, "ipaSHA256": digest(ipa) if ipa else None})
    if ipa and receipt.get("ipa_sha256") and manifest["ipaSHA256"] != receipt["ipa_sha256"]:
        raise ValueError("IPA checksum differs from deployment receipt")
    identity = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    parent = (root or artifact_root()) / "releases"
    parent.mkdir(parents=True, exist_ok=True)
    destination = parent / identity
    if destination.exists():
        stored = json.loads((destination / "symbol-manifest.json").read_text())
        if stored != manifest or tree_hashes(destination / "Trinket.xcarchive") != files:
            raise ValueError(f"Existing symbol backup is damaged; preserve and inspect {destination}")
        if ipa and digest(destination / "Trinket.ipa") != manifest["ipaSHA256"]:
            raise ValueError(f"Existing IPA backup is damaged: {destination}")
    else:
        staging = Path(tempfile.mkdtemp(prefix=".copy-", dir=parent))
        try:
            shutil.copytree(archive, staging / "Trinket.xcarchive", symlinks=True)
            if ipa:
                shutil.copy2(ipa, staging / "Trinket.ipa")
            if tree_hashes(staging / "Trinket.xcarchive") != files or tree_hashes(archive) != files:
                raise ValueError("Archive changed during backup or copy verification failed")
            if ipa and digest(staging / "Trinket.ipa") != manifest["ipaSHA256"]:
                raise ValueError("IPA changed during backup")
            write_json_atomic(staging / "symbol-manifest.json", manifest)
            # Identical concurrent backups can converge without overwriting evidence.
            try:
                staging.rename(destination)
            except FileExistsError:
                return backup_archive(archive, ipa, receipt, root, write_receipt=write_receipt)
        finally:
            if staging.exists():
                shutil.rmtree(staging)
    if write_receipt:
        write_json_atomic(destination / "receipt.json", receipt)
    return {"status": "verified", "path": str(destination), "manifestSHA256": digest(destination / "symbol-manifest.json"),
            "binaries": manifest["binaries"]}


def verified_release(receipt: dict, root: Path | None = None) -> tuple[Path, dict]:
    """Revalidate durable bytes and native identity before retiring working copies."""
    saved = receipt['symbol_artifacts']
    destination = Path(saved['path'])
    releases = (root or artifact_root()) / 'releases'
    if (saved.get('status') != 'verified' or destination.parent != releases
            or destination.is_symlink() or destination.resolve() != destination
            or not destination.is_dir()):
        raise ValueError('Unknown or unsafe authoritative release location')
    manifest_path = destination / 'symbol-manifest.json'
    if manifest_path.is_symlink() or digest(manifest_path) != saved['manifestSHA256']:
        raise ValueError('Authoritative symbol manifest is missing or changed')
    manifest = json.loads(manifest_path.read_text())
    for field, key in (('bundleIdentifier', 'bundle_id'), ('version', 'version'),
                       ('build', 'build'), ('commit', 'commit'), ('xcode', 'xcode')):
        if str(manifest[field]) != str(receipt[key]):
            raise ValueError(f'Authoritative release {field} differs from receipt')
    archive = destination / 'Trinket.xcarchive'
    ipa = destination / 'Trinket.ipa'
    if archive.is_symlink() or ipa.is_symlink() or tree_hashes(archive) != manifest['archiveFiles']:
        raise ValueError('Authoritative archive is missing or damaged')
    actual = app_manifest(archive / 'Products/Applications/Trinket.app', archive / 'dSYMs')
    if any(actual[key] != manifest[key] for key in actual) or actual['binaries'] != saved['binaries']:
        raise ValueError('Authoritative native identity or symbols changed')
    if digest(ipa) != manifest['ipaSHA256'] or manifest['ipaSHA256'] != receipt['ipa_sha256']:
        raise ValueError('Authoritative IPA differs from receipt')
    validate_ipa(ipa, manifest)
    with zipfile.ZipFile(ipa) as zipped:
        if zipped.testzip() is not None:
            raise ValueError('Authoritative IPA contains damaged resources')
    return destination, manifest


def trace_identities(samples: Path) -> set[tuple[str, str]]:
    identities = set()
    for _, element in ET.iterparse(samples, events=("end",)):
        if element.tag == "binary" and element.get("name") == "Trinket" and element.get("UUID"):
            identities.add((element.get("UUID").upper(), element.get("arch")))
        element.clear()
    if not identities:
        raise ValueError("Trace contains no Trinket binary UUID; cannot validate its symbols")
    return identities


def symbolicated_app_frames(samples: Path) -> int:
    binary_ids = set()
    named = 0
    for _, element in ET.iterparse(samples, events=("end",)):
        if element.tag == "binary" and element.get("name") == "Trinket" and element.get("id"):
            binary_ids.add(element.get("id"))
        elif element.tag == "frame":
            binary = element.find("binary")
            if binary is not None and (binary.get("id") in binary_ids or binary.get("ref") in binary_ids):
                name = element.get("name", "")
                named += bool(name and not re.fullmatch(r"0x[0-9a-fA-F]+", name))
            element.clear()
        elif element.tag == "row":
            element.clear()
    if not named:
        raise ValueError("Symbolicated trace contains no named Trinket frames")
    return named


def preserve_profile_symbols(samples: Path, roots: list[Path], destination: Path, metadata: dict) -> dict:
    identities = trace_identities(samples)
    required = identities | {tuple(value) for binary in metadata.get("buildSymbols", {}).get("binaries", [])
                             for value in binary["uuids"]}
    index = symbol_index(roots)
    if required - index.keys():
        raise ValueError("No dSYM matches the recorded Trinket binary. Supply --symbols PATH to its original dSYM, "
                         "or record a fresh --build; the partial capture is retained.")
    destination.mkdir(parents=True)
    copied = []
    for number, bundle in enumerate(dict.fromkeys(index[value] for value in sorted(required))):
        target = destination / str(number) / bundle.name
        shutil.copytree(bundle, target)
        if tree_hashes(target) != tree_hashes(bundle):
            raise ValueError("Profile symbol copy verification failed")
        copied.append(str(target.relative_to(destination)))
    if required - symbol_index([destination]).keys():
        raise ValueError("Preserved profile dSYMs do not match the recorded binary")
    result = {"binaryUUIDs": [list(value) for value in sorted(identities)], "dSYMs": copied,
              "files": tree_hashes(destination), "build": metadata}
    write_json_atomic(destination / "symbol-manifest.json", result)
    return result


def link_backup(archive: Path | None, ipa: Path | None, receipt_path: Path, root: Path, backup_root: Path | None = None) -> dict:
    """Backfill the receipt under the deployment lock after verifying recovery bytes."""
    from internal import output_retention, release_retention
    backup_root = backup_root.expanduser().resolve() if backup_root else None
    state = root / '.DerivedData/testflight'
    if (not receipt_path.is_absolute() or not receipt_path.is_relative_to(state)
            or receipt_path.name != 'receipt.json' or not output_retention.safe_path(receipt_path, root)):
        raise ValueError('Linking requires a safe receipt in the primary TestFlight directory')
    with release_retention.deployment_lock(root, True):
        before = receipt_path.read_bytes()
        receipt = json.loads(before)
        if receipt.get('schema') != 1 or receipt.get('stage') not in ('exported', 'ready'):
            raise ValueError('Only exported or ready receipts can be linked')
        if receipt.get('symbol_artifacts'):
            verified_release(receipt, backup_root)
            return receipt['symbol_artifacts']
        if archive is not None and ipa is not None:
            if Path(receipt['archive']) != archive or Path(receipt['ipa']) != ipa:
                raise ValueError('Archive and IPA must match the original receipt paths')
            saved = backup_archive(archive, ipa, receipt, backup_root, write_receipt=False)
        elif archive is None and ipa is None:
            releases = (backup_root or artifact_root()) / 'releases'
            matches = []
            for manifest_path in releases.glob('*/symbol-manifest.json'):
                if manifest_path.is_symlink() or manifest_path.parent.is_symlink():
                    continue
                try:
                    manifest = json.loads(manifest_path.read_text())
                    keys = (('bundleIdentifier', 'bundle_id'), ('version', 'version'), ('build', 'build'),
                            ('commit', 'commit'), ('xcode', 'xcode'), ('ipaSHA256', 'ipa_sha256'))
                    if all(str(manifest[a]) == str(receipt[b]) for a, b in keys):
                        matches.append({'status': 'verified', 'path': str(manifest_path.parent),
                                        'manifestSHA256': digest(manifest_path), 'binaries': manifest['binaries']})
                except (OSError, ValueError, KeyError, TypeError):
                    raise ValueError(f'Uninspectable release manifest: {manifest_path}')
            if len(matches) != 1:
                raise ValueError(f'Expected one matching release backup, found {len(matches)}')
            saved = matches[0]
        else:
            raise ValueError('Supply both archive and IPA, or neither to find an existing backup')
        linked = dict(receipt, symbol_artifacts=saved)
        verified_release(linked, backup_root)
        backup_receipt = Path(saved['path']) / 'receipt.json'
        if backup_receipt.is_symlink():
            raise ValueError('Backup receipt cannot be a symlink')
        if backup_receipt.exists():
            previous = json.loads(backup_receipt.read_text())
            for key in ('build', 'commit', 'ipa_sha256', 'bundle_id', 'version', 'xcode'):
                if previous.get(key) != receipt.get(key):
                    raise ValueError(f'Backup receipt identity differs: {key}')
        if receipt_path.read_bytes() != before:
            raise ValueError('Receipt changed while linking; original retained')
        write_json_atomic(backup_receipt, linked)
        write_json_atomic(receipt_path, linked)
        return saved


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate and back up an exact release archive and its symbols")
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--ipa", type=Path)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--backup-root", type=Path)
    parser.add_argument("--link", action="store_true", help="verify and link the backup to the deployment receipt")
    args = parser.parse_args()
    try:
        if args.link:
            from internal.cli import ROOT, primary_worktree_root
            result = link_backup(args.archive, args.ipa, args.receipt, primary_worktree_root(ROOT), args.backup_root)
        else:
            if not args.archive:
                raise ValueError("--archive is required unless linking an existing backup")
            result = backup_archive(args.archive, args.ipa, json.loads(args.receipt.read_text()), args.backup_root)
        print(json.dumps(result))
        return 0
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Symbol retention failed: {error}\n")
