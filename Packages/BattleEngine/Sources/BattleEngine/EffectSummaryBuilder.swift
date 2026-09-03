import Foundation
import TrinketContent
import TrinketCore

public enum EffectSummaryBuilder {
    private static let priorityOrder: [EffectKind] = [
        .deathsDoor,
        .burn, .poison,
        .bleed, .hemorrhage,
        .shield,
        .thorns, .marked, .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride,
        .nextHolyStrike, .nextStrikeDouble, .nextBurnBonus, .evadeNextHit,
        .nextStrikeCritical, .freezeNextAttacker, .onHitDamage, .maximumManaBonus,
        .recurringDamage, .avatar,
        .damageReductionPercent, .damageReductionFlat, .healingReductionPercent,
        .controlMeter,
    ]

    public static func build(for effects: [ActiveEffect]) -> [EffectSummary] {
        let grouped = Dictionary(grouping: effects, by: \.effect.kind)
        var summaries: [EffectSummary] = []
        summaries.reserveCapacity(grouped.count)
        for kind in priorityOrder {
            guard let kindEffects = grouped[kind], !kindEffects.isEmpty else { continue }
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
