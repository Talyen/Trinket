import TrinketContent
import TrinketCore

public extension BattleState {
    var earnedGold: Int {
        gold - initialGold
    }

    var isEnemyDefeated: Bool {
        roster.isEnemyDefeated
    }

    var isHeroAlive: Bool {
        roster.hero.isAlive
    }

    var isPetAlive: Bool {
        roster.pet.isAlive
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

    var matchup: BattleMatchup {
        cachedMatchup
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
        if combatantID == roster.hero.id {
            return heroModifiers
        }
        if combatantID == roster.pet.id {
            return petModifiers
        }
        if combatantID == roster.enemy.id {
            return enemyModifiers
        }
        return .zero
    }
}
