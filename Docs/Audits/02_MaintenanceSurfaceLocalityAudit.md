# 02. Maintenance Surface & Locality Audit

**Goal:** Reduce live authored maintenance and context cost when a narrow change
requires more code, guidance, touchpoints, or verification than its behavior
warrants.

## Intent

Confirm large or recurring maintenance surfaces, then simplify them through an
existing source of truth or semantic owner. This is a retrospective inventory,
not the per-diff `change-budget.sh` advisory. A successful fix reduces authored
LOC/declarations/files, mixed-job prereads, routine touchpoints, duplicated
policy, verification fan-out, or diagnostic volume without weakening behavior.

## What belongs here

| Tell | Required cause |
|------|----------------|
| Large authored file, script, test harness, or guidance card | Mixed jobs or avoidable scaffolding forces unrelated context |
| Routine change touches 3+ authored policy/configuration surfaces | One duplicated fact or command forces the co-change |
| Repeated verification or diagnostics exceed the behavior's owner | Routing or output is broader than the dependency evidence requires |
| Live folder/package mass is dominated by parallel scaffolding | The scaffolding does not express distinct shipping behavior |

**Not this audit:** zero-consumer, reachable twin, or pure-ceremony surface →
[06](06_DeadParallelCeremonialSurfaceAudit.md); wrong semantic owner →
[13](13_StateGravityOwnershipAudit.md); duplicate product screens →
[09](09_DuplicateFeatureSurfaceAudit.md); test portfolio value → [10](10_E2ETestQualityAudit.md)
or [17](17_UnitTestAudit.md).

## Hard stops

- Size, churn, or co-change alone is not a finding. Name the avoidable cause.
- Exclude generated output, build artifacts, ContentManifest/catalog volume, and
  intentional source/test or authored/generated companionship.
- Do not weaken gates, suppress diagnostics, or narrow verification without
  dependency and behavior evidence.
- Do not split files, merge owners, or add routing/configuration frameworks merely
  to improve a count.
- Allowlist load-bearing battle pipelines, save wire/mapping invariants, catalog
  codegen boundaries, and measured presentation infrastructure unless mixed jobs
  are independently confirmed.

## Evidence bar

All of:

- **Magnitude or recurrence:** three comparable instances; two with demonstrated
  drift/failure; or one extreme surface that repeatedly forces unrelated context,
  touchpoints, verification tiers, or high-volume output
- **Causality:** a named mixed job, duplicated declaration/policy/command, missing
  source of truth, or over-expanded scaffold
- **Excess surface:** necessary behavior, tests, generated output, and verification
  are separated from the avoidable portion
- **Existing home:** a current executable source, semantic owner, or routing
  mechanism can absorb the remedy
- **Measurable direction:** a before/after proxy with correctness coverage intact

## Domain rules

Inventory authored Swift, tests, scripts/configuration, and guidance separately;
do not compare unlike artifacts by raw LOC. Platform docs own architecture and
testing policy, `AGENTS.md` owns repository-wide guardrails, executable scripts
own mechanics, and routed cards/skills contain only distinct exceptions. Prefer
links over copied policy while retaining the minimum local instruction needed to
act safely.

Prefer collapse/delete → move a mixed job to its existing owner → owner-preserving
split when Architecture already prescribes the seam. A LOC-neutral split succeeds
only when it materially reduces unrelated prereads, change fan-out, or verification
cost. Report the before/after proxy and unchanged correctness signal.
