import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CleanseHealingRecipientTests {
    @Test(arguments: [15, 20])
    func `Healing Hymn restores only the cleansed ally`(companionHealth: Int) {
        var triggers = CombatTraitTriggers()
        triggers.cleanseBonusHeal = 2
        var battle = makeBattle(triggers: triggers, companionHealth: companionHealth)

        _ = EffectHandlersTestSupport.dispatch(
            .cleanse(nil), source: battle.hero, target: battle.companion, battle: &battle,
        )

        #expect(battle.health(of: battle.hero) == 5)
        #expect(battle.health(of: battle.companion) == min(20, companionHealth + 2))
        #expect(battle.roster.companion.activeEffects.isEmpty)
    }

    @Test func `Fae Mending still restores the lowest Health ally`() {
        var triggers = CombatTraitTriggers()
        triggers.cleanseSelfHeal = 2
        var battle = makeBattle(triggers: triggers, companionHealth: 15)

        _ = EffectHandlersTestSupport.dispatch(
            .cleanse(nil), source: battle.hero, target: battle.companion, battle: &battle,
        )

        #expect(battle.health(of: battle.hero) == 7)
        #expect(battle.health(of: battle.companion) == 15)
    }

    private func makeBattle(triggers: CombatTraitTriggers, companionHealth: Int) -> BattleState {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatModifierProfile(triggers: triggers), dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 5
        battle.roster.companion.currentHealth = companionHealth
        battle.appendEffect(.poison(3), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 0)
        return battle
    }
}
