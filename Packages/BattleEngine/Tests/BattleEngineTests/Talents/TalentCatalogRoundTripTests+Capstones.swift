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

    @Test func `wishspring shares overhealing with existing blessings and respects mana capacity`() {
        var battle = capstoneBattle(companion: ["pixie_health_t4_1", "pixie_health_t3_1", "pixie_health_t3_2"])
        battle.roster.hero.currentMana = 0
        _ = HealingEngine.resolveHeal(
            HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.companion.id), in: &battle,
        )
        #expect(battle.roster.hero.currentMana == 4)
        #expect(battle.roster.hero.maxHealth == 41)
        #expect(talentPoints(.shield, on: .hero, in: battle) == 7)
        battle.roster.hero.currentMana = 9
        _ = HealingEngine.resolveHeal(
            HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.companion.id), in: &battle,
        )
        #expect(battle.roster.hero.currentMana == 10)
        battle.roster.hero.currentHealth = 1
        battle.roster.hero.currentMana = 0
        _ = HealingEngine.resolveHeal(
            HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.companion.id), in: &battle,
        )
        #expect(battle.roster.hero.currentMana == 0)
    }

    @Test func `marrowmend emits block for leech overhealing without exceeding six`() {
        var battle = capstoneBattle(companion: ["risen_skeleton_leech_t4_1"])
        var options = DamageOperation.reaction()
        options.abilityHasLeech = true
        let request = DamageRequest(
            amount: 12, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.companion.id, options: options,
        )
        let result = battle.resolveDamage(request)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 6)
        #expect(result.events.contains { $0.abilityName == "Marrowmend" && $0.amount == 6 })
        _ = battle.resolveDamage(request)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 6)
        _ = battle.applyBlock(4, to: battle.companion, source: battle.companion, abilityName: "Other Block")
        _ = battle.resolveDamage(request)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 10)
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
