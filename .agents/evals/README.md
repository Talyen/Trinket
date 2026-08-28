# Evals

Pragmatic place to test whether a skill or knowledge change actually helps.

Do **not** build an autonomous benchmark harness. Prefer objective signals via existing gates:

- `build` passes (`build.sh` / `test-package.sh`)
- `tests` pass (package unit, smoke canary)
- `lint` / `style` passes (`test.sh style`)
- `boundaries` pass (`check-module-boundaries.sh`)
- no unexpected warnings
- task requirements satisfied
- minimal unnecessary diff

## Using evals

1. Pick a representative task below that matches the change’s concern.
2. Run the task in an isolated worktree or slot.
3. Validate with `./Scripts/handoff.sh --isolate --paths <touched-files>` (canonical gate).
4. Record pass/fail in `skill-impact.md` when promoting a skill change.

Future skill changes should be validated against at least one relevant eval before being permanently promoted.

## Available evals

| Eval | Concern | Skills exercised |
|---|---|---|
| [eval-01-battle-effect](eval-01-battle-effect.md) | Add `EffectKind` + handler + deterministic test | `architect`, `battle-engine` |
| [eval-02-shop-flow](eval-02-shop-flow.md) | Shop UI affordance + AccessibilityID + smoke ownership | `apple-design`, `swiftui-features` |

## Adding an eval

Keep it to one Markdown file with: goal, setup steps, pass/fail criteria (gates + behavior), and anti-goals (what not to test). Link it here.
