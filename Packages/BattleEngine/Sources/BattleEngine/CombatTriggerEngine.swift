import TrinketContent
import TrinketCore

package enum CombatTriggerEngine {
    static func traitName(
        for combatant: Combatant,
        in context: BattleState,
    ) -> String {
        context.modifiers(for: combatant.id).traitDisplayName ?? "Trait"
    }

    static func triggerAbilityName(
        _ key: String,
        for combatant: Combatant,
        fallback: String,
        in context: BattleState,
    ) -> String {
        context.modifiers(for: combatant.id).triggerAbilityName(key, fallback: fallback)
    }

    static func livingAllies(
        in context: BattleState,
    ) -> [(combatant: Combatant, profile: CombatModifierProfile)] {
        var allies: [(combatant: Combatant, profile: CombatModifierProfile)] = []
        if context.roster.hero.isAlive {
            allies.append((context.roster.hero.combatant, context.heroModifiers))
        }
        if context.roster.companion.isAlive {
            allies.append((context.roster.companion.combatant, context.companionModifiers))
        }
        return allies
    }

    static func livingAllyModifiers(in context: BattleState) -> [CombatModifierProfile] {
        livingAllies(in: context).map(\.profile)
    }

    static func livingPartyTriggers(in context: BattleState) -> CombatTraitTriggers {
        livingAllyModifiers(in: context).reduce(into: CombatTraitTriggers()) { merged, profile in
            merged.merge(profile.triggers)
        }
    }

    static func frozenTargetCannotBlockOrHeal(_ target: Combatant, in context: BattleState) -> Bool {
        guard target.role == .enemy else { return false }
        guard context.roster.hasControlStatus(for: target, keyword: .freeze) else { return false }
        return context.partyTriggers.frozenEnemyCannotBlockOrHeal
    }

    static func incomingHealMultiplier(for target: Combatant, in context: BattleState) -> Double {
        guard target.role == .enemy else { return 1 }
        let isBurning = context.roster.activeEffects(for: target).contains { $0.effect.keyword == .burn }
        guard isBurning else { return 1 }
        var reduction = 0.0
        if context.roster.hero.isAlive {
            reduction += context.heroModifiers.triggers.burnReducesEnemyHealingAndLeechPercent
        }
        if context.roster.companion.isAlive {
            reduction += context.companionModifiers.triggers.burnReducesEnemyHealingAndLeechPercent
        }
        return max(0, 1 - min(1, reduction))
    }

    static func partyDebuffsExpireFaster(in context: BattleState) -> Bool {
        (context.roster.hero.isAlive && context.heroModifiers.triggers.partyDebuffDurationHalved)
            || (context.roster.companion.isAlive && context.companionModifiers.triggers.partyDebuffDurationHalved)
    }

    static func companionReactingToHeroTriggers(in context: BattleState) -> CombatTraitTriggers? {
        guard context.roster.companion.isAlive else { return nil }
        return context.companionModifiers.triggers
    }

    static func resolveBonusHeal(
        amount: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> CombatOutcome {
        guard amount > 0 else { return .empty }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: traitName(for: source, in: context),
                    keyword: .health,
                ),
            ),
            in: &context,
        )
    }
}
