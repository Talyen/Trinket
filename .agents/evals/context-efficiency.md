# Context-efficiency scenario review

2026-09-11; baseline checkout `3d327ae2`, with the existing in-flight app changes
preserved. This is a routing/search scenario review, not an autonomous feature
trial. Counts are Unicode characters, not tokenizer counts or billed tokens.

## Required guidance

For each path below, run `./Scripts/agent-context.sh --paths <path>`. Count the
deduplicated files in **Read first** and **Context cards**, including root
`AGENTS.md`; exclude optional skills/memory, router output and implementation
reads. The root is usually already injected in a task and should not be reread.

| Route | Before | After | Reduction |
|---|---:|---:|---:|
| Damage | 13,470 | 11,186 | 17.0% |
| Effect handler | 13,470 | 11,186 | 17.0% |
| Healing | 13,470 | 10,549 | 21.7% |
| Stage completion | 13,244 | 11,669 | 11.9% |
| Shared save store | 13,244 | 14,053 | -6.1% |
| Shop UI | 10,620 | 10,696 | -0.7% |
| Script tooling | 8,013 | 8,089 | -0.9% |

Paths, respectively:

```text
Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineResolutionSteps.swift
Packages/BattleEngine/Sources/BattleEngine/EffectHandlers/TimedDebuffHandlers.swift
Packages/BattleEngine/Sources/BattleEngine/HealingEngine.swift
Packages/TrinketPersistence/Sources/TrinketPersistence/StageCompletion.swift
Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift
Trinket/Features/Play/Shop/ShopEncounterView.swift
Scripts/check-links.py
```

The shared store intentionally receives both detailed contracts. Router output
increased by about 140–280 characters per probe because it now supplies search
roots and focused references. Do not claim a uniform reduction for every route.

Package entry points also became smaller: BattleEngine 14,768 → 4,692 characters;
DesignSystem 11,151 → 982; Persistence 1,937 → 1,384. These are indexes, not
replacement summaries: matching details still need to be loaded. Do not count
the entire removed README text as a saving when its references are needed.

## Discovery probes

Compare these operations for `talent`, `DamagePipeline` and `PreparedArtwork`:

```sh
rg -n -i -g '*.swift' '<term>' Packages Trinket
python3 Scripts/agent-search.py -i '<term>' --scope Packages --scope Trinket
```

| Term | Raw search characters | Discovery characters | Reduction |
|---|---:|---:|---:|
| talent | 361,725 | 2,123 | 99.4% |
| DamagePipeline | 3,387 | 1,344 | 60.3% |
| PreparedArtwork | 23,641 | 2,480 | 89.5% |

These measure initial discovery only. The raw search includes tests/generated
Swift; discovery returns authored file counts, and has explicit bounds. Talent
omitted 78 matching files and PreparedArtwork omitted 16; DamagePipeline omitted
none. Retrieve relevant tests with `--mode tests`, generated output explicitly,
and code with a file scope plus `--excerpts` or a bounded `rg`/`sed` read. The
tool reports omissions and shortened lines so a partial result cannot masquerade
as an exhaustive investigation. Follow-up reads belong in total-task accounting.

## Verification selection

`handoff.sh --isolate --dry-run --paths Scripts/README.md` previously selected all
15 Python and three shell regression suites. It now selects the documentation
check plus the unchanged cheap slices. Leaf-script families cover authored
search, documentation checks, performance reports and user release notes.
Mixed/shared/unknown executable inputs fall back to all suites; adding a new
test file is discovered by the unscoped full runner. Syntax and build-input
alignment remain full-tree. CI remains unscoped.

## Preserved decisions and acceptance

- **Battle effect scenario:** engine mutation ownership and deterministic evidence
  remain in the common contract; handler paths also load damage/application/expiry
  rules. Registry parity remains explicit. Shared engine paths load all operation
  contracts. New schema/public API handling still routes the architect skill.
- **Shop scenario:** SwiftUI guidance and the design skill still apply. The smaller
  DesignSystem index directs price/color work to visual roles and modifier work
  to its API reference. Semantic color, identifier, coverage and observation
  requirements remain available; no UI behavior changed in this work.
- Search regression fixtures exercise surface separation, tracked/untracked files,
  ignored artifacts, space-containing paths, bounded output and argument safety.
  Routing fixtures exercise cross-concern unions and conservative fallbacks.

The acceptance criterion for an autonomous comparison remains **at least 10%
less total task-token usage across the same representative workload, with no
correctness regression**. Include follow-up reads, retries, recovery and final
verification; compare equivalent models and outcomes. Actual task-token savings
have not been measured here. Component percentages must not be summed or
presented as satisfying that criterion. Use the existing evaluation procedure
for a behavioral trial; no new benchmark service or persistent index is needed.
