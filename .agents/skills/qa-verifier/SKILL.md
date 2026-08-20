---
name: qa-verifier
description: Mid-Task Fast Iteration & Test Router. Auto-triggers post-edit during active development to select and execute the cheapest suitable test tier per Docs/Platform/Verification.md, reserving full handoff.sh for task completion.
---

# Mid-Task Fast Iteration & Test Router

Select and execute the fastest, cheapest verification command for modified paths during mid-task iteration, adhering to the project's confidence ladder.

## Trigger Scenarios

Auto-triggers when:
- Code edits have been applied during mid-task development.
- Verifying a localized bug fix before handoff.

## Execution Steps

1. **Inspect Changed Paths**:
   - Check modified files:
     ```bash
     git diff --name-only HEAD
     ```

2. **Select Cheapest Tier (per `Docs/Platform/Verification.md`)**:
   - **Single SPM Package** (`Packages/<Package>/...`):
     ```bash
     ./Scripts/test-package.sh <Package>
     ```
   - **App Shell Only** (`Trinket/...`):
     ```bash
     ./Scripts/test.sh unit --app-only
     ```
   - **All Unit Schemes**:
     ```bash
     ./Scripts/test.sh unit
     ```
   - **Scripts / Project Config**:
     ```bash
     ./Scripts/ci-gate.sh
     ```

3. **Use Mid-Task Optimization**:
   - On mid-task re-runs in the same slot after a green isolated build, append `--no-build` for fast feedback.

4. **Reserve Handoff for Completion**:
   - Remember that final task completion requires canonical path-scoped handoff:
     ```bash
     ./Scripts/handoff.sh --isolate --paths <touched-files...>
     ```
