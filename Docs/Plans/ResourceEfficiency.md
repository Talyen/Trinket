---
type: execution-plan
status: active
created: 2026-10-25
updated: 2026-10-25
expires: 2026-11-08
---

# Disk and RAM efficiency

## Objective

Reduce local repository/build storage and investigate lower game RAM use while
preserving the player's visual fidelity, sound, offline play and responsiveness.
Storage retention, cache expiry, evidence reuse, universal size reporting and
CI-first script-gate repair are implemented. The reviewed migration removed
3,962,818,560 allocated bytes (3.69 GiB); the subsequent dry run found zero
eligible outputs. Explicit keeps, unknown/unfinished releases and mismatched
extractions remain intact. No artwork, audio or runtime behavior changed.

The user resumed local measurements and authorized waiting ten minutes and
retrying when host admission is busy. After two ten-minute waits, a retained-build
thinning export and catalog inspection completed. Physical-device RAM remains
blocked on the paired iPhone requiring its passcode. No app was installed or
launched, and no upload or push occurred. Do not claim RAM improvement from the
storage result or treat local Xcode size estimates as actual App Store delivery.

## Agreed trade-offs

- Keep one verified, authoritative archive, IPA, matching symbols and provenance
  record for each uploaded build indefinitely. Keep build-number reservations and
  deployment receipts permanently, including failed reservations.
- Remove successful inspection extractions as soon as their consumers finish.
  Duplicate release working copies expire after **24 hours**, measured from
  verified preservation and a terminal deployment state. Interrupted, ambiguous
  or resumable deployments stay protected until their recovery needs are resolved.
- Expire inactive task and obsolete package caches after **three days**. A slower
  subsequent developer build is acceptable. Preserve existing shared warm caches
  and compatible cache reuse; keep concurrent mutable build tenants isolated.
- Preserve explicitly kept investigations. Narrow a whole-cache keep only after
  its needed evidence is identified and verified in durable storage; unresolved
  ownership remains protected.
- Preserve artwork pixels, audio quality, animation/gameplay timing, feedback,
  offline content, supported devices and OS versions, launch/imminent artwork
  pins, first-screen preparation, mounted roots and existing artwork budgets.
  Do not introduce downloads, quality reductions or smaller artwork to meet a goal.

## Baseline and limits

The read-only investigation on October 24, 2026 measured approximately:

| Area | Footprint / observation |
| --- | --- |
| Primary checkout, including worktrees | 48 GiB |
| Primary DerivedData | 28 GiB; TestFlight outputs account for 19 GiB |
| TestFlight inspection extractions | 6.7 GiB including recovery extraction |
| Primary package `.build` caches | 2 GiB |
| Explicitly kept agent run cache | 6.3 GiB |
| Worktrees | 12 GiB across 25 directories; activity was not established |
| Git directory | 2.5 GiB packed objects plus 3.1 GiB retained task evidence |
| External release/profiling artifact store | 18 GiB |
| Cleanup dry run | Zero eligible bytes under existing rules |

Retained build 62, source `fe1049dc87e5488532467e05b8f3e29c002c5e54`,
Xcode 27.1 (`27A9275`), contains a 433 MiB `Assets.car`: approximately 353 MiB
of RGB fallback renditions and 69 MiB of HEIF renditions. Those HEIF image
dimensions imply about 1.7 GiB of RGBA pixels for the entire catalog, including
portraits excluded from default warmup. This is not resident RAM or device install
size. Current source at investigation was `c7ad136207bc5cf52c175790ab90d458cc98cb69`.

Footprints are not reclaim estimates. Refresh inventory before migration, do not
double-count nested directories, and distinguish logical/allocated bytes from
actual freed space when filesystem clones share blocks. No current-device RAM
baseline or matched before/after performance result has been established.

## Execution order and recommendations

### 1. Establish cleanup eligibility and measurements

- [x] Extend the existing cleanup inventory to classify disposable extraction,
  duplicate verified release, retained release, cache, evidence and unknown paths.
  Report allocated bytes, protection reason, consumer/owner and proposed expiry.
- [x] Recheck live processes, leases, deployment state, open files and keep markers
  immediately before deletion through the existing locking/retention owners.
  Unavailable inventories, unknown ownership, symlinks or incomplete manifests
  must preserve the path. Directory age alone is insufficient.
- [x] Keep cleanup explicit or opportunistic through existing tools; no background
  daemon, foreign process termination, Git history rewrite or worktree mass purge.

### 2. Remove redundant TestFlight storage first

Recommendation: eliminate transient copies before altering any game resource.
Owners: [deployment](../../Scripts/internal/testflight.rb),
[symbol preservation](../../Scripts/internal/build_symbols.py) and
[output retention](../../Scripts/internal/output_retention.py).

- [x] Use scoped temporary directories for successful IPA inspection, including
  recovery paths. Preserve compact inspection results and signature/identity
  proof. Failed diagnostic output follows existing retention and keep controls.
- [x] Resolve archive/IPA consumers through the authoritative preserved location
  before retiring duplicate working copies. Cover resume, checksum validation,
  symbol validation and inspection, including legacy receipts with local paths.
- [x] Verify complete manifests, hashes, executable UUIDs and matching symbols;
  atomically publish the preserved record before permitting 24-hour duplicate
  expiry. A path existing is not sufficient verification. Do not hard-link
  artifacts that signing, export or inspection might mutate.
- [x] Preserve indefinite release artifacts and receipts. Skip original-only,
  damaged, actively referenced or incompletely preserved builds. Migration starts
  with a dry run and proves recovery from the retained copy before deletion.

### 3. Bound cache growth and repeated evidence copies

Recommendation: trade occasional developer rebuilds for predictable storage,
while preserving compatible warm builds and investigation provenance.
Owners: [output retention](../../Scripts/internal/output_retention.py),
[cache pruning](../../Scripts/prune-derived-data-cache.sh) and
[evidence preservation](../../Scripts/agent-integrate.py).

- [x] Apply three-day inactivity expiry to owned task caches and obsolete SwiftPM
  caches, including eligible legacy `.build` directories. Confirm consumers such
  as the balance CLI before retiring their cached executable. Do not broaden
  deletion to arbitrary unknown directories or current shared warm caches.
- [ ] Preserve needed outputs independently before narrowing broad keep markers.
  Existing broad keeps have unresolved investigation ownership and remain intact.
  Completed worktrees use existing clean/integrated cleanup and activity checks;
  unfinished, dirty, live or ambiguous worktrees remain intact.
- [x] Reuse verified identical immutable evidence snapshots instead of copying
  unchanged deliverables at integration and again at cleanup. Preserve a distinct
  provenance record for each capture/preservation event. Start with snapshot
  deduplication; add no general blob store without measured need. Existing evidence
  is not age-deleted. Use verified independent copies when reuse is unsafe.

### 4. Measure shipped asset size before changing packaging

Recommendation: inspect device-thinned products before treating universal
fallback renditions as waste. Owners:
[media generation](../../Scripts/prepare-media.py) and
[project configuration](../../project.yml).

- [x] Generate per-device download/install size estimates through hosted or explicitly
  requested release diagnostics. Record source, toolchain, variant, `Assets.car`
  composition and audio/binary sizes. Use
  [Apple's size-report procedure](https://developer.apple.com/documentation/Xcode/reducing-your-app-s-size).
  Retained build 62 (`fe1049dc87e5`, Xcode `27A9275`) produced iPhone and iPad
  variants spanning the report's iOS 18/26/27 descriptors. Both estimate
  **126.9 MB compressed / 142.4 MB uncompressed**, versus universal
  **501.2 MB / 517.4 MB** (native decimal MB). This is a named historical build,
  not a current-source release certification or an actual App Store download.
- [x] Determine whether the measured fallback renditions survive thinning for
  supported devices and OS versions. If thinning already removes them, close that
  candidate without a packaging rewrite. The observed 353 MiB is not promised savings.
  Each thinned catalog is **78,922,072 bytes** and retains all **645 HEIF**
  renditions (72,659,481 bytes). The universal catalog's **636 RGB555 fallback**
  renditions (370,474,814 bytes) are absent in both variants. No fallback-removal
  rewrite is justified by this baseline; that candidate is closed.
- [x] Preserve authored asset-generation/configuration inputs and image/audio
  quality. No packaging or runtime change was needed for the measured candidate.
  Future packaging proposals still require decoded pixel/color/transparency,
  loading and supported-device parity, plus matched shipping renders before adoption.

### 5. Attribute RAM, then improve artwork lifetime

Recommendation: retain the hitch-prevention contract and target unnecessary
residency/work rather than reducing cache budgets or image quality. Owners:
[artwork cache](../../Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/PreparedArtworkCache.swift),
[memory-pressure entry point](../../Packages/TrinketAppState/Sources/TrinketAppState/App/AppState.swift)
and [artwork lifecycle](../AgentContext/ui-performance.md).

- [ ] Establish a named optimized-device baseline for launch, Collection scrolling
  and details, battle enter/exit, navigation return and background/foreground.
  Attribute pinned/unpinned artwork, UIKit source caching, sized rasters, GPU
  surfaces, audio and process footprint. Multiple references to the same image do
  not represent duplicate pixel allocations. Report memory outside the cache too.
- [ ] If attribution supports it, connect memory pressure to explicit unpinned
  artwork release and suspension/cancellation of speculative warmup. Preserve
  visible/imminent/launch pins and shared demanded decodes; prevent a running
  deferred request from immediately refilling a deliberately trimmed cache.
- [ ] Compare bounded, pressure-aware deferred warmup with today's catalog sweep.
  Keep viewport/imminent priority, first-paint readiness and decode admission.
  Do not replace prepared artwork with synchronous loading. Adopt changes only
  when matched measurements show useful savings without a responsiveness loss.
- [ ] Treat audio and other caches as secondary candidates only if traces establish
  material cost. Catalog size and source patterns alone do not justify rewrites.

### 6. Verify, migrate and document

- [x] Add focused protection for consequential failure modes: active/unknown owner,
  hash/UUID mismatch, failed preservation, interrupted deployment, legacy receipt
  recovery, exact expiry boundaries, kept evidence, snapshot reuse and concurrent
  cleanup/preservation. Use fixtures instead of real signing or uploads.
- [ ] For RAM changes, exercise pin survival, cancellation, shared decode demand,
  pressure recovery and prepared navigation; run matched device performance and
  visual/interaction comparisons. Require repeatable footprint improvement and
  no regression under the existing scenario thresholds. If evidence is absent
  or the trade-off fails, retain existing behavior and report the candidate open.
- [x] Record before/after actual disk space, protected bytes and reasons; replay
  the cleanup dry run after migration to demonstrate bounded repeat behavior.
- [x] Add compact size/retention measurements to existing reports and release CI.
  Establish baselines before enforcing growth thresholds. Do not add a broad
  performance sweep to every push or reduce existing diagnostic retention.
- [ ] Update [Release](../Platform/Release.md),
  [command reference](../../Scripts/Reference.md),
  [artwork lifecycle](../AgentContext/ui-performance.md) and
  [performance budgets](../Platform/PerformanceInvestigationPlaybook.md) only for
  implemented behavior. Review, verify and integrate task changes; remove this
  plan when all work is resolved, folding remaining durable requirements into
  canonical owners.

## Current evidence and remaining prerequisites

### Work available without profiling

- [x] Prepare a dry-run-only migration inventory for legacy profiling derivatives,
  with raw-trace/provenance links and keep/owner protection. A metadata-only scan
  found 1.84 GiB of XML under the external profiling store, including a 1.02 GiB
  `swiftui.xml`. XML totals include potentially essential trace metadata; extension
  alone never establishes disposability. Prefer dropping verified reproducible
  derivatives or lossless archival of needed exports when resources are available.
  Do not compress gigabytes, hash all captures or remove kept evidence while the
  user's other work runs. Current capture tooling already uses temporary exports.
  The new inventory separates 93 named export candidates (1.79 GiB allocated),
  720 raw-trace XML components and 22 unknown XML files. Zero bytes are eligible
  for deletion from metadata alone; no profiling evidence was removed.
- [x] Audit CI cache path ownership and prepare compact per-shard footprint
  reporting for a future authorized CI run. Confirmed producers use
  `host/<package>` or `packages/<package>`; dependency builds stay inside that
  owner. Restore/save now uses declared packages, preserving compiler/platform
  identities and mutable isolation. A namespace change causes one cold rebuild;
  restored/final reports establish actual populated sizes before claiming savings.
- [x] Review artwork/audio/task retention and cancellation by source contracts.
  Implement only confirmed lifetime defects with focused protection; do not tune
  cache budgets, warmup or first-paint pins from source patterns alone.
  The review found balanced artwork leases/generation fences and audio release/
  stale-load handling, with existing focused regressions for these contracts.
  No additional lifetime defect was confirmed. Swift regressions were inspected,
  not executed; RAM and hitch behavior remain unmeasured. No runtime code changed.
- [x] Run the lightweight asset/manifest integrity check: zero missing assets and
  zero orphaned entries. Registered content is not thereby proven reachable or
  unreachable; any deeper unused-content proposal must trace gameplay references
  and preserve save identifiers.

### Verification and deferred measurements

- Resumed measurements used shared host admission. Initial admission was busy;
  two ten-minute waits preceded successful export. The reporter now inspects
  exported catalogs before scoped temporary products disappear. Three focused
  Python regressions passed, covering compact catalog evidence and cleanup on
  export success/failure. Both real build-62 exports succeeded; no products were
  uploaded and no provisioning updates were requested.
- Physical preflight found Ryan's iPhone 14 Pro on iOS 27.0.1 (`24A446`) over
  Wi-Fi with Developer Mode enabled. Device support preparation succeeded.
  The first lock-state query timed out; after preparation, the native query
  returned `passcodeRequired: true`. Unlock is the remaining prerequisite; no
  runtime/RAM capture or build/install/launch was attempted. Stages 5 and its
  parity gates stay open. Device availability was requested while size work continued.
- `ResourceMeasurements/build-62-variant-catalogs/` retains the native thinning
  report, compact per-IPA rendition groups, source/build identity and export log.
  `ResourceMeasurements/request-and-admission.json` records waits and hardware
  prerequisites. Exported IPAs and scratch catalogs were removed by scoped cleanup.
- Seven additional focused Python regressions passed for inventory safety,
  sparse-file allocation, symlink/keep/owner handling, scoped tenant selection
  and the actual CI cache-key shell. Metadata-only inventory ran against existing
  captures. Task deliverables retain `Resources/legacy-profile-inventory.json`
  and `Resources/source-lifetime-review.json`; no capture contents were hashed,
  compressed or exported. Hosted workflow execution remains pending.
- Focused script regressions cover release recovery/tampering/ownership, cache
  expiry, snapshot reuse, inspection lifetime, export failure cleanup and static
  gate selection. A fixture prerequisite failure was repaired and its exact case
  passed; broader script runs selected by the old gate were stopped, not accepted
  as qualification. Full regression/compiled qualification remains hosted.
- Static handoff passed. It now runs script syntax/cache alignment and reports
  broad script regressions as deferred to CI, correcting the encountered mismatch
  between executable routing and the existing CI-first policy.
- Task deliverables contain `Resources/cleanup-before.txt`,
  `Resources/cleanup-applied.txt`, `Resources/cleanup-after.txt`,
  `Resources/build-62-size/build-size.json` and `Resources/result.json`.
  Integration preserves them under the shared task evidence directory for
  `codex/resource-efficiency-20261024` before task-worktree cleanup.
- After the paired phone is unlocked, select a development-signed optimized
  current-source build and obtain RAM evidence under the host lane. The user has
  already authorized this measurement phase and ten-minute busy retries. Keep
  stage 5 open until its evidence gates resolve. Preserve game behavior if a
  proposed trade-off fails measurement; refresh size qualification on a future
  release rather than treating retained build 62 as current-source certification.

## Verification and handoff

Follow [isolated implementation and integration](../../AGENTS.md#route-and-read)
and [verification](../Platform/Verification.md). Local completion uses static
handoff; compilation, broad tests and size/performance qualification stay hosted.
Local heavy measurements require the repository's express authorization and
shared host lane. Report disk, static, compiled, hosted, visual and device
performance evidence separately. Pushes and deployment need separate authorization.

Disk-retention implementation can finish independently of a blocked device
measurement. Do not present that as completion of the RAM investigation or claim
game memory/quality parity from cleanup or source-only evidence.
