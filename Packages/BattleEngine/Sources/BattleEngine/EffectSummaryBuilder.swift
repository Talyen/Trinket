import Foundation
import TrinketContent
import TrinketCore

/// Builds the per-combatant effect summaries used by the detail pane and
/// the status line. Replaces the in-line `groupedEffectSummaries` function
/// that previously lived on `BattleState`.
///
/// For each keyword group, kinds are tried in `priorityOrder` and the first
/// handler that returns a non-nil summary wins. This preserves the historical
/// priority ordering (decaying DoTs first, then bleed, then defensive
/// totals, then control-meter build-up, then active control effects, then leech,
/// then cleanse).
public enum EffectSummaryBuilder {
    private static let priorityOrder: [EffectKind] = [
        .deathsDoor,
        .burn, .poison,
        .bleed,
        .shield, .mitigation,
        .haste, .thorns, .marked, .criticalChanceBonus, .restoreManaOnHit,
        .controlMeter,
        .leech
    ]

    /// Returns one `EffectSummary` per keyword that has at least one active
    /// effect with a non-nil summary. Order is unspecified.
    public static func build(for effects: [ActiveEffect]) -> [EffectSummary] {
        Dictionary(grouping: effects, by: \.keyword).compactMap { keyword, group in
            for kind in priorityOrder {
                let stacks = group.filter { $0.effect.kind == kind }
                guard !stacks.isEmpty else { continue }
                guard let handler = EffectHandlers.all[kind] else { continue }
                if let summary = handler.summary(for: stacks, keyword: keyword) {
                    return summary
                }
            }
            return nil
        }
    }
}
