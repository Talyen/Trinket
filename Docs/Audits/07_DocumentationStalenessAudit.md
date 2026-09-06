# 07. Documentation Staleness Audit

**Goal:** Repair documentation that misleads execution or maintenance through wrong
claims, broken references, consequential omissions, or drifting duplicated policy.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
The [documentation map](../README.md) owns sources of truth and policy precedence.

## Evidence and remedy

Confirm a mismatch against the relevant configuration, script interface, source
contract, product decision, or canonical guide. Executable behavior establishes what
runs, not necessarily what should run: inspect intent before changing prose to match
a potentially defective implementation. If intent remains ambiguous, state the
conflict and decision needed rather than silently choosing a side.

A missing instruction is a finding when the intended workflow needs it to succeed
or avoid a concrete mistake. Once a fact or workflow is confirmed wrong, update its
material authored references and remove duplicated policy where a canonical link
serves better. Broken paths, anchors, commands, version claims, and audit routing
are useful leads; cosmetic rewriting is not the goal.

## Boundaries and verification

- Do not hand-edit `CHANGELOG.md`; release tooling owns it.
- Resolve relative links from their source file and verify heading anchors. Check
  command examples and behavioral claims against their actual owners; link checks
  alone cannot prove instructions correct.
- Check external sources when changing their claims and network is available;
  an unavailable endpoint alone does not prove staleness.
- Keep audit guides procedural. Remove embedded run logs, Done tables, and dated
  execution trackers. Run outcomes belong in handoffs/commits/PRs;
  [Proposals.md](Proposals.md) holds only decisions and intentional exceptions.
- Reconcile an obsolete memory pointer with the current owner before pruning it;
  a renamed symbol need not invalidate the decision it records.

Success is a usable, consistent workflow or corrected fact at its authoritative
owner and affected references. Preserve useful design rationale; do not broaden
this into style-only prose cleanup.
