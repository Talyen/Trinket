# Trinket asset sources

This directory contains Trinket's selected artwork, music, sound effects, Icon
Composer package, and preserved launch-animation source sheets. Masters are
ordinary tracked files, independent copies of their original library files.
Trinket never discovers or imports updates from an external asset library.

Manifest `source_path` values resolve relative to this directory. The existing
`2d Assets/Game Sources/` and `Sounds/Game Sources/` hierarchy retains source
identity without changing manifest selections. Historical paths in preserved
animation prompts describe their original references, not pipeline dependencies.

To adopt an asset, copy its master here, select it in the appropriate manifest,
and run `./Scripts/prepare-assets.sh` (or select `--kind art`, `music`, `sfx`, or
`app-icon`). Review and commit the master, manifest, and prepared outputs together.
Preparation and checks use only this checkout; `ASSET_LIBRARY_ROOT` is ignored.
Missing sources and paths or symlinks escaping this directory are rejected.

The app bundles prepared files under `Trinket/`, not these masters. Sparse build
jobs can omit this directory and validate committed outputs without regenerating
media. Full asset preparation and source-freshness checks require these files.
The [media pipeline](../Docs/AgentContext/content-and-manifests.md#media-assets)
owns preparation, integrity checks, and explicit repair commands.
