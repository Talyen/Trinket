# Scripts

Entry points for Trinket's generated project, verification, asset, and release tooling. The scripts and checked-in configuration are authoritative;
the linked guides explain routing and operating policy.

Runnable commands live directly under `Scripts/`. Imported Python helpers live
under `internal/` (including content, diagnostics, and performance owners);
the trigger-family schema stays with its content parser. `lib/` owns sourced shell
helpers, `config/` owns shared configuration, and `Tests/` owns script regressions.

## Everyday workflow

```sh
./Scripts/agent-context.sh --agent --status --paths <changed-paths...>
./Scripts/handoff.sh --isolate --quiet --paths <changed-paths...>
```

These are the routing and final verification steps. Between them, use the
focused checks appropriate to the task; the [command reference](Reference.md) lists choices,
not a checklist. Pass individual files to `--paths`; directories are rejected
because routing depends on file ownership. Create an execution plan only when durable coordination or
resumption is useful; see [Plans](../Docs/Plans/README.md).

Generation and verification selection follow [Verification](../Docs/Platform/Verification.md).
Add `--smoke` to handoff for its selected UI journeys; ordinary handoff does not
run them. [UI verification requirements](../Docs/Platform/Verification.md#choosing-ui-verification)
own when to select that option. Isolation mechanics live in
[Simulator operations](../Docs/Platform/SimulatorOperations.md); commit and push
safeguards live in [Release](../Docs/Platform/Release.md#local-hooks-and-push-discipline).

Use [CI diagnostics](../Docs/AgentContext/ci-diagnostics.md) after a failure.
Run artifacts are ephemeral by default; use the owning command's keep/cleanup
switches when an investigation needs retained evidence. Preview verification
with `handoff.sh --isolate --quiet --dry-run --paths <files...>` before an unfamiliar route.

## Commands by task

| Task | Focused reference |
|---|---|
| Development | [Generation, builds, discovery, and simulator/device launch](Reference.md#development) |
| Verification | [Package tests, UI checks, handoff, and gates](Reference.md#verification) |
| Assets | [Artwork and media preparation](Reference.md#assets) |
| TestFlight | `./Scripts/testflight.sh` — [one-time setup and recovery](../Docs/Platform/Release.md#local-testflight-deployment) |
| Release | [Release and deploy verification](Reference.md#release) |
| Automated playthroughs | [Manual careers, replay, and comparison](Reference.md#headless-playthroughs) |
| Diagnostics | [Failures, timings, performance, and cleanup](Reference.md#diagnostics) |
| Tooling maintenance | [Internal helpers](Reference.md#internal-helpers) and [toolchain requirements](Reference.md#toolchain-ladder) |

## Script regression ownership

Each Python test module may declare a literal `SCRIPT_INPUTS = ("Scripts/owner.py", ...)`
tuple of repository-relative files or globs. The selector reads it with AST literal
parsing and never imports test modules. Keep ownership beside the tests when adding
or moving coverage; shared consumers combine their selections. Shell-suite mappings
and explicit full-suite exceptions remain in `script_test_selection.py`. Unknown
inputs fall back to the full suite; ownership regressions reject unaccounted leaves
and malformed metadata. Direct edits to a test module select that module.
