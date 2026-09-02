# Knowledge index

Searchable institutional memory. **Not auto-loaded** into normal coding-agent context.

Load a pattern only when the task touches its concern or a skill’s `PURPOSE.md` points here. One-off failures stay in session history.

## Lifecycle

```
one-off failure → session history
recurring / generalizable issue → knowledge pattern (active / uncertain)
clear reusable prevention → candidate skill update (record in skill-impact.md)
validated improvement → promote to active skill
mechanically enforceable → encode in types / lint / tests / boundaries, remove prose
```

Patterns support merging, marking `superseded` / `obsolete`, and preserving rejected approaches that are likely to be re-proposed. The author landing the superseding change marks the old pattern; no automated pruning.

## Patterns

| Pattern | Status | Confidence | Trigger |
|---|---|---|---|
| [artwork-working-set](patterns/artwork-working-set.md) | active | high | Launch art, `PreparedArtwork*`, `NSCache` budget, hitch/memory work |
| [module-dag-containment](patterns/module-dag-containment.md) | active | high | Adding imports, `Package.swift` deps, new hubs or cross-package moves |
| [architecture-deferred-seams](patterns/architecture-deferred-seams.md) | active | medium | Proposing package splits, new platform sync, or further Battle presentation boundaries |

## Skill impact

[skill-impact.md](skill-impact.md) — audit log for instruction changes. Prevents re-proposing failed changes.

## Evals

[../evals/README.md](../evals/README.md) — representative tasks for validating skill changes.
