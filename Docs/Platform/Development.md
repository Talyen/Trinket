# Development workflow

Task checkouts, local integration, evidence preservation, and Git hooks.
[AGENTS.md](../../AGENTS.md#route-and-read) owns the implementation loop and
authorization; [Verification](Verification.md) owns check selection and completion.
Release and TestFlight operations live in [Release](Release.md).

## Commit messages

Use an imperative subject, preferably:

```text
<type>(<scope>): <subject no longer than 72 characters>

- <notable change>
```

Supported types are `feat`, `fix`, `perf`, `refactor`, `content`, `style`,
`test`, `ci`, `chore`, `build`, and `docs` (`build` and `chore` are excluded
from release notes). Plain imperative subjects remain supported.
Prefer `feat` or `fix` when a change is player-visible; use `refactor` for
internal reshaping. Player-facing notes are inferred from commit type and
touched paths at release time.

## Isolated chat workflow

Follow [AGENTS.md](../../AGENTS.md#route-and-read) for the task workflow and
[workspace safeguards](../../AGENTS.md#protect-the-workspace) for authorization and
isolation. Read-only investigations need no worktree. This section owns landing,
recovery and cleanup; [command help](../../Scripts/Reference.md#development) owns options.

Use `--base <ref>` at creation only for a user-specified alternative. Reuse only
this chat's suitable checkout; existing branches/directories are preserved.
Installed tools resolve from the task checkout, then primary checkout, then PATH;
version/checksum pins still apply. No PATH setup is needed. Missing tools use
`./Scripts/ensure-ci-tools.sh`; lookup never installs implicitly. Build products
and generated resources stay checkout-local. Simulator leases remain shared
across isolated checkouts.

New task checkouts automatically omit `AssetSources/` when the target revision
has the prepared-output build/CI contract and committed runtime media. Prepared
catalogs, app icons, audio, code and tests remain present. Older/incomplete revisions
fall back to a full checkout. Use `create --task <slug> --full-assets` for asset
production, or run `git sparse-checkout disable` inside an existing task before
source checks, regeneration or authoring. Missing-source preparation fails before
publishing outputs and prints this restoration command.

Large retained tracked assets (at least 256 KiB) use per-file APFS copy-on-write
when a same-commit, clean source file is available in primary. The optional Python
standard-library bridge calls Apple's `clonefile`; unsupported platforms, volumes,
missing Python, dirty/mismatched sources and checkout filters use normal Git.
Each clone is verified against the target blob and executable mode. Git creates
its own index and refreshes normal status; dependencies/build caches are not copied.
Concurrent creations use Git's registration/index locks. Creation reports omitted
and cloned logical bytes plus population/first-status time; these are not physical
savings because APFS shares extents. Existing checkouts are never converted.

### Landing and review

Review the full task diff and relevant consumers, then commit only task files.
The integration helper holds a nonblocking OS lock in Git's common directory,
requires a clean task checkout on `codex/` and clean primary main with no unfinished
Git operations, and rebases the task onto current main. If main advanced, it
pauses before landing so the combined work can be reviewed and affected verification
refreshed. Retry after that review. To avoid a redundant checkpoint when current
main was already reviewed against the task, pass `integrate --reviewed-main <commit>`;
the helper rejects a later main advance before rebasing or landing.

For API/combat migrations, repeat the [consumer review](Testing.md#fixtures) after
incorporating main, including unchanged downstream tests and shared fixtures.
A clean textual rebase is not semantic or compiled evidence.

Integration does not require or launch local compilation or package tests; those
remain hosted obligations. Review the combined result, refresh affected lightweight
[handoff](Verification.md#confidence-ladder) checks outside the lock and reassess
visual evidence after relevant changes. Integration then runs a final **static**
handoff with plan closure under the lock,
rechecks both checkouts and ignored-file collisions, then fast-forwards main.
Use this helper for every automated local landing. It does not fetch, push or run
hosted checks. The lock is cooperative; keep manual main edits out of the landing
window. Never delete the lock file. A busy lock means retry later without messaging
peers. Dirty main remains untouched: preserve committed task work and report the
blocker if it persists. Resolve understood rebase conflicts only in the task checkout;
bring ambiguous behavior decisions to the user. A failed check leaves main unchanged.
For maintenance of an intentionally unfinished plan, use `integrate --keep-plan`.
It forwards handoff's explicit retention choice; metadata, links and all other
landing checks still run. Keep the plan's actual status and remaining work intact.

### Evidence and cleanup

Final landing preserves evidence and removes the invoking task checkout when its
ignored files are classified for safe removal. Use `integrate --keep-worktree` for an intermediate
landing or when further work needs the checkout. Completion follows
[Verification](Verification.md#completion-states), including required visual evidence.
Automatic cleanup stops if ignored files are not classified as preserved deliverables,
disposable Python bytecode, or byte-identical tools independently present in primary.
Review and preserve other ignored files before explicit cleanup.

Handoff writes verification reports automatically. Integration adds `task-report.json`
with the local completion state, main base, task paths and evidence links, and copies
`.DerivedData/Deliverables/` to Git's shared `trinket-evidence/<branch>/` directory.
Snapshots have preservation commit/branch/path metadata and never follow
symlinks. Repeated preservation at the same commit reuses an identical snapshot
only after comparing actual source and retained bytes. A separate
`preservations.jsonl` records each preservation event; changed or damaged snapshots
are preserved separately. New evidence files use independent copy-on-write clones
when supported, falling back to ordinary copies; both are verified against the
source. Unchanged files in a later snapshot can clone a verified earlier file;
each new manifest records file hashes, while paths and independent writes remain.
No mutable hard links are used. After completed worktree cleanup, newly
classified successful static handoff reports expire after seven days during later
task creation; their original snapshot inventory and expiry journal remain.
Legacy snapshots can also expire successful static reports when an integrated
task record, matching commit and report path establish provenance. Old snapshots
did not record whether a report was explicitly requested, so unmarked legacy
reports meeting those conditions also expire. New explicit evidence requests,
keep markers, failures, visual or release evidence, unclassifiable reports and
active tasks remain.
The task report's verification-report paths can therefore expire. Failed
preservation stops landing or cleanup; raw build logs expire
separately. Save visual artifacts in Deliverables. For other task-local evidence,
use `node Scripts/agent-worktree.mjs evidence <paths...>`; without paths it prints
the durable directory. Evidence provenance still comes from the capture/build record.

When a kept checkout is no longer needed, or automatic cleanup failed, run
`cleanup` there. It preserves
deliverables again and removes only this clean, registered, integrated task worktree,
including ignored outputs; it retains the branch and never changes primary main.
It refuses unmerged/dirty tasks, locked worktrees, submodules, unsafe registrations,
foreign processes using the checkout, and unavailable process/open-file inventories.
It can run after main advances or while primary files are dirty. A cleanup failure
does not roll back landing; inspect the reported path and retry cleanup.

Removal first moves the checkout to a temporary directory under
`~/.codex/worktree-archives/Trinket/`, unregisters it, then deletes that temporary
copy. Failed unregistration restores the checkout. `CODEX_WORKTREE_ARCHIVE_ROOT`
can select another external staging directory; cross-filesystem moves fail without
deleting the source. `recovery.json` identifies the original checkout, branch and
commit. Recover tracked work with `git worktree add <path> <branch>`; ignored files
are permanently deleted by successful cleanup. Legacy `remove --task <slug>` from
primary remains supported and refuses ignored files as well as dirty/unmerged work.

## Local hooks and push discipline

The Git safety shim refuses destructive commands on a dirty tree without
stashing files or changing the index. Leading Git options such as `-C` and `-c`
apply to both its checks and the requested command.

`git config core.hooksPath .githooks` enables the advisory commit-message hook,
staged-project validation, and pre-push checks. Generation and idempotence policy
lives in [Verification.md](Verification.md#generated-project-consistency); the hooks
enforce staged-project completeness at commit time. Pre-push styles Swift files in
the commits being pushed (platform bans stay full-tree) and checks committed
generated-output completeness. Asset-routed pushes also check selected repository
`AssetSources/` masters for freshness; other pushes check prepared outputs alone.
Prepare changed media and include selected masters before an asset-routed push;
[media preparation](../AgentContext/content-and-manifests.md#media-assets) owns that workflow.
Pre-push does not regenerate assets or run package tests.
Select local and hosted checks through the [confidence ladder](Verification.md#confidence-ladder).
A requested push still requires a green path-scoped
handoff for the complete task; successful locked integration supplies the final
static gate, with compiled qualification deferred to CI. A standalone task must
run handoff explicitly. Review and include only task-related
authored and generated files; stage individual hunks when task and unrelated changes share a file.

Pre-push validates Git's outgoing ref/object pairs against the checked-out HEAD
and requires a clean checkout, including nonignored untracked files. It fails on
unavailable revisions or failed Git inspection; new remote refs select their full
tree, and deletions and both rename endpoints remain in scope. Checks revalidate
source before reporting success. Preserve outstanding work rather than clearing
it to pass the hook.

Pre-push invokes `agent-push-gate.sh` internally with that outgoing scope; do not
run it manually after commit. Landing policy remains in [AGENTS.md](../../AGENTS.md#protect-the-workspace).

Direct pushes to `main` retain inexpensive pre-push safeguards: scoped style and
committed generated-output completeness, plus the asset checks described above.
The [verification report](Verification.md#failures-and-reporting) lists executed and deferred checks;
watch CI for the deferred obligations after an authorized push. The hook implements `SKIP_TRINKET_PREPUSH=1` as a
manual bypass, but it does not satisfy the required verification or authorize
skipping checks during routine agent work. Report blocked checks under
[Verification.md](Verification.md#failures-and-reporting).

TestFlight uploads use the [local deployment command](Release.md#local-testflight-deployment).
App Store submission remains a separate owner-requested action.
