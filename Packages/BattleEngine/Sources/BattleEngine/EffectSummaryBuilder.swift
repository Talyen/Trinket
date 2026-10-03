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
        .nextStrikeDamageKeywordOverride, .nextHolyStrike, .nextStrikeDouble, .nextBurnBonus, .evadeNextHit,
        .nextStrikeCritical, .nextStrikeLeech, .partyDamageBonus, .freezeNextAttacker, .onHitDamage, .maximumManaBonus,
        .recurringDamage, .avatar,
        .damageReductionPercent, .damageReductionFlat, .healingReductionPercent,
        .controlMeter,
    ]

    private static let priorityIndices = Dictionary(uniqueKeysWithValues: priorityOrder.enumerated().map {
        ($0.element, $0.offset)
    })

    private struct Group: Hashable {
        let kind: EffectKind
        let keyword: Keyword
    }

    public static func build(for effects: [ActiveEffect]) -> [EffectSummary] {
        let grouped = Dictionary(grouping: effects) { Group(kind: $0.effect.kind, keyword: $0.keyword) }
        return grouped.sorted { lhs, rhs in
            if lhs.key.kind != rhs.key.kind {
                let left = priorityIndices[lhs.key.kind] ?? Int.max
                let right = priorityIndices[rhs.key.kind] ?? Int.max
                // Unlisted kinds follow the declared order rather than disappearing.
                return left != right ? left < right : String(describing: lhs.key.kind) < String(describing: rhs.key.kind)
            }
            return lhs.key.keyword.rawValue < rhs.key.keyword.rawValue
        }.compactMap { group, stacks in
            EffectHandlers.handler(for: group.kind).summary(for: stacks, keyword: group.keyword)
        }
    }
}
