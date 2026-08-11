import Foundation
import TrinketContent
import TrinketCore

/// Persistent buff aura painted on a combatant card while qualifying effects remain.
public enum CombatantBuffAuraKind: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Shadowstep: next-strike double and/or evade-next-hit.
    case shadowstep
    /// Avatar: glowing with holy light — holding a next holy strike or holy damage
    /// override, or currently the source of recurring holy damage on the enemy.
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
        kind(from: effects, causesRecurringHolyDamage: false)
    }

    /// State-aware variant: also yields `.avatar` when `combatant` is the source of
    /// an active recurring holy damage effect. The DoT lives on the enemy, but the
    /// caster glows with holy light for its duration.
    public static func kind(
        for combatant: Combatant,
        in state: BattleState
    ) -> CombatantBuffAuraKind? {
        let causesRecurringHolyDamage = state.roster.allRuntimes.contains { runtime in
            runtime.activeEffects.contains { active in
                active.sourceActorID == combatant.id
                    && active.effect.isRecurringHolyDamage
            }
        }
        return kind(
            from: state.activeEffects(of: combatant),
            causesRecurringHolyDamage: causesRecurringHolyDamage
        )
    }

    private static func kind(
        from effects: [ActiveEffect],
        causesRecurringHolyDamage: Bool
    ) -> CombatantBuffAuraKind? {
        let hasShadowstep = effects.contains { active in
            switch active.effect.kind {
            case .nextStrikeDouble, .evadeNextHit:
                true
            default:
                false
            }
        }
        if hasShadowstep {
            return .shadowstep
        }

        let hasAvatar = causesRecurringHolyDamage || effects.contains { active in
            switch active.effect {
            case .nextHolyStrike:
                true
            case let .damageKeywordOverride(keyword, _, _):
                keyword == .holy
            default:
                false
            }
        }
        if hasAvatar {
            return .avatar
        }

        return nil
    }
}

private extension Effect {
    var isRecurringHolyDamage: Bool {
        if case let .recurringDamage(keyword, _, _) = self {
            return keyword == .holy
        }
        return false
    }
}
