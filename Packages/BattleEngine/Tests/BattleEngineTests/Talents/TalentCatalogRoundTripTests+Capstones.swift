import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `living archive does not echo passive healing or revive its recipient`() throws {
        var battle = capstoneBattle(companion: ["library_owl_health_t4_1"])
        battle.roster.hero.currentHealth = 1
        _ = battle.healEmitting(amount: 4, target: battle.hero, source: battle.companion, abilityName: "Passive")
        let afterPassive = battle.roster.hero.currentHealth
        _ = battle.endTurn()
        #expect(battle.roster.hero.currentHealth == afterPassive)
        let card = Ability(
            id: "archive-heal", name: "Archive Heal", tier: .skill,
            targetedEffects: [TargetedEffect(.instantHeal(.health, 6), target: .hero)],
        )
        try playHeroTalentCard(card, owner: .companion, in: &battle)
        battle.roster.hero.currentHealth = 0
        _ = HealingEngine.resolveHealingEchoes(in: &battle)
        #expect(battle.roster.hero.currentHealth == 0)
    }

    @Test func `contagious joy shares only retriever overhealing`() {
        var battle = capstoneBattle(companion: ["golden_retriever_health_t4_1"])
        battle.roster.hero.currentHealth = 1
        battle.roster.companion.currentHealth = battle.roster.companion.maxHealth - 2
        _ = HealingEngine.resolveHeal(HealRequest(
            amount: 4, target: battle.companion, sourceActorID: battle.companion.id,
        ), in: &battle)
        #expect(battle.roster.companion.currentHealth == battle.roster.companion.maxHealth)
        #expect(battle.roster.hero.currentHealth == 3)
    }

    @Test func `lesson learned prevents reapplication but not damage until next turn`() throws {
        var battle = capstoneBattle(companion: ["library_owl_cleanse_t4_1", "library_owl_cleanse_t2_2"])
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle, source: .enemy)
        seedHeroTalentEffect(.burn(2), on: .companion, in: &battle, source: .enemy)
        try playHeroTalentCard(.cleanse, owner: .companion, in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
        #expect(talentPoints(.burn, on: .companion, in: battle) == 0)
        let health = battle.roster.hero.currentHealth
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .poison, potency: 3, to: battle.hero, sourceActorID: battle.enemy.id,
            application: .ability, in: &battle,
        )
        #expect(battle.roster.hero.currentHealth == health - 3)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
        seedHeroTalentEffect(.burn(3), on: .companion, in: &battle, source: .enemy)
        #expect(talentPoints(.burn, on: .companion, in: battle) == 0)
        _ = battle.endTurn()
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle, source: .enemy)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 2)
    }
}
