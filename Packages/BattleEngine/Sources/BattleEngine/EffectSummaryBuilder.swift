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

    public static func build(for effects: [ActiveEffect]) -> [EffectSummary] {
        var grouped: [EffectKind: [Keyword: [ActiveEffect]]] = [:]
        for effect in effects {
            grouped[effect.effect.kind, default: [:]][effect.keyword, default: []].append(effect)
        }
        // Fail-open ordering: kinds in priorityOrder keep their slots; any
        // other kind (e.g. a future handler gaining a summary) appends after
        // them in rawValue order instead of being silently dropped.
        let orderedKinds = grouped.keys.sorted { lhs, rhs in
            let lhsIndex = priorityIndices[lhs]
            let rhsIndex = priorityIndices[rhs]
            switch (lhsIndex, rhsIndex) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return String(describing: lhs) < String(describing: rhs)
            }
        }
        var summaries: [EffectSummary] = []
        summaries.reserveCapacity(grouped.count)
        for kind in orderedKinds {
            guard let groupedByKeyword = grouped[kind] else { continue }
            let handler = EffectHandlers.handler(for: kind)
            for (keyword, stacks) in groupedByKeyword.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                if let summary = handler.summary(for: stacks, keyword: keyword) {
                    summaries.append(summary)
                }
            }
        }
        return summaries
    }
}
