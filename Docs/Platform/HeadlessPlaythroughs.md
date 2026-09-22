# Headless playthrough testing

The manual playthrough runner develops a private, real SwiftData save through
production AppState, encounter, BattleSession, and persistence commands. It runs
inside an owned iOS Simulator test process without constructing a SwiftUI view
tree. The runtime still uses Apple frameworks and its normal presentation models;
this is not a macOS/Linux port or UI verification.

## Running

Commands and flags belong to [Scripts](../../Scripts/Reference.md#headless-playthroughs).
The default scenario selects Knight and Wolf through onboarding, plays two settled
Campaign attempts, spends earned talent points and equipment, considers one
Homestead investment per attempt, advances one simulated hour, collects production,
and reopens the private save after each attempt. Defeat leaves the encounter
available; a subsequent attempt may legally retry it. An objective counts settled
attempts, not victories. Campaign completion before an oversized attempt horizon
is reported as unsupported, rather than inventing more content.

Use `--full-access` for simulated ownership; default careers use free access from
onboarding. Policies are `greedy-v1`, `setupAware-v1`, `random-v1` (a separate policy
random stream), and `rotation-v1` (rotate toward the lowest-level earned party).
Select a mode and a legal starter pair explicitly. A party with no attuned Spire,
a locked encounter, or an unavailable choice produces an incomplete result.

Every output career includes its complete `scenario.json`; copy and edit that file
and pass `--scenario` to change action, turn, step, evidence, or simulated-time
budgets. A supplied scenario overrides CLI defaults; `--scenarios` runs consecutive
world seeds. Seed selection is not filtered for wins. Each career runs in a new
process, sequentially under a managed Simulator lease. Ordinary package tests run
only bounded correctness cases; `PlaythroughSweepTests` is disabled unless the
wrapper supplies its private request file.

## Production boundaries and determinism

The test controller chooses among observed actions. It never grants progress,
inserts victories, alters enemy health, or calls mode completion to bypass a battle.
Targeted correctness fixtures are explicitly separate from fresh career reports.
Equipment uses the same edit operation as Collection; talent, Shop, Mystery,
Contracts, and Homestead actions use their owning production operations.

Battle seeds are journaled with each launch before command execution. Mystery and
Contract streams derive independently from the recorded world seed and action
sequence (`worldSeed XOR sequence XOR 0x4954454D` for items and `0x434F4E54` for
Contracts). Contract IDs use the world seed, action sequence, and offer index;
production identity validation remains enabled. Policy randomness never samples a
gameplay stream. Economic dates come from the scenario clock, including Mystery
settlement. Battle configuration and talent-confirmation UUIDs remain transient;
replay resolves their current identities instead of removing identity checks.

Auto-battle is disabled. The controller cancels scheduled auto-end turns after
every command and uses zero-delay outcome presentation through existing session
injection points. It checks session readiness, submits real card/turn commands,
claims rewards, finishes presentation, and ends runtime work at teardown.

Snapshots compare the full production `CloudSaveSnapshot` domain: roster builds,
progression, inventory, equipment, all mode progress, claims/offers, Homestead,
world seed, and onboarding. Only write-time `modifiedAt` and local
`sessionGeneration` bookkeeping are excluded. Embedded offer payloads normalize
JSON dictionary ordering and the known unordered `keywords` sets; no gameplay
field, offer order, or malformed payload is discarded. Immediate reload comparison
happens before further gameplay, with graph/sanitizer and durable-backend checks.
The correctness suite also compares uninterrupted A, unrelated B, and reloaded A.

## Evidence and replay

`actions.jsonl` flushes an attempted action before execution and records its result
separately afterward. Records contain semantic save and combat observations.
A missing result means **unknown outcome**, not rejection. Limits preserve the
entire journal suffix; reaching a bound produces an incomplete result.

`checkpoint/` preserves the initial closed private database and its sidecars.
`store/` retains the last written private database, recovery records, and sidecars.
Replay currently starts from the recorded fresh career inputs; it executes recorded
actions rather than rerunning the policy. This deliberately avoids adding a
mid-battle save or a second checkpoint-continuation format. In-process reloads keep
the live policy/RNG cursors and simulated clock. Isolated defaults begin empty;
no scenario changes Options, and silent runtime dependencies override audiovisual
preferences. No player save, real purchase, or iCloud container is used.

The crash proof terminates the owned test worker after launch consumes its seed,
and separately after a victory commits, before the command result is journaled.
It copies the entire closed store directory before opening disposable copies.
Fresh workers replay the action history and compare recovered committed state.
No scene/background callback or final save runs at termination. Xcode may wait
for diagnostics after an intentional exit; a durable interruption marker lets the
wrapper stop its own Xcode process after ten seconds. The general external watchdog
also identifies and stops only its registered test worker and owned process group.
In-process primary/total-write failure tests remain distinct from this proof.

Exact replay is a same-input/code/content experiment. `identity.json` records
commit, dirty-change hash, OS, Xcode, Swift, and booted runtime identity. Changed-code
replay reports the first divergence and is a regression experiment. Preserve a
failing directory before inspection; store initialization may recover and repair
files. A replay that reproduces a recorded rejection reports `reproducedFailure`,
never `completedObjective`.

## Reports and interpretation

Read `report-agent.md` first. This preview is bounded to 12,000 characters and
contains experiment identity, aggregate metrics, confidence, limitations, findings,
and next experiments. Warnings precede informational findings. It shows at most
five highest-frequency failure contexts and five seed/attempt examples, discloses
omitted blocks and shortened fields, and links to complete collections by JSON
field path. All findings are calculated from complete data before preview selection.

`report-agent.json` retains the complete derived analysis, including growing
attempt trajectories, outcome sequences, stage counts, and paired transitions.
It does not include worker summaries, action journals, logs, test bundles, or
private store contents. `report.html` presents insights for human review, and
`report.json` retains the full structured worker result for local diagnostics and
tooling.

The report generator derives planned, completed, and incomplete counts; career and
attempt outcomes; retry sequences; reached encounters; turns/actions;
observed/playable/chosen cards; Gold earned/spent; equipment changes, talents,
Homestead upgrades; simulated cadence; and process/worker wall time. It also
generates sample-size confidence, economy-coverage warnings, full attempt-trajectory
comparisons, late-run regression findings, compact failure contexts by encounter and
enemy, memory-budget findings, baseline effects, and context-aware next-experiment
recommendations. Failure contexts include bounded seed/attempt examples for targeted
follow-up; raw journals remain omitted.
`cardsDrawn` reads the engine's newly dealt card identity counter, including
buffered/automatic cards; `cardsObserved` counts distinct visible or buffered IDs,
and `playableObservations` counts legal cards at command boundaries, so those are
intentionally different metrics. Zero milestones remain in the reports with the
configured horizon.

Raw evidence remains available under each worker for replay and forensic debugging,
but is deliberately omitted from the agent report. Retrieve only a named career
and bounded evidence range when investigating a specific anomaly; do not dump a
whole `actions.jsonl`, `.xcresult`, log, checkpoint, or store into agent context.

Baseline comparison requires identical scenario settings and seed populations.
The policy may differ intentionally for a paired policy comparison. Reports retain
paired outcomes and Gold effects; uncertainty uses careers, not correlated battles.
The Wilson interval for careers reaching a victory is conditional on completed
careers, whose denominator is explicit; incomplete careers remain visible
separately. A single career supplies no estimated standard error for an economy
difference. Thresholds are advisory; confirm anomalies with more seeds and another
policy before making a balance claim. No automation or balance CI gate is installed.

## Coverage and execution budget

| Area | Retained coverage |
|---|---|
| Fresh progression | Onboarding, earned victories/defeats, recruit/Mystery/Shop choices, talents, equipment and Homestead investment; free and simulated-full cohorts |
| Battle lifecycle | Real commands, readiness, Retry/Leave/retreat, stale configuration, duplicate victory, primary-write recovery and total-write compensation/retry |
| Modes | Campaign reachability, attuned Spire floors, reachable persistent Labyrinth nodes, renewable Contracts and offer identities |
| Storage | Immediate file-backed reload, uninterrupted/reloaded comparison, A/B/A isolation, actual owned-worker interruption and fresh-process recovery/replay |
| Time | Explicit session cadence, collection, build/upgrade target tiers, persisted production state |
| Limits | Action/turn/step/evidence bounds, unsupported/rejected actions, external watchdog, zero-test/missing-result rejection |

Focused production owners retain their deeper matrices: `PlayerHomesteadStoreTests`,
`ShopPurchaseApplierTests`, Contracts tests, roster/sanitizer tests, and AppState
encounter tests. Voyage is not supported by the current headless career runner;
its mode coverage remains with the focused package tests. The runner does not
duplicate all rare-state fixtures or promise
exhaustion of builds, renewable Contracts, or infinite Labyrinth depth. CloudKit,
StoreKit delivery, UI wiring/accessibility, art/audio, and device behavior retain
their separate verification routes.

Initial measurements on 2026-09-19 (Xcode 27 Simulator, Debug): baseline AppState
package build/test was 23 seconds; warm manual two/three-attempt workers took about
3.6–4.0 seconds including process startup, with roughly 0.13–0.20 seconds in careers.
A 20-attempt full-access setup-aware Campaign career settled 19 victories and one
defeat, reached Chapter 4, performed 20 reloads, earned 12 talent unlocks and seven
Homestead upgrades: about 4.4 seconds in the career, 8.1 seconds including startup,
and 17 MiB of journal evidence. Two four-attempt rotation workers peaked near
279 MiB resident memory; use 512 MiB as an initial advisory worker budget. Peak
resident memory is recorded per worker, including framework startup. Cold clean
compilation was not measured; no native-port decision depends on that cost. These are feasibility measurements, not game
performance targets. Defaults are 180 seconds externally, 2,000 actions, 100 turns
per battle, 200 career steps, and 32 MiB journal evidence. Keep workers sequential
on the managed host; native hosting/parallelism is unnecessary at this throughput.
