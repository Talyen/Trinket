# CI and project-generation context

Use for XcodeGen, build/test commands, CI workflows, simulator problems, or release tooling.

The root workflow owns task-scoped routing: start with
`./Scripts/agent-context.sh --paths <file...>` for a human briefing (`--json` is
machine-readable and `--agent` is the concise handoff form), then preview the
selected checks with `./Scripts/verify-changed.sh --dry-run --paths <same files>` and
run them sequentially by omitting `--dry-run`. Without `--paths`, both commands inspect
the entire working tree; use that mode only when the tree represents one task.

This card adds the CI/project-generation exceptions:

- `verify-changed.sh` runs required generation once, then sets `SKIP_GENERATE=1` for app
  wrapper tests so a single verification run does not regenerate the project repeatedly.
- Do not run wrapper tests in parallel: `test.sh` may invoke XcodeGen and concurrent
  generation collides. Use a filtered command for intentionally narrow work; an affected
  player flow needs `./Scripts/test.sh smoke <Class>`, while bare `smoke` is only the
  local Homestead canary.
- Use `--no-build` only after a matching successful build; the wrappers reject stale
  inputs. Without Xcode 26/simulator, run the applicable generation, generated-output,
  boundary, style, and CI-gate checks and report skipped build/test work.

When a test or CI invocation fails, load
[`ci-diagnostics.md`](ci-diagnostics.md) before inspecting raw logs. Read
`Scripts/README.md` for gate composition and `Docs/Platform/Testing.md` for test
ownership.
