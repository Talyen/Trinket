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
Packages/BattleEngine/Sources/BattleEngine/Healing/HealingEngine.swift
Packages/TrinketPersistence/Sources/TrinketPersistence/Progression/StageCompletion.swift
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

## Focused retrieval follow-up — 2026-09-11

Compared the current dirty checkout immediately before and after this change;
existing documentation cleanup and source moves are included in both sides.
Counts are Unicode characters, not tokens. Required reads use the same
Read first + Context cards union as above, including the already-injected root.
This is a scenario review, not an autonomous feature trial.

| Route | Required guidance: before → after | Router: before → after |
|---|---:|---:|
| Damage | 11,497 → 11,497 | 769 → 769 |
| Effect handler | 11,497 → 11,497 | 681 → 681 |
| Healing | 10,755 → 10,755 | 793 → 793 |
| Stage completion | 11,638 → 11,638 | 694 → 694 |
| Shared save store | 14,022 → 14,187 | 823 → 823 |
| Shop UI | 10,665 → 10,665 | 577 → 577 |
| Script tooling | 7,308 → 7,308 | 412 → 412 |
| Battle card view | 18,441 → 15,440 | 803 → 846 |
| Shared BattleSession | 14,933 → 15,842 | 636 → 716 |
| Battle launch | 14,484 → 12,030 | 702 → 739 |
| Runtime protocol | 18,259 → 15,801 | 736 → 704 |

The first seven paths are the original probes above. Added probes are
`BattleAbilityCardView.swift`, `BattleSession.swift` (BattleFeature),
`PlaySession+BattleLaunch.swift` (AppState), and `BattleRuntime.swift` (BattleEngine).
All eleven isolated handoff dry-run outputs were identical before and after.
The root contributes 5,722 characters on both sides; excluding it, the card-view
route falls from 12,719 to 9,718 characters (23.6%). Shared BattleSession grows
by 909 characters because it receives both detailed contracts and their routing
instructions. Do not extrapolate the leaf-view saving to shared lifecycle work.
All original contract content remains in the three-card union.

### Discovery and follow-up reads

For `agent-search.py 'verification|handoff' --mode docs`, Verification.md moves
from result 32 to result 17 and becomes visible within the default 20 files.
The bounded output grows from 1,223 to 1,288 characters. In the deterministic
recovery probe, the old result requires a second call with `--limit 100` (2,378
additional characters); the new result requires no search expansion. Both then
read the verification policy. These are retrieval steps, not a claim that every
agent would choose the same recovery strategy. History remains searchable by
scope; ordering does not remove matches. Search fixtures check ordering before
both file and excerpt limits, source line order within a file, `.mdc`
discovery, scope filtering, error propagation, and explicit omissions.

The Scripts entry page falls from 12,917 to 2,553 characters (80.2%). Command
reference sections are follow-up reads, not deleted information: an entry-page
visit followed by the entire reference costs more than the old single page.
For ordinary command discovery, follow only the task's section; verification
and simulator guidance now link directly to their command sections. All command
entries were carried forward; concurrent plan-tooling updates to two entries
were retained. Inventory checks still reject missing commands.

For Battle presentation, the detail card is already included in the required
read count, so a leaf card-view probe needs no additional launch-contract read.
A call crossing into preparation, settlement, or Continue must load the launch
card too; that route has the shared-contract cost shown above. Shop styling and
engine effect probes keep their existing guides and optional skill references.
Implementation/test reads and agent retries are not measured by this review.

### Preserved decisions

The effect scenario retains engine mutation ownership, deterministic dispatch/
expiry evidence, registry parity, and the public-contract skill trigger. The
Shop scenario retains semantic design-system roles, purchase eligibility,
identifier policy, and the coverage rubric. Battle presentation retains retiring
view state, synchronous rules versus playback, readiness/suspension, and opaque
hand cards; launch retains prepared identity/seed validation, sibling retention,
settlement validation, storage retry, and navigation restoration. Unknown,
composition, and lifecycle paths receive both contracts; mixed routes deduplicate
their union. Existing tests exercise these routing outcomes rather than prose.

Total-task token usage remains unmeasured. The ≥10% criterion above remains
unproven; these component measurements must not be presented as satisfying it.

The scoped change-budget advisory reports net +153 test lines against HEAD,
including pre-existing edits in shared test files. This change extends existing
suites for conservative contract routing, bounded retrieval ordering/errors, and
command-inventory ownership. Link checks alone were rejected as insufficient:
they cannot detect silently omitted contracts or current policy displaced by
history. No gameplay or Swift test changes belong to this implementation.

## Owner discovery and complete reads — 2026-09-12

Compared the implementation-start working snapshot with this change; unrelated
work continued in the checkout. These are deterministic retrieval/scenario
probes and Unicode character counts, not autonomous tasks or billed tokens.
Both search implementations used the same current source inventory.

| Probe | Before | After |
|---|---:|---:|
| BattleState discovery, recovery and complete owner read | 27,193 characters | 17,828 characters |
| Documentation-checker selection | 146 methods across five modules | 18 methods in one module |
| Selected documentation test source | 150,310 characters | 21,173 characters |
| Two-file workspace inspection | 26,304 characters (default short status) | 728 characters (status briefing) |

BattleState previously appeared at position 65. The recovery probe reads the
first 20 results, expands to 100 when the owner is absent, then reads the complete
15,733-character owner. The new probe finds it in the initial results and reads
the same owner. This models one explicit recovery strategy, not every agent.
Filename search also provides direct discovery without content matches.

The status comparison uses `Scripts/agent-search.py` and `Scripts/check-links.py`.
The briefing counts individual untracked files and prints both rename endpoints;
expanded short status for the same checkout was 39,804 characters. Status does
not replace overlapping diff inspection; identical follow-up diffs are excluded
from both sides. Root guidance grows by 101 characters, paid across tasks.

Complete optional-reference reads, including the reader's line numbers and parent
headings, cost 2,393 characters for the simulator budget, 2,376 for verification
commands, and 539 for script-failure triage. Their whole documents at measurement
time cost 12,395, 11,582 and 7,161 characters. These savings apply when avoiding
whole-document reads. Precise bounded reads already cost only 2,137, 2,214 and
398 characters; the reader adds framing while removing heading-location work.
Required guides/cards still need their full contracts.

Sixteen existing test methods moved without duplicate copies. Their assertions
remain; two fixtures additionally copy the shared Markdown helper or create their
probe plan in a temporary repository instead of the product checkout. Two new
documentation tests cover section/anchor behavior and consumer selection. Content
codegen setup now belongs only to its consuming suite. Shared/unknown script
inputs and unscoped CI retain full-suite selection.

The Battle-effect, Shop, tooling and cross-owner BattleState/save-store router
probes produce identical briefings without `--status`. The existing effect and
Shop evaluation criteria were reviewed: ownership, expiry evidence, semantic
colors, purchase eligibility, identifiers, and required verification remain.
Search and status regressions cover bounded ordering, inventory filters, scope,
staged/unstaged changes, deletions, untracked files and both rename endpoints.

No autonomous feature trial was run. Follow-up implementation, retries, reasoning
and complete task-token usage remain unmeasured; the ≥10% total-task criterion is
still unproven. The scoped change-budget warning includes pre-existing test edits
against HEAD. New coverage protects retrieval completeness and workspace safety;
relocations preserve coverage. Merely trimming output or checking links would not
prove those behaviors. No Swift production or test surface was added here.
