# CI failure diagnostics context

Load this card only after a test, package, build, or CI invocation fails. Structured
diagnostics are the first source of evidence; raw xcodebuild logs are a last resort.

## Script regressions

`test-scripts.sh` prints a bounded failure excerpt with suite, exit status, and
full log path. Failed Python/shell regression logs survive command exit under
`$RESULTS_DIR/script-tests.*` or `.DerivedData/ScriptTestResults/`; successful
logs are removed. Inspect the retained file only for details missing from the
excerpt. These logs do not use Xcode invocation manifests.

## Emitted reports

Every test or package invocation writes an atomically completed
`*-invocation.json` manifest in the run’s `RESULTS_DIR` (shared default
`.DerivedData/TestResults/`, or `.DerivedData/runs/agent-N/TestResults/` when
`TRINKET_ISOLATE=1` / `handoff --isolate`). It records the label,
exit code, pass/fail status, result-bundle path, and optional diagnostics-report path.
The manifest also records `completion_source` (`process-exit` or
`watchdog-log-inference`), `test_execution_proven`, and `result_bundle_complete`.
A passed suite can hang during Xcode result finalization, leaving an incomplete
`.xcresult` even after a longer idle allowance. The watchdog bounds that wait and
can report log-proven test success; this does not prove the bundle finalized or
that motion was correct. Earlier test failures and process crashes still override
later passing summaries, and zero executed tests cannot establish a test pass.
This is a supported workaround for the Xcode hang, not a fix to Xcode itself.

For these investigations, retain the manifest and raw log with
`./Scripts/ci-diagnostics.sh --cleanup --keep <results-dir>` to suppress cleanup. Capture motion
separately using the managed lease and recording workflow in
[Simulator operations](../Platform/SimulatorOperations.md#inspection-lease-and-capture);
an incomplete result bundle may not contain usable recordings or attachments.

Failed invocations also produce bounded sibling reports:

- `*-diagnostics.json` with the label, exit code, result-bundle path, classification,
  actionable issues, structured-source availability, terminal limits, and any
  failure attachments that could not be associated with one test.
- `*-diagnostics.md` with a human-readable summary.
- `*-diagnostics.annotations` with GitHub Actions annotations.
- `*-diagnostics.attachments/` when a bounded attachment is needed.

Narrative budgets are intentionally small and live in
`Scripts/config/diagnostic-limits.env` — read that file (or the report header)
for the current caps on printed lines, issue counts, and message sizes. Use an
explicit retained path or `--full` for forensic payloads; do not paste the
raw log into the agent prompt.

Classifications are `test-failure`, `build-failure`, `simulator-infrastructure`,
`configuration`, `tooling`, or `unknown`. The infrastructure vocabulary is
owned by `Scripts/config/infrastructure-patterns.env` — the Python reporter,
the local retry matcher (`Scripts/lib/xcodebuild-infra.sh`), and the CI rerun
matcher (`Scripts/ci-infra-rerun.sh`) all read that one list, and xcodebuild
exit code 70 is always `simulator-infrastructure`. Do not add pattern tokens
anywhere else; extend the config file when a new infrastructure signature
appears. Test-owned attachments stay on their
matching issue; runner-level or otherwise unmatched attachments are listed once at
report level. A failure report may identify source locations and attachments even
when the underlying result bundle is incomplete.

## Aggregate and triage order

Run (the current diagnostics session is selected automatically):

```sh
# Shared tenant (humans / CI):
./Scripts/ci-diagnostics.sh .DerivedData/TestResults

# Isolated agent run — use the RESULTS_DIR printed by run-env:
./Scripts/ci-diagnostics.sh .DerivedData/runs/<TRINKET_RUN_ID>/TestResults
```

The command aggregates only the current session's completion manifests and failure reports into
`<RESULTS_DIR>/ci-diagnostics.json`; in CI it also writes the actionable
summary to `GITHUB_STEP_SUMMARY`. Every test/build orchestration receives a
unique diagnostics session, and `handoff`, deploy verification, and nested
package commands inherit one session, so the aggregate reports only the
current failed run while older retained failures stay available for forensic
use. It consumes the structured reports and does not
reparse xcresult bundles. Cached status/diagnostic artifacts can be cleared at job
start without deleting raw logs or xcresult bundles:

```sh
./Scripts/ci-diagnostics.sh --reset .DerivedData/TestResults
# or the isolated RESULTS_DIR for an agent run
```
Coding agents should inspect the aggregate first, then the referenced per-invocation
Markdown for the failure category, issue, source location, and suggested action.
Open per-invocation JSON, annotations, or attachments only when the Markdown points
to missing detail. Inspect raw xcodebuild logs only when the aggregate category is
`unknown` (or a report explicitly escalates to raw-log inspection).

After the aggregate has been staged, successful invocation artifacts are ephemeral
by default. `ci-diagnostics.sh --cleanup` removes passed bundles, reports, manifests,
raw logs, and timing history while retaining failed evidence for current triage.
Pass `--keep` for a deliberate local investigation. The same cleanup sweeps
orphaned bundles/logs from runs
that crashed before writing a completion manifest, age-bounded by
`TRINKET_ORPHAN_MAX_AGE_DAYS` (default 3 days); failed evidence carrying a
diagnostics report is retained.

For GitHub Actions failures, prefer check-run annotations (SwiftLint / compiler)
and a short `--log-failed` tail over scraping the full log when the excerpt only
shows “Found N violation(s)” without a path — style findings reach annotations
through SwiftLint's `github-actions-logging` reporter in `Scripts/lint.sh`.
`./Scripts/agent-watch-ci.sh` prints those when used manually.

The test and package command scopes are unchanged: diagnostics describe the existing
`test.sh`, `test-package.sh`, and wrapper invocations rather than replacing focused
verification or the pre-push gates.

CI uploads a structured-first artifact. The test job stages manifests,
bounded reports, the aggregate, and timing data; raw logs, `.xcresult` bundles, and
attachments are staged only when the aggregate category is failed or unknown. Use
`python3 ./Scripts/ci-diagnostics.py --full <RESULTS_DIR> <OUTPUT_PATH>` when an investigation
needs the uncompressed aggregate invocation payload.
