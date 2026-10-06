# Agent token-efficiency evaluation

Use [agent-efficiency.py](../../Scripts/agent-efficiency.py) for reproducible
retrieval measurements and controlled complete-task report comparison. Commands
and request strings live in its `SCENARIOS`; this guide owns interpretation.

Reports under `.DerivedData/AgentEvaluationResults/` use the shared 24-hour
retention policy. Keep them explicitly during longer active comparisons, then
release them; custom output locations stay caller-owned.

## Retrieval probes

Run against immutable text snapshots containing the same current product inputs,
Git inventory, and script dependencies. Apply only the candidate guidance and
retrieval-tool changes to the candidate snapshot. A dirty primary checkout is
not a stable before/after source baseline. These read-only probes require no
Swift compilation, Simulator, generated project, or autonomous agent.

```sh
python3 Scripts/agent-efficiency.py probe --root /tmp/baseline --output .DerivedData/AgentEvaluationResults/before.json
python3 Scripts/agent-efficiency.py probe --root /tmp/candidate --output .DerivedData/AgentEvaluationResults/after.json
python3 Scripts/agent-efficiency.py compare .DerivedData/AgentEvaluationResults/before.json .DerivedData/AgentEvaluationResults/after.json
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
python3 Scripts/agent-efficiency.py prepare --root /tmp/baseline --repetitions 3 --output .DerivedData/AgentEvaluationResults/baseline-trial.json
python3 Scripts/agent-efficiency.py collect .DerivedData/AgentEvaluationResults/baseline-trial.json --output .DerivedData/AgentEvaluationResults/baseline-tasks.json
python3 Scripts/agent-efficiency.py compare .DerivedData/AgentEvaluationResults/baseline-tasks.json .DerivedData/AgentEvaluationResults/candidate-tasks.json
```

`prepare` pins the product fingerprint and four requests but leaves settings,
judgements and measurements null. Fill settings and independently judge each
result; record transcript/diff/verification evidence and the extraction method for
repeated reads, retries, failed commands and unnecessary stops. Add repetitions
with distinct task IDs, including every outcome, including failed/incomplete work, in the active comparison.
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
subset again. Keep the original export and normalization method for the active comparison;
release them when that comparison finishes.

`collect` rejects missing, negative or boolean token counts, repeated
response IDs within or across tasks, and totals that disagree with the export. It records
the export SHA-256 and response count, computes input plus output usage, and
validates the remaining report fields. False correctness/completion judgements
remain recordable and make comparison fail. Collection validates the supplied
data; it cannot authenticate an export, prove all responses were included, or
independently judge completion. Do not substitute retrieval character counts.
