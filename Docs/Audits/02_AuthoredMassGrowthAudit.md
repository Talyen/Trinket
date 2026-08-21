# 02. Authored Mass & Growth Hotspot Audit

**Goal:** Reduce expensive authored maintenance surface by confirming live mass/growth hotspots across source, tests, scripts, configuration, and guidance — not per-change deltas and not unused symbols alone.

`./Scripts/change-budget.sh` warns on the current diff. This audit inventories retrospective mass. DeadCode removes unused symbols; InelegantSlop removes ceremony; neither ranks live file or package hotspots.

## Intent

Confirm authored hotspots whose size or mixed jobs cost more to read, edit, or verify than the behavior warrants, then reduce that cost through an existing owner. Growth means accumulated live surface relative to peers / shipping behavior — not `git log` LOC rates and not per-diff `change-budget.sh` deltas. Historical churn may be a candidate signal only; it is not required evidence. A successful fix reports a net reduction in authored LOC/declarations/files or a measured reduction in mixed-job prereads, change fan-out, or verification cost. A split may be LOC-neutral when it establishes ownership already required by Architecture and materially reduces unrelated context; moving mass without either removal or a measured locality win is not success.

## What counts as a mass or growth hotspot

| Tell | Why it is a finding candidate |
|------|-------------------------------|
| Large authored file with mixed jobs | Review and agent context pay for unrelated concerns in one surface |
| Folder-level mass dominated by parallel scaffolding or accumulated helpers that do not express distinct shipping behaviors | Surface grew without matching distinct product jobs — still requires the full evidence bar |
| Fat mapping / sanitizer / session / lab files that force unrelated code prereads because of mixed jobs | One change requires reading load-bearing neighbors it does not own |
| Over-expanded test matrices or support harnesses dwarfing unique assertions | Maintenance cost sits in harness mass, not semantic coverage — prefer UnitTest when the hit is primarily portfolio ownership |
| Large scripts, configuration, or guidance surfaces mixing unrelated workflows | Routine changes and verification require reading or editing policy that does not belong to the behavior |

**Not this audit:** single-path ceremony with correct ownership → InelegantSlop;
unused symbols → DeadCode; per-change advisory growth → `change-budget.sh` only.

## Hard stops

- Do not treat file length alone as a finding. Size is a candidate signal until an avoidable cause and smaller shape are confirmed.
- Do not hand-edit `Generated/*`, `.DerivedData/`, `.tools/`, or build products. Exclude them from hotspot inventory. Do not treat ContentManifest / generated catalog volume as authored Swift mass.
- Do not rewrite allowlisted load-bearing complexity “to split files”: battle damage/turn pipeline math, save wire format / sanitizer invariants that must stay co-located, catalog/codegen boundaries, intentional motion labs when product juice requires them.
- Do not invent absolute LOC or coverage % CI gates. Prefer evidence and local reduction over ratchets.
- Prefer the owning audit when the hit is primarily dead code, slop ceremony, dual-path retention, duplicate UI, state ownership, change locality / routing friction, or unit/UI test portfolio fit.

## Evidence bar

All of:

- **Hotspot:** an authored source, test, script, configuration, or guidance surface that is large relative to comparable peers in its owner, or that routinely forces unrelated prereads because of mixed jobs in one file
- **Avoidable cause:** mixed jobs, parallel scaffolding, over-expanded matrices/fixtures, or accumulated helpers without a second need — not inherent domain density
- **Existing home:** engine handler, store slice, DesignSystem / FeatureSupport shell, or existing test owner that can absorb the split or collapse
- **Measurable direction:** authored LOC/declarations/files decrease, or a justified owner-preserving split materially reduces unrelated prereads, change fan-out, or verification cost while behavior and required coverage stay intact

## Domain rules

Inventory authored Swift under app and packages, then authored scripts, configuration, documentation tooling, and test support in their own categories; do not compare unlike artifacts by raw LOC. Use reproducible proxies — largest authored files per owner plus repeated preread/change/verification fan-out where available — so successive runs rank the same hotspots and the handoff can compare against the prior run’s inventory. Skip generated output, build artifacts, and ContentManifest / catalog volume. Allowlist justified density (battle rule pipelines, save graph mapping when co-location is the invariant, intentional spectacle labs). Prefer collapse/delete → move jobs to the existing owner → split a hub when [Architecture.md](../Platform/Architecture.md) already expects handlers/engines/`+` files and the move removes mixed jobs or materially narrows required context.

Successful fixes leave a smaller hotspot, delete the avoidable portion, or produce a measured owner-preserving locality improvement; approval-sensitive hub splits follow the README right-size policy.
