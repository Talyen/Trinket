# Documentation Staleness Audit

**Goal:** Fix misleading docs — stale paths, broken links, wrong versions, outdated claims.

## Intent

Discover markdown mechanically (do not trust a hardcoded count), but do not load it wholesale. Use capped probes, open only candidate files and nearby source-of-truth lines, and fix Critical/Moderate drift in one coherent area. A pass with no contradiction is valid.

## Hard stops

- Do not hand-edit `CHANGELOG.md` (owned by `./Scripts/release.sh`).
- Do not treat dated “Last execution” / Done tables inside audits as source of truth — **delete** those tracker sections when found.
- Do not rewrite design prose for style-only preferences or turn this into a repo-wide docs rewrite.

## Severity

| Level | Criteria |
|-------|----------|
| Critical | Wrong API/path, broken link, stale architecture assumption, wrong version constraint |
| Moderate | Wrong count, “in progress” for finished work, inconsistent terminology |
| Minor | Typo, formatting, missing code-fence language |

## Domain rules

**Sources of truth:** `project.yml` (`deploymentTarget`, `SWIFT_VERSION`, marketing version); `Packages/*/Package.swift` `swift-tools-version`; smoke class count via `ls TrinketUITests/Smoke/Smoke*.swift`; canonical names from [Architecture.md](../Platform/Architecture.md).

**Links:** internal `.md` links resolve **relative to the source file**; heading anchors must still exist. Recheck edited links and factual claims against their listed source of truth. External URLs: check only when changing that source and network is available — do not fail solely on an unavailable endpoint.

**Audit hygiene:** if an audit contains embedded run logs, Done tables, or “Last execution” trackers, remove them and restore procedural guide shape per [README.md](README.md).

## Probe hints

Inventory paths without printing full contents (skip Generated / DerivedData / tools / Raw Assets). Rank broken-path/link/version and tracker-residue candidates, inspect only the strongest few, and stop when the selected doc area is clean.
