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

    enum TraitFallback: String {
        case bloodfire = "Bloodfire"
        case cutpurse = "Cutpurse"
        case oathbound = "Oathbound"
        case healingFlames = "Healing Flames"
        case flameShield = "Flame Shield"
        case emberShield = "Ember Shield"
        case luckyClover = "Lucky Clover"
        case payoff = "Payoff"
        case confoundingLoot = "Confounding Loot"
        case generic = "Trait"
    }

    static func affixName(_ affix: AffixName) -> String {
        GameContent.itemAffixDefinition(matching: affix.rawValue)?.title ?? affix.rawValue
    }

    static func traitName(
        for combatant: Combatant,
        fallback: TraitFallback = .generic,
        in context: BattleState
    ) -> String {
        context.modifiers(for: combatant.id).traitDisplayName ?? fallback.rawValue
    }

    static func frozenTargetCannotBlockOrHeal(_ target: Combatant, in context: BattleState) -> Bool {
        guard context.roster.hasControlStatus(for: target, keyword: .freeze) else { return false }
        return context.heroModifiers.triggers.frozenEnemyCannotBlockOrHeal
            || context.companionModifiers.triggers.frozenEnemyCannotBlockOrHeal
    }

    static func incomingHealMultiplier(for target: Combatant, in context: BattleState) -> Double {
        let isBurning = context.roster.activeEffects(for: target).contains { $0.effect.keyword == .burn }
        guard isBurning else { return 1 }
        let reduction = max(
            context.heroModifiers.triggers.burnReducesEnemyHealingAndLeechPercent,
            context.companionModifiers.triggers.burnReducesEnemyHealingAndLeechPercent
        )
        return max(0, 1 - min(1, reduction))
    }

    /// True when any living ally has Purifying Aura.
    static func partyDebuffsExpireFaster(in context: BattleState) -> Bool {
        for owner in [BattleParticipant.hero, .companion] {
            let member = context.roster[owner]
            guard member.isAlive else { continue }
            if context.modifiers(for: member.id).triggers.partyDebuffDurationHalved {
                return true
            }
        }
        return false
    }
}
