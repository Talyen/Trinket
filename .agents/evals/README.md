# Skill evaluations

Use a representative task when a skill change alters a consequential decision or
workflow. Trigger and wording fixes usually need link checks, comparison with the
executable owner, and scenario review; they do not need a synthetic app feature.

For a behavioral trial, use an isolated disposable worktree created through the
repository worktree helper. Keep its implementation out of the product change.
Provide the evaluator with the request and relevant guidance, then judge its
observable result against the criteria. If delegated, keep reviewer criteria
separate from the task brief so the evaluator must make the decision itself.

Run the path-scoped verification selected for the trial, not a fixed build/test
checklist. Report what was exercised and its limitations in the task handoff.
Passing syntax or link checks does not establish that a workflow works in practice.

| Scenario | Guidance exercised |
| --- | --- |
| [Battle effect](eval-01-battle-effect.md) | `architect` skill and battle-engine context card |
| [Shop affordance](eval-02-shop-flow.md) | `apple-design` skill and SwiftUI feature context card |

Add a scenario only for a recurring decision worth testing. Include a concrete
request, relevant setup, and observable pass criteria; avoid scoring whether the
agent followed an arbitrary sequence or reproduced a preferred phrase.

For context-efficiency changes, compare the same starting source snapshot with
only guidance/tooling changed. Record routing output, available reference size,
and the constraints retained. Count actual follow-up reads when available; making
a reference optional does not establish that a task consumes fewer tokens.
Review the existing scenarios for lost instructions and label static comparisons
as scenario review, not autonomous behavioral trials.

For autonomous comparisons, hold the Astra model, reasoning settings, tools,
request, and starting code constant. Judge correctness and completion first,
then unnecessary stops, repeated reads, retries, and total effort/token use when
available. A lower token count does not compensate for a missed requirement.
There is no fixed percentage-savings target. Record configuration and limitations;
scenario reasoning does not establish measured task-success rates.

[Context-efficiency measurements](context-efficiency.md) preserve the historical
September baseline. [Agent judgment](agent-judgment.md) records the later scenario
comparison and additional diagnostic, presentation, and shared-journey probes.
