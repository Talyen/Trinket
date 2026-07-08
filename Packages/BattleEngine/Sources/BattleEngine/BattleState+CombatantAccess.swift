import TrinketContent
import TrinketCore

extension BattleState {

    public var earnedGold: Int {
        gold - initialGold
    }

    public var isEnemyDefeated: Bool {
        roster.isEnemyDefeated
    }

    public var isHeroAlive: Bool {
        roster.hero.isAlive
    }

    public var isPetAlive: Bool {
        roster.pet.isAlive
    }

    public var isPartyDefeated: Bool {
        roster.isPartyDefeated
    }

    public var isBattleOver: Bool {
        isEnemyDefeated || isPartyDefeated
    }

    public var enemyAttackTarget: Combatant {
        roster.enemyAttackTarget
    }

    public var matchup: BattleMatchup {
        cachedMatchup
    }

    public func health(of combatant: Combatant) -> Int {
        roster.health(for: combatant)
    }

    public func maxHealth(of combatant: Combatant) -> Int {
        roster.maxHealth(for: combatant)
    }

    public func mana(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.currentMana ?? 0
    }

    public func maxMana(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.maxMana ?? 0
    }

    public func actionCount(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.actionCount ?? 0
    }

    public func activeEffects(of combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    public func effectSummaries(of combatant: Combatant) -> [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEffects(of: combatant))
    }


    public func modifiers(for combatantID: String) -> CombatModifierProfile {
        if combatantID == roster.hero.id { return heroModifiers }
        if combatantID == roster.pet.id { return petModifiers }
        if combatantID == roster.enemy.id { return enemyModifiers }
        return .zero
    }
}
