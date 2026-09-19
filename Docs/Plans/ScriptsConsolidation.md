---
type: execution-plan
status: active
created: 2026-09-18
updated: 2026-09-18
expires: 2026-10-02
---

# ScriptsConsolidation

## Objective

Consolidate the `Scripts/` subsystem toward the "right shape": one CLI-flag
parsing substrate (`lib/args.sh`), one gate-composition executor, one Python
I/O substrate (`internal/cli.py`), fewer bespoke tempdir/trap/simctl spellings,
and consistent exit codes / flag spellings — with no player-visible behavior
change. Random roll (`seed=1195712200`) selected `Scripts` from 12 candidates.

Baseline: in-flight work already consolidated `lib/rg-check.sh` shared helpers
(`trinket_rg_has_nearby_allow`, `trinket_rg_contains`, adopted by the three
`check-*.sh` gates) and the `cheap-slices.txt` skip marker. This plan preserves
that work and builds on it; it does not rewrite dirty files' in-flight regions.

## Plan

- [ ] Phase A — CLI flags: extend `lib/args.sh` (`trinket_args_help`,
  `trinket_args_paths_missing`, `-v` support); adopt in handoff-family +
  gates; unify missing-value exit code to 2; one `run-env.sh` source spelling.
- [ ] Phase B — Tempdir/trap + simctl + tool-installer dedup (on top of the
  in-flight `rg-check.sh` work; no rewrites of dirty regions).
- [ ] Phase C — Single gate-composition executor (`trinket_run_full_gate`);
  `ci-gate.sh` becomes a thin caller; drop string-substitution docs rewrite.
- [ ] Phase D — Python substrate: timeout runner + `read_json` + `glob_match`
  into `internal/cli.py`; remove `ci-path-filter.py` fork; unify loaders.
- [ ] Phase E — Docs quartet subcommands; perf quintet one I/O path;
  section-aware script-index check.
- [ ] Phase F — `config/packages.env` split; single TSV/ENV parsers;
  `--fast` disambiguation; bare-alias deprecation.
- [ ] Phase G — `FAMILIES` derivation; mega-test split; shared fixtures.
- [ ] Record the outcome in `Docs/Plans/Archived/README.md`, delete this file, and report verification.

## Notes

Keep durable policy in its canonical documentation owner. When the work is complete, record the outcome in `Docs/Plans/Archived/README.md` and delete this plan; Git history retains the full text.

## Blocked: prior reviewed rejection overlaps this plan

`Docs/Plans/Archived/README.md` (2026-09-15, "Scripts simplification") records
rejections "with evidence" for: args-helper migration, sourcing sweep,
xcode-lib merge, diagnostics/perf/docs merges, CLI restandardization, `--fast`
hollowing, dead-helper deletion. Phases A (args-helper migration, sourcing
sweep, exit-code/message restandardization) and F3 (`--fast` rename) of this
plan overlap those rejections directly. The detailed evidence is not in the
repo beyond that row (commit `371cac7f` carries only the summary).

Corroborating signal from this session: every new cross-file shell dependency
broke standalone test fixtures (performance.sh needed `lib/args.sh`;
project-generation/assert paths needed `lib/tempdir.sh` /
`lib/generated-paths.sh`), each requiring fixture-copy updates — the same
coupling tax the prior round likely weighed. The full suite is green with
those fixture updates included.

Phases B–E as implemented deliberately stayed narrower than the rejected
"merges" (no CLI folding, no taxonomy unification, forks kept with parity
tests). Awaiting direction before F3/F4/G: (1) keep everything as verified,
(2) revert the rejected-overlap items (Phase A + F3) while keeping B–E,
(3) stop and hand back. Phase F1 (packages.env split) is additionally deferred
on independent grounds: 5+ bash fixtures source build-inputs.env standalone
and would break under `set -u`; the file already declares single-registry
ownership in comments, so the split buys no behavior.

## Resolution (2026-09-19): option (2) adopted

Phase A reverted on architectural grounds (thin wrappers added a dependency
edge from ~15 scripts onto `lib/args.sh`, often transitively; two helpers
shipped with zero/one production callers; `-v` and exit-code 1→2 changed
behavior; the sourcing sweep was behavior-identical churn), corroborating the
prior rejection's coupling concern. Phases B–E kept as verified, plus review
fixes: `run-simulator.sh` failure evidence untracked from EXIT cleanup via new
`trinket_temp_untrack`, lock-acquire stderr restored, doc drifts corrected
(`ApplePlatformReference` owner list, empty-cleanse qualifier, EULA clause).
F3/F1 remain absent per the deferral above; G stays routing-only.

## Investigated, intentionally unchanged

- `ci-path-filter.py` standalone `read_env_arrays` fork: the /tmp changes
  workflow fetches only that file plus `build-inputs.env` by design, so the
  fallback with its `try/except` canonical-first import plus the parity test
  (`test_ci_path_filter.py`) is the right shape. Vendoring `internal/cli.py`
  into the workflow would trade a pinned 60-line fork for workflow coupling.
- Path-taxonomy unification (`ci-path-filter` globs vs `agent-search` /
  `release-notes-user` prefix lists): the taxonomies answer different
  questions (CI job selection vs product/infra classification); merging them
  risks semantic changes for aesthetic gain.
- Subprocess-wrapper unification (`performance_environment.command` swallows
  failures to `"unknown"` while `release-notes-user.run` raises): the error
  policies are intentional per caller. No shared wrapper without a policy
  change, which is out of scope.
- `validate_repo_paths` in `script_test_selection.py`: the selector silently
  routes unknown/out-of-repo paths to the full suite (fail-safe); the
  validator rejects them (fail-closed). Delegating would turn lenient
  fallback into hard errors. Overlap stays at three lines.
- Dead `trinket_cheap_slice_commands` (`lib/cheap-slices.sh`) and the
  `check-*.sh` / `Reference.md` / `cheap-slices.txt` in-flight regions:
  owned by concurrent uncommitted work; left untouched to avoid conflicts.
- `content_codegen.py` (1939 lines) per-catalog split: flagged for a future
  pass; out of scope here.
