import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `returning bloom restores the wounded Hero when the Companion is full`() throws {
        var battle = capstoneBattle(hero: ["druid_poison_t2_2"])
        battle.roster.hero.currentHealth = 5
        seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle)

        let events = EffectTurnEngine.advanceAll(context: &battle)

        #expect(!battle.roster.hasAffliction(.poison, on: battle.enemy))
        #expect(battle.roster.hero.currentHealth == 8)
        #expect(battle.roster.companion.currentHealth == battle.roster.companion.maxHealth)
        let restoration = try #require(events.first { $0.abilityName == "Returning Bloom" })
        #expect(restoration.targetID == battle.hero.id)
        #expect(restoration.amount == 3)
    }
}
