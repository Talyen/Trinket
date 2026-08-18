import TrinketContent
import TrinketCore

/// Resolves reactions from the unified trait-and-affix trigger profile.
package enum CombatTriggerEngine {
    enum AffixName: String {
        case absolving
        case aetherward
        case arcaneWard = "arcane_ward"
        case beacon
        case bloodPrice = "blood_price"
        case bounty
        case branding
        case cascading
        case disrupting
        case nullifying
        case payday
        case sanctum
        case secondWind = "second_wind"
        case sidestep
        case siphoning
        case symbiosis
        case unmaking
        case untouchable
        case whiplash
    }

    static func affixName(_ affix: AffixName) -> String {
        GameContent.itemAffixDefinition(matching: affix.rawValue)?.title ?? affix.rawValue
    }

    static func traitName(
        for combatant: Combatant,
        in context: BattleState
    ) -> String {
        context.modifiers(for: combatant.id).traitDisplayName ?? "Trait"
    }

    static func triggerAbilityName(
        _ key: String,
        for combatant: Combatant,
        fallback: String,
        in context: BattleState
    ) -> String {
        context.modifiers(for: combatant.id).triggerAbilityName(key, fallback: fallback)
    }

    /// Living hero and companion with their modifier profiles.
    static func livingAllies(
        in context: BattleState
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

    /// Modifier profiles for living hero and companion.
    static func livingAllyModifiers(in context: BattleState) -> [CombatModifierProfile] {
        livingAllies(in: context).map(\.profile)
    }

    static func livingPartyTriggers(in context: BattleState) -> CombatTraitTriggers {
        livingAllyModifiers(in: context).reduce(into: CombatTraitTriggers()) { merged, profile in
            merged.merge(profile.triggers)
        }
    }

    static func frozenTargetCannotBlockOrHeal(_ target: Combatant, in context: BattleState) -> Bool {
        guard context.roster.hasControlStatus(for: target, keyword: .freeze) else { return false }
        return context.partyTriggers.frozenEnemyCannotBlockOrHeal
    }

    static func incomingHealMultiplier(for target: Combatant, in context: BattleState) -> Double {
        let isBurning = context.roster.activeEffects(for: target).contains { $0.effect.keyword == .burn }
        guard isBurning else { return 1 }
        let reduction = livingAllyModifiers(in: context)
            .reduce(0) { $0 + $1.triggers.burnReducesEnemyHealingAndLeechPercent }
        return max(0, 1 - min(1, reduction))
    }

    /// True when any living ally has Purifying Aura.
    static func partyDebuffsExpireFaster(in context: BattleState) -> Bool {
        livingAllyModifiers(in: context).contains(where: \.triggers.partyDebuffDurationHalved)
    }

    /// Companion-authored `onHero*` reactions when the hero acts and the companion is alive.
    static func companionReactingToHeroTriggers(in context: BattleState) -> CombatTraitTriggers? {
        guard context.roster.companion.isAlive else { return nil }
        return context.companionModifiers.triggers
    }

    static func resolveBonusHeal(
        amount: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
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
                    displayAmount: amount
                )
            ),
            in: &context
        )
    }
}
