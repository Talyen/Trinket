# Archived plan outcomes

Completed and cancelled plans leave only a concise outcome here. Durable rules
belong in their Product, Platform, package, AgentContext, skill, or knowledge
owner; Git history retains the full execution record. Do not reactivate an old
plan—create a new active plan under `Docs/Plans/` when follow-up work is needed.

| Plan | Closed | Outcome |
|------|--------|---------|
| ContinuousCardPlay.md | 2026-09-12 | Implemented immediate card input, independent full-size automatic casts, ally-first Pack Tactics, and immutable visual-only finishing taps. The approved plan is retained as standing policy in [CardPlay.md](../../Product/CardPlay.md), with regression ownership in the battle presentation contract. |
| Battle balance tuning | 2026-09-12 | Implemented the agreed card, talent, trait, and affix changes; bounded Fox’s Gold draw loop and repaired enemy Basic Freeze triggers. Isolated handoff passed 887 package tests and repository gates. Balance comparisons retain documented Alchemist/Pixie and Wildcard/Fox progression walls. |
| Architecture simplification | 2026-09-10 | Contained combat mutation and talent lifetimes, unified save commits and reward wiring, and removed obsolete development-save migrations. Performance retained advisory pacing findings. |
| Lucide game icons | 2026-09-10 | Added Lucide game imagery with native SF controls, painted resources, and saved icon compatibility. Performance retained a card-play stall and Collection capture timeout. |
| Prevent recurring defects | 2026-09-10 | Unified combat healing allocation and defense caps, reward settlement and reveal, durable encounter stock and atomic commands, and shared visibility/action semantics; retired replaced session and inventory-prefix paths. |
| Test fixture correctness and simplification | 2026-09-10 | Removed permissive control-skip assertions and corrected target checks; clarified direct item fixtures. |
| Battle artwork pin lifecycle | 2026-09-10 | Balanced overlapping acquisitions and preserved active/sibling pins through activation. Performance retained pacing misses and Collection capture timeouts. |
| Battle feedback scheduling | 2026-09-10 | Repaired deadlines and renderer cleanup; removed unused tracking and duplicate expiry coverage. Performance retained pacing misses; Collection passed only on isolated recheck. |
| TrinketCore talent validation | 2026-09-10 | Made canonical tree rows authoritative and applied prerequisite repair at every point budget; approved with no current players or saves, restored points for removed selections, and extended model, migration, and disk-reload coverage. |
| Combat reaction contracts | 2026-09-10 | Implemented shared selected-outcome and payment facts, explicit reaction checkpoints and automatic ancestry, cohesive healing state, and consistent defense/affliction rules; preserved serialized contracts and removed nested-reaction stack pressure. |
| Generated project consistency | 2026-09-08 | Added uncached pinned generation, staged-project validation, idempotence, and freshness routing. Hosted CI confirmation still requires a requested push. |
| Monetization | 2026-09-08 | Implemented the permanent Full Game offer, free-content boundaries, earned recruitment, free-first roster ordering, all-ability Spire matching, StoreKit development purchases, and support/privacy page sources. Developer enrollment, live store setup, public support contact, and website publication remain release prerequisites. |
| Battle card cues | 2026-09-08 | Added recipient, resource-use, and denial cues; preserved saved powers and repaired interrupted input and launch-readiness coverage. |
| Talent reworks | 2026-09-07 | Reworked 20 talents without their former activation limits/caps, preserved saved IDs through three node swaps, extended balance contrasts to final rows, and isolated the shared-session verification fixture; Grove Reserve remains a tuning follow-up against First Bloom. |
| Contracts | 2026-09-07 | Added persistent renewable jobs with party-based levels, regular rewards, atomic claims, and free refresh/retries; reused Stage UI. |
| Homestead portrait disclosure | 2026-09-07 | Added portrait building details, progressive upgrade offers, and saved-purchase feedback; preserved landscape art and repaired diagnostic fixtures. |
| Content progression | 2026-09-07 | Implemented bounded Campaign scaling, fixed Spire levels, rising minimums through infinite Labyrinth floors, and uncapped logarithmic enemy HP / linear damage growth; preserved catch-up XP, aligned balance tooling, and repaired integer-boundary rounding. Contracts design follows separately. |
| Complete Unique collection | 2026-09-07 | Completed equipment Unique coverage with themed Mystery rewards and combat/save rules; repaired large-log watchdog detection. |
| Agent token efficiency | 2026-09-06 | Reduced required guidance and routine routing output, routed UI performance details by concern, retained bounded script-failure evidence, and added handoff outcomes; global setup preserved. |
| Missing heroes | 2026-09-06 | Added Alchemist, Druid, and Wildcard with original portraits, approved loadouts, 63 distinct Talents, and deterministic combat/content/save coverage; compared legal builds and Talent siblings without claiming final balance. |
| Approved balance changes | 2026-09-05 | Repaired Health affordability, Frost Whelp talents, Hemorrhage, Loyal Companion, and Luck Potion; retained simulator evidence and isolated further talent-stack proposals. |
| Documentation simplification | 2026-08-21 | Established the documentation ownership map; remaining work moved into Docs/tooling simplification |
| Token efficiency | 2026-08-21 | Replaced broad context and diagnostic proposals with routed guidance and structured output work owned by the Docs/tooling plan |
| Docs/tooling simplification | 2026-08-21 | Consolidated routing and documentation policy, removed dead guidance, improved plan/docs checks, and simplified shared script mechanics |
| Docs residual cleanup | 2026-08-21 | Corrected stale test and ownership references, reduced audit/skill duplication, and added package-test README validation |
| Simplification correctness pass | 2026-08-25 | Landed approved combat, presentation, persistence, content, and tooling corrections; durable decisions moved to standing owners |
| Labyrinth modifier expansion | 2026-08-25 | Removed the Forge flow, expanded Labyrinth modifiers, preserved old saves, and updated content/persistence verification |
| Battle and tooling simplification | 2026-08-27 | Unified healing and auto-battle behavior and hardened Swift Testing and static-analysis tooling |
| Elegant simplification round | 2026-08-28 | Reduced trigger/codegen, persistence, presentation, and tooling surface; deferred high-churn engine work |
| Simplification consolidation round 2 | 2026-09-01 | Cancelled after landing runtime, artwork, save-durability, and Labyrinth recovery work; unresolved items moved to `SimplificationFollowup` |
| Elegant simplification round 3 | 2026-09-01 | Removed confirmed over-engineering and fixed persistence, concurrency, performance, and build-pipeline issues |
| Elegant simplification round 4 | 2026-09-01 | Cancelled after its confirmed residual work moved to `SimplificationFollowup` |
| Labyrinth cleared-node refresh | 2026-08-29 | Replaced success-green cleared nodes with quieter visited-parchment styling |
| BattleEngine simplification (`BattleEngineSimplification.md`) | 2026-09-03 | Centralized combat policy, removed duplicated card-engine paths, and moved residual work to `SimplificationFollowup` |
| Combat semantic architecture | 2026-09-09 | Unified operation, action, preparation, reward, and turn-playback contracts. Performance retained a Collection sampling failure and advisory frame-budget misses. |

For committed plan detail, search both historical locations using the original
filename (retain it in the Plan column when known):

```sh
git log --all -p -- Docs/Plans/<former-name>.md Docs/Plans/Archived/<former-name>.md
```

If the filename is unknown, discover it with
`git log --all --name-only --format= -- Docs/Plans/`. An outcome row does not
establish that a full plan was committed; uncommitted execution detail remains
in its original task history.
