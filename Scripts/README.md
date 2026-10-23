# Scripts

Entry points for Trinket's generated project, verification, asset, and release tooling. The scripts and checked-in configuration are authoritative;
the linked guides explain routing and operating policy.

Runnable commands live directly under `Scripts/`. Imported Python helpers live
under `internal/` (including content, diagnostics, and performance owners);
the trigger-family schema stays with its content parser. `lib/` owns sourced shell
helpers, `config/` owns shared configuration, and `Tests/` owns script regressions.

## Everyday workflow

The [root agent guide](../AGENTS.md#route-and-read) owns the ordinary procedure:
create an isolated task worktree, load a scoped briefing, implement/review/commit,
then integrate locally. Read-only investigations need no worktree. The briefing
supplies safeguards and ownership; ordinary `rg`, file reads and Git diffs handle
navigation. Optional retrieval helpers remain available through their `--help`.

```sh
node Scripts/agent-worktree.mjs create --task <slug>
# In the task checkout:
python3 Scripts/agent-brief.py --status --read --paths <files...>
# Implement, then verify the complete task (scope defaults to main):
./Scripts/handoff.sh --quiet
# Review and commit task files, then land:
node Scripts/agent-worktree.mjs integrate
# After reporting and finishing remaining work:
node Scripts/agent-worktree.mjs cleanup
```

Handoff selects scoped static checks and bounded compiled checks automatically;
`--dry-run` previews the plan. [Verification](../Docs/Platform/Verification.md#confidence-ladder)
owns optional selectors, visual evidence and the difference between local and
hosted results. Integration performs the final static gate and retains the checkout.
[Release](../Docs/Platform/Release.md#isolated-chat-workflow) owns landing recovery
and explicit cleanup. Pushes and publication remain separately authorized.

Ordinary navigation uses `rg`, file reads and Git diffs. The optional retrieval
helpers are compatibility utilities; no task requires learning their command family.

## Commands by task

| Task | Focused reference |
|---|---|
| Development | [Generation, builds, discovery, and simulator/device launch](Reference.md#development) |
| Verification | [Package tests, UI checks, handoff, and gates](Reference.md#verification) |
| Localization | `python3 Scripts/localization.py job`, `finish <response.json> --rationale …`, `check` — [agent workflow](../Docs/Platform/Localization.md) |
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
