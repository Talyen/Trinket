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
/// totals, then control-meter build-up, then active control effects, then cleanse).
public enum EffectSummaryBuilder {
    private static let priorityOrder: [EffectKind] = [
        .deathsDoor,
        .burn, .poison,
        .bleed, .hemorrhage,
        .shield,
        .thorns, .marked, .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride,
        .nextHolyStrike, .nextStrikeDouble, .evadeNextHit,
        .nextStrikeCritical, .freezeNextAttacker, .onHitDamage, .maximumManaBonus,
        .recurringDamage, .avatar,
        .damageReductionPercent, .damageReductionFlat, .strengthReduction,
        .controlMeter,
    ]

    /// Returns an `EffectSummary` for each active effect kind/stack group.
    /// Order follows `priorityOrder`.
    public static func build(for effects: [ActiveEffect]) -> [EffectSummary] {
        var summaries: [EffectSummary] = []
        for kind in priorityOrder {
            let kindEffects = effects.filter { $0.effect.kind == kind }
            guard !kindEffects.isEmpty else { continue }
            guard let handler = EffectHandlers.all[kind] else { continue }
            let groupedByKeyword = Dictionary(grouping: kindEffects, by: \.keyword)
            for (keyword, stacks) in groupedByKeyword {
                if let summary = handler.summary(for: stacks, keyword: keyword) {
                    summaries.append(summary)
                }
            }
        }
        return summaries
    }
}
