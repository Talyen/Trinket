# Agent token-efficiency evaluation

Use [agent-efficiency.py](../../Scripts/agent-efficiency.py) for reproducible
retrieval measurements and controlled complete-task report comparison. Commands
and request strings live in its `SCENARIOS`; this guide owns interpretation.

## Retrieval probes

Run against immutable text snapshots containing the same current product inputs,
Git inventory, and script dependencies. Apply only the candidate guidance and
retrieval-tool changes to the candidate snapshot. A dirty primary checkout is
not a stable before/after source baseline. These read-only probes require no
Swift compilation, Simulator, generated project, or autonomous agent.

```sh
python3 Scripts/agent-efficiency.py probe --root /tmp/baseline --output /tmp/before.json
python3 Scripts/agent-efficiency.py probe --root /tmp/candidate --output /tmp/after.json
python3 Scripts/agent-efficiency.py compare /tmp/before.json /tmp/after.json
```

Each workflow routes an owner, reads the listed applicable guides/contracts,
looks up source and test mentions, and reads up to 80 owner-source lines. Root
guidance is already injected; skills and knowledge stay trigger-based. Large
unanchored contracts are read completely rather than counting an outline as a
read. Current tools use batching and related lookup; older tools use individual
reads and separate source/test searches. The report records every command, exit,
actual output size, read target, and handoff command. Comparisons reject changed
product inputs, requests, scenario versions, or verification commands.

Characters and command counts describe these retrieval workflows only. They
exclude reasoning, agent-selected follow-up reads, implementation, and actual
token usage. A successful probe does not prove that a feature task was completed
correctly. Review retained constraints and regression evidence alongside counts.

## Complete-task comparison

For actual agent trials, follow the controlled setup in [the evaluation guide](README.md):
hold starting code, request, model, reasoning, tools, and acceptance criteria
constant; change only guidance/retrieval tooling. Use disposable evaluations,
keeping their implementation out of the product checkout. Include both trial
branches of each repeated scenario; do not select only the best candidate run.

Use the combat, Shop, persistence, and tooling requests from `SCENARIOS` for
bounded read-only investigations, or the existing [Battle effect](eval-01-battle-effect.md)
and [Shop flow](eval-02-shop-flow.md) fixtures for implementation trials. Judge
correctness and completion from the resulting explanation/diff and relevant
verification, independently of usage. Investigations must identify ownership,
relevant callers and tests, and applicable game/save constraints; textual test
mentions alone do not establish coverage.

Save one report per side with this shape. Fill placeholders from the trial's
actual configuration, provider usage, transcript, and evaluated result; missing
measurements remain `null` and cannot produce a valid token comparison.

```json
{
  "kind": "task",
  "context": {
    "source_sha256": "same starting product-input fingerprint on both sides",
    "model": "exact model identifier",
    "reasoning": "actual setting",
    "tools": ["same enabled tools and configuration"]
  },
  "tasks": [{
    "id": "combat",
    "request": "identical complete request on both sides",
    "correct": null,
    "complete": null,
    "evidence": "transcript, diff, verification, and independent acceptance evidence",
    "metrics": {
      "total_tokens": null,
      "repeated_reads": null,
      "retries": null,
      "failed_commands": null,
      "unnecessary_stops": null
    }
  }]
}
```

`total_tokens` is actual input plus output usage for the entire trial, using the
same provider accounting on both sides; never estimate it from characters.
Repeated reads count additional reads of unchanged overlapping content; retries
count repeated attempts of the same operation after failure; failed commands
count nonzero tool/command results; unnecessary stops count approval/clarification
stops where the supplied task already resolved the decision. Record how these
were extracted with the evidence. Use distinct IDs for repetitions.

`compare` requires matching context, task IDs, and requests and all measured
nonnegative integer metrics. It exits unsuccessfully if either side lacks
correctness or completion, even when the candidate spends fewer tokens. The
comparator validates supplied reports; it does not independently judge code or
authenticate provider usage. No fixed savings target or automatic recurring
benchmark is introduced.

### Collecting actual task usage

Prepare a manifest on each immutable starting snapshot, then run the same requests
with the same model, reasoning, tools and acceptance criteria. Keep trial work and
artifacts out of the primary checkout. The repository tools do not launch agents.

```sh
python3 Scripts/agent-efficiency.py prepare --root /tmp/baseline --repetitions 3 --output /tmp/baseline-trial.json
python3 Scripts/agent-efficiency.py collect /tmp/baseline-trial.json --output /tmp/baseline-tasks.json
python3 Scripts/agent-efficiency.py compare /tmp/baseline-tasks.json /tmp/candidate-tasks.json
```

`prepare` pins the product fingerprint and four requests but leaves settings,
judgements and measurements null. Fill settings and independently judge each
result; record transcript/diff/verification evidence and the extraction method for
repeated reads, retries, failed commands and unnecessary stops. Add repetitions
with distinct task IDs, retaining every outcome, including failed/incomplete work.
`--repetitions` prepares those IDs and an explicit investigation acceptance checklist.
Use the same checklist on both sides; provider exports and independent judgements
remain required. Preparing a manifest does not run a trial or measure usage.

For each task, add `usage_file` (relative to the manifest or absolute) and
`usage_evidence` describing the provider export and its accounting. Normalize
actual exported final per-response usage into a JSON array such as:

```json
[{"id": "provider-response-id", "input_tokens": 123, "output_tokens": 45}]
```

The numbers above illustrate the schema, not measured results. Include every
response from the whole task, including retries. Use one final row per response,
not cumulative samples. Input includes its cached-token subset and output includes
its reasoning-token subset under the provider's accounting; do not add either
subset again. Preserve the original export and normalization method as evidence.

`collect` rejects missing, negative or boolean token counts, repeated
response IDs within or across tasks, and totals that disagree with the export. It records
the export SHA-256 and response count, computes input plus output usage, and
validates the remaining report fields. False correctness/completion judgements
remain recordable and make comparison fail. Collection validates the supplied
data; it cannot authenticate an export, prove all responses were included, or
independently judge completion. Do not substitute retrieval character counts.

## October 2 results

Compared immutable snapshots of 2,178 text files from the current dirty checkout,
with only this change's guidance/retrieval inputs overlaid on the candidate.
The product-input fingerprint and every selected handoff command matched. Both
contracts retained every existing non-heading line; mixed-owner regression probes
retain broad hub references and shared safety sections.

| Workflow | Output characters before → after | Commands before → after |
| --- | ---: | ---: |
| Combat | 22,797 → 16,634 (27.0% less) | 7 → 4 |
| Shop | 11,476 → 11,549 (0.6% more) | 6 → 4 |
| Persistence | 32,447 → 24,432 (24.7% less) | 8 → 4 |
| Tooling | 3,796 → 4,005 (5.5% more) | 4 → 3 |
| Combined | 70,516 → 56,620 (19.7% less) | 25 → 15 |

All commands succeeded. Batching reduces invocation count; related lookup adds
labels and coverage caveats, so the smaller workflows can emit more text.
Optional fingerprints and glob recovery are covered by executable regressions
but are not exercised by these four probes. Root-injected guidance, optional
skills/knowledge, and actual agent reasoning/follow-up work are excluded as
described above. Complete agent trials and total task-token savings remain
unmeasured; the complete-task comparator is covered with synthetic report fixtures.

### Follow-up retrieval evidence

This pass compared immutable copies of 2,187 starting text inputs from the dirty
checkout, overlaying only the new retrieval/guidance changes. The product
fingerprint on both sides was
`2e45e1a59c83aba19cb7f09ed8aceac7460fa8f0887c58f9036b7d4a5bcd3806`;
all selected handoff commands matched and every probe command succeeded.

| Workflow | Output characters before → after | Commands before → after |
| --- | ---: | ---: |
| Combat | 16,634 → 16,634 | 4 → 4 |
| Shop | 11,631 → 11,631 | 4 → 4 |
| Persistence | 25,141 → 25,030 | 4 → 4 |
| Tooling | 4,005 → 4,023 | 3 → 3 |
| Combined | 57,411 → 57,318 (0.16% less) | 15 → 15 |

These already optimized probes barely change: combined roles remove a duplicate
file hint, while curated test pointers can add output. They do not exercise the
new concern lookup, error recovery or receipt-based guidance reuse.

The AgentContext quickstart fell from 11,823 to 5,370 characters (54.6% less);
every nonempty moved reference line remains in `Retrieval.md`. This measures page
size, not actual agent usage. Executable regressions cover corrected-command
retries, strict scoped test pointers, unique related-file rows, stale index paths
and anchors, receipt edit invalidation, cross-chat isolation, complete-read-only
recording, unchanged routing/warnings, and usage collection rejecting incomplete
or double-counted data. Complete-task trials and actual token savings remain
pending real provider exports and independently judged trial outcomes.


### Concern routing and mixed-read evidence

The next pass compares immutable copies of 2,189 starting text inputs, overlaying
only retrieval/guidance changes on the candidate. Both sides use the same driver
and concern source paths. The product fingerprint is
`6d357546a6d25dd66eac1dfc7b7182d59ece9502a3897750e1441e0e4a601077`;
all handoff commands match and all probe commands succeed.

Run this workflow with the current driver against both snapshots:

```sh
python3 Scripts/agent-efficiency.py probe --workflow concerns --root /tmp/baseline --output /tmp/before.json
python3 Scripts/agent-efficiency.py probe --workflow concerns --root /tmp/candidate --output /tmp/after.json
python3 Scripts/agent-efficiency.py compare /tmp/before.json /tmp/after.json
```

| Workflow | Output characters before → after | Commands before → after |
| --- | ---: | ---: |
| Combat | 23,242 → 12,473 (46.3% less) | 4 → 3 |
| Shop | 52,970 → 29,496 (44.3% less) | 5 → 3 |
| Persistence | 25,030 → 16,275 (35.0% less) | 4 → 3 |
| Tooling | 4,023 → 6,791 (68.8% more) | 3 → 3 |
| Combined | 105,265 → 65,035 (38.2% less) | 16 → 12 |

The baseline reads path-routed behavior cards; the candidate reads ownership
constraints plus indexed concern contracts and batches those with the source
range. Both route the entire concern's source paths and preserve the same local
safeguards, behavior-discovery references, warnings and verification. The tooling
candidate adds the script regression and documentation editing contracts that
were absent from the earlier path briefing. This is a different probe version
from the original path workflows; compare only matching versions.

These bounded probes do not prove complete-task correctness or token savings.
They omit agent-selected caller/test reads and implementation. The additional
Voyage, Labyrinth, transitions, audio and artwork pointers are validated against
live paths and anchors; their retrieval savings are unmeasured. Script regressions
cover mixed-read failure continuation, executable recovery, session identity,
complete-guidance-only receipts, invalidation and unchanged verification scope.

Three repetitions of each of the four investigation requests have been prepared
on both snapshots, with acceptance checklists and unmeasured fields left null.
Matched complete-agent trials, final per-response provider exports and independent
acceptance judgements are unavailable in this run. Usage collection remains
pending those inputs; no character-to-token estimate substitutes for them.


### Progression sections and executable recovery

Compared immutable copies of 2,221 starting text inputs, overlaying only this
pass's retrieval, routing and guidance changes. Product fingerprints, scenario
requests and selected handoff commands match; every probe command succeeded.
The progression contract preserves every existing nonempty nonheading line in
its original order. Shop leaves retain stock identity, noncombat completion and
Voyage identity sections; mixed scopes containing a shared persistence hub keep
the full contract. Homestead leaves retain displayed-tier validation and durable
transaction rules.

| Workflow | Output characters before → after | Commands before → after |
| --- | ---: | ---: |
| Combat | 12,473 → 12,627 | 3 → 3 |
| Shop | 29,525 → 22,914 | 3 → 3 |
| Persistence | 16,133 → 16,290 | 3 → 3 |
| Tooling | 6,790 → 6,947 | 3 → 3 |
| Combined | 64,921 → 58,778 (9.46% less) | 12 → 12 |

The probe does not execute the suggested task-read command or exercise recovery
from invalid scopes/ranges. Executable regressions cover those paths, preserved
chat identity and explicit scope, unknown-task failure, guidance receipts and
handoff rerun arguments. Small routes grow slightly to expose the executable read
suggestion; the Shop route saves unrelated progression reading.

Three repetitions of each investigation request are prepared on both snapshots
with matching product fingerprints and null usage/judgement fields. Actual
matched agent runs, final per-response provider usage exports and independent
acceptance judgements are unavailable. Complete-task token savings remain
unmeasured; this retrieval comparison does not establish them. Use the existing
prepare/collect/compare workflow when those inputs are available.

### Briefing reuse and focused progression

Compared immutable text snapshots of 2,231 starting inputs, overlaying only the
candidate guidance/retrieval changes. Both snapshots used the same measurement
driver and ten scenario requests. Product fingerprints and handoff commands
matched; every probe command succeeded. The product fingerprint was
`770163e9b0f2e77dba0dbffe9c19b00be8be9f431005e78f78d03ea27ad0058d`.

The concern workflow emitted 186,634 → 184,724 characters (1.02% less) across
30 commands per side. Voyage fell 28,556 → 27,853 (2.5% less), Labyrinth
28,763 → 27,556 (4.2% less); the other eight scenarios were unchanged. Focused
progression reads retain reward arithmetic, modifiers, XP, Mystery claims, Shop
identity, noncombat completion and Voyage identities where applicable. Shared
owners still expose whole-card behavior references.

The `briefings` workflow measures a cold brief followed by a repeated brief in
the same isolated probe chat. The candidate explicitly reuses retained guidance;
the baseline repeats it. Both continue to display routing, warnings, scoped status,
source signatures, test pointers and the same handoff command. Receipt setup and
cleanup are excluded; root guidance is already injected. This is delivery-volume
evidence under retained context, not an autonomous investigation or completion test.

| Scenario | Cold plus repeat characters before → after | Reduction |
| --- | ---: | ---: |
| Combat | 25,058 → 18,095 | 27.8% |
| Shop | 47,486 → 32,619 | 31.3% |
| Persistence | 27,951 → 18,402 | 34.2% |
| Tooling | 9,796 → 7,386 | 24.6% |
| Particles | 35,900 → 22,657 | 36.9% |
| Feedback | 35,560 → 24,089 | 32.3% |
| Collection | 48,179 → 30,256 | 37.2% |
| Simulator | 12,280 → 8,479 | 31.0% |
| Voyage | 56,512 → 37,045 | 34.4% |
| Labyrinth | 59,026 → 38,557 | 34.7% |
| Combined | 357,748 → 237,585 | 33.59% |

Each side used 20 commands with zero failures. Reader regressions exercise
edit invalidation, section/whole-file reuse boundaries, chat isolation, compaction
reset, source reads remaining visible, mixed full-file/anchor batches, and compact
per-request failures that continue later reads. Investigation regressions exercise
complete assertion bodies, explicit tests, scope/generated exclusions, ambiguity,
body omission and fingerprinted continuations. Live Python and Shop purchase
bundles returned complete declarations and explicit oversized-body pointers.
These error/bundle paths are outside the measured retrieval workflows.

Thirty complete-task trial entries per side were prepared with matched starting
product fingerprints and acceptance criteria. Actual agent trials, final per-response
provider usage exports and independent outcome judgments are unavailable; their
usage and judgments remain null. Total task-token savings are unmeasured. Reports
and source snapshots remain outside the repository; use `prepare`, `collect` and
`compare` when the required trial evidence is available.
