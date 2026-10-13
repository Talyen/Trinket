import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `sacrificial guard spends companion block before hero health`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_block_t3_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 10
        DefensePoolEngine.set(6, on: battle.companion, in: &battle)

        _ = battle.resolveTestDamage(4, from: .enemy, to: .hero, options: .reaction())

        #expect(battle.roster.hero.currentHealth == 10)
        #expect(battle.roster.companion.currentHealth == battle.roster.companion.maxHealth)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 2)
    }
}
