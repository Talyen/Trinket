import TrinketCore

public enum CombatantBuffAuraKind: String, Sendable, Equatable, Hashable, CaseIterable {
    case shadowstep
    case predatorsFocus
    case glacialWard
    case moltenBulwark
    case thorns
    case avatar
    case marked
    case blizzard
    case earthquake
}

public enum CombatantBuffAura: Sendable {
    private static let priorityOrder: [CombatantBuffAuraKind] = [
        .shadowstep,
        .predatorsFocus,
        .glacialWard,
        .moltenBulwark,
        .thorns,
        .avatar,
        .marked,
        .blizzard,
        .earthquake,
    ]

    public static func kind(for effect: Effect) -> CombatantBuffAuraKind? {
        switch effect {
        case .nextStrikeDouble, .evadeNextHit:
            .shadowstep
        case .nextStrikeCritical:
            .predatorsFocus
        case .freezeNextAttacker, .onHitDamage(.freeze, _):
            .glacialWard
        case .onHitDamage(.burn, _):
            .moltenBulwark
        case .onHitDamage(.holy, _):
            .avatar
        case let .thorns(stacks) where stacks > 0:
            .thorns
        case .avatar, .nextHolyStrike:
            .avatar
        case let .damageKeywordOverride(keyword, _, _) where keyword == .holy:
            .avatar
        case .marked:
            .marked
        case let .recurringDamage(keyword, _, _) where keyword == .freeze:
            .blizzard
        case let .recurringDamage(keyword, _, _) where keyword == .stun:
            .earthquake
        default:
            nil
        }
    }

    public static func kind(from effects: [ActiveEffect]) -> CombatantBuffAuraKind? {
        let activeKinds = Set(effects.compactMap { kind(for: $0.effect) })
        for candidate in priorityOrder where activeKinds.contains(candidate) {
            return candidate
        }
        return nil
    }
}
