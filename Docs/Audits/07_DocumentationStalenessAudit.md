# 07. Documentation Staleness Audit

**Goal:** Fix documentation that can mislead execution or maintenance — stale paths, broken links, wrong versions, outdated claims, incomplete required workflows, and drifting duplicated policy.

## Intent

Find P1/P2 contradictions, omissions, and drift between docs and their sources of truth. Once one fact or workflow is confirmed stale, inspect and update every material authored reference to that same fact within the evidence cone.

## Hard stops

- Do not hand-edit `CHANGELOG.md` (owned by `./Scripts/release.sh`).
- Do not treat dated “Last execution” / Done tables inside audits as source of truth — **delete** those tracker sections when found.
- Do not rewrite design prose for style-only preferences or turn this into an unbounded prose cleanup. Cohesive terminology or workflow corrections may span documents when inconsistency would otherwise remain.

Severity follows the [shared audit scale](README.md#severity-scale). Prioritize
wrong paths/APIs, broken links, stale architecture or version claims, and omitted
required workflow steps; leave cosmetic typos for an already-touched surface.

## Domain rules

**Sources of truth:** [Docs/README.md](../README.md) source-of-truth table; `project.yml` (`deploymentTarget`, `SWIFT_VERSION`, marketing version); `Packages/*/Package.swift` `swift-tools-version`; checked-in scripts and CI configuration for executable workflows; smoke class inventory under `TrinketUITests/Smoke/`; canonical names from [Architecture.md](../Platform/Architecture.md). A missing instruction is a finding only when the executable source of truth proves it is required for the documented workflow. Duplicated policy that diverges from the Docs/README owner is P2 drift.

**Links:** internal `.md` links resolve **relative to the source file**; heading anchors must still exist. Recheck edited links and factual claims against their listed source of truth. External URLs: check only when changing that source and network is available — do not fail solely on an unavailable endpoint.

**Audit hygiene:** if an audit contains embedded run logs, Done tables, or “Last execution” trackers, remove them and restore procedural guide shape per [README.md](README.md). Run history belongs only in `Docs/Audits/Proposals.md`; prune its entries whose evidence pointers no longer resolve. Cross-audit routing consistency is in scope: an audit guide’s routing pointers must agree with the README owner and confusable-pairs tables.

## Evidence bar

A P1/P2 finding is a confirmed mismatch, consequential omission, non-working example, or duplicated-policy drift between documentation and a named source of truth (path, API, version, architecture assumption, executable workflow, or broken relative link/anchor). P3 issues are optional cleanup only when already touching that file.
