import TrinketCore

/// Persistent buff aura painted on a combatant card while qualifying effects remain.
public enum CombatantBuffAuraKind: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Shadowstep: next-strike double and/or evade-next-hit.
    case shadowstep
    /// Avatar: glowing with holy light — holding the Avatar self-buff, a next
    /// holy strike, or a holy damage override.
    case avatar
}

/// Picks a buff aura from active effects for combatant-card presentation.
///
/// Independent of `CombatantBorderAccent` so Death's Door / Stun / Freeze can still
/// own their accent paths while a buff aura border may coexist (except when the
/// stroke itself is claimed by Death's Door pulse in the view layer).
public enum CombatantBuffAura: Sendable {
    /// Highest-priority buff aura among `effects`, or `nil` when none qualify.
    public static func kind(from effects: [ActiveEffect]) -> CombatantBuffAuraKind? {
        var hasAvatar = false
        for active in effects {
            switch active.effect {
            case .nextStrikeDouble, .evadeNextHit:
                return .shadowstep
            case .avatar, .nextHolyStrike:
                hasAvatar = true
            case let .damageKeywordOverride(keyword, _, _) where keyword == .holy:
                hasAvatar = true
            default:
                break
            }
        }
        return hasAvatar ? .avatar : nil
    }
}
