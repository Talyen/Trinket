# Scripts

Entry points for Trinket's generated project, verification, asset, and release tooling. The scripts and checked-in configuration are authoritative;
the linked guides explain routing and operating policy.

Runnable commands live directly under `Scripts/`. Imported Python helpers live
under `internal/` (including content, diagnostics, and performance owners);
the trigger-family schema stays with its content parser. `lib/` owns sourced shell
helpers, `config/` owns shared configuration, and `Tests/` owns script regressions.

## Everyday workflow

Implementation chats start in an isolated worktree with
`node Scripts/agent-worktree.mjs create --task <slug>` (or reuse their own suitable
worktree). Work and commit there, then run `node Scripts/agent-worktree.mjs integrate`
there to verify and land into local `main` under the shared integration lock.
[Isolated chat workflow](../Docs/Platform/Release.md#isolated-chat-workflow) owns
failure recovery, authorization, and the quiet communication policy. Push separately
only when requested. Read-only investigations do not need a new worktree.

Use ordinary scoped search, reads and Git diffs. Before editing intended files,
load their safeguards with `python3 Scripts/agent-brief.py --status --read --paths
<files...>`. Concern shortcuts and specialized retrieval helpers are optional;
[quickstart](../Docs/AgentContext/README.md#quickstart) owns their use.

For the complete task, including committed and dirty work:

```sh
python3 Scripts/agent-brief.py --status --read --base main
./Scripts/handoff.sh --isolate --quiet --base main
```

Use the user-specified base when different. Explicit `--paths <files...>` remains
available for focused checks. Handoff reports each kind of verification evidence
and the next permitted action; a local pass establishes lightweight checks only.
Create an execution plan only when durable coordination or resumption is useful.

Generation and verification selection follow [Verification](../Docs/Platform/Verification.md).
Routine handoff runs lightweight scoped static/script checks without compilation
or Simulator. Add `--smoke` to identify the selected CI-owned UI journeys; local
execution reports them as deferred. [UI verification requirements](../Docs/Platform/Verification.md#choosing-ui-verification)
own when to select that option. Isolation mechanics live in
[Simulator operations](../Docs/Platform/SimulatorOperations.md); commit and push
safeguards live in [Release](../Docs/Platform/Release.md#local-hooks-and-push-discipline).

Use [CI diagnostics](../Docs/AgentContext/ci-diagnostics.md) after a failure.
Successful logs are removed after their consumers finish. Failure, comparison,
and timing evidence expires after 24 hours; use the
[output keep/release controls](Reference.md#output-retention) for active investigations. Preview verification
with `handoff.sh --isolate --quiet --dry-run --paths <files...>` before an unfamiliar route.

## Commands by task

| Task | Focused reference |
|---|---|
| Development | [Generation, builds, discovery, and simulator/device launch](Reference.md#development) |
| Verification | [Package tests, UI checks, handoff, and gates](Reference.md#verification) |
| Localization | `python3 Scripts/localization.py plan`, `apply <response.json>`, `check` — [agent workflow](../Docs/Platform/Localization.md) |
| Assets | [Artwork and media preparation](Reference.md#assets) |
| TestFlight | `./Scripts/testflight.sh` — [one-time setup and recovery](../Docs/Platform/Release.md#local-testflight-deployment) |
| Release | [Release and deploy verification](Reference.md#release) |
| Automated playthroughs | [Manual careers, replay, and comparison](Reference.md#headless-playthroughs) |
| Diagnostics | [Failures, timings, performance, and cleanup](Reference.md#diagnostics) |
| Tooling maintenance | [Internal helpers](Reference.md#internal-helpers) and [toolchain requirements](Reference.md#toolchain-ladder) |

## Script regression ownership

Use the three questions in [Testing.md](../Docs/Platform/Testing.md#coverage-decision-new-and-changed-behavior)
for script-test additions and retirement.

[script-regressions.tsv](config/script-regressions.tsv) maps each repository-relative
input file or glob to comma-separated test suite basenames. Keep one row per input;
list all consumers together when adding or moving coverage. Python and shell suites
share this registry, which the selector validates without importing test modules.
Literal directories, duplicate inputs, and malformed suite names are rejected.
List direct inputs even when a shared source already takes the full-suite route.
Explicit full-suite exceptions remain in `script_test_selection.py`; changing the
registry itself runs the full suite. Unknown script and infrastructure inputs fall
back to the full suite. Unrelated product paths use their own gates unless claimed
in the registry. Ownership regressions reject unaccounted leaves, missing consumers,
and malformed metadata. Direct edits to a test module select that module.

Python workers use `script_test_execution.py` to require at least one successful
test or subtest per selected module. Empty or entirely skipped modules fail rather
than providing false coverage. Individual unavailable cases can still skip within
an executing module.

## Player coverage automation

`player-coverage.sh ios18|compact|tablet|duo|soak` owns minimum-OS compatibility,
serial settings profiles, and weekly functional soak/recovery. It is CI-owned and respects the heavy-local policy.
[Player coverage](../Docs/Platform/PlayerCoverage.md) owns scenarios, cadence,
explicit profile prerequisites, and evidence limitations. UI membership is authored
in `config/ui-tests.tsv`; Profiles and Soak stay outside routine FullUI.
