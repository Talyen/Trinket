import Testing
import TrinketContent
import TrinketContentTestSupport
@testable import BattleEngine

struct FrostCircuitRegressionTests {
    @Test func `Ray of Frost restores Mana for each Critical Hit`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wizard_mana_t4_1"])
        profile.triggers.criticalChanceBonus = 0.65
        var foundTwoCriticalHits = false

        for seed in UInt64(1) ... 16 {
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                heroAbilities: [.rayOfFrost], enemyMaxHealth: 100,
                heroMaxMana: 10, heroMana: 0, heroModifiers: profile,
                rngSeed: seed,
            )
            battle.appliesFightPacing = false
            let card = try #require(battle.hand.cards.first { $0.owner == .hero })
            let events = try battle.playCard(cardID: card.id)
            let criticalHits = events.count {
                $0.kind == .abilityDamage && $0.abilityID == Ability.rayOfFrost.id && $0.isCritical
            }
            guard criticalHits == 2 else { continue }

            foundTwoCriticalHits = true
            #expect(battle.roster.hero.currentMana == 2)
            break
        }
        #expect(foundTwoCriticalHits)
    }
}
