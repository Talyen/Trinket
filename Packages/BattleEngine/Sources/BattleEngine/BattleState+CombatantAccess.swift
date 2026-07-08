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

    /// Skill-only charge wipe projection for battle presentation.
    /// Returns `nil` when the next cast is not a Skill (basic, ultimate, or mana fallback).
    func skillChargeProjection(of combatant: Combatant) -> SkillChargeProjection? {
        guard let runtime = roster.runtime(for: combatant), runtime.isAlive else {
            return nil
        }

        let turnNumber = runtime.actionCount + 1
        guard BattleTurnEngine.preferredTier(for: turnNumber) == .skill else {
            return nil
        }

        guard let ability = BattleTurnEngine.selectedAbility(
            for: combatant,
            turnNumber: turnNumber,
            currentMana: runtime.currentMana
        ), ability.tier == .skill else {
            return nil
        }

        return SkillChargeProjection(
            ability: ability,
            progress: runtime.actionChargeProgress(atTick: tickCount)
        )
    }

    func activeEffects(of combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    func effectSummaries(of combatant: Combatant) -> [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEffects(of: combatant))
    }

    func modifiers(for combatantID: String) -> CombatModifierProfile {
        if combatantID == roster.hero.id { return heroModifiers }
        if combatantID == roster.pet.id { return petModifiers }
        if combatantID == roster.enemy.id { return enemyModifiers }
        return .zero
    }
}
