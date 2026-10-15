---
type: execution-plan
status: blocked
reason: Combined main contains unrelated unpushed changes requiring publication approval.
created: 2026-10-15
updated: 2026-10-15
expires: 2026-10-29
---

# Hosted CI verification

## Objective

Verify the CI reliability changes published at `53ef9777f`, investigate concrete
hosted failures, and preserve product assertions and exact-build qualification.
Pushes and workflow dispatches were authorized by the user on October 14.

## Plan

- [x] Verify repository retention is 14 days and artifact expiry respects 14-day
  diagnostics versus one-day products.
- [x] Observe successful qualified selection on both runner inventories:
  Engine/Battle use `27A9275`; Content passes with fallback `27A9269`.
- [x] Inspect main CI run `38680834397`; Engine, Content, Battle, gate, and smoke pass.
  State fails its external-save-generation fixture's seed assertion. AppState's
  installed cleanup hook removes the stale registration before the intended
  pre-cleanup generation-fence test. Repair `3aa1a69e5` isolates that callback,
  explicitly requires the stale registration, and preserves every product assertion.
- [x] Verify the repair in push run `38683089222` at `3aa1a69e5`: green; native Core,
  Persistence, AppState, and all remaining required jobs pass.
- [ ] Dispatch exact-build standard validation after publishing the diagnostic
  follow-up, requiring `27A9275` in every lane. Superseded queued runs `38681168733`
  and `38683100693` were canceled before execution. A missing candidate is a
  qualification blocker, never a fallback admission.
- [ ] Finish player coverage `38681171142`: critical phone/iPad profiles, iOS 18
  compatibility, and repeated-play/crash recovery. Review retained visual evidence
  for any UI failures before changing layout or gestures.
  Soak job `116245844551` fails `Audio-enabled battle must resolve` on its fourth
  contract. Raw log shows query latency rising from about 0.1 to 6–7 seconds near
  the 45-second deadline; retained screenshot shows Victory. Earlier contracts
  finish, all headless cohorts and settlement recovery complete. Keep the deadline
  unchanged until a focused exact-product diagnostic distinguishes battle duration
  from scheduling or UI observation delay. Artifact `11949007677` retains evidence.
  iOS 18 smoke, purchases, recovery and all 394 Persistence tests pass. Largest-text
  profiles fail an inaccessible-text audit on Defeat and reward Continue scrolling.
  Logs prove the scroll helper selected a nested horizontal carousel rather than
  the outer scroll view containing Continue. Repair target ancestry without changing
  scroll counts or visibility assertions. Retain bounded accessibility hierarchies
  alongside failure screenshots to identify the audit's missing semantic surface.
  Artifact `11949777170` retains the original screenshots and raw traces.
- [x] Repair the diagnostic workflow's relocated budget driver: retain its new
  `internal` and `config` dependencies before checking out the source revision.
  A regression executes the actual copy step and confirms failure classification
  and original exit status without relying on checkout dependencies (14 tests pass).
  The driver now admits the existing Soak plan, validates its source selectors,
  and retains the same diagnostic deadline and original test exit status.
- [ ] Publish the diagnostic workflow repair and run the existing repeated-play
  selector against retained products; inspect new visual/log evidence.
- [x] Lightweight handoff passes for the generation-fence fixture repair; compiled
  verification remains hosted.
- [x] Commit reviewed fixture repair, integrate under the shared lock, and push.
  Running smoke evidence completed before the push; player coverage remains intact.
- [ ] Update canonical owners, delete this file, and report the outcome and verification in the task handoff.

## Notes

Publication approval is pending: locked integration incorporated `07bd8ce50`
(atomic save projections) and `0b885b1fe` (typed trigger coding/discovery) alongside
the task follow-ups. Remote main remains `3aa1a69e5` with green CI. Combined local
main at `5d58d6c27` passes outgoing-range lightweight handoff, including script
regressions; generation, compilation, and tests for that combined range remain
hosted work. Preserve all commits. Do not publish unrelated work without the
requested approval. Original critical phone/iPad job remains in progress.

Historical compilation/assertion repairs remain intact. No waits, execution proof,
or accessibility scope have been weakened. Routine local compilation and simulator
work remain deferred to CI. Merchant opening and timing defects require concrete
current failures before further product edits.
