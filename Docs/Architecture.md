# Architecture

High-level structure for Trinket and the planned Swift package migration.

## Current layout (monolithic app target)

```text
Trinket/
  App/              Shell, environment, tab routing
  Features/         SwiftUI product surfaces (Play, Collection, Battle UI, …)
  Battle/           BattleRun, ActiveBattleConfiguration, victory UI wiring
  State/            Player*Store coordination + Persistence/
  Models/           Domain types
  Content/          Journey roster/enemies/chapters + homestead (app-owned)
  Generated/        Art/music codegen output (do not edit)
  Shared/           Reusable SwiftUI
  DesignSystem/     TrinketDesign
  Audio/            Music director
```

Manifests and pipelines live outside the app folder:

- `ContentManifest/*.tsv` → `Scripts/content_codegen.py` → `Packages/TrinketContent/Sources/TrinketContent/Generated/`
- `ArtManifest/curated-assets.tsv` → `Scripts/prepare-art-assets.sh` → `Trinket/Generated/ArtCatalog.generated.swift`
- `MusicManifest/music.tsv` → `Scripts/prepare-music-assets.sh`

## Generate workflow

**Single entry point:** `./Scripts/generate.sh`

1. Validate `ContentManifest` TSV files
2. Regenerate content catalogs and ability shorthand
3. Optionally prepare art/music (`--assets`)
4. Run XcodeGen

**Drift check:** `./Scripts/assert-generated-output.sh` (CI runs this after `generate.sh`).

After editing `ContentManifest/` or custom ability catalog files under `Packages/TrinketContent/Sources/TrinketContent/Content/`:

```sh
./Scripts/generate.sh
git add Packages/TrinketContent/Sources/TrinketContent/Generated/
```

After editing art or music manifests:

```sh
./Scripts/generate.sh --assets
```

## Dependency rules (today)

| Layer | May import | Must not import |
|-------|------------|-----------------|
| `Battle/` | `Models/`, `Content/` | `Features/`, SwiftUI |
| `Features/` | `Battle/`, `State/`, `Shared/`, `DesignSystem/` | — |
| `State/` | `Models/`, `Content/`, `Persistence/` | feature views |
| `Models/` | Foundation only | `State/`, `Features/` |

## Target module graph (in progress)

Local Swift packages under `Packages/`:

```text
TrinketCore          Shared domain types
  ↑
TrinketContent       Catalogs + Generated/
  ↑
BattleEngine         Trinket/Battle/
  ↑
TrinketPersistence   Save file, migration, CloudKit sync
  ↑
Trinket app          Features, State stores, App shell
```

Migration phases:

1. **Phase 0** — codegen orchestration + CI drift check (done)
2. **Phase 1** — `TrinketCore` package with leaf types: effects, enums, `PrimaryStats` (done)
3. **Phase 2** — `TrinketContent` package (done)
4. **Phase 3** — `BattleEngine` package (done)
5. **Phase 4** — `TrinketPersistence` package
6. **Phase 5** — thin app target, optional `TrinketDesignSystem` package

## Tech stack

- iOS 26.0, Swift 6.0, SwiftUI shell
- XCTest unit + XCUITest UI (tiered via `.xctestplan` files)
- XcodeGen (`project.yml`), SwiftLint, SwiftFormat
- No third-party Swift dependencies today
- Battle presentation is SwiftUI; SpriteKit is not in use yet
