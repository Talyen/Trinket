# Authored Mass & Growth Hotspot Audit

**Goal:** Reduce expensive authored maintenance surface by confirming live mass/growth hotspots — not per-change deltas and not unused symbols alone.

`./Scripts/change-budget.sh` warns on the current diff. This audit inventories retrospective mass. DeadCode removes unused symbols; InelegantSlop removes ceremony; neither ranks live file or package hotspots.

## Intent

Confirm authored production or test hotspots whose size or mixed jobs cost more to read, edit, or verify than the behavior warrants, then shrink them through an existing owner. Growth means accumulated live surface relative to peers / shipping behavior — not `git log` LOC rates and not per-diff `change-budget.sh` deltas. Historical churn may be a candidate signal only; it is not required evidence. A successful fix reports a net reduction in authored LOC, declarations, or files. Moving mass without removing the old path is not success. A clean pass is valid. Planning and phasing: [README.md](README.md).

## What counts as a mass or growth hotspot

| Tell | Why it is a finding candidate |
|------|-------------------------------|
| Large authored file with mixed jobs | Review and agent context pay for unrelated concerns in one surface |
| Folder-level mass dominated by parallel scaffolding or accumulated helpers that do not express distinct shipping behaviors | Surface grew without matching distinct product jobs — still requires the full evidence bar |
| Fat mapping / sanitizer / session / lab files that force unrelated code prereads because of mixed jobs | One change requires reading load-bearing neighbors it does not own |
| Over-expanded test matrices or support harnesses dwarfing unique assertions | Maintenance cost sits in harness mass, not semantic coverage — prefer UnitTest when the hit is primarily portfolio ownership |

**Not this audit:** unused symbols → DeadCode; single-path ceremony with correct ownership → InelegantSlop; copy-paste UI shells → DuplicateFeatureSurface; wrong semantic owner → StateGravity; retained parallel live implementations / shims → DualPathRetention; recurring co-touch / routing / guidance duplication → ChangeLocality; per-change advisory growth → `change-budget.sh` only.

## Hard stops

- Do not treat file length alone as a finding. Size is a candidate signal until an avoidable cause and smaller shape are confirmed.
- Do not hand-edit `Generated/*`, `.DerivedData/`, `.tools/`, or build products. Exclude them from hotspot inventory. Do not treat ContentManifest / generated catalog volume as authored Swift mass.
- Do not rewrite allowlisted load-bearing complexity “to split files”: battle damage/turn pipeline math, save wire format / sanitizer invariants that must stay co-located, catalog/codegen boundaries, intentional motion labs when product juice requires them.
- Do not invent absolute LOC or coverage % CI gates. Prefer evidence and local reduction over ratchets.
- Prefer the owning audit when the hit is primarily dead code, slop ceremony, dual-path retention, duplicate UI, state ownership, change locality / routing friction, or unit/UI test portfolio fit.

## Evidence bar

All of:

- **Hotspot:** an authored production or test surface that is large relative to peers in its owner, or that routinely forces unrelated code prereads because of mixed jobs in one file
- **Avoidable cause:** mixed jobs, parallel scaffolding, over-expanded matrices/fixtures, or accumulated helpers without a second need — not inherent domain density
- **Existing home:** engine handler, store slice, DesignSystem / FeatureSupport shell, or existing test owner that can absorb the split or collapse
- **Measurable direction:** net authored LOC, declarations, or files decreases while behavior and required coverage stay intact

## Domain rules

Inventory authored Swift under app and packages; count production and test separately. Skip generated output, build artifacts, and ContentManifest / catalog volume. Allowlist justified density (battle rule pipelines, save graph mapping when co-location is the invariant, intentional spectacle labs). Prefer collapse/delete → move jobs to the existing owner → split a hub only when [Architecture.md](../Platform/Architecture.md) hub containment already expects handlers/engines/`+` files and the local move removes mixed jobs.

Successful fixes leave a smaller hotspot or delete the avoidable portion; proposals for significant hub splits follow the README right-size policy.
