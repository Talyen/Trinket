# CI and project-generation context

Use for XcodeGen, build/test commands, CI workflows, simulator problems, or release tooling.

Start with `./Scripts/changed-source-summary.sh` and preview the route with `./Scripts/verify-changed.sh --dry-run`. `verify-changed.sh` runs generation first, then uses `SKIP_GENERATE=1` for app wrapper tests so generation occurs once per verification run.

The wrapper chooses the broadest affected source layer. For an intentionally narrow change, use the task-specific filtered test command instead of treating the wrapper as a substitute for judgment.

| Goal | Command |
|---|---|
| Format/lint/style | `./Scripts/test.sh style` |
| One package | `./Scripts/test-package.sh <Package>` |
| App orchestration | `./Scripts/test.sh unit <Class>` |
| Local UI canary | `./Scripts/test.sh smoke` |
| Pre-push | `./Scripts/ci-locally.sh` |
| Pre-merge | `./Scripts/test-deploy.sh` |

Do not run wrapper tests in parallel: `test.sh` can regenerate the project and concurrent XcodeGen work collides. Use `--no-build` only after a matching successful build; the scripts reject stale inputs. Quiet test output writes raw logs to `.DerivedData/TestResults/` and prints a concise failure summary.

Read `Scripts/README.md` for gate composition and `Docs/Platform/Testing.md` for test ownership. Without Xcode 26/simulator, run generation, generated-output assertion, module-boundary, UI-style, and CI-gate checks that apply; state skipped build/test work.
