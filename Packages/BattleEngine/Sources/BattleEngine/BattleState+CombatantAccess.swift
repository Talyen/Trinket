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
        if combatantID == hero.id {
            return heroModifiers
        }
        if combatantID == companion.id {
            return companionModifiers
        }
        if combatantID == enemy.id {
            return enemyModifiers
        }
        return .zero
    }
}
