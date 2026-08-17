import TrinketContent
import TrinketCore

public extension BattleState {
    var hero: Combatant {
        roster.hero.combatant
    }

    var companion: Combatant {
        roster.companion.combatant
    }

    var enemy: Combatant {
        roster.enemy.combatant
    }

    var earnedGold: Int {
        gold - initialGold
    }

    var isEnemyDefeated: Bool {
        roster.isEnemyDefeated
    }

    var isHeroAlive: Bool {
        roster.hero.isAlive
    }

    var isCompanionAlive: Bool {
        roster.companion.isAlive
    }

    var isPartyDefeated: Bool {
        roster.isPartyDefeated
    }

    var isBattleOver: Bool {
        isEnemyDefeated || isPartyDefeated
    }

    var enemyAttackTarget: Combatant {
        roster.enemyAttackTarget
    }

    func health(of combatant: Combatant) -> Int {
        roster.health(for: combatant)
    }

    func maxHealth(of combatant: Combatant) -> Int {
        roster.maxHealth(for: combatant)
    }

    func mana(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.currentMana ?? 0
    }

    func maxMana(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.maxMana ?? 0
    }

    func actionCount(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.actionCount ?? 0
    }

    func activeEffects(of combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    func effectSummaries(of combatant: Combatant) -> [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEffects(of: combatant))
    }

    func modifiers(for combatantID: String) -> CombatModifierProfile {
        if combatantID == roster.hero.id || combatantID == "hero" {
            return heroModifiers
        }
        if combatantID == roster.companion.id || combatantID == "companion" {
            return companionModifiers
        }
        if combatantID == roster.enemy.id || combatantID == "enemy" {
            return enemyModifiers
        }
        return .zero
    }

    /// Enemy target selection adjusted by Companion talents: Shadow Camouflage forces
    /// the Hero as target; High Altitude makes the Whelp untargetable above the threshold.
    var talentAdjustedEnemyTarget: Combatant {
        let base = roster.enemyAttackTarget
        if roster.hero.isAlive, companionModifiers.triggers.redirectSingleTargetAttacksToHero {
            return roster.hero.combatant
        }
        if base.id == roster.companion.id, roster.hero.isAlive,
           companionModifiers.triggers.untargetableAboveHealthPercent > 0,
           roster.maxHealth(for: roster.companion.combatant) > 0,
           Double(roster.health(for: roster.companion.combatant)) / Double(roster.maxHealth(for: roster.companion.combatant))
           >= companionModifiers.triggers.untargetableAboveHealthPercent {
            return roster.hero.combatant
        }
        return base
    }
}
