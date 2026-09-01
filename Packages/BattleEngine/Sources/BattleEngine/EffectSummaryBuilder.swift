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
        .nextHolyStrike, .nextStrikeDouble, .evadeNextHit,
        .nextStrikeCritical, .freezeNextAttacker, .onHitDamage, .maximumManaBonus,
        .recurringDamage, .avatar,
        .damageReductionPercent, .damageReductionFlat,
        .controlMeter,
    ]

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
