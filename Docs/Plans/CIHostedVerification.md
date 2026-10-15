---
type: execution-plan
status: active
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
- [ ] Finish main CI run `38680834397`; Engine, Content, Battle, and gate pass.
  State fails its external-save-generation fixture's seed assertion. AppState's
  installed cleanup hook removes the stale registration before the intended
  pre-cleanup generation-fence test. Isolate that callback, explicitly require the
  stale registration, and preserve every existing product assertion.
- [ ] Finish exact-build standard run `38681168733`, requiring `27A9275` in every
  lane. A missing candidate is a qualification blocker, never a fallback admission.
- [ ] Finish player coverage `38681171142`: critical phone/iPad profiles, iOS 18
  compatibility, and repeated-play/crash recovery. Review retained visual evidence
  for any UI failures before changing layout or gestures.
- [x] Lightweight handoff passes for the generation-fence fixture repair; compiled
  verification remains hosted.
- [ ] Commit reviewed follow-ups, integrate under the shared lock, push, and verify
  affected jobs. Preserve running evidence until its current checks finish.
- [ ] Update canonical owners, delete this file, and report the outcome and verification in the task handoff.

## Notes

Historical compilation/assertion repairs remain intact. No waits, execution proof,
or accessibility scope have been weakened. Routine local compilation and simulator
work remain deferred to CI. Merchant opening and timing defects require concrete
current failures before further product edits.
