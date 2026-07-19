# CI failure diagnostics context

Load this card only after a test, package, build, or CI invocation fails. Structured
diagnostics are the first source of evidence; raw xcodebuild logs are a last resort.

## Emitted reports

Every test or package invocation writes an atomically completed
`*-invocation.json` manifest in the run’s `RESULTS_DIR` (shared default
`.DerivedData/TestResults/`, or `.DerivedData/runs/agent-N/TestResults/` when
`TRINKET_ISOLATE=1` / `verify-changed --isolate`). It records the label,
exit code, pass/fail status, result-bundle path, and optional diagnostics-report path.
Failed invocations also produce bounded sibling reports:

- `*-diagnostics.json` with the label, exit code, result-bundle path, classification,
  actionable issues, structured-source availability, and terminal limits.
- `*-diagnostics.md` with a human-readable summary.
- `*-diagnostics.annotations` with GitHub Actions annotations.
- `*-diagnostics.attachments/` when a bounded attachment is needed.

Classifications are `test-failure`, `build-failure`, `simulator-infrastructure`,
`configuration`, `tooling`, or `unknown`. A failure report may identify source
locations and attachments even when the underlying result bundle is incomplete.

## Aggregate and triage order

Run:

```sh
# Shared tenant (humans / CI):
./Scripts/ci-diagnostics.sh .DerivedData/TestResults

# Isolated agent run — use the RESULTS_DIR printed by run-env:
./Scripts/ci-diagnostics.sh .DerivedData/runs/<TRINKET_RUN_ID>/TestResults
```

The command aggregates completion manifests and failure reports into
`<RESULTS_DIR>/ci-diagnostics.json`; in CI it also writes the actionable
summary to `GITHUB_STEP_SUMMARY`. It consumes the structured reports and does not
reparse xcresult bundles. Cached status/diagnostic artifacts can be cleared at job
start without deleting raw logs or xcresult bundles:

```sh
./Scripts/ci-diagnostics.sh --reset .DerivedData/TestResults
# or the isolated RESULTS_DIR for an agent run
```
Coding agents should inspect the aggregate, then the referenced per-invocation JSON,
Markdown, annotations, and attachments for the failure category, issue, source
location, and suggested action. Inspect raw xcodebuild logs only when the aggregate
category is `unknown` (or a report explicitly escalates to raw-log inspection).

For GitHub Actions failures, `./Scripts/agent-watch-ci.sh` already prints failed job
names, check-run annotations (SwiftLint / compiler), and a short `--log-failed`
tail. Prefer those annotations over scraping the full log when the excerpt only
shows “Found N violation(s)” without a path — style findings often live in
annotations when `github-actions-logging` is enabled.

The test and package command scopes are unchanged: diagnostics describe the existing
`test.sh`, `test-package.sh`, and wrapper invocations rather than replacing focused
verification or the pre-push/pre-merge gates.
