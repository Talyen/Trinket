import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DecayingDoTDetailsTests {
    @Test(arguments: [Keyword.burn, .poison])
    func `DoT details describe potency instead of promising damage from a fading stack`(keyword: Keyword) throws {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
        )
        let effect: Effect = keyword == .burn ? .burn(1) : .poison(1)
        battle.appendEffect(effect, to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let summary = try #require(EffectSummaryBuilder.build(for: battle.roster.enemy.activeEffects).first)
        #expect(summary.text.contains("1 \(keyword.rawValue) potency"))
        #expect(summary.text.contains("decays before"))

        _ = EffectTurnEngine.advanceEffects(on: battle.enemy, context: &battle)
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(!battle.roster.hasAffliction(keyword, on: battle.enemy))
    }
}
