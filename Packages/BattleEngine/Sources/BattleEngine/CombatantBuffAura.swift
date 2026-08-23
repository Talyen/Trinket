import TrinketCore

/// Persistent buff aura painted on a combatant card while qualifying effects remain.
public enum CombatantBuffAuraKind: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Shadowstep: next-strike double and/or evade-next-hit.
    case shadowstep
    /// Predator's Focus: next-strike critical bonus.
    case predatorsFocus
    /// Glacial Ward: freeze on hit and/or freeze next attacker.
    case glacialWard
    /// Molten Bulwark: reactive burn ward.
    case moltenBulwark
    /// Thorns: active physical thorns reflection buffer.
    case thorns
    /// Avatar: glowing with holy light — holding the Avatar self-buff, a next
    /// holy strike, or a holy damage override.
    case avatar
    /// Marked: vulnerability debuff on an enemy.
    case marked
    /// Blizzard: recurring freeze storm on an enemy.
    case blizzard
    /// Earthquake: recurring stun channel on an enemy.
    case earthquake
}

/// Picks a buff aura from active effects for combatant-card presentation.
///
/// Independent of `CombatantBorderAccent` so Death's Door / Stun / Freeze can still
/// own their accent paths while a buff aura border may coexist (except when the
/// stroke itself is claimed by Death's Door pulse in the view layer).
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

    /// Maps an individual effect to its matching aura kind, if any.
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

    /// Highest-priority buff aura among `effects`, or `nil` when none qualify.
    public static func kind(from effects: [ActiveEffect]) -> CombatantBuffAuraKind? {
        let activeKinds = Set(effects.compactMap { kind(for: $0.effect) })
        for candidate in priorityOrder where activeKinds.contains(candidate) {
            return candidate
        }
        return nil
    }
}
