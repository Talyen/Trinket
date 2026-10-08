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
