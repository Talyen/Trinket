import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct BlockPoolMutationRegressionTests {
    @Test func `preventing new Block does not erase retained or spent Block`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        DefensePoolEngine.set(12, on: battle.enemy, in: &battle)
        battle.roster.enemy.talents.turn.blockGainPrevented = true

        #expect(DefensePoolEngine.halveBlock(on: battle.enemy, in: &battle))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 6)
        _ = CombatExecutor.run { await DefensePoolEngine.decayBlock(on: battle.enemy, in: &battle) }
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 3)
        #expect(battle.applyBlockGain(4, to: battle.enemy, source: battle.enemy, abilityName: "Blocked gain").applied == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 3)
    }

    @Test func `resolved enemy Block does not repeat Burning gain reduction`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.burningEnemyBlockGainMultiplier = 0.5
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.appendEffect(.burn(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        let resolved = battle.applyBlockGain(
            8, to: battle.enemy, source: battle.enemy, abilityName: "Resolved gain", amountBasis: .resolved,
        )
        let base = battle.applyBlockGain(8, to: battle.enemy, source: battle.enemy, abilityName: "Base gain")
        #expect(resolved.applied == 8)
        #expect(base.applied == 4)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 12)
    }
}
