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
run attempt. Requested FullUI that fails, is cancelled, is skipped, or lacks
readable execution evidence fails its own advisory aggregate; warnings and links
preserve the individual conclusions. That aggregate remains outside `CI OK`.
An unrequested portfolio is reported as not run.

## Preparation timing

The manual **Exact-build UI diagnostic** workflow accepts a completed CI run and
explicit source-revision UI selectors. It validates the producing build step and
attempt, repository/branch, artifact availability, then checks the restored commit,
SDK, toolchain, architecture, and source stamps. Missing or incompatible products
fail instead of rebuilding. It runs only selected cases without automatic retries;
its result never changes the original run or establishes standard CI proof.

Command execution uses the job's absolute deadline under
[verification deadlines](../Platform/Verification.md#execution-deadlines). A timed-out
supervisor writes a failed budget receipt in the same diagnostic session, even if
the child never reached Xcode or completed an invocation manifest.
The supervisor also records unsuccessful preparation commands lacking a current
failure receipt. Preparation reports retain the phase, command, elapsed time,
environment identity and a bounded output tail. Simulator boot timeouts classify
as infrastructure, SDK lookup timeouts as tooling; compiler errors and assertions
take precedence over infrastructure noise. Setup failures publish their own
diagnostic artifact even when no build/test step starts.

Unit and native-comparator jobs each set an explicit diagnostics session inherited
by every phase, staging and summary command. Preparation inventory timeouts are
tooling failures, with `simulator-process-inventory` or `output-inventory` phase
context; they do not establish a failed test. Read-only process and worktree
inventories retry a transient timeout once and still refuse cleanup when ownership
cannot be established. Real assertions and source compiler errors retain precedence
when mixed with preparation noise.

Required CI and advisory Player coverage summaries list each job's actual result
and count failed and cancelled jobs separately. Requested execution cannot pass
through a skipped job. Advisory exhaustive coverage remains independent of `CI OK`.

Native Swift Testing failures extract assertions, test identities and source
locations from the event stream, with compiler diagnostics from the raw log.
An interrupted event stream does not discard earlier assertions. Successful native
execution still requires the independent catalog and complete execution/parity
proof; diagnostic extraction cannot turn an incomplete run into success.

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

The shared watchdog tracks top-level starts and completions in log order. A new
Swift Testing run disarms idle finalization inferred from an earlier legacy
XCTest summary; the normal wall deadline still bounds active tests.
The shared watchdog allows 45 seconds of quiet after the terminal test marker
before treating finalization as stalled; `TRINKET_XCODE_IDLE_TIMEOUT_SECONDS`
overrides that limit. Local tests use the same allowance as CI: healthy exports
can take longer than 10 seconds after the suite passes. A passed suite can still
hang during result finalization, leaving an incomplete `.xcresult`. The watchdog bounds that wait and
can report success only after an authoritative `** TEST SUCCEEDED **` or
`** BUILD SUCCEEDED **` action marker. XCTest suite and Swift Testing run summaries
can appear before later tests finish; without a full-action marker, a watchdog kill
returns timeout exit 124. Log-proven success does not prove the bundle finalized or
that motion was correct. Earlier test failures and process crashes still override
later success markers, and zero executed tests cannot establish a test pass.
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

The UI test base attaches one device-screen screenshot and a bounded accessibility
hierarchy directly to the first recorded failure, including XCTest framework
exceptions. If the app is no longer foregrounded, record its state instead of
requesting an unavailable app frame or hierarchy. Warnings do not consume that capture;
attaching evidence to the issue keeps it in failures-only exports. Large hierarchies
retain at most 12,000 characters from each end with an omission marker.

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
UI fixture marks the exact XCTest system snapshot timeout only while waiting for
launch preparation. That phase-qualified signature is eligible for the same single
targeted retry; unmarked query timeouts during gameplay remain test failures.
Failure context records the phase, elapsed time, runtime, and application state.
A snapshot timeout skips another hierarchy query, and an empty XCTest screenshot
is reported as unavailable rather than exported as an empty PNG.
The reporter also attempts a post-invocation simulator screenshot and recent app/test
logs through bounded `simctl` calls while the test lease is held. It verifies the
exact simulator UUID, name, and booted state first; failed capture never changes the
test result. These attachments describe the state after the invocation, not the
exact instant of the test failure.
The original failure manifest/report stay intact until normal successful-artifact cleanup;
`infrastructure_recovery` links the
successful retry and both execution sets. The aggregate validates that proof before
reporting recovery, and preserves the recovered failure in its structured evidence.
Recovered invocations retain both attempts' raw logs, result bundles, and attachments
in the 14-day hosted diagnostic artifact even when the final gate passes. After
staging, verified recovered pairs are cleaned together locally as passing coverage;
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
./Scripts/ci-diagnostics.sh "$RESULTS_DIR"
```

In a separate shell, set `RESULTS_DIR` to that printed path first. Default isolated
directories are keyed by agent slot, not by `TRINKET_RUN_ID`; a run ID alone does
not identify the results directory.

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
and raw logs while retaining failed evidence and recent timing entries.
UI CI jobs retain compact current-job timing and aggregate JSON,
including passing runs; cached timing is cleared before a CI invocation so old
runs cannot be mistaken for the current one. Successful full bundles and screenshots
remain ephemeral. Timing queries are bounded and optional; targeted-test evidence queries are
bounded and fail when execution cannot be established.
Pass `--keep` for a deliberate local investigation. Automatic producer cleanup
records historical failure/orphan candidates for review rather than deleting
unique evidence. [Output retention](../../Scripts/Reference.md#output-retention)
owns the review window, timing expiry, deletion conditions and persistent keep controls.

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
attachments are staged when the aggregate category is failed or unknown, or a
targeted infrastructure retry recovered the run. Use
`python3 ./Scripts/ci-diagnostics.py --full <RESULTS_DIR> <OUTPUT_PATH>` when an investigation
needs the uncompressed aggregate invocation payload.

Artifact staging accepts a fresh or empty destination, or replaces a directory
with its own ownership receipt for the same results directory. It refuses to
replace other nonempty directories; choose a fresh destination for legacy artifacts
without a receipt. Existing symlink and overlapping-directory guards still apply.

Hosted failure artifact names include the run attempt so a rerun can retain new
evidence without colliding with the original upload. Their lifetime, the
repository retention setting and large product-transfer exceptions are owned by
[output retention](../../Scripts/Reference.md#output-retention).

When a merchant smoke failure reports a missing purchase frame, first establish
whether inspection opened the detail sheet at all. Preserve its failed screenshot;
an unopened sheet does not establish a layout defect. Reproduce against the exact
selected Xcode build before changing product gestures. For battle timer failures,
compare the focused case with the complete package: main-actor raster work can
delay unrelated session scheduling, and a focused pass alone does not prove the
concurrent package is healthy.
