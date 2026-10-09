# CI failure diagnostics context

Load this card only after a test, package, build, or CI invocation fails. Structured
diagnostics are the preferred starting point; use targeted raw-log searches when
the reports cannot answer the diagnostic question.

## Script regressions

`test-scripts.sh` prints a bounded failure excerpt with suite, exit status, and
full log path. Failed Python/shell regression logs survive command exit under
`$RESULTS_DIR/script-tests.*` or `.DerivedData/ScriptTestResults/`; successful
logs are removed. Inspect the retained file only for details missing from the
excerpt. These logs do not use Xcode invocation manifests.

Failed hosted gates upload `gate-failure-<run>-<attempt>` artifacts containing
the gate transcript and retained script regression reports. Large logs keep
their beginning and end within the artifact budget owned by
`Scripts/diagnostic_maintenance.py`; local originals remain complete.

The exhaustive advisory summary reads actual shard conclusions for the current
run attempt. Failed or cancelled shards produce warnings and links while remaining
outside `CI OK`; unavailable results are reported as unknown.

## Preparation timing

Test wrappers own simulator preparation and recovery. CI actions must not run a
background boot alongside that owner: competing recovery can erase a device
while another process is booting or testing it.

Test jobs retain `phase-timing.jsonl` alongside compact test timing. Records separate
environment, simulator, shared input preparation, and compile/test phases by scope
and diagnostics session. Compare these with XCTest case durations before attributing
slow jobs to assertions. Multi-package jobs share their initial identity/input snapshot
only while the recorded parent PID/start-time and DerivedData scope match. Each package
still checks inputs and identity at completion; guest-baseline and cleanup safeguards
are unchanged.

## Emitted reports

Every test or package invocation writes an atomically completed
`*-invocation.json` manifest in the run’s `RESULTS_DIR` (shared default
`.DerivedData/TestResults/`, or `.DerivedData/runs/agent-N/TestResults/` when
`TRINKET_ISOLATE=1` / `handoff --isolate`). It records the label,
exit code, action, pass/fail status, result-bundle path, and optional diagnostics-report path.
Build and build-for-testing actions accept a successful process exit without an
xcresult; every test action requires positive execution evidence from its result
summary or completed-test logs, including ordinary successful process exits.
Swift Testing's aggregate count includes skips; log fallback requires a completed
individual test with cases or a non-skipped XCTest total.
The manifest also records `completion_source` (`process-exit` or
`watchdog-log-inference`), `test_execution_proven`, and `result_bundle_complete`.
When available, it retains the invocation's compact test summary. Timing and
targeted UI recovery reuse that summary only for the matching finalized bundle
and still export its case tree; missing, legacy, or mismatched manifests use a
fresh summary export.
Routine simulator test actions pass `-collect-test-diagnostics never`. A sampled
post-test stall was Xcode waiting for `simctl diagnose --timeout=600`, even after
all test cases passed; stopping that collector allowed the result bundle to finalize.
Disabling bulk simulator diagnostics retains XCTest results, ordinary attachments,
and our structured failure reports. An explicit `-collect-test-diagnostics on-failure`
argument to the shared runner remains available for a deliberate forensic run.

The shared watchdog allows 45 seconds of quiet after the terminal test marker
before treating finalization as stalled; `TRINKET_XCODE_IDLE_TIMEOUT_SECONDS`
overrides that limit. Local tests use the same allowance as CI: healthy exports
can take longer than 10 seconds after the suite passes. A passed suite can still
hang during result finalization, leaving an incomplete `.xcresult`. The watchdog bounds that wait and
can report log-proven test success; this does not prove the bundle finalized or
that motion was correct. Earlier test failures and process crashes still override
later passing summaries, and zero executed tests cannot establish a test pass.
The watchdog remains a fallback for other export stalls; routine runs should finish
with `completion_source=process-exit` and `result_bundle_complete=true`.

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

The UI test base attaches one screenshot directly to the first recorded failure,
including XCTest framework exceptions. Warnings do not consume that capture;
attaching it to the issue keeps the image in failures-only exports.

Narrative budgets are intentionally small and live in
`Scripts/config/diagnostic-limits.env` — read that file (or the report header)
for the current caps on printed lines, issue counts, and message sizes. Use an
explicit retained path or `--full` for forensic payloads; do not paste the
raw log into the agent prompt.

Classifications are `test-failure`, `build-failure`, `simulator-infrastructure`,
`configuration`, `tooling`, or `unknown`. The infrastructure vocabulary is
owned by `Scripts/config/infrastructure-patterns.env` — the Python reporter,
the local retry matcher (`Scripts/lib/xcodebuild-infra.sh`), and the CI rerun
matcher (`Scripts/ci-infra-rerun.sh`) all read that one list. Exit code 70 alone
does not establish infrastructure failure. Do not add infrastructure pattern tokens
anywhere else; extend the config file when a new signature appears.
CI UI commands first use [ci_ui_retry.py](../../Scripts/ci_ui_retry.py) to retry only
identified infrastructure-failed cases once on the same runner. This requires a
complete original result, execution evidence for every requested class, no skipped
or unexecuted cases, and specific infrastructure issues for every failed case.
Mixed assertions, incomplete results, and unknown failures remain failures. The
original failure manifest/report stay intact until normal successful-artifact cleanup;
`infrastructure_recovery` links the
successful retry and both execution sets. The aggregate validates that proof before
reporting recovery, and preserves the recovered failure in its structured evidence.
After staging, verified recovered pairs are cleaned together as passing coverage;
unrecovered failures retain their forensic artifacts.
The managed simulator is re-prepared for the targeted retry. Whole-suite retries
are disabled only inside this CI wrapper; other callers retain their existing policy.

The external CI rerun matcher requires launch evidence from each failed job's own failed
steps. An ineligible job, explicit assertion or source compiler failure, or
unreadable log prevents an automatic rerun of all failed jobs. Reports preserve
assertion and source compiler classifications even when their messages contain
launch-failure wording. Test-owned attachments stay on their
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
Prefer the aggregate and referenced per-invocation Markdown for the failure
category, issue, source location, and suggested action. Inspect JSON, annotations,
attachments, or targeted raw-log excerpts when reports are incomplete, contradictory,
or insufficient to test a hypothesis. A known classification does not imply a
complete explanation; no report-issued escalation is required. Keep output bounded
and use the current invocation's evidence.

After the aggregate has been staged, successful invocation artifacts are ephemeral
by default. `ci-diagnostics.sh --cleanup` removes passed bundles, reports, manifests,
and raw logs while retaining failed evidence and the recent timing entries (24-hour expiry per entry).
UI CI jobs retain compact current-job timing and aggregate JSON for one day,
including passing runs; cached timing is cleared before a CI invocation so old
runs cannot be mistaken for the current one. Successful full bundles and screenshots
remain ephemeral. Timing queries are bounded and optional; targeted-test evidence queries are
bounded and fail when execution cannot be established.
Pass `--keep` for a deliberate local investigation. The same cleanup sweeps
orphaned bundles/logs from runs
that crashed before writing a completion manifest, age-bounded by
`TRINKET_OUTPUT_MAX_AGE_HOURS` (default 24 hours). Failed manifests, reports,
attachments, and raw logs also expire after 24 hours. `--keep` marks the results
directory for an active investigation until explicitly released; see
[output cleanup](../../Scripts/Reference.md#output-retention).

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
