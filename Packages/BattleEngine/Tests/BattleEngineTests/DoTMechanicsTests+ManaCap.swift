import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension DoTMechanicsTests {
    @Test(arguments: [0, 3])
    func `Burn Mana caps limit actual restoration after bonuses and doubling`(bonus: Int) {
        let cap = 2
        var profile = CombatModifierProfile.withTriggers {
            $0.onBurnDamageRestoreManaFlat = 1
            $0.onBurnDamageRestoreManaPerTurnCap = cap
            $0.manaGainDoubleChancePercent = 1
            $0.manaRestorationDoubleChancePercent = 1
        }
        profile.manaRestoredBonus = bonus
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 20, heroMana: 0, heroModifiers: profile,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        let events = battle.recordingEvents { state in
            for _ in 0 ..< 2 {
                await CombatTriggerEngine.restoreManaFromBurnDamage(
                    sourceActorID: state.hero.id, sourceTriggers: profile.triggers, in: &state,
                )
            }
        }

        #expect(battle.mana(of: battle.hero) == cap)
        #expect(battle.turnCadence.burnManaRestored[.hero] == cap)
        #expect(events.filter { $0.effectKind == .resourceGain && $0.keyword == .mana }.map(\.amount) == [cap])
    }
}
