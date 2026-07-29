# Documentation Staleness Audit

**Goal:** Fix misleading docs — stale paths, broken links, wrong versions, outdated claims.

## Intent

Find P1/P2 contradictions between docs and their sources of truth. A pass with no contradiction is valid. Planning and phasing: [README.md](README.md).

## Hard stops

- Do not hand-edit `CHANGELOG.md` (owned by `./Scripts/release.sh`).
- Do not treat dated “Last execution” / Done tables inside audits as source of truth — **delete** those tracker sections when found.
- Do not rewrite design prose for style-only preferences or turn this into a repo-wide docs rewrite.

## Severity

Shared scale: [README.md](README.md).

| Sev | Criteria |
|-----|----------|
| P1 | Wrong API/path, broken link, stale architecture assumption, wrong version constraint |
| P2 | Wrong count, “in progress” for finished work, inconsistent terminology |
| P3 | Typo, formatting, missing code-fence language |

## Domain rules

**Sources of truth:** `project.yml` (`deploymentTarget`, `SWIFT_VERSION`, marketing version); `Packages/*/Package.swift` `swift-tools-version`; smoke class inventory under `TrinketUITests/Smoke/`; canonical names from [Architecture.md](../Platform/Architecture.md).

**Links:** internal `.md` links resolve **relative to the source file**; heading anchors must still exist. Recheck edited links and factual claims against their listed source of truth. External URLs: check only when changing that source and network is available — do not fail solely on an unavailable endpoint.

**Audit hygiene:** if an audit contains embedded run logs, Done tables, or “Last execution” trackers, remove them and restore procedural guide shape per [README.md](README.md). Run history belongs only in `Docs/Audits/Proposals.md`; prune its entries whose evidence pointers no longer resolve. Cross-audit routing consistency is in scope: an audit guide’s routing pointers must agree with the README owner and confusable-pairs tables.

## Evidence bar

A P1/P2 finding is a confirmed mismatch between a doc claim and a named source of truth (path, API, version, architecture assumption, or broken relative link/anchor). P3 issues are optional cleanup only when already touching that file.
