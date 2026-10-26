---
type: execution-plan
status: active
created: 2026-10-25
updated: 2026-10-25
expires: 2026-11-08
---

# Disk and RAM efficiency

## Objective and boundaries

Finish the resource-efficiency investigation while preserving artwork pixels,
audio quality, animation/gameplay timing, feedback, offline content, supported
devices/OS versions, launch/imminent artwork pins, first-screen preparation,
mounted roots and existing budgets. Do not introduce downloads or reduce quality
to meet a storage/RAM goal. A slower developer rebuild is an accepted trade-off.

The user authorized local measurements and ten-minute busy-admission waits/retries
for this investigation. Pushes and deployment remain separate. The last physical
preflight required the paired iPhone's passcode; refresh that prerequisite before
resuming. No runtime/RAM capture, app install/launch, push or upload was performed.

## Completed results and evidence

Storage retention, cache expiry, immutable evidence reuse, build-size reporting,
scoped CI cache ownership and the encountered CI-first script-gate repair are
implemented. The reviewed migration removed **3,962,818,560 allocated bytes
(3.69 GiB)**; its next dry run found zero eligible outputs. Kept investigations,
unknown/unfinished releases and mismatched copies were preserved. No artwork,
audio or runtime behavior changed; these results establish no game RAM savings.

| Completed concern | Current owner / retained evidence |
|---|---|
| Artifact lifetimes and cleanup protection | [Output retention](../../Scripts/Reference.md#output-retention); [release validation/recovery](../Platform/Release.md#options-and-recovery) |
| Immutable evidence snapshots and event provenance | [Evidence preservation](../Platform/Release.md#evidence-and-cleanup) |
| Size and legacy-profile inventory reporting | [Resource reports](../../Scripts/Reference.md#resource-reports) |
| Declared-package CI caches and footprint reports | [Cache identity](../Platform/VerificationInternals.md#build-products-and-cache-identity); hosted execution pending |
| Disk migration | `Resources/cleanup-before.txt`, `cleanup-applied.txt`, `cleanup-after.txt`, `result.json` |
| Universal size baseline | `Resources/build-62-size/build-size.json` |
| Thinned export/catalog inspection | `ResourceMeasurements/build-62-variant-catalogs/` and `request-and-admission.json` |
| Metadata-only legacy-profile inventory / source lifetime review | `Resources/legacy-profile-inventory.json` and `source-lifetime-review.json` |

Those relative evidence paths belong to the retained task evidence for
`codex/resource-efficiency-20261024`, not this documentation task's checkout.
Find them under Git's shared `trinket-evidence/codex/resource-efficiency-20261024/`
store and verify availability before reuse. The full pre-condensation record is also
preserved in Git at
`47087791fa5b7f5fcd4466e6a7483bb5ac03ee94:Docs/Plans/ResourceEfficiency.md`
and in the documentation-consolidation task's retained baseline evidence.

Retained build 62 (`fe1049dc87e5488532467e05b8f3e29c002c5e54`, Xcode `27A9275`)
produced iPhone/iPad thinning estimates of **126.9 MB compressed / 142.4 MB
uncompressed**, versus universal **501.2 MB / 517.4 MB**. Each thinned catalog
retained all 645 HEIF renditions and omitted all 636 RGB555 fallbacks. The
fallback-removal candidate is closed: no packaging rewrite is justified by that
baseline. These are historical Xcode estimates, not current-source certification,
actual App Store delivery or resident RAM. Any future packaging change still needs
pixel/color/transparency, loading, supported-device and matched-render parity.

The metadata-only profile inventory identified 93 named export candidates,
720 raw-trace XML components and 22 unknown XML files; **zero bytes were eligible
for deletion from metadata alone**. No captures were hashed, compressed or removed.
Source review confirmed balanced artwork/audio lifetimes and existing focused
protection, without a new lifetime defect. Asset integrity found no missing or
orphaned entries; that does not prove gameplay reachability. Swift regressions
were inspected, not executed. Focused Python regressions and static handoff passed;
full regression/compiled/hosted qualification remains outstanding. Broader runs
stopped under the older gate do not count as qualification.

## Remaining work

- [ ] Preserve needed outputs independently before narrowing broad keep markers.
  Their investigation ownership remains unresolved. Verify raw-trace provenance,
  reproducibility and consumers before proposing any derivative deletion. No
  background cleanup, foreign process termination, Git rewrite or worktree mass purge.
- [ ] After the paired phone is unlocked, establish a named optimized current-source
  device baseline for launch, Collection scrolling/details, battle enter/exit,
  navigation return, background/foreground and extended play. Attribute pinned and
  unpinned artwork, UIKit source caching, sized rasters, GPU surfaces, audio and
  process footprint without double-counting references to the same pixels.
- [ ] Only if attribution supports it, connect memory pressure to unpinned artwork
  release and speculative-warmup suspension/cancellation. Preserve visible/imminent/
  launch pins and shared demanded decodes; prevent trimmed caches immediately
  refilling from an already-running deferred request.
- [ ] Compare bounded, pressure-aware deferred warmup with the current catalog sweep.
  Preserve viewport/imminent priority, first-paint readiness and decode admission;
  never replace prepared artwork with synchronous loading. Investigate audio/other
  caches only when traces establish material cost.
- [ ] For any RAM change, verify pin survival, cancellation, shared decode demand,
  pressure recovery and prepared navigation. Require repeatable peak/settled RAM
  improvement, matched device performance and visual/interaction parity under
  existing thresholds. Keep behavior unchanged if evidence is absent or fails.
- [ ] Complete current-revision hosted regression/compiled/cache-report qualification
  after authorized publication; refresh size qualification on a future release.
  Do not substitute build-62 exports for a current-source release check.
- [ ] Update the artwork lifecycle and performance owners only for implemented
  behavior. Review, verify and integrate remaining work; preserve results in the
  handoff and delete this plan when all acceptance and ownership questions close.

Use [isolated integration](../../AGENTS.md#route-and-read),
[verification](../Platform/Verification.md) and the
[device investigation procedure](../Platform/PerformanceInvestigationPlaybook.md#memory-and-energy).
Report disk, static, compiled, hosted, visual and device evidence separately.
Disk-retention completion does not close the RAM investigation or establish quality parity.
